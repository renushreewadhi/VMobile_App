import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String keyToken = 'hrm_token';
  static const String keyRefreshToken = 'hrm_refresh_token';
  static const String keyUserData = 'hrm_user';
  static const String keyDarkMode = 'hrm_dark_mode';
  static const String keyReduceTransparency = 'hrm_reduce_transparency';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: keyToken, value: token);
  }

  Future<String?> getToken() async {
    return await _secureStorage.read(key: keyToken);
  }

  Future<void> saveRefreshToken(String refreshToken) async {
    await _secureStorage.write(key: keyRefreshToken, value: refreshToken);
  }

  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: keyRefreshToken);
  }

  Future<void> saveUserData(String userDataJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyUserData, userDataJson);
  }

  Future<String?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyUserData);
  }

  Future<void> setDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyDarkMode, isDark);
  }

  Future<bool> isDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyDarkMode) ?? false;
  }

  Future<void> setReduceTransparency(bool reduce) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyReduceTransparency, reduce);
  }

  Future<bool> isReduceTransparency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyReduceTransparency) ?? false;
  }

  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyUserData);
  }
}
