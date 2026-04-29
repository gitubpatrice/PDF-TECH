import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../widgets/result_sheet.dart';

/// Éditeur de PDF par blocs : chaque bloc est un paragraphe de texte avec
/// son propre formatage (taille, couleur, gras, italique, souligné, barré),
/// ou un titre, ou une image, ou un lien, ou un bloc de code.
///
/// L'utilisateur ajoute / réordonne / supprime des blocs et l'app génère le
/// PDF en parcourant la liste — chaque bloc devient un PdfTextElement (texte)
/// ou une PdfBitmap (image) dans la page.
///
/// Avantages vs éditeur monolithique :
/// - UX mobile claire (un bloc = une carte avec ses contrôles)
/// - Formatage par bloc, pas de sélection à gérer
/// - Export PDF déterministe (1:1 mapping)
class CreatePdfScreen extends StatefulWidget {
  const CreatePdfScreen({super.key});

  @override
  State<CreatePdfScreen> createState() => _CreatePdfScreenState();
}

enum _BlockType { title, subtitle, paragraph, bullet, code, image, link }

class _Block {
  _BlockType type;
  String text;
  String? imagePath;
  String? linkUrl;
  double fontSize;
  Color color;
  bool bold;
  bool italic;
  bool underline;
  bool strike;
  _Block({
    required this.type,
    this.text = '',
    this.imagePath,
    this.linkUrl,
    this.fontSize = 12,
    this.color = const Color(0xFF111111),
    this.bold = false,
    this.underline = false,
  }) : italic = false, strike = false;
}

class _CreatePdfScreenState extends State<CreatePdfScreen> {
  final _titleCtrl = TextEditingController(text: 'Mon document');
  final _authorCtrl = TextEditingController();
  final List<_Block> _blocks = [
    _Block(type: _BlockType.paragraph, text: ''),
  ];
  bool _processing = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    super.dispose();
  }

  void _addBlock(_BlockType type) {
    setState(() {
      _blocks.add(_Block(
        type: type,
        fontSize: type == _BlockType.title
            ? 22
            : type == _BlockType.subtitle
                ? 16
                : 12,
        bold: type == _BlockType.title || type == _BlockType.subtitle,
      ));
    });
  }

  Future<void> _addImage() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image);
    if (res == null || res.files.single.path == null) return;
    setState(() {
      _blocks.add(_Block(type: _BlockType.image, imagePath: res.files.single.path));
    });
  }

  Future<void> _addLink() async {
    final urlCtrl = TextEditingController();
    final textCtrl = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Insérer un lien'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: textCtrl,
            decoration: const InputDecoration(
                labelText: 'Texte affiché', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: urlCtrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
                labelText: 'URL (https://…)', border: OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, urlCtrl.text.trim()),
              child: const Text('Insérer')),
        ],
      ),
    );
    if (url == null || url.isEmpty) return;
    final display = textCtrl.text.trim().isEmpty ? url : textCtrl.text.trim();
    setState(() => _blocks.add(_Block(
      type: _BlockType.link,
      text: display,
      linkUrl: url,
      color: Colors.blue,
      underline: true,
    )));
  }

  void _removeBlock(int i) {
    setState(() => _blocks.removeAt(i));
  }

  void _moveBlock(int oldIdx, int newIdx) {
    setState(() {
      if (newIdx > oldIdx) newIdx--;
      final b = _blocks.removeAt(oldIdx);
      _blocks.insert(newIdx, b);
    });
  }

  Future<void> _create() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entrez un titre')));
      return;
    }
    final hasContent = _blocks.any((b) =>
        b.text.trim().isNotEmpty || b.imagePath != null);
    if (!hasContent) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ajoutez au moins un bloc avec du contenu')));
      return;
    }
    setState(() => _processing = true);
    try {
      final out = await _exportPdf();
      if (!mounted) return;
      await showResultSheet(context,
          outputPath: out, operationLabel: 'PDF créé avec succès');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<String> _exportPdf() async {
    final doc = PdfDocument();
    try {
      doc.documentInformation.title = _titleCtrl.text.trim();
      if (_authorCtrl.text.trim().isNotEmpty) {
        doc.documentInformation.author = _authorCtrl.text.trim();
      }
      final layout = PdfLayoutFormat(
          layoutType: PdfLayoutType.paginate,
          breakType: PdfLayoutBreakType.fitPage);

      var page = doc.pages.add();
      page.graphics.drawString(
        _titleCtrl.text.trim(),
        PdfStandardFont(PdfFontFamily.helvetica, 22, style: PdfFontStyle.bold),
        bounds: Rect.fromLTWH(40, 40, page.getClientSize().width - 80, 40),
      );
      double cursorY = 90;

      for (final b in _blocks) {
        if (b.type == _BlockType.image && b.imagePath != null) {
          try {
            final bytes = await File(b.imagePath!).readAsBytes();
            final bitmap = PdfBitmap(bytes);
            final maxW = page.getClientSize().width - 80;
            final scale = bitmap.width > maxW ? maxW / bitmap.width : 1.0;
            final dw = bitmap.width * scale;
            final dh = bitmap.height * scale;
            // Saut de page si pas la place
            if (cursorY + dh > page.getClientSize().height - 40) {
              page = doc.pages.add();
              cursorY = 40;
            }
            page.graphics.drawImage(
                bitmap, Rect.fromLTWH(40, cursorY, dw, dh));
            cursorY += dh + 12;
          } catch (_) {/* image illisible — skip */}
          continue;
        }

        if (b.text.trim().isEmpty) {
          cursorY += b.fontSize * 0.8;
          continue;
        }

        // Police
        final styles = <PdfFontStyle>[];
        if (b.bold)      styles.add(PdfFontStyle.bold);
        if (b.italic)    styles.add(PdfFontStyle.italic);
        if (b.underline) styles.add(PdfFontStyle.underline);
        if (b.strike)    styles.add(PdfFontStyle.strikethrough);
        // Code → monospace
        final family = b.type == _BlockType.code
            ? PdfFontFamily.courier
            : PdfFontFamily.helvetica;
        final font = PdfStandardFont(family, b.fontSize,
            multiStyle: styles.isEmpty ? null : styles);

        final brush = PdfSolidBrush(PdfColor(
            b.color.r.toInt(), b.color.g.toInt(), b.color.b.toInt()));

        // Préfixe selon type
        var text = b.text;
        if (b.type == _BlockType.bullet) {
          text = '• $text';
        }

        // Bloc de code : fond gris clair (estimation par lignes réelles + wrap
        // approximatif à 70 chars/ligne pour rester sûr en portrait standard).
        if (b.type == _BlockType.code) {
          final lines = text.split('\n');
          var totalLines = 0;
          for (final l in lines) {
            totalLines += 1 + (l.length / 70).floor();
          }
          final estHeight = (b.fontSize * 1.4 * totalLines) + 10;
          if (cursorY + estHeight > page.getClientSize().height - 40) {
            page = doc.pages.add();
            cursorY = 40;
          }
          page.graphics.drawRectangle(
            brush: PdfSolidBrush(PdfColor(245, 245, 245)),
            bounds: Rect.fromLTWH(40, cursorY,
                page.getClientSize().width - 80, estHeight),
          );
        }

        // Lien : on dessine le texte normalement (PdfDocument supporte aussi
        // PdfUriAnnotation, mais le simple drawString suffit pour l'apparence)
        final element = PdfTextElement(
            text: text, font: font, brush: brush);
        final result = element.draw(
          page: page,
          bounds: Rect.fromLTWH(
              40, cursorY,
              page.getClientSize().width - 80,
              page.getClientSize().height - cursorY - 40),
          format: layout,
        );
        if (result != null) {
          page = result.page;
          cursorY = result.bounds.bottom + 8;
        } else {
          cursorY += b.fontSize * 1.4;
        }
      }

      final outBytes = await doc.save();
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final out = File('${dir.path}/${_titleCtrl.text.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}_$ts.pdf');
      await out.writeAsBytes(outBytes);
      return out.path;
    } finally {
      doc.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un PDF'),
        actions: [
          IconButton(
            tooltip: 'Générer le PDF',
            icon: _processing
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            onPressed: _processing ? null : _create,
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Column(children: [
            TextField(
              controller: _titleCtrl,
              maxLength: 80,
              decoration: const InputDecoration(
                  labelText: 'Titre du document', border: OutlineInputBorder(),
                  isDense: true,
                  counterText: ''),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _authorCtrl,
              decoration: const InputDecoration(
                  labelText: 'Auteur (optionnel)', border: OutlineInputBorder(),
                  isDense: true),
            ),
          ]),
        ),
        const Divider(height: 12),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: _blocks.length,
            onReorder: _moveBlock,
            itemBuilder: (_, i) => _BlockCard(
              key: ValueKey(_blocks[i].hashCode),
              block: _blocks[i],
              onChanged: () => setState(() {}),
              onRemove: () => _removeBlock(i),
            ),
          ),
        ),
        // Toolbar : ajouter blocs
        SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3))),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _addBtn(Icons.title, 'Titre',     () => _addBlock(_BlockType.title)),
                _addBtn(Icons.subtitles_outlined, 'Sous-titre', () => _addBlock(_BlockType.subtitle)),
                _addBtn(Icons.subject, 'Texte',    () => _addBlock(_BlockType.paragraph)),
                _addBtn(Icons.format_list_bulleted, 'Liste', () => _addBlock(_BlockType.bullet)),
                _addBtn(Icons.code, 'Code',        () => _addBlock(_BlockType.code)),
                _addBtn(Icons.image_outlined, 'Image', _addImage),
                _addBtn(Icons.link, 'Lien',        _addLink),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _addBtn(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
  }
}

/// Carte d'un bloc dans la liste : éditeur du texte + boutons formatage.
class _BlockCard extends StatefulWidget {
  final _Block block;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  const _BlockCard({
    super.key,
    required this.block,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_BlockCard> createState() => _BlockCardState();
}

class _BlockCardState extends State<_BlockCard> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.block.text);
    _ctrl.addListener(() {
      widget.block.text = _ctrl.text;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _label() {
    switch (widget.block.type) {
      case _BlockType.title:     return 'Titre';
      case _BlockType.subtitle:  return 'Sous-titre';
      case _BlockType.paragraph: return 'Paragraphe';
      case _BlockType.bullet:    return 'Puce';
      case _BlockType.code:      return 'Code';
      case _BlockType.image:     return 'Image';
      case _BlockType.link:      return 'Lien';
    }
  }

  IconData _icon() {
    switch (widget.block.type) {
      case _BlockType.title:     return Icons.title;
      case _BlockType.subtitle:  return Icons.subtitles_outlined;
      case _BlockType.paragraph: return Icons.subject;
      case _BlockType.bullet:    return Icons.format_list_bulleted;
      case _BlockType.code:      return Icons.code;
      case _BlockType.image:     return Icons.image_outlined;
      case _BlockType.link:      return Icons.link;
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.block;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(_icon(), size: 16,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text(_label(),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const Spacer(),
            ReorderableDragStartListener(
              index: 0,
              child: const Icon(Icons.drag_handle, size: 18),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: widget.onRemove,
            ),
          ]),
          const SizedBox(height: 6),
          if (b.type == _BlockType.image)
            b.imagePath != null
                ? Image.file(File(b.imagePath!), height: 100, fit: BoxFit.contain)
                : const Text('—', style: TextStyle(color: Colors.grey))
          else
            TextField(
              controller: _ctrl,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              style: TextStyle(
                fontSize: b.fontSize,
                color: b.color,
                fontWeight: b.bold ? FontWeight.bold : FontWeight.normal,
                fontStyle: b.italic ? FontStyle.italic : FontStyle.normal,
                decoration: TextDecoration.combine([
                  if (b.underline) TextDecoration.underline,
                  if (b.strike)    TextDecoration.lineThrough,
                ]),
                fontFamily: b.type == _BlockType.code ? 'monospace' : null,
              ),
              decoration: InputDecoration(
                hintText: 'Saisissez le ${_label().toLowerCase()}',
                border: const OutlineInputBorder(),
                isDense: true,
                fillColor: b.type == _BlockType.code
                    ? Colors.grey.withValues(alpha: 0.10) : null,
                filled: b.type == _BlockType.code,
              ),
            ),
          if (b.type != _BlockType.image)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                _fmtBtn(Icons.format_bold, b.bold,
                    () => setState(() { b.bold = !b.bold; widget.onChanged(); })),
                _fmtBtn(Icons.format_italic, b.italic,
                    () => setState(() { b.italic = !b.italic; widget.onChanged(); })),
                _fmtBtn(Icons.format_underline, b.underline,
                    () => setState(() { b.underline = !b.underline; widget.onChanged(); })),
                _fmtBtn(Icons.format_strikethrough, b.strike,
                    () => setState(() { b.strike = !b.strike; widget.onChanged(); })),
                PopupMenuButton<double>(
                  tooltip: 'Taille',
                  icon: const Icon(Icons.format_size, size: 18),
                  onSelected: (v) => setState(() {
                    b.fontSize = v; widget.onChanged();
                  }),
                  itemBuilder: (_) => [10, 12, 14, 16, 20, 26]
                      .map((s) => PopupMenuItem(
                          value: s.toDouble(),
                          child: Text('$s pt')))
                      .toList(),
                ),
                PopupMenuButton<Color>(
                  tooltip: 'Couleur',
                  icon: Icon(Icons.palette, size: 18, color: b.color),
                  onSelected: (c) => setState(() {
                    b.color = c; widget.onChanged();
                  }),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: Color(0xFF111111), child: Text('Noir')),
                    PopupMenuItem(value: Color(0xFFB71C1C), child: Text('Rouge')),
                    PopupMenuItem(value: Color(0xFF1565C0), child: Text('Bleu')),
                    PopupMenuItem(value: Color(0xFF2E7D32), child: Text('Vert')),
                    PopupMenuItem(value: Color(0xFF6A1B9A), child: Text('Violet')),
                    PopupMenuItem(value: Color(0xFFE65100), child: Text('Orange')),
                  ],
                ),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _fmtBtn(IconData icon, bool active, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, size: 18,
          color: active ? Theme.of(context).colorScheme.primary : null),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      onPressed: onTap,
    );
  }
}
