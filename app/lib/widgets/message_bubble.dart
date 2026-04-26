import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../config/api_config.dart';
import '../models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showAvatar;
  final String? senderName;
  final String? senderAvatar;

  const MessageBubble({
    super.key,
    required this.message,
    this.onTap,
    this.onLongPress,
    this.showAvatar = true,
    this.senderName,
    this.senderAvatar,
  });

  static String _fullUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiConfig.baseUrl}$path';
  }

  bool get _isMe => message.isMe;
  
  Color get _bubbleColor {
    final isDark = false; // Will be overridden by theme
    if (_isMe) {
      return const Color(0xFF95EC69); // WeChat style green
    }
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMe = message.isMe;

    if (message.isRecalled) {
      return _buildRecalledMessage(context);
    }

    if (message.type == MessageType.system) {
      return _buildSystemMessage(context);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe && showAvatar) ...[
            _buildAvatar(context, isDark),
            const SizedBox(width: 8),
          ],
          if (isMe && showAvatar) const SizedBox(width: 40),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe && senderName != null && senderName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 2),
                    child: Text(
                      senderName!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? DarkColors.textTertiary : AppColors.textTertiary,
                      ),
                    ),
                  ),
                GestureDetector(
                  onTap: onTap,
                  onLongPress: onLongPress,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.65,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isMe 
                          ? (isDark ? DarkColors.myBubble : Color(0xFF95EC69))
                          : (isDark ? DarkColors.otherBubble : Colors.white),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(isMe ? 16 : 4),
                        topRight: Radius.circular(isMe ? 4 : 16),
                        bottomLeft: const Radius.circular(16),
                        bottomRight: const Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _buildMessageContent(context, isDark),
                  ),
                ),
                const SizedBox(height: 2),
                if (isMe) _buildStatus(isDark),
              ],
            ),
          ),
          if (isMe && showAvatar) ...[
            const SizedBox(width: 8),
            _buildAvatar(context, isDark),
          ],
          if (!isMe && showAvatar) const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, bool isDark) {
    // Simple circle avatar for message bubbles
    final s = 40.0;
    final color = isDark ? DarkColors.primary : AppColors.primary;
    
    if (message.senderAvatar != null && message.senderAvatar!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          _fullUrl(message.senderAvatar),
          width: s,
          height: s,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(s, color),
        ),
      );
    }
    return _buildAvatarPlaceholder(s, color);
  }

  Widget _buildAvatarPlaceholder(double s, Color color) {
    final initial = message.senderName?.isNotEmpty == true 
        ? message.senderName![0].toUpperCase() 
        : '?';
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, bool isDark) {
    switch (message.type) {
      case MessageType.text:
        return Text(
          message.content,
          style: TextStyle(
            fontSize: 15,
            color: message.isMe 
                ? (isDark ? DarkColors.textPrimary : Colors.black87)
                : (isDark ? DarkColors.textPrimary : AppColors.textPrimary),
          ),
        );
      
      case MessageType.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
            child: Image.network(
              _fullUrl(message.mediaUrl),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 150,
                height: 100,
                color: (isDark ? DarkColors.otherBubble : Colors.grey[200]),
                child: Icon(
                  Icons.broken_image_outlined,
                  color: isDark ? DarkColors.textTertiary : AppColors.textTertiary,
                ),
              ),
            ),
          ),
        );
      
      case MessageType.voice:
        return _buildVoiceMessage(context, isDark);
      
      case MessageType.system:
        return const SizedBox.shrink();
      
      default:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file,
              size: 20,
              color: isDark ? DarkColors.textSecondary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                message.content,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? DarkColors.textPrimary : AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
    }
  }

  Widget _buildVoiceMessage(BuildContext context, bool isDark) {
    final duration = message.mediaDuration ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.isMe)
          Text(
            '${duration}"',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? DarkColors.textSecondary : AppColors.textSecondary,
            ),
          ),
        if (message.isMe) const SizedBox(width: 6),
        Icon(
          Icons.play_arrow,
          size: 20,
          color: isDark ? DarkColors.textPrimary : AppColors.textPrimary,
        ),
        // Voice wave animation placeholder
        Container(
          width: duration.clamp(40.0, 120.0).toDouble(),
          height: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: List.generate(
              3,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                width: 2,
                height: (i == 1 ? 14 : 8).toDouble(),
                decoration: BoxDecoration(
                  color: isDark ? DarkColors.textPrimary : AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
        ),
        if (!message.isMe) const SizedBox(width: 6),
        if (!message.isMe)
          Text(
            '${duration}"',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? DarkColors.textSecondary : AppColors.textSecondary,
            ),
          ),
      ],
    );
  }

  Widget _buildStatus(bool isDark) {
    final statusColor = _getStatusColor(isDark);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          _formatTime(message.createdAt),
          style: TextStyle(
            fontSize: 11,
            color: isDark ? DarkColors.textLight : AppColors.textLight,
          ),
        ),
        const SizedBox(width: 4),
        _buildStatusIcon(statusColor),
      ],
    );
  }

  Color _getStatusColor(bool isDark) {
    switch (message.status) {
      case MessageStatus.sending:
        return isDark ? DarkColors.textLight : AppColors.textLight;
      case MessageStatus.sent:
        return isDark ? DarkColors.sent : AppColors.sent;
      case MessageStatus.delivered:
        return isDark ? DarkColors.sent : AppColors.sent;
      case MessageStatus.read:
        return isDark ? DarkColors.read : AppColors.read;
      case MessageStatus.failed:
        return Colors.redAccent;
      case MessageStatus.recalled:
        return isDark ? DarkColors.textLight : AppColors.textLight;
      default:
        return isDark ? DarkColors.sent : AppColors.sent;
    }
  }

  Widget _buildStatusIcon(Color color) {
    switch (message.status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        );
      case MessageStatus.sent:
        return Icon(Icons.check, size: 14, color: color);
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 14, color: color);
      case MessageStatus.read:
        return Icon(Icons.done_all, size: 14, color: color);
      case MessageStatus.failed:
        return Icon(Icons.error_outline, size: 14, color: color);
      case MessageStatus.recalled:
        return const SizedBox.shrink();
      default:
        return Icon(Icons.check, size: 14, color: color);
    }
  }

  Widget _buildRecalledMessage(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          message.isMe ? '你撤回了一条消息' : '对方撤回了一条消息',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? DarkColors.textLight : AppColors.textLight,
          ),
        ),
      ),
    );
  }

  Widget _buildSystemMessage(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? DarkColors.surface : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.content,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? DarkColors.textTertiary : AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (messageDay == today) {
      return DateFormat('HH:mm').format(dateTime);
    }
    
    final yesterday = today.subtract(const Duration(days: 1));
    if (messageDay == yesterday) {
      return '昨天 ${DateFormat('HH:mm').format(dateTime)}';
    }
    
    return DateFormat('MM/dd HH:mm').format(dateTime);
  }
}