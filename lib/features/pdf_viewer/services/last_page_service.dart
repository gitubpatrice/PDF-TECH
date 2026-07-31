import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Service de persistence de la dernière page lue pour un PDF donné.
///
/// Gère :
/// - un debounce pour éviter d'écrire à chaque changement de page lors d'un
///   scroll rapide ;
/// - un index LRU pour limiter le nombre de clés `last_page_*` stockées et
///   éviter de gonfler indéfiniment SharedPreferences.
class LastPageService {
  LastPageService();

  static const _idxKey = 'last_page_lru_v1';
  static const _nightKey = 'night_mode_pdf';
  static const _lastPageMaxEntries = 200;

  Timer? _saveDebounce;
  int? _pendingPage;

  /// Charge la dernière page sauvegardée pour [path] ainsi que le mode nuit
  /// global.
  Future<LastPagePrefs> load(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefKey(path);
    return LastPagePrefs(
      page: prefs.getInt(key) ?? 1,
      nightMode: prefs.getBool(_nightKey) ?? false,
    );
  }

  /// Persiste la page [page] pour [path] avec debounce.
  void scheduleSave(String path, int page) {
    _pendingPage = page;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () async {
      final p = _pendingPage;
      if (p == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKey(path), p);
      await _bumpLruAndCap(prefs, path.hashCode);
      _pendingPage = null;
    });
  }

  /// Persiste immédiatement la page en attente si elle existe.
  Future<void> flush(String path) async {
    _saveDebounce?.cancel();
    final p = _pendingPage;
    if (p == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey(path), p);
    await _bumpLruAndCap(prefs, path.hashCode);
    _pendingPage = null;
  }

  /// Bascule et persiste le mode nuit global.
  Future<bool> toggleNightMode(bool current) async {
    final next = !current;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_nightKey, next);
    return next;
  }

  Future<void> _bumpLruAndCap(SharedPreferences prefs, int currentHash) async {
    final raw = prefs.getStringList(_idxKey) ?? const <String>[];
    final updated = raw.where((h) => h != '$currentHash').toList()
      ..add('$currentHash');
    while (updated.length > _lastPageMaxEntries) {
      final evicted = updated.removeAt(0);
      await prefs.remove('last_page_$evicted');
    }
    await prefs.setStringList(_idxKey, updated);
  }

  static String _prefKey(String path) => 'last_page_${path.hashCode}';

  void dispose() {
    _saveDebounce?.cancel();
  }
}

class LastPagePrefs {
  final int page;
  final bool nightMode;

  const LastPagePrefs({required this.page, required this.nightMode});
}
