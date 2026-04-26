class GroupModel {
  final String id;
  final String name;
  final String? description;
  final String? avatar;
  final String creatorId;
  final List<String> admins;
  final List<GroupMember> members;
  final int maxMembers;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;

  GroupModel({
    required this.id,
    required this.name,
    this.description,
    this.avatar,
    required this.creatorId,
    this.admins = const [],
    this.members = const [],
    this.maxMembers = 500,
    this.isPublic = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      avatar: json['avatar'],
      creatorId: json['creatorId'] ?? '',
      admins: List<String>.from(json['admins'] ?? []),
      members: (json['members'] as List<dynamic>?)
              ?.map((m) => GroupMember.fromJson(m))
              .toList() ??
          [],
      maxMembers: json['maxMembers'] ?? 500,
      isPublic: json['isPublic'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'avatar': avatar,
      'creatorId': creatorId,
      'admins': admins,
      'members': members.map((m) => m.toJson()).toList(),
      'maxMembers': maxMembers,
      'isPublic': isPublic,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  int get memberCount => members.length;
  
  bool isAdmin(String userId) => admins.contains(userId);
  bool isCreator(String userId) => creatorId == userId;
  bool isManager(String userId) => isAdmin(userId) || isCreator(userId);
}

class GroupMember {
  final String userId;
  final String? nickname;
  final String? avatar;
  final String role;
  final DateTime joinedAt;

  GroupMember({
    required this.userId,
    this.nickname,
    this.avatar,
    this.role = 'member',
    required this.joinedAt,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: json['userId'] ?? '',
      nickname: json['nickname'] ?? json['user']?['nickname'],
      avatar: json['avatar'] ?? json['user']?['avatar'],
      role: json['role'] ?? 'member',
      joinedAt: json['joinedAt'] != null
          ? DateTime.parse(json['joinedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'nickname': nickname,
      'avatar': avatar,
      'role': role,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }
}

class GroupRole {
  static const String creator = 'creator';
  static const String admin = 'admin';
  static const String member = 'member';
}
