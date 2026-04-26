class UserModel {
  final String id;
  final String? xuyanId;
  final String? phone;
  final String nickname;
  final String? avatar;
  final String? signature;
  final String? email;
  final String? gender;
  final DateTime? birthday;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isOnline;
  final DateTime? lastSeen;

  UserModel({
    required this.id,
    this.xuyanId,
    this.phone,
    required this.nickname,
    this.avatar,
    this.signature,
    this.email,
    this.gender,
    this.birthday,
    required this.createdAt,
    required this.updatedAt,
    this.isOnline = false,
    this.lastSeen,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['_id']?.toString() ?? '',
      xuyanId: json['xuyanId']?.toString(),
      phone: json['phone']?.toString(),
      nickname: json['nickname'] ?? '',
      avatar: json['avatar'],
      signature: json['signature'] ?? json['bio'],
      email: json['email'],
      gender: json['gender'],
      birthday: json['birthday'] != null ? DateTime.parse(json['birthday']) : null,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : DateTime.now(),
      isOnline: json['isOnline'] ?? false,
      lastSeen: json['lastSeen'] != null 
          ? DateTime.parse(json['lastSeen']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'xuyanId': xuyanId,
      'nickname': nickname,
      'avatar': avatar,
      'signature': signature,
      'email': email,
      'phone': phone,
      'gender': gender,
      'birthday': birthday?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? xuyanId,
    String? nickname,
    String? avatar,
    String? signature,
    String? email,
    String? phone,
    String? gender,
    DateTime? birthday,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return UserModel(
      id: id ?? this.id,
      xuyanId: xuyanId ?? this.xuyanId,
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
      signature: signature ?? this.signature,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
