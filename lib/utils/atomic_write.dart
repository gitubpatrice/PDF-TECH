/// Helpers d'écriture atomique pour fichiers PDF.
///
/// Pattern POSIX : write tmp → fsync (via flush:true) → rename atomique.
/// Sur Android, `rename` sur le même filesystem est atomique. Si la
/// machine crash entre `write` et `rename`, le fichier original reste
/// intact (l'utilisateur a perdu les modifs in-flight, mais pas les
/// données existantes — ce qui est l'invariant attendu pour un éditeur
/// de PDF).
///
/// Usage typique (annotations save, form fill flatten) :
///
/// ```dart
/// // Au lieu de : await File(path).writeAsBytes(bytes);
/// await atomicWriteBytes(path, bytes);
/// ```
library;

import 'dart:io';

/// Écrit [bytes] dans [path] de manière atomique (write tmp + rename).
///
/// Accepte `List<int>` pour rester compatible avec les API qui ne
/// retournent pas un `Uint8List` strict (ex : `SfPdfViewerController.saveDocument()`).
///
/// Si une exception survient avant `rename`, le fichier `.tmp` est
/// nettoyé best-effort. Le fichier cible reste inchangé.
///
/// Sur succès, `path` contient les nouveaux bytes ; sur échec, il
/// contient toujours les anciens bytes (ou n'existe pas).
Future<void> atomicWriteBytes(String path, List<int> bytes) async {
  final tmpPath = '$path.tmp';
  final tmpFile = File(tmpPath);
  try {
    // `flush: true` garantit fsync(2) avant retour — sans ça, la donnée
    // peut rester dans le page cache OS et un kernel panic la perdrait.
    await tmpFile.writeAsBytes(bytes, flush: true);
    // `rename` POSIX : opération atomique sur même FS. Sur Android le
    // sandbox app est entièrement sur `/data` donc OK.
    await tmpFile.rename(path);
  } catch (e) {
    // Cleanup best-effort du tmp si l'écriture a partiellement réussi
    // mais le rename a échoué (ex: target en cours d'utilisation par
    // un autre handle). Le fichier original reste intact.
    try {
      if (await tmpFile.exists()) {
        await tmpFile.delete();
      }
    } catch (_) {
      /* swallow — best-effort cleanup */
    }
    rethrow;
  }
}

/// Variante string. UTF-8 par défaut. Ajouté v1.12.2 pour OCR text export
/// (`_saveAsTxt`) et autres flux text-based.
Future<void> atomicWriteString(String path, String content) async {
  final tmpPath = '$path.tmp';
  final tmpFile = File(tmpPath);
  try {
    await tmpFile.writeAsString(content, flush: true);
    await tmpFile.rename(path);
  } catch (e) {
    try {
      if (await tmpFile.exists()) await tmpFile.delete();
    } catch (_) {}
    rethrow;
  }
}
