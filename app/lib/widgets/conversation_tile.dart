import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/conversation_model.dart';
import 'avatar.dart';

class ConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ConversationTile({
    super.key,
    required this.conversation,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lastMsg = conversation.lastMessage;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? DarkColors.surface : AppColors.surface,
          border: Border(
            bottom: BorderSide(
              color: isDark ? DarkColors.divider : AppColors.divider,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Avatar(
              imageUrl: conversation.displayAvatar,
              name: conversation.displayName,
              size: 52,
              showOnlineStatus: conversation.type == ConversationType.single,
              isOnline: conversation.otherUserOnline ?? false,
            ),
            const SizedBox(width: 12),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.displayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? DarkColors.textPrimary : AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(conversation.updatedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: conversation.unreadCount > 0
                              ? AppColors.primary
                              : (isDark ? DarkColors.textLight : AppColors.textLight),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  
                  // Last message row
                  Row(
                    children: [
                      if (lastMsg != null)
                        _buildMessagePreview(lastMsg, isDark),
                      const Spacer(),
                      if (conversation.isMuted)
                        Icon(
                          Icons.volume_off,
                          size: 16,
                          color: isDark ? DarkColors.textLight : AppColors.textLight,
                        ),
                      if (conversation.isPinned)
                        Icon(
                          Icons.push_pin,
                          size: 16,
                          color: isDark ? DarkColors.textLight : AppColors.textLight,
                        ),
                      if (conversation.unreadCount > 0) ...[
                        const SizedBox(width: 6),
                        _buildUnreadBadge(conversation.unreadCount, isDark),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagePreview(var message, bool isDark) {
    String content = '';
    IconData? icon;
    
    switch (message.type) {
      case 'text':
        content = message.content;
        break;
      case 'image':
        content = '[图片]';
        icon = Icons.image_outlined;
        break;
      case 'voice':
        content = '[语音]';
        icon = Icons.mic_outlined;
        break;
      case 'video':
        content = '[视频]';
        icon = Icons.videocam_outlined;
        break;
      case 'file':
        content = '[文件]';
        icon = Icons.insert_drive_file_outlined;
        break;
      case 'system':
        content = message.content;
        break;
      default:
        content = message.content;
    }
    
    return Expanded(
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: conversation.unreadCount > 0
                  ? (isDark ? DarkColors.textPrimary : AppColors.textPrimary)
                  : (isDark ? DarkColors.textSecondary : AppColors.textSecondary),
            ),
            const SizedBox(width: 4),
          ],
          if (message.senderId != null && message.senderId != message.receiverId) ...[
            // Show "Me:" if sent by me
            Text(
              '',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? DarkColors.textSecondary : AppColors.textSecondary,
              ),
            ),
          ],
          Flexible(
            child: Text(
              content,
              style: TextStyle(
                fontSize: 14,
                fontWeight: conversation.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                color: conversation.unreadCount > 0
                    ? (isDark ? DarkColors.textPrimary : AppColors.textPrimary)
                    : (isDark ? DarkColors.textSecondary : AppColors.textSecondary),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnreadBadge(int count, bool isDark) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.unreadBadge,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
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
      return '昨天';
    }
    
    if (now.year == dateTime.year) {
      return DateFormat('MM/dd').format(dateTime);
    }
    
    return DateFormat('yy/MM/dd').format(dateTime);
  }
}