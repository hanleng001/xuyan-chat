import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/api_config.dart';

class UpdateInfo {
  final bool hasUpdate;
  final String? version;
  final int? buildNumber;
  final String? releaseNotes;
  final String? releaseDate;
  final bool forceUpdate;
  final FullPackage? fullPackage;
  final PatchPackage? patchPackage;
  final String message;

  UpdateInfo({
    required this.hasUpdate,
    this.version,
    this.buildNumber,
    this.releaseNotes,
    this.releaseDate,
    this.forceUpdate = false,
    this.fullPackage,
    this.patchPackage,
    required this.message,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      hasUpdate: json['hasUpdate'] ?? false,
      version: json['version'],
      buildNumber: json['buildNumber'],
      releaseNotes: json['releaseNotes'],
      releaseDate: json['releaseDate'],
      forceUpdate: json['forceUpdate'] ?? false,
      fullPackage: json['fullPackage'] != null
          ? FullPackage.fromJson(json['fullPackage'])
          : null,
      patchPackage: json['patchPackage'] != null
          ? PatchPackage.fromJson(json['patchPackage'])
          : null,
      message: json['message'] ?? '',
    );
  }

  bool get hasPatchUpdate {
    if (patchPackage == null || fullPackage == null) return false;
    return patchPackage!.size < fullPackage!.size;
  }

  int get patchSavingPercent {
    if (patchPackage == null || fullPackage == null) return 0;
    return ((1 - patchPackage!.size / fullPackage!.size) * 100).round();
  }
}

class FullPackage {
  final String url;
  final int size;
  final String hash;

  FullPackage({required this.url, required this.size, required this.hash});

  factory FullPackage.fromJson(Map<String, dynamic> json) {
    return FullPackage(url: json['url'], size: json['size'], hash: json['hash']);
  }
}

class PatchPackage {
  final String url;
  final int size;
  final String fromVersion;
  final String toVersion;

  PatchPackage({
    required this.url,
    required this.size,
    required this.fromVersion,
    required this.toVersion,
  });

  factory PatchPackage.fromJson(Map<String, dynamic> json) {
    return PatchPackage(
      url: json['url'],
      size: json['size'],
      fromVersion: json['fromVersion'],
      toVersion: json['toVersion'],
    );
  }
}

typedef UpdateService = AppUpdateService;

class AppUpdateService {
  static const _platform = MethodChannel('com.xuyan.xuyan/apk_patch');
  final Dio _dio = Dio();
  static const String _updateEndpoint = '/api/update/check';

  /// 检查更新
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      // 获取当前版本号，容错处理
      String currentVersion;
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        currentVersion = packageInfo.version;
        if (currentVersion.isEmpty) {
          currentVersion = _fallbackVersion;
        }
      } catch (e) {
        print('PackageInfo.fromPlatform() 失败: $e，使用兜底版本号');
        currentVersion = _fallbackVersion;
      }

      print('checkForUpdate: 当前版本=$currentVersion');
      final response = await _dio.get(
        '${ApiConfig.baseUrl}$_updateEndpoint',
        queryParameters: {'version': currentVersion, 'platform': 'android'},
      );
      if (response.statusCode == 200 && response.data['success']) {
        return UpdateInfo.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      print('检查更新失败: $e');
      return null;
    }
  }

  /// 兜底版本号（与 pubspec.yaml 保持一致，每次打包前更新）
  static const String _fallbackVersion = '1.1.4';

  /// 获取当前APK路径
  Future<String?> getApkPath() async {
    try {
      return await _platform.invokeMethod<String>('getApkPath');
    } catch (e) {
      print('获取APK路径失败: $e');
      return null;
    }
  }

  /// 下载文件（支持自动重试）
  Future<String?> _downloadFile(
    String url,
    String fileName, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
    int maxRetries = 3,
  }) async {
    final dir = await getTemporaryDirectory();
    final savePath = '${dir.path}/$fileName';
    var retries = 0;

    // 删除旧文件，避免续传冲突
    final oldFile = File(savePath);
    if (await oldFile.exists()) {
      await oldFile.delete();
      print('_downloadFile: 删除旧文件 $savePath');
    }

    while (retries <= maxRetries) {
      try {
        final response = await _dio.download(
          url,
          savePath,
          onReceiveProgress: (received, total) {
            onProgress?.call(received, total);
          },
          cancelToken: cancelToken,
          options: Options(
            receiveTimeout: const Duration(minutes: 10),
            sendTimeout: const Duration(minutes: 5),
            responseType: ResponseType.bytes,
          ),
        );

        final file = File(savePath);
        if (await file.exists() && await file.length() > 0) {
          return savePath;
        }
        return null;
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          print('_downloadFile: 用户取消');
          return null;
        }
        if (retries < maxRetries) {
          retries++;
          print('_downloadFile: 下载失败 (第$retries次), ${e.type}, 2秒后重试...');
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        print('_downloadFile: 重试耗尽, ${e.type}: ${e.message}');
        return null;
      } catch (e) {
        if (retries < maxRetries) {
          retries++;
          print('_downloadFile: 未知错误, 第$retries次重试...');
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        print('_downloadFile: 重试耗尽: $e');
        return null;
      }
    }
    return null;
  }

  /// 下载差量补丁
  Future<String?> downloadPatch(
    String url, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) => _downloadFile(url, 'xuyan_patch.patch', onProgress: onProgress, cancelToken: cancelToken);

  /// 下载完整APK
  Future<String?> downloadApk(
    String url, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) => _downloadFile(url, 'xuyan_update.apk', onProgress: onProgress, cancelToken: cancelToken);

  /// 应用差量补丁
  Future<String?> applyPatch(String patchPath) async {
    try {
      final currentApkPath = await getApkPath();
      if (currentApkPath == null) {
        print('applyPatch: 获取当前APK路径失败');
        return null;
      }

      final dir = await getTemporaryDirectory();
      final outputPath = '${dir.path}/xuyan_patched.apk';
      print('applyPatch: oldApk=$currentApkPath, patch=$patchPath, output=$outputPath');

      // 清理旧的合成文件
      final oldOutput = File(outputPath);
      if (await oldOutput.exists()) {
        await oldOutput.delete();
      }

      final result = await _platform.invokeMethod<String>('applyPatch', {
        'oldApkPath': currentApkPath,
        'patchPath': patchPath,
        'newApkPath': outputPath,
      });
      print('applyPatch result: $result');

      // 验证合成结果
      if (result != null) {
        final patchedFile = File(result);
        if (await patchedFile.exists()) {
          final size = await patchedFile.length();
          print('applyPatch: 合成文件大小 $size bytes');
          if (size < 1024 * 1024) {
            // APK应该至少几MB
            print('applyPatch: 合成文件过小，可能损坏');
            return null;
          }
          return result;
        }
      }
      return null;
    } catch (e) {
      print('应用补丁失败: $e');
      return null;
    }
  }

  /// 安装APK
  Future<bool> installApk(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('installApk: 文件不存在 $filePath');
        return false;
      }
      final fileSize = await file.length();
      print('installApk: 准备安装 $filePath, 大小=${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB');

      try {
        final result = await _platform.invokeMethod<bool>('installApk', {'apkPath': filePath});
        print('installApk: 原生安装结果=$result');
        if (result == true) return true;
      } catch (e) {
        print('installApk: 原生安装失败 $e');
      }

      final result = await OpenFile.open(filePath, type: 'application/vnd.android.package-archive');
      print('installApk: OpenFile结果=${result.type}');
      return result.type == ResultType.done;
    } catch (e) {
      print('安装失败: $e');
      return false;
    }
  }

  /// 差量更新流程（优先差量，失败自动退回全量）
  Future<bool> incrementalUpdate(
    UpdateInfo updateInfo, {
    void Function(String stage, double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final patchInfo = updateInfo.patchPackage;
    final fullInfo = updateInfo.fullPackage;

    if (patchInfo != null && updateInfo.hasPatchUpdate) {
      print('incrementalUpdate: 开始差量更新');
      onProgress?.call('下载差量补丁...', 0.05);
      final patchPath = await downloadPatch(
        patchInfo.url,
        onProgress: (received, total) {
          if (total > 0) {
            onProgress?.call('下载差量补丁...', 0.05 + (received / total) * 0.45);
          }
        },
        cancelToken: cancelToken,
      );

      if (cancelToken?.isCancelled == true) return false;

      if (patchPath != null) {
        print('incrementalUpdate: 补丁下载完成');
        onProgress?.call('正在合成新版本...', 0.55);
        final newApkPath = await applyPatch(patchPath);

        if (newApkPath != null) {
          print('incrementalUpdate: APK合成成功');
          onProgress?.call('正在安装...', 0.95);
          return await installApk(newApkPath);
        } else {
          print('incrementalUpdate: APK合成失败，自动退回全量下载');
        }
      } else {
        print('incrementalUpdate: 补丁下载失败，自动退回全量下载');
      }

      onProgress?.call('差量更新失败，开始全量下载...', 0.5);
      // 短暂延迟让用户看到提示
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (fullInfo != null) {
      return await fullUpdate(fullInfo.url, onProgress: onProgress, cancelToken: cancelToken);
    }
    return false;
  }

  /// 全量更新流程
  Future<bool> fullUpdate(
    String url, {
    void Function(String stage, double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    onProgress?.call('下载更新包...', 0);
    final apkPath = await downloadApk(
      url,
      onProgress: (received, total) {
        if (total > 0) {
          onProgress?.call('下载更新包...', received / total);
        }
      },
      cancelToken: cancelToken,
    );
    if (apkPath == null) return false;
    onProgress?.call('正在安装...', 0.95);
    return await installApk(apkPath);
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
