import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../config/api_config.dart';

enum AvatarSize { tiny, small, medium, large, xlarge }

class Avatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double? size;
  final AvatarSize? avatarSize;
  final bool showOnlineStatus;
  final bool isOnline;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const Avatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size,
    this.avatarSize,
    this.showOnlineStatus = false,
    this.isOnline = false,
    this.backgroundColor,
    this.onTap,
  });

  static String _fullUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiConfig.baseUrl}$path';
  }

  double get _effectiveSize {
    if (size != null) return size!;
    switch (avatarSize) {
      case AvatarSize.tiny:
        return 28;
      case AvatarSize.small:
        return 36;
      case AvatarSize.medium:
        return 48;
      case AvatarSize.large:
        return 64;
      case AvatarSize.xlarge:
        return 80;
      case null:
        return 48;
    }
  }

  Color get _defaultBgColor {
    if (backgroundColor != null) return backgroundColor!;
    if (name != null && name!.isNotEmpty) {
      // Generate color from name
      final hash = name!.hashCode;
      final colors = [
        const Color(0xFF5B8DB8),
        const Color(0xFFFF8A65),
        const Color(0xFF66BB6A),
        const Color(0xFFAB47BC),
        const Color(0xFFEF5350),
        const Color(0xFF42A5F5),
        const Color(0xFFFFA726),
        const Color(0xFF26C6DA),
      ];
      return colors[hash.abs() % colors.length];
    }
    return AppColors.primary;
  }

  String get _initials {
    if (name == null || name!.isEmpty) return '?';
    if (name!.length == 1) return name!.toUpperCase();
    // For Chinese names, take first char; for English, take initials
    if (RegExp(r'[\u4e00-\u9fa5]').hasMatch(name!)) {
      return name!.substring(0, 1);
    }
    final parts = name!.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name!.substring(0, 2).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final s = _effectiveSize;
    final statusSize = s * 0.28;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Widget avatarWidget;
    
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      avatarWidget = ClipOval(
        child: CachedNetworkImage(
          imageUrl: _fullUrl(imageUrl),
          width: s,
          height: s,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildPlaceholder(s),
          errorWidget: (context, url, error) => _buildPlaceholder(s),
        ),
      );
    } else {
      avatarWidget = _buildPlaceholder(s);
    }

    if (onTap != null) {
      avatarWidget = GestureDetector(
        onTap: onTap,
        child: avatarWidget,
      );
    }

    if (!showOnlineStatus) return avatarWidget;

    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        children: [
          avatarWidget,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: statusSize,
              height: statusSize,
              decoration: BoxDecoration(
                color: isDark ? DarkColors.surface : AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Container(
                margin: EdgeInsets.all(statusSize * 0.15),
                decoration: BoxDecoration(
                  color: isOnline 
                      ? (isDark ? DarkColors.online : AppColors.online)
                      : (isDark ? DarkColors.offline : AppColors.offline),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(double s) {
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: _defaultBgColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.38,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}