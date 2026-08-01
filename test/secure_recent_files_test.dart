import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_tech/services/secure_recent_files_service.dart';

void main() {
  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('SecureRecentFilesService', () {
    const service = SecureRecentFilesService(key: 'secure_recents_test');

    test('load retourne une liste vide au depart', () async {
      final files = await service.load();
      expect(files, isEmpty);
    });

    test('addOrUpdate refuse un chemin avec basename invalide', () async {
      final result = await service.addOrUpdate([], '/foo/..');
      expect(result, isEmpty);
    });

    test('addOrUpdate ajoute un fichier PDF valide', () async {
      final tmp = Directory.systemTemp.createTempSync('pdf_tech_test');
      final file = File('${tmp.path}/test.pdf');
      await file.writeAsBytes(List<int>.filled(100, 0));

      final files = await service.addOrUpdate([], file.path);
      expect(files.length, 1);
      expect(files.first.name, 'test.pdf');
      expect(files.first.path, file.path);

      await service.remove(files, file.path);
      tmp.deleteSync(recursive: true);
    });

    test('toggleFavorite met a jour le statut favori', () async {
      final tmp = Directory.systemTemp.createTempSync('pdf_tech_test');
      final file = File('${tmp.path}/fav.pdf');
      await file.writeAsBytes(List<int>.filled(50, 0));

      final files = await service.addOrUpdate([], file.path);
      final withFav = await service.toggleFavorite(files, file.path);
      expect(withFav.first.isFavorite, true);

      await service.remove(withFav, file.path);
      tmp.deleteSync(recursive: true);
    });
  });
}
