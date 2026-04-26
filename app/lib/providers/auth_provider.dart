import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final StorageService _storage = StorageService();
  
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  UserModel? _user;
  String? _token;
  String? _errorMessage;

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  UserModel? get user => _user;
  String? get token => _token;
  String? get errorMessage => _errorMessage;
  String? get userId => _user?.id;
  String? get username => _user?.xuyanId;
  String? get nickname => _user?.nickname;
  String? get avatar => _user?.avatar;

  Future<void> init() async {
    if (_isInitialized) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      _token = await _storage.getToken();
      final isLoggedIn = await _storage.isLoggedIn();
      
      if (isLoggedIn && _token != null) {
        try {
          final user = await _authService.getCurrentUser();
          if (user != null) {
            _user = user;
            _isAuthenticated = true;
          } else {
            // API返回null但token存在，保持登录状态等待重试
            _isAuthenticated = true;
          }
        } catch (e) {
          // 网络错误时保持登录状态，不强制退出
          _isAuthenticated = true;
        }
      }
    } catch (e) {
      // 网络错误不自动清除登录状态
      final isLoggedIn = await _storage.isLoggedIn();
      if (isLoggedIn) {
        _isAuthenticated = true;
        _token = await _storage.getToken();
      }
    }

    _isLoading = false;
    _isInitialized = true;
    notifyListeners();
  }

  Future<bool> login(String account, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.login(account, password);
      if (user != null) {
        _user = user;
        _token = await _storage.getToken();
        _isAuthenticated = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = '登录失败，请重试';
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> register({
    required String phone,
    String? nickname,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.register(
        phone: phone,
        nickname: nickname,
        password: password,
      );
      if (user != null) {
        _user = user;
        _token = await _storage.getToken();
        _isAuthenticated = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = '注册失败，请重试';
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.logout();
    } catch (e) {
      // Ignore logout errors
    }

    await _clearAuth();
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> updateProfile({
    String? nickname,
    String? bio,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.updateProfile(
        nickname: nickname,
        bio: bio,
      );
      if (user != null) {
        _user = user;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<String?> uploadAvatar(String filePath) async {
    _isLoading = true;
    notifyListeners();

    try {
      final avatarUrl = await _authService.uploadAvatar(filePath);
      if (avatarUrl != null && _user != null) {
        _user = _user!.copyWith(avatar: avatarUrl);
        notifyListeners();
      }
      _isLoading = false;
      notifyListeners();
      return avatarUrl;
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return null;
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.changePassword(currentPassword, newPassword);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// 设置序言号（只能设置一次）
  Future<bool> setXuyanId(String xuyanId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.setXuyanId(xuyanId);
      if (user != null) {
        _user = user;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// 检查序言号是否可用
  Future<bool?> checkXuyanId(String xuyanId) async {
    try {
      return await _authService.checkXuyanId(xuyanId);
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    }
  }

  Future<void> _clearAuth({bool clearStorage = true}) async {
    _user = null;
    _token = null;
    _isAuthenticated = false;
    if (clearStorage) {
      await _storage.clearAll();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}