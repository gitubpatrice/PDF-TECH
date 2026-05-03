// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_tech/services/pdf_tools_service.dart';

/// Helper : crée un fichier temporaire avec [bytes] et retourne son chemin.
Future<String> _writeTemp(String name, List<int> bytes) async {
  final dir = await Directory.systemTemp.createTemp('pdf_tech_test_');
  final f = File('${dir.path}/$name');
  await f.writeAsBytes(bytes);
  return f.path;
}

/// Génère un PDF minimal valide (signature `%PDF-1.4` + EOF).
List<int> _minimalPdfBytes() {
  return Uint8List.fromList('%PDF-1.4\n%âãÏÓ\n%%EOF\n'.codeUnits);
}

void main() {
  group('PdfToolsService.safeReadPdf', () {
    test('rejette un fichier inexistant', () async {
      expect(
        () => PdfToolsService.safeReadPdf('/this/path/does/not/exist.pdf'),
        throwsA(isA<PdfValidationException>()),
      );
    });

    test('rejette un fichier trop court (< 5 octets)', () async {
      final path = await _writeTemp('tiny.pdf', [0x25, 0x50]);
      expect(
        () => PdfToolsService.safeReadPdf(path),
        throwsA(isA<PdfValidationException>()),
      );
    });

    test('rejette un fichier sans signature %PDF-', () async {
      // 5 octets mais pas la bonne magic.
      final path = await _writeTemp('fake.pdf', 'HELLO'.codeUnits);
      expect(
        () => PdfToolsService.safeReadPdf(path),
        throwsA(isA<PdfValidationException>()),
      );
    });

    test('accepte un PDF minimal valide', () async {
      final path = await _writeTemp('ok.pdf', _minimalPdfBytes());
      final bytes = await PdfToolsService.safeReadPdf(path);
      expect(bytes, isNotEmpty);
      expect(bytes[0], 0x25); // %
      expect(bytes[1], 0x50); // P
      expect(bytes[2], 0x44); // D
      expect(bytes[3], 0x46); // F
      expect(bytes[4], 0x2D); // -
    });

    test('expose maxPdfBytes (cap) > 0', () {
      expect(PdfToolsService.maxPdfBytes, greaterThan(0));
    });
  });
}
