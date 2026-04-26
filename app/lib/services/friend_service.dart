import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/friend_request_model.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class FriendService {
  final ApiService _api = ApiService();

  // 获取好友列表
  Future<List<UserModel>> getFriends() async {
    try {
      final response = await _api.get(ApiEndpoints.friends);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((e) => UserModel.fromJson(e)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 搜索用户
  Future<List<UserModel>> searchUsers(String keyword) async {
    try {
      final response = await _api.get(
        ApiEndpoints.searchUsers,
        queryParameters: {'query': keyword},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((e) => UserModel.fromJson(e)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 发送好友请求
  // POST /api/friends/request {to, message}
  Future<void> sendFriendRequest({
    required String userId,
    String? message,
  }) async {
    try {
      await _api.post(
        ApiEndpoints.sendFriendRequest,
        data: {
          'to': userId,
          if (message != null) 'message': message,
        },
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 获取好友请求列表（收到的 + 自己发出的）
  Future<Map<String, List<FriendRequestModel>>> getFriendRequests() async {
    try {
      final response = await _api.get(ApiEndpoints.friendRequests);
      if (response.statusCode == 200) {
        final data = response.data;
        // 兼容旧格式（数组）和新格式（{received, sent}）
        if (data is List) {
          final list = data.map((e) => FriendRequestModel.fromJson(e as Map<String, dynamic>)).toList();
          return {'received': list, 'sent': <FriendRequestModel>[]};
        }
        final received = (data['received'] as List?)?.map((e) => FriendRequestModel.fromJson(e as Map<String, dynamic>)).toList() ?? [];
        final sent = (data['sent'] as List?)?.map((e) => FriendRequestModel.fromJson(e as Map<String, dynamic>)).toList() ?? [];
        return {'received': received, 'sent': sent};
      }
      return {'received': <FriendRequestModel>[], 'sent': <FriendRequestModel>[]};
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 获取待处理的好友请求数量
  Future<int> getPendingRequestCount() async {
    try {
      final response = await _api.get(
        '${ApiEndpoints.friendRequests}/count',
      );
      if (response.statusCode == 200) {
        return response.data['count'] ?? 0;
      }
      return 0;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 接受好友请求
  // POST /api/friends/accept/:requestId
  Future<void> acceptFriendRequest(String requestId) async {
    try {
      await _api.post(
        '${ApiEndpoints.acceptFriendRequest}/$requestId',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 拒绝好友请求
  // POST /api/friends/reject/:requestId
  Future<void> rejectFriendRequest(String requestId) async {
    try {
      await _api.post(
        '${ApiEndpoints.rejectFriendRequest}/$requestId',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 删除好友
  Future<void> removeFriend(String friendId) async {
    try {
      await _api.delete('${ApiEndpoints.deleteFriend}/$friendId');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 获取用户资料
  Future<UserModel?> getUserProfile(String userId) async {
    try {
      final response = await _api.get('/api/users/$userId');
      if (response.statusCode == 200) {
        return UserModel.fromJson(response.data);
      }
      return null;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response != null) {
      final data = e.response!.data;
      if (data is Map<String, dynamic> && data['message'] != null) {
        return data['message'];
      }
      switch (e.response!.statusCode) {
        case 400:
          return '请求参数错误';
        case 401:
          return '登录已过期';
        case 403:
          return '没有权限';
        case 404:
          return '用户不存在';
        case 409:
          return '好友请求已存在';
        case 500:
          return '服务器错误';
        default:
          return '请求失败';
      }
    }
    return '网络错误';
  }
}
