import 'dart:io';
import 'package:files_tech_core/files_tech_core.dart';
import 'package:flutter/material.dart';

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
      // Pré-calcule les FileStat puis tri (évite un O(n log n) de statSync IO
      // dans le comparator).
      final withStat = <(File, FileStat)>[
        for (final f in found) (f, f.statSync()),
      ]..sort((a, b) => b.$2.modified.compareTo(a.$2.modified));
      if (!mounted) return;
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

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays == 0) return 'Aujourd\'hui';
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty
        ? _pdfs
        : _pdfs
              .where(
                (f) => f.path
                    .split('/')
                    .last
                    .toLowerCase()
                    .contains(_search.toLowerCase()),
              )
              .toList();

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
                      onChanged: (v) => setState(() => _search = v),
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
