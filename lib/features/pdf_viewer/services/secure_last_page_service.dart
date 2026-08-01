import 'dart:async';

import '../../../services/secure_storage_service.dart';

/// Version chiffree de [LastPageService] : persiste la derniere page lue
/// et le mode nuit dans [FlutterSecureStorage] au lieu de [SharedPreferences].
///
/// Garde la meme API que le service original pour faciliter la migration.
class SecureLastPageService {
  SecureLastPageService();

  static const _idxKey = 'secure_last_page_lru_v1';
  static const _nightKey = 'secure_night_mode_pdf';
  static const _lastPageMaxEntries = 200;

  Timer? _saveDebounce;
  int? _pendingPage;

  Future<LastPagePrefs> load(String path) async {
    final key = _prefKey(path);
    final page = await SecureStorageService.readInt(key) ?? 1;
    final nightMode = await SecureStorageService.readBool(_nightKey);
    return LastPagePrefs(page: page, nightMode: nightMode);
  }

  void scheduleSave(String path, int page) {
    _pendingPage = page;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () async {
      final p = _pendingPage;
      if (p == null) return;
      await SecureStorageService.writeInt(_prefKey(path), p);
      await _bumpLruAndCap(path.hashCode);
      _pendingPage = null;
    });
  }

  Future<void> flush(String path) async {
    _saveDebounce?.cancel();
    final p = _pendingPage;
    if (p == null) return;
    await SecureStorageService.writeInt(_prefKey(path), p);
    await _bumpLruAndCap(path.hashCode);
    _pendingPage = null;
  }

  Future<bool> toggleNightMode(bool current) async {
    final next = !current;
    await SecureStorageService.writeBool(_nightKey, next);
    return next;
  }

  Future<void> _bumpLruAndCap(int currentHash) async {
    final raw = await SecureStorageService.readStringList(_idxKey);
    final hashStr = '$currentHash';
    final updated = raw.where((h) => h != hashStr).toList()..add(hashStr);
    while (updated.length > _lastPageMaxEntries) {
      final evicted = updated.removeAt(0);
      await SecureStorageService.remove('secure_last_page_$evicted');
    }
    await SecureStorageService.writeStringList(_idxKey, updated);
  }

  static String _prefKey(String path) => 'secure_last_page_${path.hashCode}';

  void dispose() {
    _saveDebounce?.cancel();
  }
}

class LastPagePrefs {
  final int page;
  final bool nightMode;

  const LastPagePrefs({required this.page, required this.nightMode});
}
