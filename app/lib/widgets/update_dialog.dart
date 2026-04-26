import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;
  final VoidCallback onDismiss;
  const UpdateDialog({super.key, required this.updateInfo, required this.onDismiss});
  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isUpdating = false;
  bool _hasStarted = false; // 防重复：确保只启动一次
  double _progress = 0;
  String _stageText = '';
  CancelToken? _cancelToken;
  final AppUpdateService _updateService = AppUpdateService();
  bool _usePatch = true;

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _startUpdate() async {
    // 防重复：如果已经启动过，忽略重复调用
    if (_hasStarted || _isUpdating) return;
    _hasStarted = true;
    
    setState(() {
      _isUpdating = true;
      _progress = 0;
      _stageText = '';
      _cancelToken = CancelToken();
    });

    final updateInfo = widget.updateInfo;
    bool success = false;

    try {
      if (_usePatch && updateInfo.hasPatchUpdate) {
        success = await _updateService.incrementalUpdate(
          updateInfo,
          onProgress: (stage, progress) {
            if (mounted) setState(() { _stageText = stage; _progress = progress; });
          },
          cancelToken: _cancelToken,
        );
      } else if (updateInfo.fullPackage != null) {
        success = await _updateService.fullUpdate(
          updateInfo.fullPackage!.url,
          onProgress: (stage, progress) {
            if (mounted) setState(() { _stageText = stage; _progress = progress; });
          },
          cancelToken: _cancelToken,
        );
      }
    } catch (e) {
      print('更新异常: $e');
    }

    if (!mounted) return;
    
    // 检查是否被取消
    if (_cancelToken?.isCancelled == true) {
      _hasStarted = false;
      setState(() { _isUpdating = false; _stageText = '已取消'; _progress = 0; });
      return;
    }
    
    if (!success) {
      // 失败后允许重试
      _hasStarted = false;
      setState(() { _isUpdating = false; _stageText = '更新失败，点击重试'; _progress = 0; });
    }
  }

  void _cancel() {
    _cancelToken?.cancel();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final updateInfo = widget.updateInfo;
    final hasPatch = updateInfo.hasPatchUpdate;
    final fullSize = updateInfo.fullPackage?.size ?? 0;
    final patchSize = updateInfo.patchPackage?.size ?? 0;

    return WillPopScope(
      onWillPop: () async => !updateInfo.forceUpdate && !_isUpdating,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B8DB8).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.system_update, color: Color(0xFF5B8DB8)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('发现新版本', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('v${updateInfo.version}', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (updateInfo.releaseNotes != null && updateInfo.releaseNotes!.isNotEmpty) ...[
                Container(
                  constraints: const BoxConstraints(maxHeight: 80),
                  child: SingleChildScrollView(
                    child: Text(updateInfo.releaseNotes!, style: TextStyle(color: Colors.grey[700])),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (hasPatch) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.flash_on, size: 16, color: Colors.green[700]),
                          const SizedBox(width: 6),
                          Text('差量更新（推荐）',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green[700])),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('节省${updateInfo.patchSavingPercent}%流量',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      Row(
                        children: [
                          Text('差量: ${_updateService.formatFileSize(patchSize)}',
                            style: TextStyle(fontSize: 12, color: Colors.green[700])),
                          const SizedBox(width: 12),
                          Text('全量: ${_updateService.formatFileSize(fullSize)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500], decoration: TextDecoration.lineThrough)),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else
                Text('包大小: ${_updateService.formatFileSize(fullSize)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              if (_isUpdating) ...[
                const SizedBox(height: 16),
                if (_stageText.isNotEmpty)
                  Text(_stageText, style: const TextStyle(fontSize: 13, color: Color(0xFF5B8DB8))),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF5B8DB8)),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(_progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!updateInfo.forceUpdate && !_isUpdating)
                    TextButton(onPressed: _cancel, child: const Text('稍后')),
                  if (_isUpdating)
                    TextButton(onPressed: _cancel, child: const Text('取消'))
                  else
                    ElevatedButton(
                      onPressed: _startUpdate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5B8DB8),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(hasPatch ? '差量更新' : '立即更新'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showUpdateDialog(BuildContext context, UpdateInfo updateInfo) {
  showDialog(
    context: context,
    barrierDismissible: !updateInfo.forceUpdate,
    builder: (context) => UpdateDialog(updateInfo: updateInfo, onDismiss: () => Navigator.of(context).pop()),
  );
}
