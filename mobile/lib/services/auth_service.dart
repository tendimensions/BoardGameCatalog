import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/constants.dart';

/// Manages secure storage and retrieval of the API key.
class AuthService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Returns the stored API key, or null if none is saved.
  Future<String?> getApiKey() async {
    return _storage.read(key: AppConstants.apiKeyStorageKey);
  }

  /// Saves the API key to secure storage.
  Future<void> saveApiKey(String key) async {
    await _storage.write(key: AppConstants.apiKeyStorageKey, value: key);
  }

  /// Removes the API key (sign out).
  Future<void> clearApiKey() async {
    await _storage.delete(key: AppConstants.apiKeyStorageKey);
  }

  /// Returns true if an API key is stored.
  Future<bool> isLoggedIn() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }
}
