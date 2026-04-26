import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config/constants.dart';
import 'storage_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FlutterLocalNotificationsPlugin? _notifications;
  final StorageService _storage = StorageService();
  bool _isInitialized = false;
  
  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNotification => _notificationController.stream;

  Future<void> init() async {
    if (_isInitialized) return;

    _notifications = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications!.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          try {
            final data = jsonDecode(details.payload!);
            _notificationController.add(data);
          } catch (e) {
            debugPrint('Notification payload decode error: $e');
          }
        }
      },
    );

    // Request permissions on Android 13+
    await _requestPermissions();

    _isInitialized = true;
  }

  Future<void> _requestPermissions() async {
    final android = _notifications?.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  Future<bool> shouldShowNotification() async {
    final enabled = await _storage.getNotificationsEnabled();
    return enabled;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool playSound = true,
    bool vibrate = true,
  }) async {
    if (!_isInitialized) await init();

    final enabled = await shouldShowNotification();
    if (!enabled) return;

    final soundEnabled = await _storage.getSoundEnabled();
    final vibrationEnabled = await _storage.getVibrationEnabled();

    final androidDetails = AndroidNotificationDetails(
      'xuyan_chat',
      '消息通知',
      channelDescription: '聊天消息通知',
      importance: Importance.high,
      priority: Priority.high,
      playSound: playSound && soundEnabled,
      enableVibration: vibrate && vibrationEnabled,
      vibrationPattern: (vibrate && vibrationEnabled) 
          ? Int64List.fromList([0, 500, 200, 500]) 
          : null,
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: const DefaultStyleInformation(true, true),
      channelShowBadge: true,
      autoCancel: true,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: playSound && soundEnabled,
      sound: playSound && soundEnabled ? 'default' : null,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications!.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> showMessageNotification({
    required String senderName,
    required String message,
    required String conversationId,
    String? senderId,
  }) async {
    final payload = jsonEncode({
      'type': 'message',
      'conversationId': conversationId,
      'senderId': senderId,
    });

    await showNotification(
      id: conversationId.hashCode,
      title: senderName,
      body: _getMessageBody(message),
      payload: payload,
    );
  }

  String _getMessageBody(String message) {
    if (message.startsWith('[图片]')) return '[图片]';
    if (message.startsWith('[语音]')) return '[语音]';
    if (message.startsWith('[文件]')) return '[文件]';
    if (message.length > 50) return '${message.substring(0, 50)}...';
    return message;
  }

  Future<void> showFriendRequestNotification({
    required String senderName,
    required String requestId,
  }) async {
    final payload = jsonEncode({
      'type': 'friend_request',
      'requestId': requestId,
    });

    await showNotification(
      id: requestId.hashCode,
      title: '新的好友请求',
      body: '$senderName 请求添加你为好友',
      payload: payload,
    );
  }

  Future<void> cancelNotification(int id) async {
    if (!_isInitialized) return;
    await _notifications!.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    if (!_isInitialized) return;
    await _notifications!.cancelAll();
  }

  void dispose() {
    _notificationController.close();
  }
}
