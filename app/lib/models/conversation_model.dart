import 'message_model.dart';

class ConversationModel {
  final String id;
  final String type;
  final String? name;
  final String? avatar;
  final List<String> participants;
  final String? creatorId;
  final MessageModel? lastMessage;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // 单聊对方信息
  final String? otherUserId;
  final String? otherUserName;
  final String? otherUserNickname;
  final String? otherUserAvatar;
  final bool? otherUserOnline;
  final DateTime? otherUserLastSeen;

  ConversationModel({
    required this.id,
    required this.type,
    this.name,
    this.avatar,
    required this.participants,
    this.creatorId,
    this.lastMessage,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
    required this.createdAt,
    required this.updatedAt,
    this.otherUserId,
    this.otherUserName,
    this.otherUserNickname,
    this.otherUserAvatar,
    this.otherUserOnline,
    this.otherUserLastSeen,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    // 后端返回格式:
    // {friend: {_id, username, nickname, avatar}, lastMessage: {...}, unreadCount}
    String? friendId;
    String? friendUsername;
    String? friendNickname;
    String? friendAvatar;
    
    final friend = json['friend'];
    if (friend is Map<String, dynamic>) {
      friendId = friend['_id']?.toString() ?? friend['id']?.toString();
      friendUsername = friend['xuyanId'];
      friendNickname = friend['nickname'];
      friendAvatar = friend['avatar'];
    }
    
    // 兼容旧格式
    friendId ??= json['otherUserId'];
    friendUsername ??= json['otherUserName'];
    friendNickname ??= json['otherUserNickname'];
    friendAvatar ??= json['otherUserAvatar'];

    // 解析 lastMessage
    MessageModel? lastMessage;
    final lastMsgRaw = json['lastMessage'];
    if (lastMsgRaw is Map<String, dynamic>) {
      lastMessage = MessageModel(
        id: '',
        senderId: '',
        type: lastMsgRaw['type'] ?? 'text',
        content: lastMsgRaw['content'] ?? '',
        mediaUrl: lastMsgRaw['mediaUrl'],
        createdAt: lastMsgRaw['createdAt'] != null 
            ? DateTime.parse(lastMsgRaw['createdAt'].toString()).toLocal() 
            : DateTime.now(),
        recalled: lastMsgRaw['recalled'] ?? false,
        status: 'sent',
      );
    } else if (json['lastMessage'] is MessageModel) {
      lastMessage = json['lastMessage'];
    }

    // 从 lastMessage.createdAt 获取 updatedAt
    DateTime? updatedAt;
    if (json['updatedAt'] != null) {
      updatedAt = DateTime.parse(json['updatedAt'].toString()).toLocal();
    } else if (lastMessage != null) {
      updatedAt = lastMessage.createdAt;
    } else {
      updatedAt = DateTime.now();
    }

    return ConversationModel(
      id: friendId ?? json['id']?.toString() ?? json['_id']?.toString() ?? '',
      type: json['type'] ?? ConversationType.single,
      name: json['name'],
      avatar: json['avatar'] ?? friendAvatar,
      participants: List<String>.from(json['participants'] ?? []),
      creatorId: json['creatorId'],
      lastMessage: lastMessage,
      unreadCount: json['unreadCount'] ?? 0,
      isPinned: json['isPinned'] ?? false,
      isMuted: json['isMuted'] ?? false,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'].toString()).toLocal() 
          : DateTime.now(),
      updatedAt: updatedAt,
      otherUserId: friendId,
      otherUserName: friendUsername ?? friendNickname,
      otherUserNickname: friendNickname,
      otherUserAvatar: friendAvatar,
      otherUserOnline: json['otherUserOnline'],
      otherUserLastSeen: json['otherUserLastSeen'] != null 
          ? DateTime.parse(json['otherUserLastSeen'].toString()) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'avatar': avatar,
      'participants': participants,
      'creatorId': creatorId,
      'lastMessage': lastMessage?.toJson(),
      'unreadCount': unreadCount,
      'isPinned': isPinned,
      'isMuted': isMuted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'otherUserId': otherUserId,
      'otherUserName': otherUserName,
      'otherUserNickname': otherUserNickname,
      'otherUserAvatar': otherUserAvatar,
      'otherUserOnline': otherUserOnline,
      'otherUserLastSeen': otherUserLastSeen?.toIso8601String(),
    };
  }

  ConversationModel copyWith({
    String? id,
    String? type,
    String? name,
    String? avatar,
    List<String>? participants,
    String? creatorId,
    // 使用专门的标志来区分"未传入"和"设为null"
    bool clearLastMessage = false,
    MessageModel? lastMessage,
    int? unreadCount,
    bool? isPinned,
    bool? isMuted,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? otherUserId,
    String? otherUserName,
    String? otherUserNickname,
    String? otherUserAvatar,
    bool? otherUserOnline,
    DateTime? otherUserLastSeen,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      participants: participants ?? this.participants,
      creatorId: creatorId ?? this.creatorId,
      lastMessage: clearLastMessage ? null : (lastMessage ?? this.lastMessage),
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      otherUserId: otherUserId ?? this.otherUserId,
      otherUserName: otherUserName ?? this.otherUserName,
      otherUserNickname: otherUserNickname ?? this.otherUserNickname,
      otherUserAvatar: otherUserAvatar ?? this.otherUserAvatar,
      otherUserOnline: otherUserOnline ?? this.otherUserOnline,
      otherUserLastSeen: otherUserLastSeen ?? this.otherUserLastSeen,
    );
  }

  String get displayName {
    if (type == ConversationType.group) {
      return name ?? '群聊';
    }
    return otherUserNickname ?? otherUserName ?? '未知用户';
  }

  String? get displayAvatar {
    if (type == ConversationType.group) {
      return avatar;
    }
    return otherUserAvatar;
  }
}

class ConversationType {
  static const String single = 'single';
  static const String group = 'group';
}
