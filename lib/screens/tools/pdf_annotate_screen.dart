import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart' as pv;
import '../../services/pdf_tools_service.dart';
import '../../widgets/result_sheet.dart';

/// Éditeur d'annotations PDF : pose des éléments par-dessus le PDF original
/// puis "aplatit" tout dans un nouveau PDF (les annotations deviennent
/// permanentes — l'éditeur n'altère pas le contenu textuel original).
///
/// Outils disponibles :
/// - **Texte** : tap → dialog → place du texte stylé
/// - **Surligner** : drag → rect jaune semi-transparent
/// - **Dessiner** : trait libre (signature, gribouillage)
/// - **Effacer** : tap sur une annotation → suppression
///
/// Toutes les annotations sont stockées en **coordonnées normalisées (0..1)**
/// par page, indépendantes du zoom et de la résolution écran. À la sauvegarde
/// on les convertit en points PDF (page.getClientSize()).
class PdfAnnotateScreen extends StatefulWidget {
  final String path;
  const PdfAnnotateScreen({super.key, required this.path});

  @override
  State<PdfAnnotateScreen> createState() => _PdfAnnotateScreenState();
}

enum _Tool { none, text, highlight, draw, image, erase }

/// Une annotation stockée par page (key = pageIndex 0-based).
class _Anno {
  final _Tool tool;

  /// Rect normalisé [0..1] dans le repère du widget (≈ page courante).
  final Rect rect;
  final String? text; // pour _Tool.text
  final List<Offset>? path; // pour _Tool.draw, en coords normalisées
  final Uint8List? imageBytes; // pour _Tool.image, PNG/JPG bytes
  final Color color;
  final double fontSize; // taille en pt PDF (pour text)
  _Anno({
    required this.tool,
    required this.rect,
    this.text,
    this.path,
    this.imageBytes,
    required this.color,
    this.fontSize = 12,
  });
}

class _PdfAnnotateScreenState extends State<PdfAnnotateScreen> {
  final _ctrl = pv.PdfViewerController();
  final Map<int, List<_Anno>> _annos = {};
  int _currentPage = 1;
  int _totalPages = 0;
  _Tool _tool = _Tool.none;
  Color _color = Colors.red;
  final double _fontSize = 14;
  bool _saving = false;

  // Pour le tracking d'un trait/rect en cours
  List<Offset>? _drawing;
  Offset? _rectStart;
  Offset? _rectCurrent;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<_Anno> get _pageAnnos => _annos[_currentPage - 1] ?? [];

  void _addAnno(_Anno a) {
    setState(() {
      _annos.putIfAbsent(_currentPage - 1, () => []).add(a);
    });
  }

  Future<void> _addText(Offset pos, Size size) async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Texte à insérer'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Saisissez le texte',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;
    // Position normalisée
    final dx = (pos.dx / size.width).clamp(0.0, 0.95);
    final dy = (pos.dy / size.height).clamp(0.0, 0.95);
    _addAnno(
      _Anno(
        tool: _Tool.text,
        rect: Rect.fromLTWH(dx, dy, 0.5, 0.05),
        text: text,
        color: _color,
        fontSize: _fontSize,
      ),
    );
  }

  /// Choisit une image (signature scannée, tampon, photo) et la pose au
  /// centre de la page courante, à 30% de la largeur. L'utilisateur peut
  /// ensuite la déplacer/redimensionner par drag (à implémenter en V2).
  Future<void> _addImage() async {
    final messenger = ScaffoldMessenger.of(context);
    final res = await FilePicker.pickFiles(type: FileType.image);
    if (res == null || res.files.single.path == null) return;
    final bytes = await File(res.files.single.path!).readAsBytes();
    if (bytes.isEmpty) return;
    // Validation : on tente de décoder via PdfBitmap pour détecter les
    // images non supportées (HEIC sans codec, fichiers corrompus, etc.)
    // avant d'ajouter l'annotation. Évite un échec silencieux à l'export.
    try {
      PdfBitmap(bytes);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Image illisible (formats supportés : JPG, PNG)'),
        ),
      );
      return;
    }
    // Position par défaut : centre de la page, 30% largeur, ratio préservé
    // approximatif (le rect est ré-ajusté visuellement au paint via fitBox).
    _addAnno(
      _Anno(
        tool: _Tool.image,
        rect: const Rect.fromLTWH(0.35, 0.40, 0.30, 0.20),
        imageBytes: bytes,
        color: Colors.transparent, // non utilisé pour image
      ),
    );
  }

  void _eraseAt(Offset pos, Size size) {
    final dx = pos.dx / size.width;
    final dy = pos.dy / size.height;
    final list = _annos[_currentPage - 1];
    if (list == null) return;
    setState(() {
      list.removeWhere((a) {
        if (a.tool == _Tool.draw && a.path != null) {
          // distance min au tracé
          for (final p in a.path!) {
            if ((p.dx - dx).abs() < 0.04 && (p.dy - dy).abs() < 0.04) {
              return true;
            }
          }
          return false;
        }
        return dx >= a.rect.left &&
            dx <= a.rect.right &&
            dy >= a.rect.top &&
            dy <= a.rect.bottom;
      });
    });
  }

  Future<void> _save() async {
    if (_annos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune annotation à sauvegarder')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final out = await _flatten();
      if (!mounted) return;
      setState(() => _saving = false);
      await showResultSheet(
        context,
        outputPath: out,
        operationLabel: 'PDF annoté avec succès',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  /// Aplatit toutes les annotations dans un nouveau PDF.
  ///
  /// Pour ne pas figer l'UI : (1) la lecture sécurisée + parse Syncfusion +
  /// dessin de toutes les annotations + save sont délégués à un isolate via
  /// [Isolate.run] ; (2) la sérialisation des annotations en types primitifs
  /// se fait sur le main thread avec un yield entre chaque page pour rendre
  /// la frame.
  Future<String> _flatten() async {
    // Sérialise les annotations en primitifs sendables (Map<String, dynamic>),
    // page par page, en yieldant entre chaque page pour ne pas bloquer la frame.
    final serialized = <int, List<Map<String, Object?>>>{};
    for (final entry in _annos.entries) {
      final list = <Map<String, Object?>>[];
      for (final a in entry.value) {
        list.add(_serializeAnno(a));
      }
      serialized[entry.key] = list;
      // Yield après chaque page pour laisser respirer la frame.
      await Future<void>.delayed(Duration.zero);
    }
    final path = widget.path;
    final outBytes = await Isolate.run(
      () => _flattenInIsolate(path, serialized),
    );
    final out = await _saveToVisibleDocuments(outBytes);
    return out.path;
  }

  /// Sérialise un `_Anno` en map de types primitifs (sendable à un isolate).
  static Map<String, Object?> _serializeAnno(_Anno a) {
    return {
      'tool': a.tool.index,
      'rL': a.rect.left,
      'rT': a.rect.top,
      'rW': a.rect.width,
      'rH': a.rect.height,
      'text': a.text,
      'path': a.path == null
          ? null
          : Float64List.fromList([
              for (final p in a.path!) ...[p.dx, p.dy],
            ]),
      'image': a.imageBytes,
      'argb': a.color.toARGB32(),
      'fontSize': a.fontSize,
    };
  }

  /// Sauve dans /Documents/PDF Tech/ (visible) avec fallback app-privé.
  Future<File> _saveToVisibleDocuments(List<int> bytes) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final filename = '${_baseName(widget.path)}_annote_$ts.pdf';
    try {
      final visible = Directory('/storage/emulated/0/Documents/PDF Tech');
      if (!await visible.exists()) await visible.create(recursive: true);
      final out = File('${visible.path}/$filename');
      await out.writeAsBytes(bytes);
      return out;
    } catch (_) {
      /* fallback */
    }
    // Fallback : /Android/data/<pkg>/files/output/ (FileProvider-shareable)
    final extDir = await getExternalStorageDirectory();
    if (extDir != null) {
      final outDir = Directory('${extDir.path}/output');
      if (!await outDir.exists()) await outDir.create(recursive: true);
      final out = File('${outDir.path}/$filename');
      await out.writeAsBytes(bytes);
      return out;
    }
    final docs = await getApplicationDocumentsDirectory();
    final out = File('${docs.path}/$filename');
    await out.writeAsBytes(bytes);
    return out;
  }

  String _baseName(String p) {
    final n = p.split(RegExp(r'[/\\]')).last;
    return n.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Annoter le PDF'),
        actions: [
          if (_totalPages > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Annuler la dernière annotation',
            icon: const Icon(Icons.undo),
            onPressed: _pageAnnos.isEmpty
                ? null
                : () => setState(() {
                    _annos[_currentPage - 1]?.removeLast();
                  }),
          ),
          IconButton(
            tooltip: 'Enregistrer',
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // PDF en arrière-plan
              pv.SfPdfViewer.file(
                File(widget.path),
                controller: _ctrl,
                onDocumentLoaded: (d) =>
                    setState(() => _totalPages = d.document.pages.count),
                onPageChanged: (d) =>
                    setState(() => _currentPage = d.newPageNumber),
              ),
              // Couche d'annotations (au-dessus, captures les touches selon outil)
              if (_tool != _Tool.none)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) {
                      final size = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      if (_tool == _Tool.text) {
                        _addText(d.localPosition, size);
                      } else if (_tool == _Tool.erase) {
                        _eraseAt(d.localPosition, size);
                      }
                    },
                    onPanStart: (d) {
                      if (_tool == _Tool.draw) {
                        setState(
                          () => _drawing = [
                            _normalize(d.localPosition, constraints.biggest),
                          ],
                        );
                      } else if (_tool == _Tool.highlight) {
                        setState(() {
                          _rectStart = d.localPosition;
                          _rectCurrent = d.localPosition;
                        });
                      }
                    },
                    onPanUpdate: (d) {
                      if (_tool == _Tool.draw && _drawing != null) {
                        setState(
                          () => _drawing!.add(
                            _normalize(d.localPosition, constraints.biggest),
                          ),
                        );
                      } else if (_tool == _Tool.highlight) {
                        setState(() => _rectCurrent = d.localPosition);
                      }
                    },
                    onPanEnd: (_) {
                      final size = constraints.biggest;
                      if (_tool == _Tool.draw &&
                          _drawing != null &&
                          _drawing!.length >= 2) {
                        // bbox
                        double minX = 1, minY = 1, maxX = 0, maxY = 0;
                        for (final p in _drawing!) {
                          if (p.dx < minX) minX = p.dx;
                          if (p.dy < minY) minY = p.dy;
                          if (p.dx > maxX) maxX = p.dx;
                          if (p.dy > maxY) maxY = p.dy;
                        }
                        _addAnno(
                          _Anno(
                            tool: _Tool.draw,
                            rect: Rect.fromLTRB(minX, minY, maxX, maxY),
                            path: List.from(_drawing!),
                            color: _color,
                          ),
                        );
                      }
                      if (_tool == _Tool.highlight &&
                          _rectStart != null &&
                          _rectCurrent != null) {
                        final s = _normalize(_rectStart!, size);
                        final e = _normalize(_rectCurrent!, size);
                        final r = Rect.fromLTRB(
                          s.dx < e.dx ? s.dx : e.dx,
                          s.dy < e.dy ? s.dy : e.dy,
                          s.dx > e.dx ? s.dx : e.dx,
                          s.dy > e.dy ? s.dy : e.dy,
                        );
                        if (r.width > 0.005 && r.height > 0.005) {
                          _addAnno(
                            _Anno(
                              tool: _Tool.highlight,
                              rect: r,
                              color: Colors.yellow,
                            ),
                          );
                        }
                      }
                      setState(() {
                        _drawing = null;
                        _rectStart = null;
                        _rectCurrent = null;
                      });
                    },
                    child: CustomPaint(
                      painter: _AnnoPainter(
                        annos: _pageAnnos,
                        drawingPath: _drawing,
                        rectStart: _rectStart,
                        rectCurrent: _rectCurrent,
                        drawingColor: _color,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                )
              else
                // Quand aucun outil n'est actif : affiche les annotations en
                // overlay, sans capturer les touches (le PDF reste interactif).
                IgnorePointer(
                  child: CustomPaint(
                    painter: _AnnoPainter(
                      annos: _pageAnnos,
                      drawingColor: _color,
                    ),
                    size: Size.infinite,
                  ),
                ),
              // Aperçu des images (overlay). CustomPainter ne peut pas dessiner
              // des bytes sans décodage async — on délègue à Image.memory dans
              // la Stack. IgnorePointer pour ne pas bloquer le PDF interactif.
              ..._pageAnnos
                  .where((a) => a.tool == _Tool.image && a.imageBytes != null)
                  .map((a) {
                    return Positioned(
                      left: a.rect.left * constraints.maxWidth,
                      top: a.rect.top * constraints.maxHeight,
                      width: a.rect.width * constraints.maxWidth,
                      height: a.rect.height * constraints.maxHeight,
                      child: IgnorePointer(
                        child: Image.memory(a.imageBytes!, fit: BoxFit.contain),
                      ),
                    );
                  }),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildToolbar(),
    );
  }

  Offset _normalize(Offset p, Size size) =>
      Offset(p.dx / size.width, p.dy / size.height);

  Widget _buildToolbar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _toolBtn(Icons.text_fields, 'Texte', _Tool.text),
            _toolBtn(Icons.highlight, 'Surligner', _Tool.highlight),
            _toolBtn(Icons.draw, 'Dessiner', _Tool.draw),
            // Image : ouvre le picker directement (action one-shot, pas un mode)
            InkWell(
              onTap: _addImage,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.image_outlined, size: 22),
                    Text('Image', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ),
            _toolBtn(Icons.auto_fix_off, 'Effacer', _Tool.erase),
            PopupMenuButton<Color>(
              tooltip: 'Couleur',
              icon: Icon(Icons.palette, color: _color),
              onSelected: (c) => setState(() => _color = c),
              itemBuilder: (_) => const [
                PopupMenuItem(value: Colors.red, child: Text('Rouge')),
                PopupMenuItem(value: Colors.black, child: Text('Noir')),
                PopupMenuItem(value: Colors.blue, child: Text('Bleu')),
                PopupMenuItem(value: Colors.green, child: Text('Vert')),
                PopupMenuItem(value: Colors.yellow, child: Text('Jaune')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolBtn(IconData icon, String label, _Tool t) {
    final selected = _tool == t;
    return InkWell(
      onTap: () => setState(() => _tool = selected ? _Tool.none : t),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? Theme.of(context).colorScheme.primary : null,
            ),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

/// Painter qui restitue les annotations stockées (en coords normalisées) à
/// l'échelle du widget courant + les éléments en cours de dessin/sélection.
class _AnnoPainter extends CustomPainter {
  final List<_Anno> annos;
  final List<Offset>? drawingPath;
  final Offset? rectStart;
  final Offset? rectCurrent;
  final Color drawingColor;
  _AnnoPainter({
    required this.annos,
    this.drawingPath,
    this.rectStart,
    this.rectCurrent,
    required this.drawingColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final a in annos) {
      final paint = Paint()
        ..color = a.color
        ..isAntiAlias = true
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2;
      switch (a.tool) {
        case _Tool.text:
          final tp = TextPainter(
            text: TextSpan(
              text: a.text ?? '',
              style: TextStyle(color: a.color, fontSize: a.fontSize),
            ),
            textDirection: ui.TextDirection.ltr,
          )..layout(maxWidth: a.rect.width * size.width);
          tp.paint(
            canvas,
            Offset(a.rect.left * size.width, a.rect.top * size.height),
          );
          break;
        case _Tool.highlight:
          paint.color = a.color.withValues(alpha: 0.35);
          paint.style = PaintingStyle.fill;
          canvas.drawRect(
            Rect.fromLTWH(
              a.rect.left * size.width,
              a.rect.top * size.height,
              a.rect.width * size.width,
              a.rect.height * size.height,
            ),
            paint,
          );
          break;
        case _Tool.draw:
          if (a.path == null || a.path!.length < 2) break;
          paint.style = PaintingStyle.stroke;
          final p = Path()
            ..moveTo(
              a.path!.first.dx * size.width,
              a.path!.first.dy * size.height,
            );
          for (var i = 1; i < a.path!.length; i++) {
            p.lineTo(a.path![i].dx * size.width, a.path![i].dy * size.height);
          }
          canvas.drawPath(p, paint);
          break;
        default:
          break;
      }
    }

    // Trait en cours
    if (drawingPath != null && drawingPath!.length >= 2) {
      final paint = Paint()
        ..color = drawingColor
        ..isAntiAlias = true
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final p = Path()
        ..moveTo(
          drawingPath!.first.dx * size.width,
          drawingPath!.first.dy * size.height,
        );
      for (var i = 1; i < drawingPath!.length; i++) {
        p.lineTo(
          drawingPath![i].dx * size.width,
          drawingPath![i].dy * size.height,
        );
      }
      canvas.drawPath(p, paint);
    }

    // Rect surlignage en cours
    if (rectStart != null && rectCurrent != null) {
      final paint = Paint()
        ..color = Colors.yellow.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromPoints(rectStart!, rectCurrent!), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AnnoPainter old) =>
      old.annos != annos ||
      old.drawingPath != drawingPath ||
      old.rectStart != rectStart ||
      old.rectCurrent != rectCurrent;
}

/// Helper pour afficher un Uint8List en image (utilisé par le picker image
/// si on étend l'éditeur). Réservé pour future extension.
@visibleForTesting
class ImageAnnoSentinel {
  final Uint8List bytes;
  ImageAnnoSentinel(this.bytes);
}

/// Exécute en isolate : lecture sécurisée du PDF, parse Syncfusion, dessin
/// de toutes les annotations et save. Tout le travail CPU lourd quitte le
/// main isolate. Les annotations sont reçues sous forme de Map primitives
/// (sendable). Aucun appel à `dart:ui` n'est fait ici : Syncfusion fait
/// tout le rendering interne en pur Dart.
Future<Uint8List> _flattenInIsolate(
  String path,
  Map<int, List<Map<String, Object?>>> serializedAnnos,
) async {
  final bytes = await PdfToolsService.safeReadPdf(path);
  final doc = PdfDocument(inputBytes: bytes);
  try {
    for (final entry in serializedAnnos.entries) {
      final pageIndex = entry.key;
      if (pageIndex < 0 || pageIndex >= doc.pages.count) continue;
      final page = doc.pages[pageIndex];
      final size = page.getClientSize();
      for (final a in entry.value) {
        _drawAnnotationFromMap(page, a, size);
      }
    }
    final List<int> saved = await doc.save();
    return saved is Uint8List ? saved : Uint8List.fromList(saved);
  } finally {
    doc.dispose();
  }
}

/// Dessine une annotation sérialisée (map de primitifs) sur une [PdfPage].
/// Top-level pour pouvoir s'exécuter dans un isolate (pas de capture de
/// `this`).
void _drawAnnotationFromMap(PdfPage page, Map<String, Object?> a, Size size) {
  final tool = _Tool.values[a['tool'] as int];
  final argb = a['argb'] as int;
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  final pdfColor = PdfColor(r, g, b);
  final rect = Rect.fromLTWH(
    (a['rL'] as double) * size.width,
    (a['rT'] as double) * size.height,
    (a['rW'] as double) * size.width,
    (a['rH'] as double) * size.height,
  );
  switch (tool) {
    case _Tool.text:
      final text = a['text'] as String?;
      if (text == null) return;
      page.graphics.drawString(
        text,
        PdfStandardFont(PdfFontFamily.helvetica, a['fontSize'] as double),
        brush: PdfSolidBrush(pdfColor),
        bounds: rect,
      );
      break;
    case _Tool.highlight:
      // Surligné : rect semi-transparent par-dessus (alpha 100/255).
      final hl = PdfColor(r, g, b, 100);
      page.graphics.drawRectangle(brush: PdfSolidBrush(hl), bounds: rect);
      break;
    case _Tool.draw:
      final flat = a['path'] as Float64List?;
      if (flat == null || flat.length < 4) return;
      final pen = PdfPen(pdfColor, width: 2);
      final pdfPath = PdfPath();
      // Premier point : startFigure + addLine sur lui-même (cohérent avec
      // le comportement original, qui marquait le point de départ).
      final x0 = flat[0] * size.width;
      final y0 = flat[1] * size.height;
      pdfPath.startFigure();
      pdfPath.addLine(Offset(x0, y0), Offset(x0, y0));
      for (var i = 2; i < flat.length; i += 2) {
        final px = flat[i - 2] * size.width;
        final py = flat[i - 1] * size.height;
        final cx = flat[i] * size.width;
        final cy = flat[i + 1] * size.height;
        pdfPath.addLine(Offset(px, py), Offset(cx, cy));
      }
      page.graphics.drawPath(pdfPath, pen: pen);
      break;
    case _Tool.image:
      final imgBytes = a['image'] as Uint8List?;
      if (imgBytes == null) return;
      try {
        final bitmap = PdfBitmap(imgBytes);
        page.graphics.drawImage(bitmap, rect);
      } catch (_) {
        /* image illisible — skip */
      }
      break;
    case _Tool.erase:
    case _Tool.none:
      break;
  }
}
