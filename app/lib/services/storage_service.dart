import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Token
  Future<void> setToken(String token) async {
    await init();
    await _prefs!.setString(AppConstants.prefToken, token);
  }

  Future<String?> getToken() async {
    await init();
    return _prefs!.getString(AppConstants.prefToken);
  }

  Future<void> removeToken() async {
    await init();
    await _prefs!.remove(AppConstants.prefToken);
  }

  // Refresh Token
  Future<void> setRefreshToken(String token) async {
    await init();
    await _prefs!.setString(AppConstants.prefRefreshToken, token);
  }

  Future<String?> getRefreshToken() async {
    await init();
    return _prefs!.getString(AppConstants.prefRefreshToken);
  }

  Future<void> removeRefreshToken() async {
    await init();
    await _prefs!.remove(AppConstants.prefRefreshToken);
  }

  // User Info
  Future<void> setUserId(String userId) async {
    await init();
    await _prefs!.setString(AppConstants.prefUserId, userId);
  }

  Future<String?> getUserId() async {
    await init();
    return _prefs!.getString(AppConstants.prefUserId);
  }

  Future<void> setUsername(String username) async {
    await init();
    await _prefs!.setString(AppConstants.prefUsername, username);
  }

  Future<String?> getUsername() async {
    await init();
    return _prefs!.getString(AppConstants.prefUsername);
  }

  Future<void> setNickname(String nickname) async {
    await init();
    await _prefs!.setString(AppConstants.prefNickname, nickname);
  }

  Future<String?> getNickname() async {
    await init();
    return _prefs!.getString(AppConstants.prefNickname);
  }

  Future<void> setAvatar(String avatar) async {
    await init();
    await _prefs!.setString(AppConstants.prefAvatar, avatar);
  }

  Future<String?> getAvatar() async {
    await init();
    return _prefs!.getString(AppConstants.prefAvatar);
  }

  // Theme
  Future<void> setThemeMode(String mode) async {
    await init();
    await _prefs!.setString(AppConstants.prefTheme, mode);
  }

  Future<String?> getThemeMode() async {
    await init();
    return _prefs!.getString(AppConstants.prefTheme);
  }

  // Notifications
  Future<void> setNotificationsEnabled(bool enabled) async {
    await init();
    await _prefs!.setBool(AppConstants.prefNotifications, enabled);
  }

  Future<bool> getNotificationsEnabled() async {
    await init();
    return _prefs!.getBool(AppConstants.prefNotifications) ?? true;
  }

  Future<void> setSoundEnabled(bool enabled) async {
    await init();
    await _prefs!.setBool(AppConstants.prefSound, enabled);
  }

  Future<bool> getSoundEnabled() async {
    await init();
    return _prefs!.getBool(AppConstants.prefSound) ?? true;
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    await init();
    await _prefs!.setBool(AppConstants.prefVibration, enabled);
  }

  Future<bool> getVibrationEnabled() async {
    await init();
    return _prefs!.getBool(AppConstants.prefVibration) ?? true;
  }

  // AI Model
  Future<void> setAiModel(String model) async {
    await init();
    await _prefs!.setString(AppConstants.prefAiModel, model);
  }

  Future<String?> getAiModel() async {
    await init();
    return _prefs!.getString(AppConstants.prefAiModel);
  }

  // AI API Key
  Future<void> setAIKey(String key) async {
    await init();
    await _prefs!.setString('ai_api_key', key);
  }

  Future<String?> getAIKey() async {
    await init();
    return _prefs!.getString('ai_api_key');
  }

  // AI Base URL
  Future<void> setAIBaseUrl(String url) async {
    await init();
    await _prefs!.setString('ai_base_url', url);
  }

  Future<String?> getAIBaseUrl() async {
    await init();
    return _prefs!.getString('ai_base_url');
  }

  // Clear all
  Future<void> clearAll() async {
    await init();
    await _prefs!.clear();
  }

  // Check login status
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
