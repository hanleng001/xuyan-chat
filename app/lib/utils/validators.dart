class Validators {
  // 敏感词列表
  static const List<String> _sensitiveWords = [
    '管理', 'admin', 'system', '系统', '官方', '客服',
    'fuck', 'shit', 'damn', 'ass',
    'Fuck', 'Shit', 'Damn', 'Ass',
    '色情', '赌博', '毒品', '枪支',
    '诈骗', '传销', '代购',
    '习近平', '江泽民', '胡锦涛', '温家宝',
    '李克强', '李强', '王岐山',
  ];

  // 用户名验证
  static String? validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入用户名';
    }
    final trimmed = value.trim();
    if (trimmed.length < 3) {
      return '用户名至少需要3个字符';
    }
    if (trimmed.length > 20) {
      return '用户名不能超过20个字符';
    }
    // 允许中文、英文、数字、下划线
    final regex = RegExp(r'^[a-zA-Z0-9_\u4e00-\u9fa5]+$');
    if (!regex.hasMatch(trimmed)) {
      return '用户名只能包含中文、英文、数字和下划线';
    }
    // 纯数字检测
    if (RegExp(r'^[0-9]+$').hasMatch(trimmed)) {
      return '用户名不能为纯数字';
    }
    // 敏感词检测
    final lowerTrimmed = trimmed.toLowerCase();
    for (final word in _sensitiveWords) {
      if (lowerTrimmed.contains(word.toLowerCase())) {
        return '用户名包含不允许的内容';
      }
    }
    return null;
  }

  // 昵称验证
  static String? validateNickname(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入昵称';
    }
    if (value.trim().length < 1) {
      return '昵称至少需要1个字符';
    }
    if (value.trim().length > 20) {
      return '昵称不能超过20个字符';
    }
    return null;
  }

  // 密码验证
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入密码';
    }
    if (value.length < 6) {
      return '密码至少需要6个字符';
    }
    if (value.length > 50) {
      return '密码不能超过50个字符';
    }
    return null;
  }

  // 确认密码验证
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return '请再次输入密码';
    }
    if (value != password) {
      return '两次输入的密码不一致';
    }
    return null;
  }

  // 邮箱验证
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // 邮箱可选
    }
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!regex.hasMatch(value.trim())) {
      return '请输入有效的邮箱地址';
    }
    return null;
  }

  // 手机号验证（必填）
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入手机号';
    }
    final regex = RegExp(r'^1[3-9]\d{9}$');
    if (!regex.hasMatch(value.trim())) {
      return '请输入有效的手机号码';
    }
    return null;
  }

  // 搜索关键词验证
  static String? validateSearchKeyword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入搜索关键词';
    }
    if (value.trim().length < 1) {
      return '搜索关键词至少需要1个字符';
    }
    return null;
  }

  // 好友请求留言验证
  static String? validateRequestMessage(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // 留言可选
    }
    if (value.trim().length > 100) {
      return '留言不能超过100个字符';
    }
    return null;
  }
}