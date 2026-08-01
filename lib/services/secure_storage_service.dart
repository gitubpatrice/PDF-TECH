import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service de stockage securise local pour les metadonnees sensibles de
/// PDF Tech (fichiers recents, dernieres pages lues, cache de mise a jour,
/// preferences applicatives).
///
/// Utilise [FlutterSecureStorage] (Keychain iOS, Keystore Android) au lieu de
/// [SharedPreferences] pour eviter que les metadonnees utilisateur (paths,
/// noms de fichiers, pages lues) ne soient lisibles en clair sur le stockage
/// de l'appareil.
///
/// Les valeurs complexes sont serialisees en JSON.
class SecureStorageService {
  SecureStorageService._();

  static const _options = AndroidOptions(
    encryptedSharedPreferences: true,
    keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
    storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
  );

  static final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: _options,
  );

  static Future<String?> readString(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      if (kDebugMode) debugPrint('[SecureStorageService] readString error: $e');
      return null;
    }
  }

  static Future<void> writeString(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SecureStorageService] writeString error: $e');
      }
    }
  }

  static Future<bool> readBool(String key, {bool defaultValue = false}) async {
    final raw = await readString(key);
    if (raw == null) return defaultValue;
    return raw == 'true';
  }

  static Future<void> writeBool(String key, bool value) async {
    await writeString(key, value ? 'true' : 'false');
  }

  static Future<int?> readInt(String key) async {
    final raw = await readString(key);
    if (raw == null) return null;
    return int.tryParse(raw);
  }

  static Future<void> writeInt(String key, int value) async {
    await writeString(key, value.toString());
  }

  static Future<List<String>> readStringList(String key) async {
    final raw = await readString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.whereType<String>().toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SecureStorageService] readStringList error: $e');
      }
      return const [];
    }
  }

  static Future<void> writeStringList(String key, List<String> value) async {
    await writeString(key, jsonEncode(value));
  }

  static Future<void> remove(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      if (kDebugMode) debugPrint('[SecureStorageService] remove error: $e');
    }
  }

  static Future<void> clear() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      if (kDebugMode) debugPrint('[SecureStorageService] clear error: $e');
    }
  }
}
