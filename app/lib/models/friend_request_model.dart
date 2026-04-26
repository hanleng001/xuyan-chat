class FriendRequestModel {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String status;
  final String? message;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // 发送者信息
  final String? fromUserName;
  final String? fromUserNickname;
  final String? fromUserAvatar;
  
  // 接收者信息
  final String? toUserName;
  final String? toUserNickname;
  final String? toUserAvatar;

  FriendRequestModel({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    this.status = 'pending',
    this.message,
    required this.createdAt,
    this.updatedAt,
    this.fromUserName,
    this.fromUserNickname,
    this.fromUserAvatar,
    this.toUserName,
    this.toUserNickname,
    this.toUserAvatar,
  });

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) {
    // 后端 from/to 可能是 populated 对象或字符串
    String fromUserId = '';
    String? fromUserName;
    String? fromUserNickname;
    String? fromUserAvatar;
    
    final fromRaw = json['from'];
    if (fromRaw is Map<String, dynamic>) {
      fromUserId = fromRaw['_id']?.toString() ?? fromRaw['id']?.toString() ?? '';
      fromUserName = fromRaw['xuyanId'];
      fromUserNickname = fromRaw['nickname'];
      fromUserAvatar = fromRaw['avatar'];
    } else if (fromRaw is String) {
      fromUserId = fromRaw;
    } else if (json['fromUserId'] != null) {
      fromUserId = json['fromUserId'].toString();
    }
    fromUserName ??= json['fromUserName'];
    fromUserNickname ??= json['fromUserNickname'];
    fromUserAvatar ??= json['fromUserAvatar'];
    
    String toUserId = '';
    String? toUserName;
    String? toUserNickname;
    String? toUserAvatar;
    
    final toRaw = json['to'];
    if (toRaw is Map<String, dynamic>) {
      toUserId = toRaw['_id']?.toString() ?? toRaw['id']?.toString() ?? '';
      toUserName = toRaw['xuyanId'];
      toUserNickname = toRaw['nickname'];
      toUserAvatar = toRaw['avatar'];
    } else if (toRaw is String) {
      toUserId = toRaw;
    } else if (json['toUserId'] != null) {
      toUserId = json['toUserId'].toString();
    }
    toUserName ??= json['toUserName'];
    toUserNickname ??= json['toUserNickname'];
    toUserAvatar ??= json['toUserAvatar'];

    return FriendRequestModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      fromUserId: fromUserId,
      toUserId: toUserId,
      status: json['status'] ?? 'pending',
      message: json['message'],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'].toString()) 
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'].toString()) 
          : null,
      fromUserName: fromUserName,
      fromUserNickname: fromUserNickname,
      fromUserAvatar: fromUserAvatar,
      toUserName: toUserName,
      toUserNickname: toUserNickname,
      toUserAvatar: toUserAvatar,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'status': status,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'fromUserName': fromUserName,
      'fromUserNickname': fromUserNickname,
      'fromUserAvatar': fromUserAvatar,
      'toUserName': toUserName,
      'toUserNickname': toUserNickname,
      'toUserAvatar': toUserAvatar,
    };
  }

  FriendRequestModel copyWith({
    String? id,
    String? fromUserId,
    String? toUserId,
    String? status,
    String? message,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? fromUserName,
    String? fromUserNickname,
    String? fromUserAvatar,
    String? toUserName,
    String? toUserNickname,
    String? toUserAvatar,
  }) {
    return FriendRequestModel(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      status: status ?? this.status,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      fromUserName: fromUserName ?? this.fromUserName,
      fromUserNickname: fromUserNickname ?? this.fromUserNickname,
      fromUserAvatar: fromUserAvatar ?? this.fromUserAvatar,
      toUserName: toUserName ?? this.toUserName,
      toUserNickname: toUserNickname ?? this.toUserNickname,
      toUserAvatar: toUserAvatar ?? this.toUserAvatar,
    );
  }

  String get displayName {
    return fromUserNickname ?? fromUserName ?? '未知用户';
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
}

class FriendRequestStatus {
  static const String pending = 'pending';
  static const String accepted = 'accepted';
  static const String rejected = 'rejected';
}
