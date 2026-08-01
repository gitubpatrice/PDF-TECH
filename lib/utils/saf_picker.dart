import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Groupe de type pour les fichiers PDF, utilisé par `file_selector`.
const _pdfTypeGroup = XTypeGroup(
  label: 'PDF',
  extensions: ['pdf'],
  mimeTypes: ['application/pdf'],
);

/// Helper SAF (Storage Access Framework) basé sur `file_selector`.
///
/// Contrairement à `file_picker`, ce helper utilise l’intent natif
/// `ACTION_OPEN_DOCUMENT` qui est plus fiable sur Android 15 / émulateurs
/// pour la sélection de fichiers. Les URI `content://` retournées par SAF
/// sont copiées dans le répertoire privé de l’application afin d’obtenir
/// un chemin fichier classique utilisable par les différents écrans/outils.
class SafPicker {
  SafPicker._();

  /// Sélectionne un seul fichier PDF.
  /// Retourne le chemin local (app-private) du fichier copié, ou `null` si
  /// l’utilisateur annule.
  static Future<String?> pickPdf() async {
    final file = await openFile(acceptedTypeGroups: [_pdfTypeGroup]);
    if (file == null) return null;
    return _persistXFile(file);
  }

  /// Sélectionne plusieurs fichiers PDF.
  /// Retourne la liste des chemins locaux (app-private) copiés.
  static Future<List<String>> pickPdfs() async {
    final files = await openFiles(acceptedTypeGroups: [_pdfTypeGroup]);
    final paths = <String>[];
    for (final file in files) {
      final path = await _persistXFile(file);
      if (path != null) paths.add(path);
    }
    return paths;
  }

  /// Sélectionne un dossier via `ACTION_OPEN_DOCUMENT_TREE`.
  /// Retourne le chemin du dossier, ou `null` si l’utilisateur annule.
  ///
  /// Note : sur Android, `getDirectoryPath()` retourne généralement un chemin
  /// réel (pas d’URI `content://`), mais ce n’est pas garanti sur tous les
  /// devices. L’écran appelant doit gérer l’accès via le path retourné.
  static Future<String?> pickDirectory() async {
    return getDirectoryPath();
  }

  /// Copie le contenu d’un [XFile] (potentiellement une URI `content://`)
  /// dans le répertoire documents de l’application et retourne le chemin local.
  static Future<String?> _persistXFile(XFile file) async {
    final name = p.basename(file.path);
    // Nettoie le nom de fichier pour éviter les chemins traversaux.
    final safeName = _sanitizeFileName(name);
    if (safeName.isEmpty) {
      if (kDebugMode) {
        debugPrint('[SafPicker] empty or invalid file name: $name');
      }
      return null;
    }

    try {
      final baseDir = await getApplicationDocumentsDirectory();
      final destDir = Directory(p.join(baseDir.path, 'saf_imports'));
      if (!destDir.existsSync()) {
        destDir.createSync(recursive: true);
      }
      final destPath = p.join(destDir.path, safeName);
      final bytes = await file.readAsBytes();
      await File(destPath).writeAsBytes(bytes, flush: true);
      if (kDebugMode) {
        debugPrint(
          '[SafPicker] copied SAF file to: $destPath (${bytes.length} bytes)',
        );
      }
      return destPath;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[SafPicker] failed to persist ${file.path}: $e\n$st');
      }
      return null;
    }
  }

  /// Supprime les caractères interdits et retourne un nom de fichier sûr.
  static String _sanitizeFileName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    // Autorise lettres, chiffres, espaces et quelques ponctuations courantes.
    final cleaned = trimmed.replaceAll(RegExp(r'[^\w\s\.\-\(\)]'), '_');
    // Évite les noms réservés ou vides après nettoyage.
    final withoutDots = cleaned.replaceAll(RegExp(r'^[\.\s]+|[\.\s]+$'), '');
    return withoutDots.isEmpty ? 'document.pdf' : withoutDots;
  }
}
