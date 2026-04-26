class AppConstants {
  static const String appName = '序言';
  static const String appSlogan = '初见书序言，相伴为续言';
  static const String appVersion = '1.0.0';
  
  // SharedPreferences Keys
  static const String prefToken = 'token';
  static const String prefRefreshToken = 'refresh_token';
  static const String prefUserId = 'user_id';
  static const String prefUsername = 'username';
  static const String prefNickname = 'nickname';
  static const String prefAvatar = 'avatar';
  static const String prefTheme = 'theme_mode';
  static const String prefNotifications = 'notifications_enabled';
  static const String prefSound = 'sound_enabled';
  static const String prefVibration = 'vibration_enabled';
  static const String prefAiModel = 'ai_model';
  
  // 分页
  static const int pageSize = 20;
  static const int messagePageSize = 30;
  
  // 聊天相关
  static const int maxMessageLength = 2000;
  static const int maxVoiceDuration = 60; // 秒
  static const int voiceRecordMinDuration = 1; // 秒
  static const int timeThresholdMinutes = 5; // 时间戳显示间隔
  
  // 文件限制
  static const int maxImageSize = 10 * 1024 * 1024; // 10MB
  static const int maxVideoSize = 50 * 1024 * 1024; // 50MB
  static const int maxFileSize = 100 * 1024 * 1024; // 100MB
  
  // 消息类型
  static const String messageTypeText = 'text';
  static const String messageTypeImage = 'image';
  static const String messageTypeVoice = 'voice';
  static const String messageTypeFile = 'file';
  static const String messageTypeSystem = 'system';
  
  // 消息状态
  static const String statusSending = 'sending';
  static const String statusSent = 'sent';
  static const String statusDelivered = 'delivered';
  static const String statusRead = 'read';
  static const String statusFailed = 'failed';
  static const String statusRecalled = 'recalled';
  
  // 好友请求状态
  static const String friendRequestPending = 'pending';
  static const String friendRequestAccepted = 'accepted';
  static const String friendRequestRejected = 'rejected';
  
  // 对话类型
  static const String conversationTypeSingle = 'single';
  static const String conversationTypeGroup = 'group';
}

class ErrorMessages {
  static const String networkError = '网络连接失败，请检查网络';
  static const String serverError = '服务器错误，请稍后重试';
  static const String unknownError = '未知错误';
  static const String timeoutError = '请求超时，请重试';
  static const String unauthorized = '登录已过期，请重新登录';
  static const String notFound = '请求的资源不存在';
  
  static const String emptyUsername = '请输入用户名';
  static const String emptyPassword = '请输入密码';
  static const String emptyNickname = '请输入昵称';
  static const String passwordNotMatch = '两次密码输入不一致';
  static const String passwordTooShort = '密码长度不能少于6位';
  static const String invalidUsername = '用户名只能包含字母、数字和下划线';
  static const String usernameTooShort = '用户名长度不能少于3位';
  
  static const String emptyMessage = '消息不能为空';
  static const String sendFailed = '发送失败，请重试';
  
  static const String noPermission = '没有权限';
  static const String alreadyFriends = '你们已经是好友了';
}

class EmojiData {
  static const List<String> basicEmojis = [
    '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂',
    '🙂', '🙃', '😉', '😊', '😇', '🥰', '😍', '🤩',
    '😘', '😗', '☺️', '😚', '😙', '🥲', '😋', '😛',
    '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔',
    '🤐', '🤨', '😐', '😑', '😶', '😶‍🌫️', '😏', '😒',
    '🙄', '😬', '🤥', '😌', '😔', '😪', '🤤', '😴',
    '😷', '🤒', '🤕', '🤢', '🤮', '🤧', '🥵', '🥶',
    '😵', '😵‍💫', '🤯', '🤠', '🥳', '🥸', '😎', '🤓',
    '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍',
    '👍', '👎', '👌', '🤌', '🤏', '✌️', '🤞', '🤟',
    '🤘', '🤙', '👈', '👉', '👆', '👇', '☝️', '👍',
  ];
}
