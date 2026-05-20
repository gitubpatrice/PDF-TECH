import 'dart:async';
import 'dart:io';
import 'package:files_tech_core/files_tech_core.dart';
import 'package:flutter/material.dart';

import '../utils/date_utils.dart';

/// Liste tous les PDFs d'un dossier (et un niveau de sous-dossiers max)
/// pour que l'utilisateur puisse en choisir un rapidement, sans passer
/// par le file picker système.
class PdfFolderScreen extends StatefulWidget {
  final String path;
  final String title;
  final void Function(String path) onPick;

  const PdfFolderScreen({
    super.key,
    required this.path,
    required this.title,
    required this.onPick,
  });

  @override
  State<PdfFolderScreen> createState() => _PdfFolderScreenState();
}

class _PdfFolderScreenState extends State<PdfFolderScreen> {
  List<File> _pdfs = [];
  // Cache de FileStat indexé par chemin : évite un statSync() IO sync à chaque
  // build de cellule pendant le scroll (ListView.builder).
  Map<String, FileStat> _stats = const {};
  bool _loading = true;
  String? _error;
  String _search = '';

  // Memoize du filtre + debounce 200 ms (cohérence avec all_pdfs_screen).
  String? _cachedQuery;
  List<File> _cachedFiltered = const [];
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  List<File> _filtered() {
    if (_cachedQuery == _search) return _cachedFiltered;
    final q = _search.toLowerCase();
    final result = q.isEmpty
        ? _pdfs
        : _pdfs
              .where(
                (f) => PathUtils.fileName(f.path).toLowerCase().contains(q),
              )
              .toList();
    _cachedQuery = _search;
    _cachedFiltered = result;
    return result;
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _search = v);
    });
  }

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    try {
      final dir = Directory(widget.path);
      if (!await dir.exists()) {
        setState(() {
          _error = 'Dossier introuvable';
          _loading = false;
        });
        return;
      }
      final found = <File>[];
      // 1 niveau de profondeur (dossier + sous-dossiers immédiats)
      await for (final e in dir.list(recursive: false, followLinks: false)) {
        if (e is File && e.path.toLowerCase().endsWith('.pdf')) {
          found.add(e);
        } else if (e is Directory) {
          try {
            await for (final sub in e.list(
              recursive: false,
              followLinks: false,
            )) {
              if (sub is File && sub.path.toLowerCase().endsWith('.pdf')) {
                found.add(sub);
              }
            }
          } catch (_) {
            /* dossier inaccessible : on ignore */
          }
        }
      }
      // Pré-calcule les FileStat en parallèle async (évite IO sync sur main
      // isolate — sur dossier 200+ PDFs ça freezait l'UI à l'ouverture).
      final withStat = await Future.wait(
        found.map((f) async => (f, await f.stat())),
      );
      withStat.sort((a, b) => b.$2.modified.compareTo(a.$2.modified));
      if (!mounted) return;
      // Invalide le memoize : nouveau _pdfs ⇒ filtré stale (même si query identique).
      _cachedQuery = null;
      _cachedFiltered = const [];
      setState(() {
        _pdfs = withStat.map((e) => e.$1).toList(growable: false);
        _stats = {for (final e in withStat) e.$1.path: e.$2};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de scanner le dossier';
        _loading = false;
      });
    }
  }

  // v1.10.1 — délégué à FormatUtils.bytesStorage (files_tech_core).
  String _formatSize(int bytes) => FormatUtils.bytesStorage(bytes);

  // v1.12.5 (D3) — délégué à DateFormatUtils.relative (utils/date_utils.dart).
  // Aligne le format sur home_screen ("Il y a N jours" au lieu de "Nj")
  // et bénéficie du DateFormat static (perf P2.1 v1.12.4) — avant :
  // padLeft inline alloué à chaque rebuild de chaque ligne de la liste.
  String _formatDate(DateTime d) => DateFormatUtils.relative(d);

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered();

    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 16)),
            if (!_loading)
              Text(
                '${_pdfs.length} PDF${_pdfs.length > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: () {
              setState(() => _loading = true);
              _scan();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.grey)),
            )
          : Column(
              children: [
                if (_pdfs.length > 5)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Rechercher…',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.folder_off_outlined,
                                  size: 64,
                                  color: cs.onSurfaceVariant,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _search.isEmpty
                                      ? 'Aucun PDF dans ce dossier'
                                      : 'Aucun PDF correspondant',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final f = filtered[i];
                            // JAMAIS de statSync() ici (IO sync dans itemBuilder).
                            // En pratique le cache _stats est rempli par _scan()
                            // avant le premier rendu de la liste.
                            final stat = _stats[f.path];
                            final name = PathUtils.fileName(f.path);
                            final parent = f.parent.path
                                .replaceAll(widget.path, '')
                                .replaceFirst(RegExp(r'^/'), '');
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 3,
                              ),
                              child: ListTile(
                                dense: true,
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFC62828,
                                    ).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.picture_as_pdf,
                                    color: Color(0xFFC62828),
                                    size: 22,
                                  ),
                                ),
                                title: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                subtitle: Text(
                                  [
                                    if (parent.isNotEmpty) parent,
                                    if (stat != null) _formatSize(stat.size),
                                    if (stat != null)
                                      _formatDate(stat.modified),
                                  ].join(' · '),
                                  style: const TextStyle(fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  widget.onPick(f.path);
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
