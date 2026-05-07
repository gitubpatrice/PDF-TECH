import '../../services/isolate_runner.dart';
import 'package:files_tech_core/files_tech_core.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';
import 'dart:io';

import '../../services/pdf_tools_service.dart';
import '../../widgets/pdf_file_header.dart';
import '../../widgets/pdf_picker_screen.dart';
import '../../widgets/result_sheet.dart';

class SignatureScreen extends StatefulWidget {
  const SignatureScreen({super.key});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  String? _filePath;
  String? _fileName;
  final GlobalKey<SfSignaturePadState> _signatureKey =
      GlobalKey<SfSignaturePadState>();
  String _position = 'centre'; // 'gauche' | 'centre' | 'droite'
  bool _processing = false;

  Future<void> _pickFile() async {
    final path = await PdfPickerScreen.pickOne(
      context,
      title: 'Choisir le PDF à signer',
    );
    if (path == null) return;
    if (!mounted) return;
    setState(() {
      _filePath = path;
      _fileName = PathUtils.fileName(path);
    });
  }

  Future<void> _insertSignature() async {
    if (_filePath == null) return;
    setState(() => _processing = true);
    try {
      // Export signature image from pad
      final image = await _signatureKey.currentState!.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Impossible d\'exporter la signature');
      }
      final pngBytes = byteData.buffer.asUint8List();

      // Load PDF (size + magic bytes validés)
      final bytes = await PdfToolsService.safeReadPdf(_filePath!);
      final position = _position;
      final out = await runPdfIsolate(
        () => _signatureIsolate(bytes, pngBytes, position),
      );

      // Save to new file
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${dir.path}/signature_$ts.pdf';
      await File(outputPath).writeAsBytes(out);

      if (!mounted) return;
      await showResultSheet(
        context,
        outputPath: outputPath,
        operationLabel: 'Signature insérée',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  static Uint8List _signatureIsolate(
    Uint8List bytes,
    Uint8List pngBytes,
    String position,
  ) {
    final document = PdfDocument(inputBytes: bytes);
    final lastPage = document.pages[document.pages.count - 1];
    final size = lastPage.getClientSize();

    const double sigWidth = 180;
    const double sigHeight = 90;
    double x;
    switch (position) {
      case 'gauche':
        x = 20;
        break;
      case 'droite':
        x = size.width - 200;
        break;
      case 'centre':
      default:
        x = (size.width - sigWidth) / 2;
        break;
    }
    final double y = size.height - 120;

    final bitmap = PdfBitmap(pngBytes);
    lastPage.graphics.drawImage(
      bitmap,
      Rect.fromLTWH(x, y, sigWidth, sigHeight),
    );

    final saved = document.saveSync();
    document.dispose();
    return saved is Uint8List ? saved : Uint8List.fromList(saved);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Insérer une signature')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── File picker card ───────────────────────────────────────────
            PdfFilePickerCard(fileName: _fileName, onPick: _pickFile),

            const SizedBox(height: 24),

            // ── Signature pad ──────────────────────────────────────────────
            Text(
              'Dessinez votre signature',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.5),
                ),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SfSignaturePad(
                  key: _signatureKey,
                  backgroundColor: Colors.white,
                  strokeColor: Colors.black,
                  minimumStrokeWidth: 1.5,
                  maximumStrokeWidth: 3.0,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Clear button ───────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('Effacer'),
                  onPressed: () => _signatureKey.currentState!.clear(),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Position selector ──────────────────────────────────────────
            Text(
              'Position sur la page',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Center(
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'gauche',
                    label: Text('Gauche'),
                    icon: Icon(Icons.align_horizontal_left),
                  ),
                  ButtonSegment(
                    value: 'centre',
                    label: Text('Centre'),
                    icon: Icon(Icons.align_horizontal_center),
                  ),
                  ButtonSegment(
                    value: 'droite',
                    label: Text('Droite'),
                    icon: Icon(Icons.align_horizontal_right),
                  ),
                ],
                selected: {_position},
                onSelectionChanged: (Set<String> s) {
                  setState(() => _position = s.first);
                },
              ),
            ),

            const SizedBox(height: 36),

            // ── Insert button ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: _processing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.draw),
                label: Text(
                  _processing ? 'Insertion en cours…' : 'Insérer la signature',
                ),
                onPressed: (_processing || _filePath == null)
                    ? null
                    : _insertSignature,
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}
