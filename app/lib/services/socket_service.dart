import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/api_config.dart';
import 'storage_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  final StorageService _storage = StorageService();
  bool _isConnected = false;
  bool _isAuthenticated = false;
  
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _onlineController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectController = StreamController<bool>.broadcast();
  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  final _authController = StreamController<bool>.broadcast();
  final _undeliverableController = StreamController<Map<String, dynamic>>.broadcast();
  final _deviceController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  Stream<Map<String, dynamic>> get onOnlineStatus => _onlineController.stream;
  Stream<bool> get onConnectionChange => _connectController.stream;
  Stream<Map<String, dynamic>> get onNotification => _notificationController.stream;
  Stream<bool> get onAuthResult => _authController.stream;
  Stream<Map<String, dynamic>> get onUndeliverable => _undeliverableController.stream;
  Stream<Map<String, dynamic>> get onDeviceChange => _deviceController.stream;

  bool get isConnected => _isConnected;
  bool get isAuthenticated => _isAuthenticated;
  io.Socket? get socket => _socket;

  Future<void> connect() async {
    if (_isConnected && _socket != null) return;

    final token = await _storage.getToken();
    if (token == null) return;

    _socket = io.io(
      ApiConfig.wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      _connectController.add(true);
      print('Socket connected');
      
      // 连接成功后发送认证事件
      _socket!.emit('auth', {'token': token});
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      _isAuthenticated = false;
      _connectController.add(false);
      print('Socket disconnected');
    });

    _socket!.onError((error) {
      print('Socket error: $error');
    });

    _socket!.onReconnect((_) {
      print('Socket reconnected');
      // 重连后重新认证
      _socket!.emit('auth', {'token': token});
    });

    // 认证成功
    _socket!.on('auth-success', (data) {
      _isAuthenticated = true;
      _authController.add(true);
      print('Socket authenticated: ${data['userId']}');
    });

    // 认证失败
    _socket!.on('auth-error', (data) {
      _isAuthenticated = false;
      _authController.add(false);
      print('Socket auth error: ${data['message']}');
    });

    // 私聊消息
    _socket!.on('private-message', (data) {
      _messageController.add({
        'type': 'message',
        ...Map<String, dynamic>.from(data),
      });
    });

    // 消息发送确认
    _socket!.on('message-sent', (data) {
      _messageController.add({
        'type': 'message-sent',
        ...Map<String, dynamic>.from(data),
      });
    });

    // 消息已读
    _socket!.on('message-read', (data) {
      _messageController.add({
        'type': 'read',
        ...Map<String, dynamic>.from(data),
      });
    });

    // 消息撤回通知
    _socket!.on('message-recalled', (data) {
      _messageController.add({
        'type': 'recall',
        ...Map<String, dynamic>.from(data),
      });
    });

    // 正在输入
    _socket!.on('typing', (data) {
      _typingController.add({
        'type': 'typing',
        ...Map<String, dynamic>.from(data),
      });
    });

    // 停止输入
    _socket!.on('stop-typing', (data) {
      _typingController.add({
        'type': 'stop-typing',
        ...Map<String, dynamic>.from(data),
      });
    });

    // 好友上线
    _socket!.on('friend-online', (data) {
      _onlineController.add({
        'type': 'online',
        ...Map<String, dynamic>.from(data),
      });
    });

    // 好友离线
    _socket!.on('friend-offline', (data) {
      _onlineController.add({
        'type': 'offline',
        ...Map<String, dynamic>.from(data),
      });
    });

    // 好友请求
    _socket!.on('friend-request', (data) {
      _notificationController.add({
        'type': 'friend-request',
        ...Map<String, dynamic>.from(data),
      });
    });

    // 好友请求被接受
    _socket!.on('friend-accepted', (data) {
      _notificationController.add({
        'type': 'friend-accepted',
        ...Map<String, dynamic>.from(data),
      });
    });

    // 好友请求被拒绝
    _socket!.on('friend-rejected', (data) {
      _notificationController.add({
        'type': 'friend-rejected',
        ...Map<String, dynamic>.from(data),
      });
    });

    // 好友被删除
    _socket!.on('friend-removed', (data) {
      _notificationController.add({
        'type': 'friend-removed',
        ...Map<String, dynamic>.from(data),
      });
    });

    // 错误
    _socket!.on('error', (data) {
      print('Socket server error: $data');
    });

    // 消息无法送达（非好友）
    _socket!.on('message-undeliverable', (data) {
      _undeliverableController.add(Map<String, dynamic>.from(data));
    });

    // 新设备登录通知
    _socket!.on('new-device-login', (data) {
      _deviceController.add({
        'type': 'new-device',
        ...Map<String, dynamic>.from(data),
      });
    });

    // 设备断开通知
    _socket!.on('device-disconnected', (data) {
      _deviceController.add({
        'type': 'device-disconnected',
        ...Map<String, dynamic>.from(data),
      });
    });

    // 被踢下线
    _socket!.on('kicked', (data) {
      _deviceController.add({
        'type': 'kicked',
        ...Map<String, dynamic>.from(data),
      });
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _isAuthenticated = false;
  }

  void reconnect() {
    disconnect();
    connect();
  }

  // 发送私聊消息 (通过 WebSocket)
  void sendPrivateMessage({
    required String to,
    required String type,
    String? content,
    String? mediaUrl,
    Map<String, dynamic>? mediaMeta,
  }) {
    if (_isConnected && _isAuthenticated) {
      _socket!.emit('private-message', {
        'to': to,
        'type': type,
        if (content != null) 'content': content,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        if (mediaMeta != null) 'mediaMeta': mediaMeta,
      });
    }
  }

  // 发送正在输入状态
  void sendTyping(String toUserId) {
    if (_isConnected && _isAuthenticated) {
      _socket!.emit('typing', {'to': toUserId});
    }
  }

  // 发送停止输入状态
  void sendStopTyping(String toUserId) {
    if (_isConnected && _isAuthenticated) {
      _socket!.emit('stop-typing', {'to': toUserId});
    }
  }

  // 标记消息已读 (通过 WebSocket)
  void markMessagesRead(String fromUserId) {
    if (_isConnected && _isAuthenticated) {
      _socket!.emit('message-read', {'from': fromUserId});
    }
  }

  // 撤回消息 (通过 WebSocket)
  void recallMessage(String messageId) {
    if (_isConnected && _isAuthenticated) {
      _socket!.emit('message-recall', {'messageId': messageId});
    }
  }

  // 获取当前在线设备列表
  void getDevices(Function(List<Map<String, dynamic>>) callback) {
    if (_isConnected && _isAuthenticated) {
      _socket!.emitWithAck('get-devices', null, ack: (data) {
        if (data is List) {
          callback(data.cast<Map<String, dynamic>>());
        } else {
          callback([]);
        }
      });
    } else {
      callback([]);
    }
  }

  // 踢出指定设备
  void kickDevice(String socketId, Function(bool) callback) {
    if (_isConnected && _isAuthenticated) {
      _socket!.emitWithAck('kick-device', {'socketId': socketId}, ack: (data) {
        if (data is Map) {
          callback(data['success'] == true);
        } else {
          callback(false);
        }
      });
    } else {
      callback(false);
    }
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _typingController.close();
    _onlineController.close();
    _connectController.close();
    _notificationController.close();
    _authController.close();
    _undeliverableController.close();
    _deviceController.close();
  }
}
