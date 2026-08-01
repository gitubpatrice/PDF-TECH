import 'dart:io';

import 'package:files_tech_core/files_tech_core.dart';

import '../../services/secure_storage_service.dart';

/// Version chiffree de [RecentFilesService] : les metadonnees des fichiers
/// recents (path, nom, date d'ouverture, taille) sont stockees dans
/// [FlutterSecureStorage] au lieu de [SharedPreferences].
class SecureRecentFilesService {
  final String key;
  final int maxFiles;

  const SecureRecentFilesService({
    this.key = 'secure_recent_files',
    this.maxFiles = 20,
  });

  Future<List<RecentFile>> load() async {
    final raw = await SecureStorageService.readStringList(key);
    final out = <RecentFile>[];
    for (final s in raw) {
      try {
        final f = RecentFile.fromJsonString(s);
        if (await File(f.path).exists()) out.add(f);
      } catch (_) {
        // Entree corrompue -> ignoree, reecriture assainie plus bas.
      }
    }
    out.sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
    if (out.length != raw.length) await _save(out);
    return out;
  }

  Future<List<RecentFile>> addOrUpdate(
    List<RecentFile> current,
    String path,
  ) async {
    final file = File(path);
    if (!await file.exists()) return current;
    final String name;
    try {
      name = PathSafe.basename(path);
    } on ArgumentError {
      return current;
    }
    final size = await file.length();
    final existing = current
        .where((f) => f.path == path)
        .cast<RecentFile?>()
        .firstWhere((_) => true, orElse: () => null);
    final isFav = existing?.isFavorite ?? false;
    final updated = [
      RecentFile(
        path: path,
        name: name,
        lastOpened: DateTime.now(),
        sizeBytes: size,
        isFavorite: isFav,
      ),
      ...current.where((f) => f.path != path),
    ];
    final trimmed = updated.take(maxFiles).toList();
    await _save(trimmed);
    return trimmed;
  }

  Future<List<RecentFile>> remove(List<RecentFile> current, String path) async {
    final updated = current.where((f) => f.path != path).toList();
    await _save(updated);
    return updated;
  }

  Future<List<RecentFile>> toggleFavorite(
    List<RecentFile> current,
    String path,
  ) async {
    final updated = current
        .map((f) => f.path == path ? f.copyWith(isFavorite: !f.isFavorite) : f)
        .toList();
    await _save(updated);
    return updated;
  }

  Future<void> _save(List<RecentFile> files) async {
    await SecureStorageService.writeStringList(
      key,
      files.map((f) => f.toJsonString()).toList(),
    );
  }
}
