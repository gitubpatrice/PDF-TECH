import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../utils/atomic_write.dart';
import '../../utils/image_bounds.dart';
import '../../utils/snack_utils.dart';
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

// Constantes centralisées pour faciliter la maintenance et l'i18n future.
const _kMaxTitleLen = 80; // NAME_MAX-safe (ext4 = 255)
const _kCodeWrapChars = 70; // approx 70 chars/ligne en monospace 12pt sur A4
const _kPdfMargin = 40.0; // marge externe en points PDF
const _kFontHelvetica = PdfFontFamily.helvetica;
const _kFontMonospace = PdfFontFamily.courier;

enum _BlockType { title, subtitle, paragraph, bullet, code, image, link }

/// Bloc immutable représentant un élément du futur PDF.
///
/// Chaque modification passe par [copyWith] ; l'identifiant [id] est stable
/// et sert de clé pour le `ReorderableListView` (pas de perte de focus).
@immutable
class _Block {
  static int _nextId = 0;

  final String id;
  final _BlockType type;
  final String text;
  final String? imagePath;
  final String? linkUrl;
  final double fontSize;
  final Color color;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;

  factory _Block({
    required _BlockType type,
    String text = '',
    String? imagePath,
    String? linkUrl,
    double fontSize = 12,
    Color color = const Color(0xFF111111),
    bool bold = false,
    bool italic = false,
    bool underline = false,
    bool strike = false,
  }) {
    return _Block._internal(
      id: '${_nextId++}',
      type: type,
      text: text,
      imagePath: imagePath,
      linkUrl: linkUrl,
      fontSize: fontSize,
      color: color,
      bold: bold,
      italic: italic,
      underline: underline,
      strike: strike,
    );
  }

  const _Block._internal({
    required this.id,
    required this.type,
    required this.text,
    required this.imagePath,
    required this.linkUrl,
    required this.fontSize,
    required this.color,
    required this.bold,
    required this.italic,
    required this.underline,
    required this.strike,
  });

  _Block copyWith({
    _BlockType? type,
    String? text,
    String? imagePath,
    String? linkUrl,
    double? fontSize,
    Color? color,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strike,
  }) {
    return _Block._internal(
      id: id,
      type: type ?? this.type,
      text: text ?? this.text,
      imagePath: imagePath ?? this.imagePath,
      linkUrl: linkUrl ?? this.linkUrl,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      strike: strike ?? this.strike,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Block && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// État mutable du layout pendant l'export PDF : document, page courante et
/// position Y. Le document est conservé pour pouvoir ajouter de nouvelles
/// pages sans exposer de getter `document` sur `PdfPage`.
final class _PdfLayout {
  final PdfDocument doc;
  PdfPage page;
  double cursorY;
  _PdfLayout(this.doc, this.page, this.cursorY);
}

class _CreatePdfScreenState extends State<CreatePdfScreen> {
  final _titleCtrl = TextEditingController(text: 'Mon document');
  final _authorCtrl = TextEditingController();
  final List<_Block> _blocks = [_Block(type: _BlockType.paragraph, text: '')];
  bool _processing = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    super.dispose();
  }

  void _addBlock(_BlockType type) {
    setState(() {
      _blocks.add(
        _Block(
          type: type,
          fontSize: type == _BlockType.title
              ? 22
              : type == _BlockType.subtitle
              ? 16
              : 12,
          bold: type == _BlockType.title || type == _BlockType.subtitle,
        ),
      );
    });
  }

  Future<void> _addImage() async {
    final res = await FilePicker.pickFiles(type: FileType.image);
    if (res == null || res.files.single.path == null) return;
    final path = res.files.single.path!;
    final imgFile = File(path);
    try {
      if (await imgFile.length() > 20 * 1024 * 1024) {
        if (!mounted) return;
        showInfoSnack(context, 'Image trop volumineuse (max 20 Mo)');
        return;
      }
      final bytes = await imgFile.readAsBytes();
      final dimErr = ImageBounds.assertSafeBounds(bytes);
      if (dimErr != null) {
        if (!mounted) return;
        showInfoSnack(context, dimErr);
        return;
      }
    } catch (e) {
      if (!mounted) return;
      showInfoSnack(context, 'Image illisible');
      return;
    }
    if (!mounted) return;
    setState(() {
      _blocks.add(_Block(type: _BlockType.image, imagePath: path));
    });
  }

  Future<void> _addLink() async {
    final urlCtrl = TextEditingController();
    final textCtrl = TextEditingController();
    // v1.12.5 (D7) — dispose explicite via try/finally pour éviter les leaks
    // de TextEditingController créés dans un dialog builder stateless
    // (ils ne sont pas disposés automatiquement avec le dialog).
    try {
      final url = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Insérer un lien'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textCtrl,
                decoration: const InputDecoration(
                  labelText: 'Texte affiché',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'URL (https://…)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, urlCtrl.text.trim()),
              child: const Text('Insérer'),
            ),
          ],
        ),
      );
      if (url == null || url.isEmpty) return;
      final display = textCtrl.text.trim().isEmpty ? url : textCtrl.text.trim();
      setState(
        () => _blocks.add(
          _Block(
            type: _BlockType.link,
            text: display,
            linkUrl: url,
            color: Colors.blue,
            underline: true,
          ),
        ),
      );
    } finally {
      urlCtrl.dispose();
      textCtrl.dispose();
    }
  }

  void _removeBlock(int i) {
    setState(() => _blocks.removeAt(i));
  }

  void _moveBlock(int oldIdx, int newIdx) {
    setState(() {
      final b = _blocks.removeAt(oldIdx);
      _blocks.insert(newIdx, b);
    });
  }

  Future<void> _create() async {
    if (_titleCtrl.text.trim().isEmpty) {
      showInfoSnack(context, 'Entrez un titre');
      return;
    }
    final hasContent = _blocks.any(
      (b) => b.text.trim().isNotEmpty || b.imagePath != null,
    );
    if (!hasContent) {
      showInfoSnack(context, 'Ajoutez au moins un bloc avec du contenu');
      return;
    }
    setState(() => _processing = true);
    try {
      final result = await _exportPdf();
      if (!mounted) return;
      await showResultSheet(
        context,
        outputPath: result.path,
        operationLabel: 'PDF créé avec succès',
      );
      if (!mounted) return;
      if (result.warnings.isNotEmpty) {
        showInfoSnack(
          context,
          '${result.warnings.length} bloc(s) ignoré(s) : ${result.warnings.join(', ')}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<({String path, List<String> warnings})> _exportPdf() async {
    final doc = PdfDocument();
    try {
      doc.documentInformation.title = _titleCtrl.text.trim();
      if (_authorCtrl.text.trim().isNotEmpty) {
        doc.documentInformation.author = _authorCtrl.text.trim();
      }
      final layoutFormat = PdfLayoutFormat(
        layoutType: PdfLayoutType.paginate,
        breakType: PdfLayoutBreakType.fitPage,
      );

      final layout = _drawTitlePage(doc);
      final warnings = <String>[];
      for (final b in _blocks) {
        await _drawBlock(b, layout, layoutFormat, warnings);
      }

      final outBytes = await doc.save();
      // P0 v1.13.2 — sortie dans le dossier app-privé (plus de dossier
      // public /Documents/PDF Tech/ sans MANAGE_EXTERNAL_STORAGE).
      final out = await _saveToAppDocuments(outBytes);
      return (path: out.path, warnings: warnings);
    } finally {
      doc.dispose();
    }
  }

  _PdfLayout _drawTitlePage(PdfDocument doc) {
    final page = doc.pages.add();
    page.graphics.drawString(
      _titleCtrl.text.trim(),
      PdfStandardFont(_kFontHelvetica, 22, style: PdfFontStyle.bold),
      bounds: Rect.fromLTWH(
        _kPdfMargin,
        _kPdfMargin,
        page.getClientSize().width - _kPdfMargin * 2,
        _kPdfMargin,
      ),
    );
    return _PdfLayout(doc, page, _kPdfMargin * 2 + 10);
  }

  Future<void> _drawBlock(
    _Block b,
    _PdfLayout layout,
    PdfLayoutFormat format,
    List<String> warnings,
  ) async {
    if (b.type == _BlockType.image && b.imagePath != null) {
      await _drawImageBlock(b, layout, warnings);
      return;
    }
    _drawTextBlock(b, layout, format);
  }

  Future<void> _drawImageBlock(
    _Block b,
    _PdfLayout layout,
    List<String> warnings,
  ) async {
    try {
      final imgFile = File(b.imagePath!);
      // G8 v1.12.3 — cap taille fichier (cohérence avec images_to_pdf
      // 20 Mo) avant lecture en RAM.
      if (imgFile.lengthSync() > 20 * 1024 * 1024) {
        warnings.add('image trop volumineuse');
        return;
      }
      final bytes = await imgFile.readAsBytes();
      // G8 v1.12.3 — probe IHDR/SOF anti image-bomb avant PdfBitmap.
      final boundsErr = ImageBounds.assertSafeBounds(bytes);
      if (boundsErr != null) {
        warnings.add('image de dimensions suspectes');
        return;
      }
      final bitmap = PdfBitmap(bytes);
      final maxW = layout.page.getClientSize().width - _kPdfMargin * 2;
      final scale = bitmap.width > maxW ? maxW / bitmap.width : 1.0;
      final dw = bitmap.width * scale;
      final dh = bitmap.height * scale;
      // Saut de page si pas la place
      if (layout.cursorY + dh >
          layout.page.getClientSize().height - _kPdfMargin) {
        layout.page = layout.doc.pages.add();
        layout.cursorY = _kPdfMargin;
      }
      layout.page.graphics.drawImage(
        bitmap,
        Rect.fromLTWH(_kPdfMargin, layout.cursorY, dw, dh),
      );
      layout.cursorY += dh + 12;
    } catch (_) {
      warnings.add('image illisible');
    }
  }

  void _drawTextBlock(_Block b, _PdfLayout layout, PdfLayoutFormat format) {
    if (b.text.trim().isEmpty) {
      layout.cursorY += b.fontSize * 0.8;
      return;
    }

    // Police
    final styles = <PdfFontStyle>[];
    if (b.bold) styles.add(PdfFontStyle.bold);
    if (b.italic) styles.add(PdfFontStyle.italic);
    if (b.underline) styles.add(PdfFontStyle.underline);
    if (b.strike) styles.add(PdfFontStyle.strikethrough);
    // Code → monospace
    final family = b.type == _BlockType.code
        ? _kFontMonospace
        : _kFontHelvetica;
    final font = PdfStandardFont(
      family,
      b.fontSize,
      multiStyle: styles.isEmpty ? null : styles,
    );

    final brush = PdfSolidBrush(
      PdfColor(
        (b.color.r * 255).round().clamp(0, 255),
        (b.color.g * 255).round().clamp(0, 255),
        (b.color.b * 255).round().clamp(0, 255),
      ),
    );

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
        totalLines += 1 + (l.length / _kCodeWrapChars).floor();
      }
      final estHeight = (b.fontSize * 1.4 * totalLines) + 10;
      if (layout.cursorY + estHeight >
          layout.page.getClientSize().height - _kPdfMargin) {
        layout.page = layout.doc.pages.add();
        layout.cursorY = _kPdfMargin;
      }
      layout.page.graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(245, 245, 245)),
        bounds: Rect.fromLTWH(
          _kPdfMargin,
          layout.cursorY,
          layout.page.getClientSize().width - _kPdfMargin * 2,
          estHeight,
        ),
      );
    }

    // Lien : on dessine le texte normalement (PdfDocument supporte aussi
    // PdfUriAnnotation, mais le simple drawString suffit pour l'apparence)
    final element = PdfTextElement(text: text, font: font, brush: brush);
    final result = element.draw(
      page: layout.page,
      bounds: Rect.fromLTWH(
        _kPdfMargin,
        layout.cursorY,
        layout.page.getClientSize().width - _kPdfMargin * 2,
        layout.page.getClientSize().height - layout.cursorY - _kPdfMargin,
      ),
      format: format,
    );
    if (result != null) {
      layout.page = result.page;
      layout.cursorY = result.bounds.bottom + 8;
    } else {
      layout.cursorY += b.fontSize * 1.4;
    }
  }

  /// P0 v1.13.2 — Sauvegarde les bytes PDF dans le dossier app-privé
  /// (getApplicationDocumentsDirectory). Sans MANAGE_EXTERNAL_STORAGE,
  /// l'app ne peut plus écrire directement dans /Documents/PDF Tech/.
  /// Le fichier reste accessible pour l'ouverture et le partage via
  /// le FileProvider de l'app.
  Future<File> _saveToAppDocuments(List<int> bytes) async {
    final base = _titleCtrl.text.trim().replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '_',
    );
    final ts = DateTime.now().millisecondsSinceEpoch;
    final filename = '${base}_$ts.pdf';
    final docs = await getApplicationDocumentsDirectory();
    final out = File('${docs.path}/$filename');
    await atomicWriteBytes(out.path, bytes);
    return out;
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
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            onPressed: _processing ? null : _create,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Column(
              children: [
                TextField(
                  controller: _titleCtrl,
                  maxLength: _kMaxTitleLen,
                  decoration: const InputDecoration(
                    labelText: 'Titre du document',
                    border: OutlineInputBorder(),
                    isDense: true,
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _authorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Auteur (optionnel)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 12),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _blocks.length,
              onReorderItem: _moveBlock,
              itemBuilder: (_, i) => _BlockCard(
                key: ValueKey(_blocks[i].id),
                block: _blocks[i],
                onChanged: (b) => setState(() => _blocks[i] = b),
                onRemove: () => _removeBlock(i),
              ),
            ),
          ),
          // Toolbar : ajouter blocs
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _addBtn(
                      Icons.title,
                      'Titre',
                      () => _addBlock(_BlockType.title),
                    ),
                    _addBtn(
                      Icons.subtitles_outlined,
                      'Sous-titre',
                      () => _addBlock(_BlockType.subtitle),
                    ),
                    _addBtn(
                      Icons.subject,
                      'Texte',
                      () => _addBlock(_BlockType.paragraph),
                    ),
                    _addBtn(
                      Icons.format_list_bulleted,
                      'Liste',
                      () => _addBlock(_BlockType.bullet),
                    ),
                    _addBtn(
                      Icons.code,
                      'Code',
                      () => _addBlock(_BlockType.code),
                    ),
                    _addBtn(Icons.image_outlined, 'Image', _addImage),
                    _addBtn(Icons.link, 'Lien', _addLink),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
  final ValueChanged<_Block> onChanged;
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
  }

  @override
  void didUpdateWidget(_BlockCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Synchronise le controller si le parent remplace le bloc (ex: undo).
    if (widget.block.text != oldWidget.block.text &&
        widget.block.text != _ctrl.text) {
      _ctrl.text = widget.block.text;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _label() {
    switch (widget.block.type) {
      case _BlockType.title:
        return 'Titre';
      case _BlockType.subtitle:
        return 'Sous-titre';
      case _BlockType.paragraph:
        return 'Paragraphe';
      case _BlockType.bullet:
        return 'Puce';
      case _BlockType.code:
        return 'Code';
      case _BlockType.image:
        return 'Image';
      case _BlockType.link:
        return 'Lien';
    }
  }

  IconData _icon() {
    switch (widget.block.type) {
      case _BlockType.title:
        return Icons.title;
      case _BlockType.subtitle:
        return Icons.subtitles_outlined;
      case _BlockType.paragraph:
        return Icons.subject;
      case _BlockType.bullet:
        return Icons.format_list_bulleted;
      case _BlockType.code:
        return Icons.code;
      case _BlockType.image:
        return Icons.image_outlined;
      case _BlockType.link:
        return Icons.link;
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.block;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  _icon(),
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  _label(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                const ReorderableDragStartListener(
                  index: 0,
                  child: Icon(Icons.drag_handle, size: 18),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red,
                  ),
                  tooltip: 'Supprimer ce bloc',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (b.type == _BlockType.image)
              b.imagePath != null
                  ? Image.file(
                      File(b.imagePath!),
                      height: 100,
                      fit: BoxFit.contain,
                      cacheHeight: 200,
                    )
                  : const Text('—', style: TextStyle(color: Colors.grey))
            else
              TextField(
                controller: _ctrl,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                onChanged: (v) => widget.onChanged(b.copyWith(text: v)),
                style: TextStyle(
                  fontSize: b.fontSize,
                  color: b.color,
                  fontWeight: b.bold ? FontWeight.bold : FontWeight.normal,
                  fontStyle: b.italic ? FontStyle.italic : FontStyle.normal,
                  decoration: TextDecoration.combine([
                    if (b.underline) TextDecoration.underline,
                    if (b.strike) TextDecoration.lineThrough,
                  ]),
                  fontFamily: b.type == _BlockType.code ? 'monospace' : null,
                ),
                decoration: InputDecoration(
                  hintText: 'Saisissez le ${_label().toLowerCase()}',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  fillColor: b.type == _BlockType.code
                      ? Colors.grey.withValues(alpha: 0.10)
                      : null,
                  filled: b.type == _BlockType.code,
                ),
              ),
            if (b.type != _BlockType.image)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    _fmtBtn(
                      Icons.format_bold,
                      b.bold,
                      () => widget.onChanged(b.copyWith(bold: !b.bold)),
                    ),
                    _fmtBtn(
                      Icons.format_italic,
                      b.italic,
                      () => widget.onChanged(b.copyWith(italic: !b.italic)),
                    ),
                    _fmtBtn(
                      Icons.format_underline,
                      b.underline,
                      () =>
                          widget.onChanged(b.copyWith(underline: !b.underline)),
                    ),
                    _fmtBtn(
                      Icons.format_strikethrough,
                      b.strike,
                      () => widget.onChanged(b.copyWith(strike: !b.strike)),
                    ),
                    PopupMenuButton<double>(
                      tooltip: 'Taille',
                      icon: const Icon(Icons.format_size, size: 18),
                      onSelected: (v) =>
                          widget.onChanged(b.copyWith(fontSize: v)),
                      itemBuilder: (_) => [10, 12, 14, 16, 20, 26]
                          .map(
                            (s) => PopupMenuItem(
                              value: s.toDouble(),
                              child: Text('$s pt'),
                            ),
                          )
                          .toList(),
                    ),
                    PopupMenuButton<Color>(
                      tooltip: 'Couleur',
                      icon: Icon(Icons.palette, size: 18, color: b.color),
                      onSelected: (c) => widget.onChanged(b.copyWith(color: c)),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: Color(0xFF111111),
                          child: Text('Noir'),
                        ),
                        PopupMenuItem(
                          value: Color(0xFFB71C1C),
                          child: Text('Rouge'),
                        ),
                        PopupMenuItem(
                          value: Color(0xFF1565C0),
                          child: Text('Bleu'),
                        ),
                        PopupMenuItem(
                          value: Color(0xFF2E7D32),
                          child: Text('Vert'),
                        ),
                        PopupMenuItem(
                          value: Color(0xFF6A1B9A),
                          child: Text('Violet'),
                        ),
                        PopupMenuItem(
                          value: Color(0xFFE65100),
                          child: Text('Orange'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fmtBtn(
    IconData icon,
    bool active,
    VoidCallback onTap, {
    String? tooltip,
  }) {
    return IconButton(
      icon: Icon(
        icon,
        size: 18,
        color: active ? Theme.of(context).colorScheme.primary : null,
      ),
      tooltip: tooltip ?? 'Formatage',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      onPressed: onTap,
    );
  }
}
