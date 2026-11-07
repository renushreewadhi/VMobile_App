import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const String keyToken = 'hrm_token';
  static const String keyRefreshToken = 'hrm_refresh_token';
  static const String keyUserData = 'hrm_user';
  static const String keyDarkMode = 'hrm_dark_mode';
  static const String keyReduceTransparency = 'hrm_reduce_transparency';
  static const String keyRememberMe = 'hrm_remember_me';

  final FlutterSecureStorage _secureStorage;

  StorageService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
      const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );

  Future<void> saveToken(String token) async {
    try {
      await _secureStorage.write(key: keyToken, value: token);
      debugPrint('[AuthDiag:StorageService] saveToken successful');
    } catch (e) {
      debugPrint('[AuthDiag:StorageService] Error saving token: $e; attempting recovery');
      try {
        await _secureStorage.deleteAll();
        await _secureStorage.write(key: keyToken, value: token);
      } catch (innerE) {
        debugPrint('[AuthDiag:StorageService] Recovery saveToken failed: $innerE');
      }
    }
  }

  Future<String?> getToken() async {
    try {
      return await _secureStorage.read(key: keyToken);
    } catch (e) {
      debugPrint('[AuthDiag:StorageService] Error reading token: $e; wiping corrupted storage');
      try { await _secureStorage.deleteAll(); } catch (_) {}
      return null;
    }
  }

  Future<void> deleteToken() async {
    try {
      await _secureStorage.delete(key: keyToken);
    } catch (e) {
      debugPrint('[AuthDiag:StorageService] Error deleting token: $e');
    }
  }

  Future<void> saveRefreshToken(String refreshToken) async {
    try {
      await _secureStorage.write(key: keyRefreshToken, value: refreshToken);
    } catch (e) {
      debugPrint('[AuthDiag:StorageService] Error saving refresh token: $e');
    }
  }

  Future<String?> getRefreshToken() async {
    try {
      return await _secureStorage.read(key: keyRefreshToken);
    } catch (e) {
      debugPrint('[AuthDiag:StorageService] Error reading refresh token: $e; wiping corrupted storage');
      try { await _secureStorage.deleteAll(); } catch (_) {}
      return null;
    }
  }

  Future<void> deleteRefreshToken() async {
    try {
      await _secureStorage.delete(key: keyRefreshToken);
    } catch (e) {
      debugPrint('[AuthDiag:StorageService] Error deleting refresh token: $e');
    }
  }

  Future<void> saveUserData(String userDataJson) async {
    try {
      await _secureStorage.write(key: keyUserData, value: userDataJson);
      debugPrint('[AuthDiag:StorageService] saveUserData successful');
    } catch (e) {
      debugPrint('[AuthDiag:StorageService] Error saving user data: $e; attempting recovery');
      try {
        await _secureStorage.deleteAll();
        await _secureStorage.write(key: keyUserData, value: userDataJson);
      } catch (innerE) {
        debugPrint('[AuthDiag:StorageService] Recovery saveUserData failed: $innerE');
      }
    }
  }

  Future<String?> getUserData() async {
    try {
      return await _secureStorage.read(key: keyUserData);
    } catch (e) {
      debugPrint('[AuthDiag:StorageService] Error reading user data: $e; wiping corrupted storage');
      try { await _secureStorage.deleteAll(); } catch (_) {}
      return null;
    }
  }

  Future<void> deleteUserData() async {
    try {
      await _secureStorage.delete(key: keyUserData);
    } catch (e) {
      debugPrint('[AuthDiag:StorageService] Error deleting user data: $e');
    }
  }

  Future<void> setDarkMode(bool isDark) async {
    try {
      await _secureStorage.write(key: keyDarkMode, value: isDark.toString());
    } catch (e) {
      debugPrint('[AuthDiag:StorageService] Error setting dark mode: $e');
    }
  }

  Future<bool> isDarkMode() async {
    try {
      final val = await _secureStorage.read(key: keyDarkMode);
      return val == 'true';
    } catch (e) {
      debugPrint('[AuthDiag:StorageService] Error reading dark mode: $e');
      return false;
    }
  }

  Future<void> setReduceTransparency(bool reduce) async {
    try {
      await _secureStorage.write(key: keyReduceTransparency, value: reduce.toString());
    } catch (e) {
      debugPrint('[AuthDiag:StorageService] Error setting reduce transparency: $e');
    }
  }

  Future<bool> isReduceTransparency() async {
    try {
      final val = await _secureStorage.read(key: keyReduceTransparency);
      return val == 'true';
    } catch (e) {
      debugPrint('[AuthDiag:StorageService] Error reading reduce transparency: $e');
      return false;
    }
  }

  Future<void> saveRememberMe(bool remember) async {
    try {
      await _secureStorage.write(key: keyRememberMe, value: remember.toString());
    } catch (e) {
      debugPrint('[AuthDiag:StorageService] Error saving remember me: $e');
    }
  }

  Future<bool> getRememberMe() async {
    try {
      final val = await _secureStorage.read(key: keyRememberMe);
      return val != 'false';
    } catch (e) {
      debugPrint('[AuthDiag:StorageService] Error reading remember me: $e');
      return true;
    }
  }

  /// Removes only the session keys. Keeps UI preferences (dark mode, reduce transparency).
  Future<void> clearSession() async {
    for (final key in [keyToken, keyRefreshToken, keyUserData, keyRememberMe]) {
      try {
        await _secureStorage.delete(key: key);
      } catch (e) {
        debugPrint('[AuthDiag:StorageService] Error deleting $key: $e');
      }
    }
  }

  Future<void> clearAll() async {
    try {
      await _secureStorage.deleteAll();
      debugPrint('[AuthDiag:StorageService] clearAll successful');
    } catch (e) {
      debugPrint('[AuthDiag:StorageService] Error clearing secure storage: $e; falling back to individual deletion');
    }
    // Always fallback to ensure all auth and user keys are deleted even if deleteAll() throws
    try { await _secureStorage.delete(key: keyToken); } catch (_) {}
    try { await _secureStorage.delete(key: keyRefreshToken); } catch (_) {}
    try { await _secureStorage.delete(key: keyUserData); } catch (_) {}
    try { await _secureStorage.delete(key: keyRememberMe); } catch (_) {}
  }
}