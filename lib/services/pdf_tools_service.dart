import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

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

  Future<String> _savePath(String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/${name}_$ts.pdf';
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
    final out = await Isolate.run(() => _mergeIsolate(allBytes));
    final path = await _savePath('fusion');
    await File(path).writeAsBytes(out);
    return path;
  }

  static Uint8List _mergeIsolate(List<Uint8List> allBytes) {
    final merged = PdfDocument();
    merged.pageSettings.margins.all = 0;
    for (final bytes in allBytes) {
      final source = PdfDocument(inputBytes: bytes);
      for (int i = 0; i < source.pages.count; i++) {
        final srcPage = source.pages[i];
        merged.pageSettings.size = srcPage.size;
        final newPage = merged.pages.add();
        newPage.graphics.drawPdfTemplate(srcPage.createTemplate(), Offset.zero);
      }
      source.dispose();
    }
    final out = _toBytes(merged.saveSync());
    merged.dispose();
    return out;
  }

  // ── Split ─────────────────────────────────────────────────────────────────

  Future<String> splitPdf(String inputPath, int fromPage, int toPage) async {
    final bytes = await _safeReadPdf(inputPath);
    final out = await Isolate.run(() => _splitIsolate(bytes, fromPage, toPage));
    final path = await _savePath('extrait_p${fromPage}_$toPage');
    await File(path).writeAsBytes(out);
    return path;
  }

  static Uint8List _splitIsolate(Uint8List bytes, int fromPage, int toPage) {
    final source = PdfDocument(inputBytes: bytes);
    final total = source.pages.count;
    final result = PdfDocument();
    result.pageSettings.margins.all = 0;
    final from = fromPage.clamp(1, total) - 1;
    final to = toPage.clamp(1, total) - 1;
    for (int i = from; i <= to; i++) {
      final srcPage = source.pages[i];
      result.pageSettings.size = srcPage.size;
      final newPage = result.pages.add();
      newPage.graphics.drawPdfTemplate(srcPage.createTemplate(), Offset.zero);
    }
    source.dispose();
    final out = _toBytes(result.saveSync());
    result.dispose();
    return out;
  }

  // ── Protect ───────────────────────────────────────────────────────────────

  Future<String> protectPdf(String inputPath, String userPassword) async {
    final bytes = await _safeReadPdf(inputPath);
    final ownerPwd = _randomOwnerPassword();
    final out = await Isolate.run(
      () => _protectIsolate(bytes, userPassword, ownerPwd),
    );
    final path = await _savePath('protege');
    await File(path).writeAsBytes(out);
    return path;
  }

  static Uint8List _protectIsolate(
    Uint8List bytes,
    String userPassword,
    String ownerPassword,
  ) {
    final document = PdfDocument(inputBytes: bytes);
    document.security.userPassword = userPassword;
    document.security.ownerPassword = ownerPassword;
    document.security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;
    final out = _toBytes(document.saveSync());
    document.dispose();
    return out;
  }

  // ── Rotate ────────────────────────────────────────────────────────────────

  Future<String> rotatePdf(String inputPath, PdfPageRotateAngle angle) async {
    final bytes = await _safeReadPdf(inputPath);
    // Le angle est un enum, sendable sans souci.
    final out = await Isolate.run(() => _rotateIsolate(bytes, angle));
    final path = await _savePath('rotation');
    await File(path).writeAsBytes(out);
    return path;
  }

  static Uint8List _rotateIsolate(Uint8List bytes, PdfPageRotateAngle angle) {
    final document = PdfDocument(inputBytes: bytes);
    for (int i = 0; i < document.pages.count; i++) {
      document.pages[i].rotation = angle;
    }
    final out = _toBytes(document.saveSync());
    document.dispose();
    return out;
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
    final out = await Isolate.run(
      () => _watermarkIsolate(bytes, text, opacity, r, g, b),
    );
    final path = await _savePath('filigrane');
    await File(path).writeAsBytes(out);
    return path;
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
    final out = _toBytes(document.saveSync());
    document.dispose();
    return out;
  }

  // ── Create ────────────────────────────────────────────────────────────────

  Future<String> createPdf({
    required String title,
    required String content,
    String author = 'PDF Tech',
  }) async {
    final out = await Isolate.run(() => _createIsolate(title, content, author));
    final safeName = title
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(' ', '_');
    final path = await _savePath(
      safeName.isEmpty ? 'nouveau_document' : safeName,
    );
    await File(path).writeAsBytes(out);
    return path;
  }

  static Uint8List _createIsolate(String title, String content, String author) {
    final document = PdfDocument();
    document.documentInformation.title = title;
    document.documentInformation.author = author;
    final page = document.pages.add();
    _drawPage(page, title, content, 0);
    _addPageNumbers(document);
    final out = _toBytes(document.saveSync());
    document.dispose();
    return out;
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
    final out = await Isolate.run(() => _compressIsolate(bytes, level));
    final path = await _savePath('compresse');
    await File(path).writeAsBytes(out);
    return path;
  }

  static Uint8List _compressIsolate(
    Uint8List bytes,
    PdfCompressionLevel level,
  ) {
    final document = PdfDocument(inputBytes: bytes);
    document.compressionLevel = level;
    final out = _toBytes(document.saveSync());
    document.dispose();
    return out;
  }

  // ── Decrypt ───────────────────────────────────────────────────────────────

  /// Déchiffre un PDF protégé. Le résultat est en CLAIR — l'appelant doit
  /// avertir l'utilisateur que le fichier de sortie est non protégé.
  Future<String> decryptPdf(String inputPath, String password) async {
    final bytes = await _safeReadPdf(inputPath);
    try {
      final out = await Isolate.run(() => _decryptIsolate(bytes, password));
      final path = await _savePath('dechiffre');
      await File(path).writeAsBytes(out);
      return path;
    } finally {
      // Best-effort wipe du buffer source (le password est toujours en clair
      // dans le String, mais au moins on n'aggrave pas en gardant le PDF
      // chiffré + clés résiduelles en RAM tampon process).
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  static Uint8List _decryptIsolate(Uint8List bytes, String password) {
    final document = PdfDocument(inputBytes: bytes, password: password);
    document.security.userPassword = '';
    document.security.ownerPassword = '';
    final out = _toBytes(document.saveSync());
    document.dispose();
    return out;
  }

  // ── Utils ─────────────────────────────────────────────────────────────────

  Future<int> getPageCount(String path) async {
    final bytes = await _safeReadPdf(path);
    return Isolate.run(() {
      final doc = PdfDocument(inputBytes: bytes);
      final count = doc.pages.count;
      doc.dispose();
      return count;
    });
  }
}
