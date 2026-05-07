import 'dart:async';
import 'dart:io';

import 'package:files_tech_core/files_tech_core.dart';
import 'package:flutter/material.dart';

/// Affiche les résultats du scan global "Trouver tous mes PDFs". Liste plate
/// avec recherche debounce 200 ms, triée par date modifiée DESC. Tap pour
/// ouvrir.
///
/// Les FileStat sont pré-calculés lors du scan et passés via [statsByPath]
/// pour ne JAMAIS faire de `statSync()` dans `itemBuilder` (jank de scroll).
class AllPdfsScreen extends StatefulWidget {
  final List<File> files;
  final Map<String, FileStat> statsByPath;
  final void Function(String path) onPick;

  const AllPdfsScreen({
    super.key,
    required this.files,
    required this.statsByPath,
    required this.onPick,
  });

  @override
  State<AllPdfsScreen> createState() => _AllPdfsScreenState();
}

class _AllPdfsScreenState extends State<AllPdfsScreen> {
  String _search = '';
  Timer? _debounce;

  /// Cache du dernier filtrage : évite de re-filtrer si on rebuild sans que
  /// la query ait changé. Acceptable pour <2000 PDFs mais c'est gratuit en
  /// cohérence avec le pattern memoizé du reste de l'app.
  String? _cachedQuery;
  List<File>? _cachedFiltered;

  String _formatSize(int b) => FormatUtils.bytesStorage(b);

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _search = v);
    });
  }

  List<File> _filtered() {
    if (_cachedQuery == _search && _cachedFiltered != null) {
      return _cachedFiltered!;
    }
    final result = _search.isEmpty
        ? widget.files
        : widget.files
              .where(
                (f) => PathUtils.fileName(
                  f.path,
                ).toLowerCase().contains(_search.toLowerCase()),
              )
              .toList();
    _cachedQuery = _search;
    _cachedFiltered = result;
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tous mes PDFs', style: TextStyle(fontSize: 16)),
            Text(
              '${widget.files.length} trouvés sur le téléphone',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
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
                ? const Center(
                    child: Text(
                      'Aucun PDF correspondant',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final f = filtered[i];
                      // FileStat pré-calculé lors du scan : JAMAIS de
                      // statSync() ici (IO sync dans itemBuilder = jank).
                      final stat = widget.statsByPath[f.path];
                      final name = PathUtils.fileName(f.path);
                      final dirName = PathUtils.fileName(f.parent.path);
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
                            stat != null
                                ? '$dirName · ${_formatSize(stat.size)}'
                                : dirName,
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
