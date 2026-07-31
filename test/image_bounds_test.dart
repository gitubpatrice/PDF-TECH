import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_tech/utils/image_bounds.dart';

Uint8List _png(int width, int height) {
  // PNG signature
  final bytes = BytesBuilder()
    ..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

  // IHDR chunk : length(4) + type(4) + width(4) + height(4) +
  // bitdepth(1) + colortype(1) + compression(1) + filter(1) + interlace(1) + crc(4)
  final ihdrData = Uint8List(13);
  final ihdrView = ByteData.view(ihdrData.buffer);
  ihdrView.setUint32(0, width, Endian.big);
  ihdrView.setUint32(4, height, Endian.big);
  ihdrData[8] = 8; // bit depth
  ihdrData[9] = 0; // color type greyscale
  ihdrData[10] = 0; // compression
  ihdrData[11] = 0; // filter
  ihdrData[12] = 0; // interlace

  final ihdrType = 'IHDR'.codeUnits;
  final ihdrLength = ByteData(4)..setUint32(0, 13, Endian.big);
  // CRC factice : on ne le vérifie pas dans ImageBounds.
  final ihdrCrc = ByteData(4)..setUint32(0, 0, Endian.big);

  bytes
    ..add(ihdrLength.buffer.asUint8List())
    ..add(ihdrType)
    ..add(ihdrData)
    ..add(ihdrCrc.buffer.asUint8List());

  // IEND chunk (vide) pour terminer proprement (optionnel pour le probe).
  final iend = BytesBuilder()
    ..add([0x00, 0x00, 0x00, 0x00])
    ..add('IEND'.codeUnits)
    ..add([0x00, 0x00, 0x00, 0x00]);
  bytes.add(iend.toBytes());

  return bytes.toBytes();
}

Uint8List _jpeg(int width, int height) {
  // SOI + SOF0 marker minimal.
  return Uint8List.fromList([
    0xFF, 0xD8, // SOI
    0xFF, 0xC0, // SOF0
    0x00, 0x0B, // length
    0x08, // precision
    (height >> 8) & 0xFF, height & 0xFF,
    (width >> 8) & 0xFF, width & 0xFF,
    0x01, // components
    0x01, 0x11, 0x00, // component info
    0xFF, 0xD9, // EOI
  ]);
}

Uint8List _gif(int width, int height) {
  return Uint8List.fromList([
    0x47, 0x49, 0x46, 0x38, 0x39, 0x61, // GIF89a
    width & 0xFF, (width >> 8) & 0xFF,
    height & 0xFF, (height >> 8) & 0xFF,
    0x00, 0x00, 0x00, // flags, bgcolor, aspect
    0x3B, // trailer
  ]);
}

void main() {
  group('ImageBounds.probeDimensions', () {
    test('détecte les dimensions d\'un PNG', () {
      final dims = ImageBounds.probeDimensions(_png(100, 200));
      expect(dims, isNotNull);
      expect(dims!.$1, 100);
      expect(dims.$2, 200);
    });

    test('détecte les dimensions d\'un JPEG', () {
      final dims = ImageBounds.probeDimensions(_jpeg(640, 480));
      expect(dims, isNotNull);
      expect(dims!.$1, 640);
      expect(dims.$2, 480);
    });

    test('détecte les dimensions d\'un GIF', () {
      final dims = ImageBounds.probeDimensions(_gif(300, 150));
      expect(dims, isNotNull);
      expect(dims!.$1, 300);
      expect(dims.$2, 150);
    });

    test('retourne null pour un buffer trop court', () {
      expect(ImageBounds.probeDimensions(Uint8List.fromList([0x89])), isNull);
    });

    test('retourne null pour un format inconnu', () {
      expect(
        ImageBounds.probeDimensions(Uint8List.fromList('UNKNOWN'.codeUnits)),
        isNull,
      );
    });
  });

  group('ImageBounds.assertSafeBounds', () {
    test('accepte une image de taille normale', () {
      expect(ImageBounds.assertSafeBounds(_png(1024, 768)), isNull);
    });

    test('rejette une image trop large', () {
      final err = ImageBounds.assertSafeBounds(_png(20000, 100));
      expect(err, isNotNull);
      expect(err, contains('max'));
    });

    test('rejette une image trop haute', () {
      final err = ImageBounds.assertSafeBounds(_png(100, 20000));
      expect(err, isNotNull);
    });

    test('rejette des dimensions négatives', () {
      // width = -1 encodé en uint32 big-endian.
      final err = ImageBounds.assertSafeBounds(_png(-1, 100));
      expect(err, isNotNull);
    });
  });
}
