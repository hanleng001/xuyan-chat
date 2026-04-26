import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'storage_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Dio? _dio;
  final StorageService _storage = StorageService();

  Dio get dio {
    _dio ??= _createDio();
    return _dio!;
  }

  Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: Duration(milliseconds: ApiConfig.connectTimeout),
        receiveTimeout: Duration(milliseconds: ApiConfig.receiveTimeout),
        sendTimeout: Duration(milliseconds: ApiConfig.sendTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          // 自动解包 {"success":true,"data":...}
          if (response.data is Map<String, dynamic>) {
            final body = response.data as Map<String, dynamic>;
            if (body.containsKey('data')) {
              response.data = body['data'];
            }
          }
          return handler.next(response);
        },
        onError: (DioException error, handler) async {
          // 仅处理 HTTP 401/403（不要用 statusCode == 401 比较 from response.data）
          final httpStatus = error.response?.statusCode;
          if (httpStatus == 401 || httpStatus == 403) {
            final refreshToken = await _storage.getRefreshToken();
            if (refreshToken != null) {
              try {
                final resp = await dio.post(
                  ApiEndpoints.refreshToken,
                  data: {'refreshToken': refreshToken},
                );
                // resp.data 已被拦截器解包，直接取 token
                dynamic newToken;
                final body = resp.data;
                if (body is Map) {
                  final data = body['data'];
                  if (data is Map) {
                    newToken = data['token'];
                  }
                  newToken ??= body['token'];
                }
                if (newToken != null) {
                  await _storage.setToken(newToken);
                  // 克隆请求再重试，避免复用已改变的 requestOptions
                  final clonedOpts = error.requestOptions.copyWith(
                    headers: {
                      ...error.requestOptions.headers,
                      'Authorization': 'Bearer $newToken',
                    },
                  );
                  final retryResp = await dio.fetch(clonedOpts);
                  return handler.resolve(retryResp);
                }
              } catch (e) {
                await _storage.clearAll();
              }
            }
          }
          return handler.next(error);
        },
      ),
    );
    return dio;
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> uploadFile(
    String path,
    String filePath, {
    String fieldName = 'file',
    Map<String, dynamic>? extraData,
    ProgressCallback? onSendProgress,
    String httpMethod = 'POST',
  }) async {
    try {
      final formData = FormData.fromMap({
        fieldName: await MultipartFile.fromFile(filePath),
        ...?extraData,
      });
      switch (httpMethod.toUpperCase()) {
        case 'PUT':
          return await dio.put(
            path,
            data: formData,
            onSendProgress: onSendProgress,
          );
        case 'PATCH':
          return await dio.patch(
            path,
            data: formData,
            onSendProgress: onSendProgress,
          );
        default:
          return await dio.post(
            path,
            data: formData,
            onSendProgress: onSendProgress,
          );
      }
    } catch (e) {
      rethrow;
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int? code;
  final dynamic data;

  ApiException(this.message, {this.code, this.data});

  factory ApiException.fromDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException('请求超时，请重试', code: -1);
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final data = error.response?.data;
        String message = data?['message'] ?? '请求失败';
        return ApiException(message, code: statusCode, data: data);
      case DioExceptionType.cancel:
        return ApiException('请求已取消', code: -2);
      default:
        return ApiException('网络错误，请检查网络连接', code: -3);
    }
  }

  @override
  String toString() => 'ApiException: $message (code: $code)';
}
