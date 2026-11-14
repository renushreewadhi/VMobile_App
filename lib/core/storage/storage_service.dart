import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';
import '../errors/api_exception.dart';

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
      debugPrint('[AuthDiag:StorageService] Error saving token: $e; attempting targeted key recovery');
      try {
        await _secureStorage.delete(key: keyToken);
        await _secureStorage.write(key: keyToken, value: token);
      } catch (innerE) {
        debugPrint('[AuthDiag:StorageService] Recovery saveToken failed: $innerE');
        rethrow;
      }
    }
  }

  Future<String?> getToken() async {
    try {
      return await _secureStorage.read(key: keyToken);
    } catch (e) {
      debugPrint('[AuthDiag:StorageService] Error reading token: $e; clearing corrupted token key');
      try { await _secureStorage.delete(key: keyToken); } catch (_) {}
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
      debugPrint('[AuthDiag:StorageService] Error saving refresh token: $e; attempting targeted key recovery');
      try {
        await _secureStorage.delete(key: keyRefreshToken);
        await _secureStorage.write(key: keyRefreshToken, value: refreshToken);
      } catch (innerE) {
        debugPrint('[AuthDiag:StorageService] Recovery saveRefreshToken failed: $innerE');
        rethrow;
      }
    }
  }

  Future<String?> getRefreshToken() async {
    try {
      return await _secureStorage.read(key: keyRefreshToken);
    } catch (e) {
      debugPrint('[AuthDiag:StorageService] Error reading refresh token: $e; clearing corrupted refresh token key');
      try { await _secureStorage.delete(key: keyRefreshToken); } catch (_) {}
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
      debugPrint('[AuthDiag:StorageService] Error saving user data: $e; attempting targeted key recovery');
      try {
        await _secureStorage.delete(key: keyUserData);
        await _secureStorage.write(key: keyUserData, value: userDataJson);
      } catch (innerE) {
        debugPrint('[AuthDiag:StorageService] Recovery saveUserData failed: $innerE');
        rethrow;
      }
    }
  }

  Future<String?> getUserData() async {
    try {
      return await _secureStorage.read(key: keyUserData);
    } catch (e) {
      debugPrint('[AuthDiag:StorageService] Error reading user data: $e; clearing corrupted user data key');
      try { await _secureStorage.delete(key: keyUserData); } catch (_) {}
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

  /// Retrieves or generates an account-isolated 256-bit AES key for encryption
  Future<String> getOrCreateUserAesKey(String userId) async {
    final keyStorageName = 'user_${userId}_aes_gcm_key';
    final existingBase64Key = await _secureStorage.read(key: keyStorageName);
    if (existingBase64Key != null && existingBase64Key.isNotEmpty) {
      return existingBase64Key;
    }
    final random = Random.secure();
    final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));
    final newBase64Key = base64Encode(keyBytes);
    await _secureStorage.write(key: keyStorageName, value: newBase64Key);
    return newBase64Key;
  }

  /// Encrypts PDF bytes using AES-256-GCM and saves to secure account storage (.enc)
  Future<File> encryptAndSavePayslipBytes({
    required Uint8List pdfBytes,
    required String userId,
    required String payrollId,
    required String targetDirectoryPath,
  }) async {
    final base64Key = await getOrCreateUserAesKey(userId);
    final keyBytes = base64Decode(base64Key);

    final random = Random.secure();
    final nonceBytes = Uint8List.fromList(List<int>.generate(12, (_) => random.nextInt(256)));

    final encryptedBytes = AesGcmPayslipCrypto.encrypt(
      plaintext: pdfBytes,
      key: keyBytes,
      nonce: nonceBytes,
    );

    final userDir = Directory('$targetDirectoryPath/user_$userId');
    if (!userDir.existsSync()) {
      await userDir.create(recursive: true);
    }

    final encFile = File('${userDir.path}/payslip_$payrollId.enc');

    // Layout: [12-byte Nonce] + [Ciphertext + 16-byte Auth Tag]
    final builder = BytesBuilder();
    builder.add(nonceBytes);
    builder.add(encryptedBytes);

    await encFile.writeAsBytes(builder.toBytes(), flush: true);
    return encFile;
  }

  /// Decrypts an AES-256-GCM encrypted payslip file (.enc) and verifies GCM authentication tag
  Future<Uint8List> decryptPayslipFile({
    required File encFile,
    required String userId,
  }) async {
    if (!await encFile.exists()) {
      throw ApiException('Encrypted payslip file not found.');
    }

    try {
      final rawBytes = await encFile.readAsBytes();
      if (rawBytes.length < 28) {
        if (await encFile.exists()) await encFile.delete();
        throw ApiException('Corrupted or invalid encrypted payslip file.');
      }

      final nonceBytes = rawBytes.sublist(0, 12);
      final ciphertextWithTag = rawBytes.sublist(12);

      final base64Key = await getOrCreateUserAesKey(userId);
      final keyBytes = base64Decode(base64Key);

      return AesGcmPayslipCrypto.decrypt(
        ciphertextWithTag: ciphertextWithTag,
        key: keyBytes,
        nonce: nonceBytes,
      );
    } catch (e) {
      debugPrint('[StorageService] AES-256-GCM decryption/tag verification failed: $e');
      if (await encFile.exists()) {
        try { await encFile.delete(); } catch (_) {}
      }
      if (e is ApiException) rethrow;
      throw ApiException('Decryption failed. File may be corrupted or tampered with.');
    }
  }

  /// Account-scoped cache helper methods
  Future<void> saveAccountCache(String userId, String key, String jsonValue) async {
    final scopedKey = 'user_${userId}_cache_$key';
    try {
      await _secureStorage.write(key: scopedKey, value: jsonValue);
    } catch (e) {
      debugPrint('[AuthDiag:StorageService] Error saving account cache: $e');
    }
  }

  Future<String?> getAccountCache(String userId, String key) async {
    final scopedKey = 'user_${userId}_cache_$key';
    try {
      return await _secureStorage.read(key: scopedKey);
    } catch (e) {
      return null;
    }
  }

  Future<void> clearAccountCache(String userId) async {
    try {
      final allKeys = await _secureStorage.readAll();
      final prefix = 'user_${userId}_cache_';
      final keysToDelete = allKeys.keys.where((k) => k.startsWith(prefix)).toList();
      for (final k in keysToDelete) {
        await _secureStorage.delete(key: k);
      }
    } catch (e) {
      debugPrint('[AuthDiag:StorageService] Error clearing account cache: $e');
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

class AesGcmPayslipCrypto {
  static Uint8List encrypt({
    required Uint8List plaintext,
    required Uint8List key,
    required Uint8List nonce,
  }) {
    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0));
    cipher.init(true, params);
    return cipher.process(plaintext);
  }

  static Uint8List decrypt({
    required Uint8List ciphertextWithTag,
    required Uint8List key,
    required Uint8List nonce,
  }) {
    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0));
    cipher.init(false, params);
    return cipher.process(ciphertextWithTag);
  }
}