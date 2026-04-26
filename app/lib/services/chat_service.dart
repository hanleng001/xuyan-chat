import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../config/constants.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import 'api_service.dart';

class ChatService {
  final ApiService _api = ApiService();

  // 获取会话列表
  Future<List<ConversationModel>> getConversations() async {
    try {
      final response = await _api.get(ApiEndpoints.conversations);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((e) => ConversationModel.fromJson(e)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 获取与指定好友的聊天记录
  // GET /api/chat/messages/:friendId?limit=50&before=xxx
  Future<List<MessageModel>> getMessages({
    required String friendId,
    String? before,
    int limit = AppConstants.messagePageSize,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
      };
      if (before != null) {
        queryParams['before'] = before;
      }
      
      final response = await _api.get(
        '${ApiEndpoints.chatMessages}/$friendId',
        queryParameters: queryParams,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((e) => MessageModel.fromJson(e)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 撤回消息
  // POST /api/chat/recall/:messageId
  Future<void> recallMessage(String messageId) async {
    try {
      await _api.post(
        '${ApiEndpoints.recallMessage}/$messageId',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 标记消息已读
  // POST /api/chat/read/:friendId
  Future<void> markMessagesAsRead(String friendId) async {
    try {
      await _api.post(
        '${ApiEndpoints.readMessages}/$friendId',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 清空聊天记录
  // DELETE /api/chat/conversations/:friendId
  Future<void> clearMessages(String friendId) async {
    try {
      await _api.delete('${ApiEndpoints.conversations}/$friendId');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 上传媒体文件
  Future<String?> uploadMedia(
    String filePath, {
    String type = 'image',
    ProgressCallback? onProgress,
  }) async {
    try {
      final response = await _api.uploadFile(
        '/api/upload/media',
        filePath,
        fieldName: 'file',
        extraData: {'type': type},
        onSendProgress: onProgress,
      );
      if (response.statusCode == 200) {
        var url = response.data['url'] as String?;
        // 如果是相对路径，拼接完整URL
        if (url != null && !url.startsWith('http')) {
          url = '${ApiConfig.baseUrl}$url';
        }
        return url;
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
          return '会话或消息不存在';
        case 413:
          return '文件过大';
        case 500:
          return '服务器错误';
        default:
          return '请求失败';
      }
    }
    return '网络错误';
  }
}
