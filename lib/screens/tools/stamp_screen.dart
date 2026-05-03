import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../services/pdf_tools_service.dart';
import '../../widgets/pdf_file_header.dart';
import '../../widgets/result_sheet.dart';
import '../../widgets/pdf_picker_screen.dart';

class StampScreen extends StatefulWidget {
  const StampScreen({super.key});

  @override
  State<StampScreen> createState() => _StampScreenState();
}

class _StampScreenState extends State<StampScreen> {
  String? _path;
  String? _name;
  bool _isProcessing = false;

  // Tampons prédéfinis
  static const _presets = [
    _StampPreset('CONFIDENTIEL', Color(0xFFD32F2F)),
    _StampPreset('APPROUVÉ', Color(0xFF388E3C)),
    _StampPreset('COPIE', Color(0xFF1976D2)),
    _StampPreset('BROUILLON', Color(0xFFF57C00)),
    _StampPreset('ANNULÉ', Color(0xFF7B1FA2)),
    _StampPreset('URGENT', Color(0xFFD32F2F)),
  ];

  int _selectedPreset = 0;
  bool _useCustom = false;
  String _customText = '';
  Color _customColor = const Color(0xFFD32F2F);
  double _opacity = 0.25;
  String _pages = 'all'; // 'all' ou 'first'

  Future<void> _pickFile() async {
    final path = await PdfPickerScreen.pickOne(
      context,
      title: 'Choisir un PDF',
    );
    if (!mounted) return;
    if (path == null) return;
    setState(() {
      _path = path;
      _name = fileNameOf(path);
    });
  }

  Future<void> _process() async {
    if (_path == null) return;
    final text = _useCustom
        ? _customText.trim()
        : _presets[_selectedPreset].text;
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrez un texte de tampon')),
      );
      return;
    }
    setState(() => _isProcessing = true);
    try {
      final color = _useCustom ? _customColor : _presets[_selectedPreset].color;
      final r = (color.r * 255.0).round().clamp(0, 255);
      final g = (color.g * 255.0).round().clamp(0, 255);
      final b = (color.b * 255.0).round().clamp(0, 255);
      final firstOnly = _pages == 'first';
      final opacity = _opacity;

      final bytes = await PdfToolsService.safeReadPdf(_path!);
      final out = await Isolate.run(
        () => _stampIsolate(bytes, text, r, g, b, opacity, firstOnly),
      );

      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final outPath = '${dir.path}/tampon_$ts.pdf';
      await File(outPath).writeAsBytes(out);

      if (!mounted) return;
      setState(() => _isProcessing = false);
      showResultSheet(
        context,
        outputPath: outPath,
        operationLabel: 'Tampon appliqué',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  static Uint8List _stampIsolate(
    Uint8List bytes,
    String text,
    int r,
    int g,
    int b,
    double opacity,
    bool firstOnly,
  ) {
    final doc = PdfDocument(inputBytes: bytes);
    final pdfColor = PdfColor(r, g, b);
    final font = PdfStandardFont(
      PdfFontFamily.helvetica,
      54,
      style: PdfFontStyle.bold,
    );
    final pageCount = firstOnly ? 1 : doc.pages.count;
    for (int i = 0; i < pageCount; i++) {
      final page = doc.pages[i];
      final w = page.getClientSize().width;
      final h = page.getClientSize().height;
      page.graphics.save();
      page.graphics.setTransparency(opacity);
      page.graphics.translateTransform(w / 2, h / 2);
      page.graphics.rotateTransform(-45 * math.pi / 180);
      page.graphics.drawString(
        text,
        font,
        brush: PdfSolidBrush(pdfColor),
        bounds: Rect.fromLTWH(-220, -35, 440, 70),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.middle,
        ),
      );
      page.graphics.restore();
    }
    final saved = doc.saveSync();
    doc.dispose();
    return saved is Uint8List ? saved : Uint8List.fromList(saved);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tampon PDF'),
        actions: [
          if (_path != null)
            _isProcessing
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    onPressed: _process,
                    child: const Text('Appliquer'),
                  ),
        ],
      ),
      body: _path == null ? _buildPicker() : _buildOptions(),
    );
  }

  Widget _buildPicker() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.approval_outlined,
              size: 88,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 24),
            Text('Tampon PDF', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Apposez CONFIDENTIEL, APPROUVÉ, COPIE… sur votre PDF',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Choisir un PDF'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PdfFileHeader(name: _name!, onChange: _pickFile),
          const SizedBox(height: 20),

          Text('Tampon', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),

          // Présets
          if (!_useCustom) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_presets.length, (i) {
                final p = _presets[i];
                final selected = _selectedPreset == i;
                return ChoiceChip(
                  label: Text(
                    p.text,
                    style: TextStyle(
                      color: selected ? Colors.white : p.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  selected: selected,
                  selectedColor: p.color,
                  side: BorderSide(color: p.color),
                  onSelected: (_) => setState(() => _selectedPreset = i),
                );
              }),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Texte du tampon',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (v) => setState(() => _customText = v),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _pickColor,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _customColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _useCustom = !_useCustom),
            child: Text(
              _useCustom ? '← Tampons prédéfinis' : 'Texte personnalisé →',
            ),
          ),

          const SizedBox(height: 16),
          Text('Opacité', style: Theme.of(context).textTheme.titleSmall),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _opacity,
                  min: 0.1,
                  max: 0.6,
                  divisions: 10,
                  label: '${(_opacity * 100).toInt()}%',
                  onChanged: (v) => setState(() => _opacity = v),
                ),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '${(_opacity * 100).toInt()}%',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Text('Pages', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('Toutes les pages')),
              ButtonSegment(value: 'first', label: Text('Première page')),
            ],
            selected: {_pages},
            onSelectionChanged: (s) => setState(() => _pages = s.first),
          ),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isProcessing ? null : _process,
              icon: const Icon(Icons.approval_outlined),
              label: const Text('Appliquer le tampon'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickColor() async {
    final colors = [
      Colors.red[700]!,
      Colors.green[700]!,
      Colors.blue[700]!,
      Colors.orange[700]!,
      Colors.purple[700]!,
      Colors.teal[700]!,
      Colors.brown[700]!,
      Colors.black,
    ];
    final picked = await showDialog<Color>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Couleur du tampon'),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: colors
              .map(
                (c) => GestureDetector(
                  onTap: () => Navigator.pop(context, c),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: c == _customColor
                            ? Colors.white
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (picked != null) setState(() => _customColor = picked);
  }
}

class _StampPreset {
  final String text;
  final Color color;
  const _StampPreset(this.text, this.color);
}
