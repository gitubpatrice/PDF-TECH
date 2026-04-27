import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfToolsService {
  Future<String> _savePath(String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/${name}_$ts.pdf';
  }

  // ── Merge ─────────────────────────────────────────────────────────────────

  Future<String> mergePdfs(List<String> inputPaths) async {
    final merged = PdfDocument();
    merged.pageSettings.margins.all = 0;

    for (final path in inputPaths) {
      final bytes = await File(path).readAsBytes();
      final source = PdfDocument(inputBytes: bytes);

      for (int i = 0; i < source.pages.count; i++) {
        final srcPage = source.pages[i];
        merged.pageSettings.size = srcPage.size;
        final newPage = merged.pages.add();
        newPage.graphics.drawPdfTemplate(srcPage.createTemplate(), Offset.zero);
      }
      source.dispose();
    }

    final path = await _savePath('fusion');
    await File(path).writeAsBytes(await merged.save());
    merged.dispose();
    return path;
  }

  // ── Split ─────────────────────────────────────────────────────────────────

  Future<String> splitPdf(String inputPath, int fromPage, int toPage) async {
    final bytes = await File(inputPath).readAsBytes();
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
    final path = await _savePath('extrait_p${fromPage}_$toPage');
    await File(path).writeAsBytes(await result.save());
    result.dispose();
    return path;
  }

  // ── Protect ───────────────────────────────────────────────────────────────

  Future<String> protectPdf(String inputPath, String userPassword) async {
    final bytes = await File(inputPath).readAsBytes();
    final document = PdfDocument(inputBytes: bytes);

    document.security.userPassword = userPassword;
    document.security.ownerPassword = userPassword;
    document.security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;

    final path = await _savePath('protege');
    await File(path).writeAsBytes(await document.save());
    document.dispose();
    return path;
  }

  // ── Rotate ────────────────────────────────────────────────────────────────

  Future<String> rotatePdf(String inputPath, PdfPageRotateAngle angle) async {
    final bytes = await File(inputPath).readAsBytes();
    final document = PdfDocument(inputBytes: bytes);

    for (int i = 0; i < document.pages.count; i++) {
      document.pages[i].rotation = angle;
    }

    final path = await _savePath('rotation');
    await File(path).writeAsBytes(await document.save());
    document.dispose();
    return path;
  }

  // ── Watermark ─────────────────────────────────────────────────────────────

  Future<String> addWatermark(
    String inputPath,
    String text, {
    double opacity = 0.25,
    Color color = Colors.grey,
  }) async {
    final bytes = await File(inputPath).readAsBytes();
    final document = PdfDocument(inputBytes: bytes);

    final font = PdfStandardFont(PdfFontFamily.helvetica, 52,
        style: PdfFontStyle.bold);
    final brush = PdfSolidBrush(PdfColor(
      (color.r * 255).round(),
      (color.g * 255).round(),
      (color.b * 255).round(),
    ));

    for (int i = 0; i < document.pages.count; i++) {
      final page = document.pages[i];
      final size = page.getClientSize();
      final g = page.graphics;

      g.save();
      g.setTransparency(opacity);
      g.translateTransform(size.width / 2, size.height / 2);
      g.rotateTransform(-45);
      g.drawString(
        text,
        font,
        brush: brush,
        bounds: Rect.fromCenter(center: Offset.zero, width: 500, height: 120),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.middle,
        ),
      );
      g.restore();
    }

    final path = await _savePath('filigrane');
    await File(path).writeAsBytes(await document.save());
    document.dispose();
    return path;
  }

  // ── Create ────────────────────────────────────────────────────────────────

  Future<String> createPdf({
    required String title,
    required String content,
    String author = 'PDF Tech',
  }) async {
    final document = PdfDocument();
    document.documentInformation.title = title;
    document.documentInformation.author = author;

    PdfPage page = document.pages.add();
    _drawPage(page, title, content, 0);

    _addPageNumbers(document);

    final safeName = title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    final path = await _savePath(safeName.isEmpty ? 'nouveau_document' : safeName);
    await File(path).writeAsBytes(await document.save());
    document.dispose();
    return path;
  }

  void _drawPage(PdfPage page, String title, String content, int pageIndex) {
    final size = page.getClientSize();
    final blue = PdfColor(21, 101, 192);

    if (pageIndex == 0) {
      // Title
      page.graphics.drawString(
        title,
        PdfStandardFont(PdfFontFamily.helvetica, 22, style: PdfFontStyle.bold),
        brush: PdfSolidBrush(blue),
        bounds: Rect.fromLTWH(0, 0, size.width, 40),
        format: PdfStringFormat(alignment: PdfTextAlignment.left),
      );
      // Separator
      page.graphics.drawLine(
        PdfPen(blue, width: 1.5),
        const Offset(0, 46),
        Offset(size.width, 46),
      );
    }

    // Content
    page.graphics.drawString(
      content,
      PdfStandardFont(PdfFontFamily.helvetica, 11),
      brush: PdfSolidBrush(PdfColor(30, 30, 30)),
      bounds: Rect.fromLTWH(0, pageIndex == 0 ? 56 : 0, size.width, size.height - (pageIndex == 0 ? 76 : 20)),
      format: PdfStringFormat(lineSpacing: 5.0),
    );

  }

  void _addPageNumbers(PdfDocument document) {
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

  Future<String> compressPdf(String inputPath, PdfCompressionLevel level) async {
    final bytes = await File(inputPath).readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    document.compressionLevel = level;
    final path = await _savePath('compresse');
    final savedBytes = await document.save();
    await File(path).writeAsBytes(savedBytes);
    document.dispose();
    return path;
  }

  // ── Utils ─────────────────────────────────────────────────────────────────

  int getPageCount(String path) {
    final bytes = File(path).readAsBytesSync();
    final doc = PdfDocument(inputBytes: bytes);
    final count = doc.pages.count;
    doc.dispose();
    return count;
  }
}
