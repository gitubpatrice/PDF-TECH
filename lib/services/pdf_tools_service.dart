import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../utils/atomic_write.dart';
import 'isolate_runner.dart';

/// Thrown when the input file is too big or not a valid PDF.
class PdfValidationException implements Exception {
  final String message;
  const PdfValidationException(this.message);
  @override
  String toString() => message;
}

class PdfToolsService {
  /// Hard cap on PDF input size (200 MB). Prevents OOM on very large or
  /// zip-bomb-style files. Adjust if real workflows need more.
  static const int _maxPdfBytes = 200 * 1024 * 1024;

  /// Hard cap exposed for callers that need to display the limit.
  static int get maxPdfBytes => _maxPdfBytes;

  /// Reads a PDF file with size validation and magic-bytes sniffing.
  /// Throws [PdfValidationException] on oversized / non-PDF input.
  ///
  /// Public entry point for screens that previously did
  /// `File(path).readAsBytes()` directly: routing through this method
  /// enforces the 200 MB cap and the `%PDF-` signature check.
  static Future<Uint8List> safeReadPdf(String path) => _safeReadPdf(path);

  /// Avoids the `Uint8List.fromList(doc.saveSync())` re-copy when Syncfusion
  /// already returns a `Uint8List` (which it currently does). Falls back to
  /// the copy only when the runtime type is a generic `List<int>`.
  static Uint8List _toBytes(List<int> saved) {
    return saved is Uint8List ? saved : Uint8List.fromList(saved);
  }

  static Future<Uint8List> _safeReadPdf(String path) async {
    final f = File(path);
    if (!await f.exists()) {
      throw const PdfValidationException('Fichier introuvable');
    }
    final length = await f.length();
    if (length > _maxPdfBytes) {
      throw PdfValidationException(
        'PDF trop volumineux (max ${_maxPdfBytes ~/ (1024 * 1024)} Mo)',
      );
    }
    if (length < 5) {
      throw const PdfValidationException('Fichier PDF invalide');
    }
    final bytes = await f.readAsBytes();
    // Magic bytes: PDF files start with "%PDF-".
    if (bytes[0] != 0x25 ||
        bytes[1] != 0x50 ||
        bytes[2] != 0x44 ||
        bytes[3] != 0x46 ||
        bytes[4] != 0x2D) {
      throw const PdfValidationException('Fichier non PDF (signature absente)');
    }
    return bytes;
  }

  /// Génère un chemin de sortie horodaté dans `getApplicationDocumentsDirectory`.
  ///
  /// **API publique statique** (audit dup v1.12) : avant cette refonte,
  /// 9 écrans `tool_*_screen.dart` réimplémentaient ce triplet
  /// `getApplicationDocumentsDirectory + ts + path` à la main. Ils peuvent
  /// désormais l'appeler directement, gardant la cohérence du naming des
  /// fichiers de sortie (`<base>_<timestamp_ms>.pdf`).
  static Future<String> outputPath(String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/${name}_$ts.pdf';
  }

  /// Écrit [bytes] de manière atomique (write tmp + rename) et renvoie le
  /// chemin final. Déduplique le pattern `outputPath` + `atomicWriteBytes`
  /// utilisé dans toutes les méthodes du service.
  static Future<String> _saveAtomic(String name, Uint8List bytes) async {
    final path = await outputPath(name);
    await atomicWriteBytes(path, bytes);
    return path;
  }

  /// Generates a cryptographically-strong random owner password.
  static String _randomOwnerPassword() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#%&*';
    final rng = Random.secure();
    return List.generate(32, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ── Merge ─────────────────────────────────────────────────────────────────

  Future<String> mergePdfs(List<String> inputPaths) async {
    // Lecture + validation IO en main, parsing+merge dans Isolate (heavy).
    final allBytes = <Uint8List>[];
    for (final path in inputPaths) {
      allBytes.add(await _safeReadPdf(path));
    }
    final out = await runPdfIsolate(() => _mergeIsolate(allBytes));
    return _saveAtomic('fusion', out);
  }

  static Uint8List _mergeIsolate(List<Uint8List> allBytes) {
    final merged = PdfDocument();
    merged.pageSettings.margins.all = 0;
    PdfDocument? source;
    try {
      for (final bytes in allBytes) {
        source = PdfDocument(inputBytes: bytes);
        for (int i = 0; i < source.pages.count; i++) {
          final srcPage = source.pages[i];
          merged.pageSettings.size = srcPage.size;
          final newPage = merged.pages.add();
          newPage.graphics.drawPdfTemplate(
            srcPage.createTemplate(),
            Offset.zero,
          );
        }
        source.dispose();
        source = null;
      }
      return _toBytes(merged.saveSync());
    } finally {
      source
          ?.dispose(); // au cas où le throw est entre PdfDocument() et dispose
      merged.dispose();
    }
  }

  // ── Split ─────────────────────────────────────────────────────────────────

  Future<String> splitPdf(String inputPath, int fromPage, int toPage) async {
    final bytes = await _safeReadPdf(inputPath);
    final out = await runPdfIsolate(
      () => _splitIsolate(bytes, fromPage, toPage),
    );
    return _saveAtomic('extrait_p${fromPage}_$toPage', out);
  }

  static Uint8List _splitIsolate(Uint8List bytes, int fromPage, int toPage) {
    final source = PdfDocument(inputBytes: bytes);
    final result = PdfDocument();
    try {
      final total = source.pages.count;
      result.pageSettings.margins.all = 0;
      final from = fromPage.clamp(1, total) - 1;
      final to = toPage.clamp(1, total) - 1;
      for (int i = from; i <= to; i++) {
        final srcPage = source.pages[i];
        result.pageSettings.size = srcPage.size;
        final newPage = result.pages.add();
        newPage.graphics.drawPdfTemplate(srcPage.createTemplate(), Offset.zero);
      }
      return _toBytes(result.saveSync());
    } finally {
      source.dispose();
      result.dispose();
    }
  }

  // ── Protect ───────────────────────────────────────────────────────────────

  Future<String> protectPdf(String inputPath, String userPassword) async {
    final bytes = await _safeReadPdf(inputPath);
    final ownerPwd = _randomOwnerPassword();
    final out = await runPdfIsolate(
      () => _protectIsolate(bytes, userPassword, ownerPwd),
    );
    return _saveAtomic('protege', out);
  }

  static Uint8List _protectIsolate(
    Uint8List bytes,
    String userPassword,
    String ownerPassword,
  ) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      document.security.userPassword = userPassword;
      document.security.ownerPassword = ownerPassword;
      document.security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;
      return _toBytes(document.saveSync());
    } finally {
      document.dispose();
    }
  }

  // ── Rotate ────────────────────────────────────────────────────────────────

  Future<String> rotatePdf(String inputPath, PdfPageRotateAngle angle) async {
    final bytes = await _safeReadPdf(inputPath);
    // Le angle est un enum, sendable sans souci.
    final out = await runPdfIsolate(() => _rotateIsolate(bytes, angle));
    return _saveAtomic('rotation', out);
  }

  static Uint8List _rotateIsolate(Uint8List bytes, PdfPageRotateAngle angle) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      for (int i = 0; i < document.pages.count; i++) {
        document.pages[i].rotation = angle;
      }
      return _toBytes(document.saveSync());
    } finally {
      document.dispose();
    }
  }

  // ── Watermark ─────────────────────────────────────────────────────────────

  Future<String> addWatermark(
    String inputPath,
    String text, {
    double opacity = 0.25,
    Color color = Colors.grey,
  }) async {
    final bytes = await _safeReadPdf(inputPath);
    final r = (color.r * 255).round();
    final g = (color.g * 255).round();
    final b = (color.b * 255).round();
    final out = await runPdfIsolate(
      () => _watermarkIsolate(bytes, text, opacity, r, g, b),
    );
    return _saveAtomic('filigrane', out);
  }

  static Uint8List _watermarkIsolate(
    Uint8List bytes,
    String text,
    double opacity,
    int r,
    int g,
    int b,
  ) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      // Hisser hors boucle (audit perf v1.12) : éviter N allocations.
      final font = PdfStandardFont(
        PdfFontFamily.helvetica,
        52,
        style: PdfFontStyle.bold,
      );
      final brush = PdfSolidBrush(PdfColor(r, g, b));
      for (int i = 0; i < document.pages.count; i++) {
        final page = document.pages[i];
        final size = page.getClientSize();
        final gfx = page.graphics;
        gfx.save();
        gfx.setTransparency(opacity);
        gfx.translateTransform(size.width / 2, size.height / 2);
        gfx.rotateTransform(-45);
        gfx.drawString(
          text,
          font,
          brush: brush,
          bounds: Rect.fromCenter(center: Offset.zero, width: 500, height: 120),
          format: PdfStringFormat(
            alignment: PdfTextAlignment.center,
            lineAlignment: PdfVerticalAlignment.middle,
          ),
        );
        gfx.restore();
      }
      return _toBytes(document.saveSync());
    } finally {
      document.dispose();
    }
  }

  // ── Stamp (timbre, similaire à watermark mais option première-page) ──────

  /// Ajoute un texte type "tampon" sur le PDF.
  /// [firstOnly] : si vrai, le tampon n'est posé que sur la première page.
  /// Centralise le pattern qui était auparavant dupliqué dans
  /// `stamp_screen._stampIsolate` (audit dup v1.12).
  Future<String> addStamp(
    String inputPath,
    String text, {
    double opacity = 0.5,
    Color color = Colors.red,
    bool firstOnly = false,
  }) async {
    final bytes = await _safeReadPdf(inputPath);
    final r = (color.r * 255).round();
    final g = (color.g * 255).round();
    final b = (color.b * 255).round();
    final out = await runPdfIsolate(
      () => _stampIsolate(bytes, text, opacity, r, g, b, firstOnly),
    );
    return _saveAtomic('tampon', out);
  }

  static Uint8List _stampIsolate(
    Uint8List bytes,
    String text,
    double opacity,
    int r,
    int g,
    int b,
    bool firstOnly,
  ) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      final font = PdfStandardFont(
        PdfFontFamily.helvetica,
        54,
        style: PdfFontStyle.bold,
      );
      final brush = PdfSolidBrush(PdfColor(r, g, b));
      final pageCount = firstOnly ? 1 : document.pages.count;
      for (int i = 0; i < pageCount; i++) {
        final page = document.pages[i];
        final size = page.getClientSize();
        final gfx = page.graphics;
        gfx.save();
        gfx.setTransparency(opacity);
        gfx.translateTransform(size.width / 2, size.height / 2);
        gfx.rotateTransform(-45);
        gfx.drawString(
          text,
          font,
          brush: brush,
          bounds: Rect.fromCenter(center: Offset.zero, width: 500, height: 120),
          format: PdfStringFormat(
            alignment: PdfTextAlignment.center,
            lineAlignment: PdfVerticalAlignment.middle,
          ),
        );
        gfx.restore();
      }
      return _toBytes(document.saveSync());
    } finally {
      document.dispose();
    }
  }

  // ── Create ────────────────────────────────────────────────────────────────

  Future<String> createPdf({
    required String title,
    required String content,
    String author = 'PDF Tech',
  }) async {
    final out = await runPdfIsolate(
      () => _createIsolate(title, content, author),
    );
    final safeName = title
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(' ', '_');
    return _saveAtomic(safeName.isEmpty ? 'nouveau_document' : safeName, out);
  }

  static Uint8List _createIsolate(String title, String content, String author) {
    final document = PdfDocument();
    try {
      document.documentInformation.title = title;
      document.documentInformation.author = author;
      final page = document.pages.add();
      _drawPage(page, title, content, 0);
      _addPageNumbers(document);
      return _toBytes(document.saveSync());
    } finally {
      document.dispose();
    }
  }

  static void _drawPage(
    PdfPage page,
    String title,
    String content,
    int pageIndex,
  ) {
    final size = page.getClientSize();
    final blue = PdfColor(21, 101, 192);
    if (pageIndex == 0) {
      page.graphics.drawString(
        title,
        PdfStandardFont(PdfFontFamily.helvetica, 22, style: PdfFontStyle.bold),
        brush: PdfSolidBrush(blue),
        bounds: Rect.fromLTWH(0, 0, size.width, 40),
        format: PdfStringFormat(alignment: PdfTextAlignment.left),
      );
      page.graphics.drawLine(
        PdfPen(blue, width: 1.5),
        const Offset(0, 46),
        Offset(size.width, 46),
      );
    }
    page.graphics.drawString(
      content,
      PdfStandardFont(PdfFontFamily.helvetica, 11),
      brush: PdfSolidBrush(PdfColor(30, 30, 30)),
      bounds: Rect.fromLTWH(
        0,
        pageIndex == 0 ? 56 : 0,
        size.width,
        size.height - (pageIndex == 0 ? 76 : 20),
      ),
      format: PdfStringFormat(lineSpacing: 5.0),
    );
  }

  static void _addPageNumbers(PdfDocument document) {
    // Hisser hors de la boucle (audit perf v1.12) : N allocations
    // PdfStandardFont/PdfSolidBrush évitées.
    final font = PdfStandardFont(PdfFontFamily.helvetica, 9);
    final brush = PdfSolidBrush(PdfColor(150, 150, 150));
    final total = document.pages.count;
    for (int i = 0; i < total; i++) {
      final page = document.pages[i];
      final w = page.getClientSize().width;
      final h = page.getClientSize().height;
      page.graphics.drawString(
        'Page ${i + 1} / $total  ·  PDF Tech',
        font,
        brush: brush,
        bounds: Rect.fromLTWH(0, h - 14, w, 14),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );
    }
  }

  // ── Compress ──────────────────────────────────────────────────────────────

  Future<String> compressPdf(
    String inputPath,
    PdfCompressionLevel level,
  ) async {
    final bytes = await _safeReadPdf(inputPath);
    final out = await runPdfIsolate(() => _compressIsolate(bytes, level));
    return _saveAtomic('compresse', out);
  }

  static Uint8List _compressIsolate(
    Uint8List bytes,
    PdfCompressionLevel level,
  ) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      document.compressionLevel = level;
      return _toBytes(document.saveSync());
    } finally {
      document.dispose();
    }
  }

  // ── Decrypt ───────────────────────────────────────────────────────────────

  /// Déchiffre un PDF protégé. Le résultat est en CLAIR — l'appelant doit
  /// avertir l'utilisateur que le fichier de sortie est non protégé.
  Future<String> decryptPdf(String inputPath, String password) async {
    final bytes = await _safeReadPdf(inputPath);
    Uint8List? plaintextRef;
    try {
      final plaintext = await runPdfIsolate(
        () => _decryptIsolate(bytes, password),
      );
      plaintextRef = plaintext;
      return await _saveAtomic('dechiffre', plaintext);
    } finally {
      // Best-effort wipe : le buffer source (PDF chiffré + clés
      // dérivées tampon Syncfusion) ET le buffer de sortie déchiffré
      // (post-écriture disque, plus utile en RAM). Try/catch silencieux
      // car certains views Uint8List sont unmodifiable selon la
      // provenance (bug connu ; cf. memory `secretbytes_wipe_unmodifiable`).
      // Note : la `String password` reste immutable en heap Dart jusqu'au
      // GC — wipe impossible côté Dart pur (dette assumée, documentée
      // dans PRIVACY).
      try {
        bytes.fillRange(0, bytes.length, 0);
      } catch (_) {
        /* unmodifiable view possible */
      }
      final pt = plaintextRef;
      if (pt != null) {
        try {
          pt.fillRange(0, pt.length, 0);
        } catch (_) {
          /* idem */
        }
      }
    }
  }

  static Uint8List _decryptIsolate(Uint8List bytes, String password) {
    final document = PdfDocument(inputBytes: bytes, password: password);
    try {
      document.security.userPassword = '';
      document.security.ownerPassword = '';
      return _toBytes(document.saveSync());
    } finally {
      document.dispose();
    }
  }

  // ── Utils ─────────────────────────────────────────────────────────────────

  Future<int> getPageCount(String path) async {
    final bytes = await _safeReadPdf(path);
    return runPdfIsolate(() {
      final doc = PdfDocument(inputBytes: bytes);
      try {
        return doc.pages.count;
      } finally {
        doc.dispose();
      }
    });
  }
}
