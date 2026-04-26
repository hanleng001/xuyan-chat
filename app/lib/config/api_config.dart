class ApiConfig {
  static const String baseUrl = 'http://101.35.160.58:3000';
  static const String wsUrl = 'http://101.35.160.58:3000';
  
  static const int connectTimeout = 30000;
  static const int receiveTimeout = 30000;
  static const int sendTimeout = 30000;
  
  static String get apiBase => baseUrl;
  static String get wsBase => wsUrl;
}

class ApiEndpoints {
  // 认证相关
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String setXuyanId = '/api/auth/xuyanId';
  static const String checkXuyanId = '/api/auth/check-xuyanId';
  // 登出接口不存在，前端只做本地清理
  static const String refreshToken = '/api/auth/refresh';
  
  // 用户相关
  static const String userProfile = '/api/auth/profile';
  static const String updateProfile = '/api/auth/profile'; // PUT, 支持 nickname, bio, avatar(multipart)
  static const String changePassword = '/api/auth/password'; // PUT, currentPassword, newPassword
  static const String searchUsers = '/api/friends/search';
  // 上传头像使用 PUT /api/auth/profile (multipart, avatar字段)
  static const String uploadAvatar = '/api/auth/profile';
  
  // 好友相关
  static const String friends = '/api/friends/list';
  static const String friendRequests = '/api/friends/requests';
  static const String sendFriendRequest = '/api/friends/request'; // POST, {to, message}
  static const String acceptFriendRequest = '/api/friends/accept'; // POST /api/friends/accept/:requestId
  static const String rejectFriendRequest = '/api/friends/reject'; // POST /api/friends/reject/:requestId
  static const String deleteFriend = '/api/friends'; // DELETE /api/friends/:friendId
  
  // 聊天相关
  static const String conversations = '/api/chat/conversations';
  // GET /api/chat/messages/:friendId?limit=50&before=xxx
  static const String chatMessages = '/api/chat/messages';
  // 撤回: POST /api/chat/recall/:messageId
  static const String recallMessage = '/api/chat/recall';
  // 标记已读: POST /api/chat/read/:friendId
  static const String readMessages = '/api/chat/read';
  
  // AI相关
  static const String aiConfig = '/api/ai/config'; // GET/PUT
  static const String aiSuggest = '/api/ai/suggest'; // POST
}
