import 'dart:io';

import 'package:files_tech_core/files_tech_core.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../services/pdf_tools_service.dart';
import '../../widgets/pdf_file_header.dart';
import '../../widgets/pdf_picker_screen.dart';
import '../../widgets/result_sheet.dart';

class CompressScreen extends StatefulWidget {
  const CompressScreen({super.key});

  @override
  State<CompressScreen> createState() => _CompressScreenState();
}

class _CompressScreenState extends State<CompressScreen> {
  String? _filePath;
  String? _fileName;
  int? _originalSize;
  PdfCompressionLevel _level = PdfCompressionLevel.normal;
  bool _processing = false;

  Future<void> _pickFile() async {
    final path = await PdfPickerScreen.pickOne(
      context,
      title: 'Choisir le PDF à compresser',
    );
    if (path == null) return;
    // Lecture async AVANT le setState : `lengthSync()` bloque le main isolate
    // (IO sync) et provoque du jank si le fichier est sur stockage lent.
    int size = 0;
    try {
      size = await File(path).length();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _filePath = path;
      _fileName = PathUtils.fileName(path);
      _originalSize = size;
    });
  }

  // v1.10.1 — délégué à FormatUtils.bytes (style FR Ko/Mo, 1 décimale Mo).
  String _formatSize(int bytes) => FormatUtils.bytes(bytes);

  Future<void> _compress() async {
    if (_filePath == null) return;
    setState(() => _processing = true);
    try {
      final output = await PdfToolsService().compressPdf(_filePath!, _level);
      final compressedSize = await File(output).length();
      if (!mounted) return;
      final saved = _originalSize! - compressedSize;
      final ratio = (_originalSize! > 0)
          ? (saved / _originalSize! * 100).toStringAsFixed(1)
          : '0';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Original : ${_formatSize(_originalSize!)}  →  '
            'Compressé : ${_formatSize(compressedSize)}  '
            '(−$ratio%)',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      await showResultSheet(
        context,
        outputPath: output,
        operationLabel: 'PDF compressé',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compresser un PDF')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── File picker card ───────────────────────────────────────────
            PdfFilePickerCard(
              fileName: _fileName,
              subtitle: _originalSize != null
                  ? 'Taille originale : ${_formatSize(_originalSize!)}'
                  : null,
              onPick: _pickFile,
            ),

            const SizedBox(height: 28),

            // ── Compression level ──────────────────────────────────────────
            Text(
              'Niveau de compression',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Center(
              child: SegmentedButton<PdfCompressionLevel>(
                segments: const [
                  ButtonSegment(
                    value: PdfCompressionLevel.belowNormal,
                    label: Text('Léger'),
                    icon: Icon(Icons.compress),
                  ),
                  ButtonSegment(
                    value: PdfCompressionLevel.normal,
                    label: Text('Moyen'),
                    icon: Icon(Icons.compress),
                  ),
                  ButtonSegment(
                    value: PdfCompressionLevel.best,
                    label: Text('Maximum'),
                    icon: Icon(Icons.compress),
                  ),
                ],
                selected: {_level},
                onSelectionChanged: (Set<PdfCompressionLevel> s) {
                  setState(() => _level = s.first);
                },
              ),
            ),

            const SizedBox(height: 28),

            // ── Info card ──────────────────────────────────────────────────
            Card(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.45),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'La compression réduit la taille du fichier en optimisant '
                        'le contenu interne du PDF. Le niveau Maximum offre la '
                        'meilleure réduction mais peut allonger le traitement. '
                        'Le résultat dépend du contenu du document.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 36),

            // ── Compress button ────────────────────────────────────────────
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
                    : const Icon(Icons.compress),
                label: Text(
                  _processing ? 'Compression en cours…' : 'Compresser',
                ),
                onPressed: (_processing || _filePath == null)
                    ? null
                    : _compress,
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}
