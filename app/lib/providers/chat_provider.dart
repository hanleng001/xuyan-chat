import 'dart:async';
import 'package:flutter/material.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../services/chat_service.dart';
import '../services/socket_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import 'auth_provider.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();
  final SocketService _socketService = SocketService();
  final StorageService _storage = StorageService();
  
  // 消息流（供全自动AI监听）
  final StreamController<MessageModel> _messageStreamController = StreamController<MessageModel>.broadcast();
  Stream<MessageModel> get messageStream => _messageStreamController.stream;
  
  List<ConversationModel> _conversations = [];
  Map<String, List<MessageModel>> _messages = {}; // key: friendId
  Map<String, bool> _typingUsers = {}; // key: "friendId"
  bool _isLoading = false;
  bool _isConnected = false;
  String? _errorMessage;
  String? _currentUserId;
  
  StreamSubscription? _messageSubscription;
  StreamSubscription? _typingSubscription;
  StreamSubscription? _onlineSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _notificationSubscription;
  StreamSubscription? _undeliverableSubscription;

  List<ConversationModel> get conversations => _conversations;
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  String? get errorMessage => _errorMessage;
  Map<String, bool> get typingUsers => _typingUsers;

  // 非好友发消息提示 {friendId: {title, subtitle, reason}}
  Map<String, Map<String, String>> _undeliverableHints = {};
  Map<String, Map<String, String>> get undeliverableHints => _undeliverableHints;

  // 使用 friendId 作为消息缓存的 key
  List<MessageModel> getMessages(String friendId) {
    return _messages[friendId] ?? [];
  }

  ConversationModel? getConversationByFriendId(String friendId) {
    try {
      return _conversations.firstWhere((c) => c.id == friendId);
    } catch (e) {
      return null;
    }
  }

  bool isUserTyping(String friendId) {
    return _typingUsers[friendId] ?? false;
  }

  Future<void> init(AuthProvider authProvider) async {
    _currentUserId = authProvider.userId;
    
    if (authProvider.isAuthenticated) {
      await _socketService.connect();
      await loadConversations();
      _listenToSocketEvents();
    }
  }

  void _listenToSocketEvents() {
    _messageSubscription = _socketService.onMessage.listen(_handleSocketMessage);
    _typingSubscription = _socketService.onTyping.listen(_handleTypingEvent);
    _onlineSubscription = _socketService.onOnlineStatus.listen(_handleOnlineEvent);
    _connectionSubscription = _socketService.onConnectionChange.listen((connected) {
      _isConnected = connected;
      notifyListeners();
    });
    _notificationSubscription = _socketService.onNotification.listen(_handleNotification);
    _undeliverableSubscription = _socketService.onUndeliverable.listen(_handleUndeliverable);
  }

  void _handleSocketMessage(Map<String, dynamic> data) {
    final type = data['type'];
    
    if (type == 'read') {
      _handleMessageRead(data);
    } else if (type == 'recall') {
      _handleMessageRecall(data);
    } else if (type == 'message-sent') {
      _handleMessageSent(data);
    } else if (type == 'message') {
      _handleNewMessage(data);
    }
  }

  void _handleNewMessage(Map<String, dynamic> data) {
    try {
      final messageRaw = data['message'];
      if (messageRaw == null) return;
      
      final Map<String, dynamic> messageData = messageRaw is Map<String, dynamic> 
          ? messageRaw 
          : <String, dynamic>{};
      
      final message = MessageModel.fromJson(messageData);
      
      // 判断消息方向
      final isFromMe = message.senderId == _currentUserId;
      final friendId = isFromMe ? message.receiverId : message.senderId;
      
      if (friendId == null || friendId.isEmpty) return;
      
      // 标记 isMe
      final messageWithFlag = message.copyWith(isMe: isFromMe);
      
      // Add message to local cache
      if (_messages.containsKey(friendId)) {
        final exists = _messages[friendId]!.any((m) => m.id == message.id);
        if (!exists) {
          _messages[friendId]!.add(messageWithFlag);
        }
      } else {
        _messages[friendId] = [messageWithFlag];
      }
      
      // 广播到消息流
      if (!_messageStreamController.isClosed) {
        _messageStreamController.add(messageWithFlag);
      }
      
      // Update conversation last message
      final convIndex = _conversations.indexWhere((c) => c.id == friendId);
      if (convIndex != -1) {
        final conv = _conversations[convIndex];
        _conversations[convIndex] = conv.copyWith(
          lastMessage: messageWithFlag,
          updatedAt: messageWithFlag.createdAt,
          unreadCount: isFromMe ? 0 : (conv.unreadCount + 1),
        );
        final convToUpdate = _conversations.removeAt(convIndex);
        _conversations.insert(0, convToUpdate);
      } else if (!isFromMe) {
        // 没有会话记录，重新加载会话列表
        loadConversations();
      }
      
      // 发送本地通知（对方发的消息才通知）
      if (!isFromMe) {
        _showMessageNotification(messageWithFlag, friendId);
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error handling new message: $e');
    }
  }

  void _showMessageNotification(MessageModel message, String friendId) async {
    try {
      // 查找会话中的好友名称
      String senderName = '用户';
      final conv = _conversations.firstWhere(
        (c) => c.id == friendId,
        orElse: () => ConversationModel(
          id: friendId,
          type: 'single',
          participants: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          otherUserNickname: '用户',
        ),
      );
      senderName = conv.displayName;
      
      await NotificationService().showMessageNotification(
        senderName: senderName,
        message: message.content,
        conversationId: friendId,
        senderId: message.senderId,
      );
    } catch (e) {
      debugPrint('Show notification error: $e');
    }
  }

  void _handleMessageSent(Map<String, dynamic> data) {
    // 收到服务器确认的消息发送，替换临时消息
    try {
      final messageRaw = data['message'];
      if (messageRaw == null) return;
      
      final Map<String, dynamic> messageData = messageRaw is Map<String, dynamic> 
          ? messageRaw 
          : <String, dynamic>{};
      
      final sentMessage = MessageModel.fromJson(messageData);
      final friendId = sentMessage.receiverId;
      
      if (friendId == null || friendId.isEmpty) return;
      
      final messages = _messages[friendId];
      if (messages == null) return;
      
      // 找到临时消息并替换
      for (var i = 0; i < messages.length; i++) {
        if (messages[i].id.startsWith('temp_') && 
            messages[i].type == sentMessage.type && 
            messages[i].content == sentMessage.content) {
          _messages[friendId]![i] = sentMessage.copyWith(isMe: true, status: MessageStatus.sent);
          break;
        }
      }
      
      // Update conversation
      final convIndex = _conversations.indexWhere((c) => c.id == friendId);
      if (convIndex != -1) {
        final conv = _conversations[convIndex];
        _conversations[convIndex] = conv.copyWith(
          lastMessage: sentMessage.copyWith(isMe: true),
          updatedAt: sentMessage.createdAt,
        );
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error handling message sent: $e');
    }
  }

  void _handleMessageRead(Map<String, dynamic> data) {
    // data: {from: userId, by: userId}
    final from = data['from'] as String?;
    final by = data['by'] as String?;
    
    if (from == null) return;
    
    // from 是发送者（即当前用户的好友），by 是标记已读的人
    // 当好友标记了我们发送的消息为已读
    final friendId = from;
    final messages = _messages[friendId];
    if (messages == null) return;
    
    for (var i = 0; i < messages.length; i++) {
      if (messages[i].isMe && messages[i].status != MessageStatus.read) {
        messages[i] = messages[i].copyWith(status: MessageStatus.read);
      }
    }
    
    notifyListeners();
  }

  void _handleMessageRecall(Map<String, dynamic> data) {
    // data: {messageId: xxx, by: userId}
    final messageId = data['messageId'] as String?;
    
    if (messageId == null) return;
    
    // 在所有会话中查找该消息
    for (final entry in _messages.entries) {
      final messages = entry.value;
      for (var i = 0; i < messages.length; i++) {
        if (messages[i].id == messageId) {
          _messages[entry.key]![i] = messages[i].copyWith(
            recalled: true,
            status: MessageStatus.recalled,
          );
          break;
        }
      }
    }
    
    notifyListeners();
  }

  void _handleTypingEvent(Map<String, dynamic> data) {
    // data: {from: userId} 或 {from: userId, type: 'stop-typing'}
    final from = data['from'] as String?;
    final type = data['type'] as String?;
    
    if (from == null) return;
    if (from == _currentUserId) return;
    
    _typingUsers[from] = type == 'stop-typing' ? false : true;
    notifyListeners();
  }

  void _handleOnlineEvent(Map<String, dynamic> data) {
    final type = data['type'];
    final userId = data['userId'] as String?;
    
    if (userId == null) return;
    
    for (var i = 0; i < _conversations.length; i++) {
      final conv = _conversations[i];
      if (conv.otherUserId == userId) {
        _conversations[i] = conv.copyWith(
          otherUserOnline: type == 'online',
          otherUserLastSeen: type == 'offline' ? DateTime.now() : null,
        );
      }
    }
    
    notifyListeners();
  }

  void _handleNotification(Map<String, dynamic> data) {
    final type = data['type'];
    if (type == 'friend-accepted') {
      loadConversations();
      onFriendRequestReceived?.call();
    } else if (type == 'friend-request') {
      onFriendRequestReceived?.call();
      // 发送本地通知
      final fromName = data['nickname'] ?? data['xuyanId'] ?? '用户';
      NotificationService().showFriendRequestNotification(
        senderName: fromName,
        requestId: data['requestId'] ?? '',
      );
    } else if (type == 'friend-removed') {
      // 好友被删除，清理会话和消息
      final userId = data['userId'] as String?;
      if (userId != null) {
        _conversations.removeWhere((c) => c.id == userId);
        _messages.remove(userId);
        notifyListeners();
      }
    }
  }

  // 好友请求回调（由外部设置，用于刷新ContactProvider）
  void Function()? onFriendRequestReceived;

  void _handleUndeliverable(Map<String, dynamic> data) {
    final to = data['to'] as String?;
    if (to == null) return;
    _undeliverableHints[to] = {
      'title': data['title'] as String? ?? '📖 对方已不在你的序言中',
      'subtitle': data['subtitle'] as String? ?? '如需续写，请重新添加好友',
      'reason': data['reason'] as String? ?? 'not-friends',
    };
    // 移除临时消息（sending状态的消息标记为failed）
    final messages = _messages[to];
    if (messages != null) {
      for (var i = 0; i < messages.length; i++) {
        if (messages[i].status == MessageStatus.sending) {
          messages[i] = messages[i].copyWith(status: MessageStatus.failed);
        }
      }
    }
    notifyListeners();
  }

  /// 清除某个好友的无法送达提示（重新添加好友后调用）
  void clearUndeliverableHint(String friendId) {
    _undeliverableHints.remove(friendId);
    notifyListeners();
  }

  Future<void> loadConversations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _conversations = await _chatService.getConversations();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // 加载消息使用 friendId
  Future<void> loadMessages(String friendId, {String? before}) async {
    try {
      final messages = await _chatService.getMessages(
        friendId: friendId,
        before: before,
      );
      
      // 标记 isMe
      final messagesWithFlag = messages.map((m) {
        final isMe = m.senderId == _currentUserId;
        return m.copyWith(isMe: isMe);
      }).toList();
      
      // 后端已返回正序（最旧在前），直接使用，配合 ListView.reverse=true
      final sorted = messagesWithFlag.toList();
      
      if (before == null) {
        _messages[friendId] = sorted;
      } else {
        // 加载更早的消息，插到前面
        _messages[friendId] = [...sorted, ...(_messages[friendId] ?? [])];
      }
      
      // 标记已读
      markAsRead(friendId);
      
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // 发送消息使用 WebSocket
  Future<void> sendMessage({
    required String friendId,
    required String type,
    required String content,
    String? mediaUrl,
    Map<String, dynamic>? mediaMeta,
  }) async {
    try {
      // 检查是否已连接
      if (!_isConnected) {
        // 离线模式：直接标记失败
        final failedMessage = MessageModel(
          id: 'failed_${DateTime.now().millisecondsSinceEpoch}',
          senderId: _currentUserId ?? '',
          receiverId: friendId,
          type: type,
          content: content,
          mediaUrl: mediaUrl,
          mediaMeta: mediaMeta,
          status: MessageStatus.failed,
          createdAt: DateTime.now(),
          isMe: true,
        );
        if (_messages.containsKey(friendId)) {
          _messages[friendId]!.add(failedMessage);
        } else {
          _messages[friendId] = [failedMessage];
        }
        notifyListeners();
        return;
      }
      
      // Create local optimistic message
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final localMessage = MessageModel(
        id: tempId,
        senderId: _currentUserId ?? '',
        receiverId: friendId,
        type: type,
        content: content,
        mediaUrl: mediaUrl,
        mediaMeta: mediaMeta,
        status: MessageStatus.sending,
        createdAt: DateTime.now(),
        isMe: true,
      );
      
      // Add to local cache
      if (_messages.containsKey(friendId)) {
        _messages[friendId]!.add(localMessage);
      } else {
        _messages[friendId] = [localMessage];
      }
      
      // Update conversation
      final convIndex = _conversations.indexWhere((c) => c.id == friendId);
      if (convIndex != -1) {
        final conv = _conversations[convIndex];
        _conversations[convIndex] = conv.copyWith(
          lastMessage: localMessage,
          updatedAt: localMessage.createdAt,
        );
        // Move to top
        final convToUpdate = _conversations.removeAt(convIndex);
        _conversations.insert(0, convToUpdate);
      }
      
      notifyListeners();
      
      // 通过 WebSocket 发送
      _socketService.sendPrivateMessage(
        to: friendId,
        type: type,
        content: content,
        mediaUrl: mediaUrl,
        mediaMeta: mediaMeta,
      );
      // 实际的确认会通过 message-sent 事件到达
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> recallMessage(String friendId, String messageId) async {
    try {
      // 通过 Socket 撤回（通知对方）
      _socketService.recallMessage(messageId);
      
      // 同时通过 HTTP API 撤回（同步数据库）
      await _chatService.recallMessage(messageId);
      
      // Update local message
      final messages = _messages[friendId];
      if (messages != null) {
        for (var i = 0; i < messages.length; i++) {
          if (messages[i].id == messageId) {
            messages[i] = messages[i].copyWith(
              recalled: true,
              status: MessageStatus.recalled,
            );
            break;
          }
        }
      }
      
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteMessage(String friendId, String messageId) async {
    try {
      // 本地删除（仅从列表移除，不删服务端数据）
      final messages = _messages[friendId];
      if (messages != null) {
        messages.removeWhere((m) => m.id == messageId);
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // 标记消息已读
  Future<void> markAsRead(String friendId) async {
    try {
      await _chatService.markMessagesAsRead(friendId);
      
      // Update conversation unread count
      final convIndex = _conversations.indexWhere((c) => c.id == friendId);
      if (convIndex != -1) {
        _conversations[convIndex] = _conversations[convIndex].copyWith(unreadCount: 0);
      }
      
      notifyListeners();
    } catch (e) {
      // Ignore read errors
    }
  }

  void sendTypingStatus(String friendId, bool isTyping) {
    if (isTyping) {
      _socketService.sendTyping(friendId);
    } else {
      _socketService.sendStopTyping(friendId);
    }
  }

  Future<String?> uploadMedia(String filePath, {String type = 'image'}) async {
    try {
      return await _chatService.uploadMedia(filePath, type: type);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> clearMessages(String friendId) async {
    try {
      await _chatService.clearMessages(friendId);
      _messages.remove(friendId);
      // 更新会话列表，清空最后一条消息
      final convIndex = _conversations.indexWhere((c) => c.id == friendId);
      if (convIndex != -1) {
        _conversations[convIndex] = _conversations[convIndex].copyWith(
          clearLastMessage: true,
          unreadCount: 0,
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('清空消息失败: $e');
    }
  }

  @override
  void dispose() {
    _messageStreamController.close();
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _onlineSubscription?.cancel();
    _connectionSubscription?.cancel();
    _notificationSubscription?.cancel();
    _undeliverableSubscription?.cancel();
    super.dispose();
  }
}
