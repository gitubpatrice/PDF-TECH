import 'secure_storage_service.dart';

/// Preferences applicatives sensibles stockees de maniere chiffree.
class SecureAppPreferences {
  static const _fullStorageKey = 'full_storage_mode_v1';

  static Future<bool> getFullStorageMode() async {
    return SecureStorageService.readBool(_fullStorageKey);
  }

  static Future<void> setFullStorageMode(bool value) async {
    await SecureStorageService.writeBool(_fullStorageKey, value);
  }
}
