import 'dart:async';
import '../../services/isolate_runner.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx_engine/pdfrx_engine.dart' as pdfrx;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../services/pdf_tools_service.dart';
import '../../utils/snack_utils.dart';
import '../../widgets/pdf_file_header.dart';
import '../../widgets/pdf_picker_screen.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  String? _pathA;
  String? _nameA;
  int _pagesA = 0;

  String? _pathB;
  String? _nameB;
  int _pagesB = 0;

  bool _isLoading = false;
  int _currentPage = 0; // 0-based
  final Map<int, Uint8List> _thumbsA = {};
  final Map<int, Uint8List> _thumbsB = {};

  // Résultat de la comparaison pixel par page (memoized) + overlay de
  // surbrillance des zones modifiées (PNG), et bascule d'affichage.
  final Map<int, _PageDiff> _diffCache = {};
  final Map<int, Uint8List> _overlay = {};
  bool _showDiff = false;

  bool get _ready => _pathA != null && _pathB != null;
  int get _maxPages => _pagesA > _pagesB ? _pagesA : _pagesB;

  Future<void> _pickFile(bool isA) async {
    final path = await PdfPickerScreen.pickOne(
      context,
      title: isA ? 'Premier PDF' : 'Second PDF',
    );
    if (!mounted) return;
    if (path == null) return;
    final int count;
    try {
      final bytes = await PdfToolsService.safeReadPdf(path);
      count = await runPdfIsolate(() {
        final doc = PdfDocument(inputBytes: bytes);
        final c = doc.pages.count;
        doc.dispose();
        return c;
      });
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
      return;
    }
    if (!mounted) return;

    final name = fileNameOf(path);
    setState(() {
      if (isA) {
        _pathA = path;
        _nameA = name;
        _pagesA = count;
        _thumbsA.clear();
      } else {
        _pathB = path;
        _nameB = name;
        _pagesB = count;
        _thumbsB.clear();
      }
      // Un nouveau document invalide toute comparaison précédente.
      _diffCache.clear();
      _overlay.clear();
      _showDiff = false;
      _currentPage = 0;
    });

    if (_ready) await _loadPage(_currentPage);
  }

  Future<void> _loadPage(int pageIndex) async {
    if (!_ready) return;
    // Déjà rendu + comparé : rien à refaire (PNG en cache pour l'affichage).
    if (_diffCache.containsKey(pageIndex)) return;
    setState(() => _isLoading = true);
    // Sérialisé (pas de Future.wait) : le rendu PDF natif est gourmand en
    // mémoire ; exécuter les deux pages en parallèle double le pic de RAM.
    final ra = await _renderRaster(_pathA!, pageIndex, _pagesA);
    if (!mounted) return;
    final rb = await _renderRaster(_pathB!, pageIndex, _pagesB);
    if (!mounted) return;
    if (ra != null) _thumbsA[pageIndex] = ra.png;
    if (rb != null) _thumbsB[pageIndex] = rb.png;
    await _computeDiff(pageIndex, ra, rb);
    if (mounted) setState(() => _isLoading = false);
  }

  /// Rend une page en PNG (affichage) + conserve les octets bruts RGBA et les
  /// dimensions (nécessaires à la comparaison pixel). Retourne null si la page
  /// n'existe pas de ce côté.
  ///
  /// P0 v1.13.2 — migration pdfx → pdfrx_engine. Le bitmap brut retourné par
  /// PDFium est encodé en PNG via package:image ; les octets normalisés en
  /// RGBA uint8 sont conservés pour la comparaison pixel.
  Future<_Raster?> _renderRaster(String path, int index, int total) async {
    if (index >= total) return null;
    final pdfDoc = await pdfrx.PdfDocument.openFile(path);
    try {
      final page = pdfDoc.pages[index];
      final pageImage = await page.render(
        width: (page.width * 1.5).toInt(),
        height: (page.height * 1.5).toInt(),
      );
      if (pageImage == null) return null;
      final image = pageImage.createImageNF();
      final png = Uint8List.fromList(img.encodePng(image));
      final raw = _imageToRgba(image);
      final w = image.width;
      final h = image.height;
      pageImage.dispose();
      return _Raster(png: png, raw: raw, w: w, h: h);
    } finally {
      await pdfDoc.dispose();
    }
  }

  /// Convertit une image pdfrx/image en buffer RGBA uint8 normalisé pour
  /// `_diffPixels`. Si l'image est déjà RGBA, l'opération est une no-op.
  Uint8List _imageToRgba(img.Image src) {
    return src.convert(format: img.Format.uint8).getBytes();
  }

  /// Compare les rasters bruts des deux côtés pour la page donnée. Le balayage
  /// pixel (O(n)) tourne dans l'isolate (runPdfIsolate) pour ne pas figer l'UI
  /// sur des pages haute résolution.
  Future<void> _computeDiff(int page, _Raster? ra, _Raster? rb) async {
    if (ra == null || rb == null) {
      _diffCache[page] = const _PageDiff(_DiffKind.missing, 0);
      return;
    }
    if (ra.w != rb.w || ra.h != rb.h) {
      // Formats différents : comparaison pixel non pertinente (le simple fait
      // que les dimensions divergent est déjà un signal de différence).
      _diffCache[page] = const _PageDiff(_DiffKind.dimMismatch, 0);
      return;
    }
    final rawA = ra.raw;
    final rawB = rb.raw;
    if (rawA.length != rawB.length) {
      // Les dimensions affichées correspondent mais les buffers bruts ont des
      // tailles différentes (formats internes différents, canal alpha, etc.).
      _diffCache[page] = const _PageDiff(_DiffKind.error, 0);
      return;
    }
    final w = ra.w;
    final h = ra.h;
    try {
      final res = await runPdfIsolate(() => _diffPixels(rawA, rawB));
      if (!mounted) return;
      final total = w * h;
      final ratio = total == 0 ? 0.0 : res.$1 / total;
      // P0 v1.13.2 — conversion RGBA → PNG via package:image.
      final overlayImage = img.Image.fromBytes(
        width: w,
        height: h,
        bytes: res.$2.buffer,
        format: img.Format.uint8,
      );
      _overlay[page] = Uint8List.fromList(img.encodePng(overlayImage));
      if (!mounted) return;
      // Seuil anti-bruit d'anti-aliasing : < 0,05 % de pixels ⇒ identique.
      _diffCache[page] = _PageDiff(
        ratio < 0.0005 ? _DiffKind.identical : _DiffKind.different,
        ratio,
      );
    } catch (_) {
      _diffCache[page] = const _PageDiff(_DiffKind.error, 0);
    }
  }

  void _goTo(int page) {
    if (page < 0 || page >= _maxPages) return;
    setState(() => _currentPage = page);
    unawaited(_loadPage(page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparer deux PDFs'),
        actions: _ready
            ? [
                IconButton(
                  tooltip: _showDiff
                      ? 'Vue côte à côte'
                      : 'Vue des différences',
                  icon: Icon(
                    _showDiff
                        ? Icons.view_column_outlined
                        : Icons.difference_outlined,
                  ),
                  // Actif seulement si un overlay est disponible pour la page.
                  onPressed: _overlay[_currentPage] != null
                      ? () => setState(() => _showDiff = !_showDiff)
                      : null,
                ),
              ]
            : null,
        bottom: _ready
            ? PreferredSize(
                preferredSize: const Size.fromHeight(36),
                child: _buildPageBar(),
              )
            : null,
      ),
      body: _ready ? _buildComparison() : _buildPicker(),
    );
  }

  Widget _buildPicker() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Icon(
            Icons.compare_outlined,
            size: 72,
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 16),
          Text(
            'Comparer deux PDFs',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Détecte les différences page par page et les met en évidence',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _pdfSlot(true),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'VS',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
          _pdfSlot(false),
        ],
      ),
    );
  }

  Widget _pdfSlot(bool isA) {
    final path = isA ? _pathA : _pathB;
    final name = isA ? _nameA : _nameB;
    final pages = isA ? _pagesA : _pagesB;
    final label = isA ? 'PDF A — Original' : 'PDF B — Comparaison';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _pickFile(isA),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: path == null
              ? Row(
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    const Text('Choisir', style: TextStyle(color: Colors.blue)),
                  ],
                )
              : Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            name!,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '$pages pages',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _pickFile(isA),
                      child: const Text('Changer'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildPageBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Page précédente',
            iconSize: 20,
            onPressed: _currentPage > 0 ? () => _goTo(_currentPage - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            'Page ${_currentPage + 1} / $_maxPages',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          IconButton(
            tooltip: 'Page suivante',
            iconSize: 20,
            onPressed: _currentPage < _maxPages - 1
                ? () => _goTo(_currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  /// Bandeau de statut de comparaison pour la page courante. Texte en
  /// `onSurfaceVariant` (contraste AA garanti) ; couleur portée par l'icône
  /// (élément non textuel, seuil 3:1).
  Widget _buildDiffChip() {
    final d = _diffCache[_currentPage];
    if (d == null) return const SizedBox(height: 6);
    final cs = Theme.of(context).colorScheme;
    final (IconData icon, Color iconColor, String label) = switch (d.kind) {
      _DiffKind.identical => (
        Icons.check_circle,
        Colors.green,
        'Pages identiques',
      ),
      _DiffKind.different => (
        Icons.difference,
        Colors.orange,
        'Différences détectées · ${_fmtRatio(d.ratio)} de la page',
      ),
      _DiffKind.dimMismatch => (
        Icons.aspect_ratio,
        Colors.deepOrange,
        'Formats de page différents',
      ),
      _DiffKind.missing => (
        Icons.remove_circle_outline,
        cs.onSurfaceVariant,
        'Page absente d\'un des documents',
      ),
      _DiffKind.error => (
        Icons.error_outline,
        cs.onSurfaceVariant,
        'Comparaison indisponible',
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtRatio(double r) {
    final pct = r * 100;
    return '${pct.toStringAsFixed(pct < 1 ? 2 : 1)} %';
  }

  Widget _buildComparison() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _nameA!,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _nameB!,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildDiffChip(),
        const Divider(height: 1),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : (_showDiff && _overlay[_currentPage] != null)
              ? _buildOverlayView()
              : Row(
                  children: [
                    Expanded(child: _pageView(_thumbsA, _pagesA, Colors.blue)),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: _pageView(_thumbsB, _pagesB, Colors.orange),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  /// Vue « différences » : image unique où les zones modifiées sont en rouge
  /// et le reste lavé en gris clair (contexte).
  Widget _buildOverlayView() {
    final ov = _overlay[_currentPage];
    if (ov == null) {
      return const Center(child: Text('Aperçu des différences indisponible'));
    }
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 4),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Text(
            'Zones en rouge = différences',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
        Expanded(
          child: InteractiveViewer(
            child: Image.memory(ov, fit: BoxFit.contain),
          ),
        ),
      ],
    );
  }

  Widget _pageView(Map<int, Uint8List> cache, int total, Color accent) {
    if (_currentPage >= total) {
      return Center(
        child: Text(
          'Pas de page ${_currentPage + 1}',
          style: TextStyle(color: accent, fontSize: 12),
        ),
      );
    }
    final thumb = cache[_currentPage];
    if (thumb == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return InteractiveViewer(child: Image.memory(thumb, fit: BoxFit.contain));
  }
}

/// Raster d'une page : PNG pour l'affichage + octets bruts RGBA + dimensions
/// pour la comparaison pixel.
class _Raster {
  final Uint8List png;
  final Uint8List raw;
  final int w;
  final int h;
  const _Raster({
    required this.png,
    required this.raw,
    required this.w,
    required this.h,
  });
}

enum _DiffKind { identical, different, dimMismatch, missing, error }

class _PageDiff {
  final _DiffKind kind;
  final double ratio; // fraction de pixels différents [0..1]
  const _PageDiff(this.kind, this.ratio);
}

/// Balayage pixel des deux rasters RGBA (même taille garantie par l'appelant).
/// Exécuté dans un isolate. Retourne (nb pixels différents, overlay RGBA).
///
/// Overlay : pixel modifié ⇒ rouge opaque ; pixel identique ⇒ gris très clair
/// (contexte lavé). Tolérance par canal pour absorber le bruit d'anti-aliasing.
(int, Uint8List) _diffPixels(Uint8List a, Uint8List b) {
  // Précondition : tailles égales (vérifiée par l'appelant). Si ce n'est pas
  // le cas, on retourne un overlay vide — l'appelant remontera une erreur.
  if (a.length != b.length) {
    return (0, Uint8List(0));
  }
  final n = a.length;
  final overlay = Uint8List(n);
  int changed = 0;
  const thr = 28;
  for (int i = 0; i + 3 < n; i += 4) {
    final dr = (a[i] - b[i]).abs();
    final dg = (a[i + 1] - b[i + 1]).abs();
    final db = (a[i + 2] - b[i + 2]).abs();
    if (dr > thr || dg > thr || db > thr) {
      changed++;
      overlay[i] = 0xE5;
      overlay[i + 1] = 0x39;
      overlay[i + 2] = 0x35;
      overlay[i + 3] = 0xFF;
    } else {
      final gray = (b[i] * 30 + b[i + 1] * 59 + b[i + 2] * 11) ~/ 100;
      final wash = 210 + gray ~/ 6;
      final v = wash > 255 ? 255 : wash;
      overlay[i] = v;
      overlay[i + 1] = v;
      overlay[i + 2] = v;
      overlay[i + 3] = 0xFF;
    }
  }
  return (changed, overlay);
}
