class MessageModel {
  final String id;
  // conversationId 不再由后端返回，用于前端本地缓存
  String? conversationId;
  // 后端 sender 是 populated 对象 {_id, username, nickname, avatar} 或 string
  final String senderId;
  final String? receiverId;
  final String? senderName;
  final String? senderAvatar;
  final String type;
  final String content;
  final String? mediaUrl;
  final int? mediaDuration;
  final String? mediaThumbnail;
  final Map<String, dynamic>? mediaMeta;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool recalled;
  final DateTime? recalledAt;
  final Map<String, dynamic>? extra;
  
  // 本地字段
  final bool isMe;

  MessageModel({
    required this.id,
    this.conversationId,
    required this.senderId,
    this.receiverId,
    this.senderName,
    this.senderAvatar,
    required this.type,
    required this.content,
    this.mediaUrl,
    this.mediaDuration,
    this.mediaThumbnail,
    this.mediaMeta,
    this.status = 'sent',
    required this.createdAt,
    this.updatedAt,
    this.recalled = false,
    this.recalledAt,
    this.extra,
    this.isMe = false,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    // 后端 sender/receiver 可能是 populated 对象或字符串
    String senderId = '';
    String? senderName;
    String? senderAvatar;
    
    final senderRaw = json['sender'];
    if (senderRaw is Map<String, dynamic>) {
      senderId = senderRaw['_id']?.toString() ?? senderRaw['id']?.toString() ?? '';
      senderName = senderRaw['nickname'] ?? senderRaw['xuyanId'] ?? '';
      senderAvatar = senderRaw['avatar'];
    } else if (senderRaw is String) {
      senderId = senderRaw;
    } else if (json['senderId'] != null) {
      // 兼容旧字段
      senderId = json['senderId'].toString();
    }
    
    String? receiverId;
    final receiverRaw = json['receiver'];
    if (receiverRaw is String) {
      receiverId = receiverRaw;
    } else if (receiverRaw is Map<String, dynamic>) {
      receiverId = receiverRaw['_id']?.toString() ?? receiverRaw['id']?.toString();
    } else if (json['receiverId'] != null) {
      receiverId = json['receiverId'].toString();
    }

    return MessageModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      conversationId: json['conversationId'],
      senderId: senderId,
      receiverId: receiverId,
      senderName: senderName ?? json['senderName'],
      senderAvatar: senderAvatar ?? json['senderAvatar'],
      type: json['type'] ?? 'text',
      content: json['content'] ?? '',
      mediaUrl: json['mediaUrl'],
      mediaDuration: json['mediaDuration'],
      mediaThumbnail: json['mediaThumbnail'],
      mediaMeta: json['mediaMeta'],
      status: json['status'] ?? 'sent',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'].toString()).toLocal() 
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'].toString()).toLocal() 
          : null,
      recalled: json['recalled'] ?? json['isRecalled'] ?? false,
      recalledAt: json['recalledAt'] != null 
          ? DateTime.parse(json['recalledAt'].toString()).toLocal() 
          : null,
      extra: json['extra'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'sender': senderId,
      'receiver': receiverId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'type': type,
      'content': content,
      'mediaUrl': mediaUrl,
      'mediaDuration': mediaDuration,
      'mediaThumbnail': mediaThumbnail,
      'mediaMeta': mediaMeta,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'recalled': recalled,
      'recalledAt': recalledAt?.toIso8601String(),
      'extra': extra,
    };
  }

  // 兼容旧代码中访问 isRecalled
  bool get isRecalled => recalled;

  MessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? receiverId,
    String? senderName,
    String? senderAvatar,
    String? type,
    String? content,
    String? mediaUrl,
    int? mediaDuration,
    String? mediaThumbnail,
    Map<String, dynamic>? mediaMeta,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? recalled,
    DateTime? recalledAt,
    Map<String, dynamic>? extra,
    bool? isMe,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      type: type ?? this.type,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaDuration: mediaDuration ?? this.mediaDuration,
      mediaThumbnail: mediaThumbnail ?? this.mediaThumbnail,
      mediaMeta: mediaMeta ?? this.mediaMeta,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      recalled: recalled ?? this.recalled,
      recalledAt: recalledAt ?? this.recalledAt,
      extra: extra ?? this.extra,
      isMe: isMe ?? this.isMe,
    );
  }
}

class MessageStatus {
  static const String sending = 'sending';
  static const String sent = 'sent';
  static const String delivered = 'delivered';
  static const String received = 'received';
  static const String read = 'read';
  static const String failed = 'failed';
  static const String recalled = 'recalled';
}

class MessageType {
  static const String text = 'text';
  static const String image = 'image';
  static const String voice = 'voice';
  static const String video = 'video';
  static const String file = 'file';
  static const String location = 'location';
  static const String system = 'system';
}
