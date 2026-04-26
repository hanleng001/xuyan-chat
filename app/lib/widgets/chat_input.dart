import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/theme.dart';

class ChatInput extends StatefulWidget {
  final Function(String text) onSendText;
  final Function(String filePath, String type) onSendMedia;
  final VoidCallback? onAiClick;
  final int aiMode; // 0=关闭, 1=半自动, 2=全自动
  final VoidCallback? onStartRecording;
  final VoidCallback? onStopRecording;
  final bool isRecording;
  final VoidCallback? onEmojiClick;
  final bool showEmoji;
  final Function(String text)? onTextChanged;

  const ChatInput({
    super.key,
    required this.onSendText,
    required this.onSendMedia,
    this.onAiClick,
    this.aiMode = 0,
    this.onStartRecording,
    this.onStopRecording,
    this.isRecording = false,
    this.onEmojiClick,
    this.showEmoji = false,
    this.onTextChanged,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  bool _showSendButton = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _textController.text;
    final show = text.trim().isNotEmpty;
    if (show != _showSendButton) {
      setState(() {
        _showSendButton = show;
      });
    }
    // 回调外部
    widget.onTextChanged?.call(text);
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    
    widget.onSendText(text);
    _textController.clear();
    _focusNode.requestFocus();
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );
      if (image != null) {
        widget.onSendMedia(image.path, 'image');
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );
      if (image != null) {
        widget.onSendMedia(image.path, 'image');
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
    }
  }

  void _showMediaOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? DarkColors.surface : AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.primary),
                title: const Text('相册'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                title: const Text('拍照'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file, color: AppColors.primary),
                title: const Text('文件'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: File picker
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: isDark ? DarkColors.surface : AppColors.surface,
        border: Border(
          top: BorderSide(
            color: isDark ? DarkColors.divider : AppColors.divider,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Voice button
          _buildIconButton(
            icon: widget.isRecording ? Icons.mic_off : Icons.mic_none,
            color: isDark ? DarkColors.textSecondary : AppColors.textSecondary,
            onTap: widget.isRecording
                ? widget.onStopRecording
                : widget.onStartRecording,
          ),
          const SizedBox(width: 4),
          
          // Text input / Recording indicator
          Expanded(
            child: widget.isRecording
                ? Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? Color(0xFF2A2A2A) : AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.fiber_manual_record,
                          color: Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '录音中...',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? DarkColors.textSecondary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSend(),
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? DarkColors.textPrimary : AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: '输入消息...',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDark ? Color(0xFF2A2A2A) : AppColors.background,
                        hintStyle: TextStyle(
                          color: isDark ? DarkColors.textLight : AppColors.textLight,
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 4),
          
          // Emoji button
          _buildIconButton(
            icon: widget.showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined,
            color: isDark ? DarkColors.textSecondary : AppColors.textSecondary,
            onTap: widget.onEmojiClick,
          ),
          const SizedBox(width: 4),
          
          // Media button / Send button / AI button
          if (_showSendButton)
            _buildSendButton(isDark)
          else ...[
            // AI button - 言
            _buildAiButton(isDark),
            const SizedBox(width: 4),
            // Plus button for media
            _buildIconButton(
              icon: Icons.add_circle_outline,
              color: isDark ? DarkColors.textSecondary : AppColors.textSecondary,
              onTap: _showMediaOptions,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return IconButton(
      icon: Icon(icon),
      color: color,
      iconSize: 24,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
      onPressed: onTap,
    );
  }

  Widget _buildSendButton(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      child: Material(
        color: isDark ? DarkColors.primary : AppColors.primary,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: _handleSend,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: const Icon(
              Icons.send,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAiButton(bool isDark) {
    // aiMode: 0=关闭(灰色), 1=半自动(蓝色), 2=全自动(蓝色+A标记)
    final isActive = widget.aiMode > 0;
    final isAuto = widget.aiMode == 2;
    
    Color bgColor, textColor;
    if (isActive) {
      bgColor = isDark ? const Color(0xFF5B8DB8) : const Color(0xFF7BAAD0);
      textColor = Colors.white;
    } else {
      bgColor = isDark ? const Color(0xFF3A3A4A) : const Color(0xFFD0D0D8);
      textColor = isDark ? Colors.white54 : Colors.white70;
    }
    
    return IconButton(
      onPressed: widget.onAiClick,
      iconSize: 32,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
      icon: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Text(
              '言',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            // 全自动模式显示小A标记
            if (isAuto)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'A',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}