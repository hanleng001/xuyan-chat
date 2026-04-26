import 'dart:convert';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';
import 'api_service.dart';
import 'storage_service.dart';

class AuthService {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  Future<UserModel?> login(String account, String password) async {
    try {
      final response = await _api.post(
        ApiEndpoints.login,
        data: {
          'account': account,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final user = UserModel.fromJson(data['user']);
        
        await _storage.setToken(data['token']);
        if (data['refreshToken'] != null) {
          await _storage.setRefreshToken(data['refreshToken']);
        }
        await _storage.setUserId(user.id);
        await _storage.setUsername(user.xuyanId ?? user.phone ?? '');
        await _storage.setNickname(user.nickname);
        if (user.avatar != null) {
          await _storage.setAvatar(user.avatar!);
        }

        return user;
      }
      return null;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<UserModel?> register({
    required String phone,
    String? nickname,
    required String password,
  }) async {
    try {
      final response = await _api.post(
        ApiEndpoints.register,
        data: {
          'phone': phone,
          'nickname': nickname,
          'password': password,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final user = UserModel.fromJson(data['user']);
        
        await _storage.setToken(data['token']);
        if (data['refreshToken'] != null) {
          await _storage.setRefreshToken(data['refreshToken']);
        }
        await _storage.setUserId(user.id);
        await _storage.setUsername(user.xuyanId ?? user.phone ?? '');
        await _storage.setNickname(user.nickname);
        if (user.avatar != null) {
          await _storage.setAvatar(user.avatar!);
        }

        return user;
      }
      return null;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 后端不存在登出接口，只做本地清理
  Future<void> logout() async {
    await _storage.clearAll();
  }

  Future<UserModel?> getCurrentUser() async {
    try {
      final response = await _api.get(ApiEndpoints.userProfile);
      if (response.statusCode == 200) {
        return UserModel.fromJson(response.data);
      }
      return null;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 后端只支持 nickname 和 bio 两个字段
  Future<UserModel?> updateProfile({
    String? nickname,
    String? bio,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (nickname != null) data['nickname'] = nickname;
      if (bio != null) data['bio'] = bio;

      if (data.isEmpty) return null;

      final response = await _api.put(
        ApiEndpoints.updateProfile,
        data: data,
      );

      if (response.statusCode == 200) {
        final user = UserModel.fromJson(response.data);
        await _storage.setNickname(user.nickname);
        return user;
      }
      return null;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 后端参数: currentPassword, newPassword
  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      await _api.put(
        ApiEndpoints.changePassword,
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 上传头像: PUT /api/auth/profile (multipart, avatar字段)
  Future<String?> uploadAvatar(String filePath) async {
    try {
      final response = await _api.uploadFile(
        ApiEndpoints.uploadAvatar,
        filePath,
        fieldName: 'avatar',
        httpMethod: 'PUT',
      );

      if (response.statusCode == 200) {
        final user = UserModel.fromJson(response.data);
        final avatarUrl = user.avatar;
        if (avatarUrl != null) {
          await _storage.setAvatar(avatarUrl);
        }
        return avatarUrl;
      }
      return null;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<bool> checkAuth() async {
    final token = await _storage.getToken();
    return token != null && token.isNotEmpty;
  }

  /// 设置序言号（只能设置一次）
  Future<UserModel?> setXuyanId(String xuyanId) async {
    try {
      final response = await _api.post(
        ApiEndpoints.setXuyanId,
        data: {'xuyanId': xuyanId},
      );

      if (response.statusCode == 200) {
        final user = UserModel.fromJson(response.data);
        return user;
      }
      return null;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// 检查序言号是否可用
  Future<bool?> checkXuyanId(String xuyanId) async {
    try {
      final response = await _api.get(
        '${ApiEndpoints.checkXuyanId}?xuyanId=$xuyanId',
      );

      if (response.statusCode == 200) {
        return response.data['available'] as bool?;
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
          return '登录已过期，请重新登录';
        case 403:
          return '没有权限执行此操作';
        case 404:
          return '请求的资源不存在';
        case 409:
          return '用户名已存在';
        case 422:
          return '输入数据无效';
        case 500:
          return '服务器错误，请稍后重试';
        default:
          return '请求失败，请重试';
      }
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return '请求超时，请检查网络连接';
    }
    return '网络错误，请检查网络连接';
  }
}
