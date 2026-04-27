import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExtractImagesScreen extends StatefulWidget {
  const ExtractImagesScreen({super.key});

  @override
  State<ExtractImagesScreen> createState() => _ExtractImagesScreenState();
}

class _ExtractImagesScreenState extends State<ExtractImagesScreen> {
  String? _path;
  String? _name;
  bool _isProcessing = false;
  List<String> _imagePaths = [];
  bool _isDone = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;
    setState(() {
      _path = result.files.single.path!;
      _name = result.files.single.name;
      _imagePaths = [];
      _isDone = false;
    });
  }

  Future<void> _process() async {
    if (_path == null) return;
    setState(() { _isProcessing = true; _imagePaths = []; });
    try {
      final pdfBytes = await File(_path!).readAsBytes();
      final jpegs = _extractJpegs(pdfBytes);

      final dir = await getApplicationDocumentsDirectory();
      final ts  = DateTime.now().millisecondsSinceEpoch;
      final outDir = Directory('${dir.path}/images_extraites_$ts');
      await outDir.create(recursive: true);

      final paths = <String>[];
      for (int i = 0; i < jpegs.length; i++) {
        final outPath = '${outDir.path}/image_${i + 1}.jpg';
        await File(outPath).writeAsBytes(jpegs[i]);
        paths.add(outPath);
      }

      if (!mounted) return;
      setState(() {
        _imagePaths = paths;
        _isDone = true;
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  // Scanne les octets du PDF à la recherche de flux JPEG (FF D8 FF … FF D9)
  List<Uint8List> _extractJpegs(Uint8List data) {
    final results = <Uint8List>[];
    int i = 0;
    while (i < data.length - 3) {
      if (data[i] == 0xFF && data[i + 1] == 0xD8 && data[i + 2] == 0xFF) {
        final start = i;
        int j = start + 2;
        bool found = false;
        while (j < data.length - 1) {
          if (data[j] == 0xFF && data[j + 1] == 0xD9) {
            results.add(data.sublist(start, j + 2));
            i = j + 2;
            found = true;
            break;
          }
          j++;
        }
        if (!found) break;
      } else {
        i++;
      }
    }
    return results;
  }

  Future<void> _shareAll() async {
    if (_imagePaths.isEmpty) return;
    await Share.shareXFiles(
      _imagePaths.map((p) => XFile(p)).toList(),
      subject: 'Images extraites de ${_name ?? "PDF"}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Extraire les images'),
        actions: [
          if (_isDone && _imagePaths.isNotEmpty)
            IconButton(
              tooltip: 'Partager tout',
              icon: const Icon(Icons.share),
              onPressed: _shareAll,
            ),
        ],
      ),
      body: _path == null ? _buildPicker() : _buildContent(),
    );
  }

  Widget _buildPicker() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_search,
                size: 88,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.35)),
            const SizedBox(height: 24),
            Text('Extraire les images',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Récupérez toutes les images intégrées dans un PDF',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center),
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

  Widget _buildContent() {
    if (_isProcessing) return _buildProgress();
    if (_isDone) return _buildResult();
    return _buildStart();
  }

  Widget _buildStart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _FileHeader(name: _name!, onChange: _pickFile),
            const SizedBox(height: 32),
            const Icon(Icons.image_search, size: 56, color: Colors.teal),
            const SizedBox(height: 16),
            const Text('Prêt à extraire les images',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Toutes les images intégrées dans le PDF\nseront extraites et sauvegardées.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _process,
              icon: const Icon(Icons.image_search),
              label: const Text('Extraire les images'),
              style: FilledButton.styleFrom(minimumSize: const Size(200, 48)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text('Extraction en cours…',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildResult() {
    if (_imagePaths.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined,
                size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('Aucune image trouvée dans ce PDF',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            const Text('Ce PDF ne contient pas d\'images intégrées.',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _pickFile,
              child: const Text('Choisir un autre PDF'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[600], size: 17),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_imagePaths.length} image${_imagePaths.length > 1 ? 's' : ''} extraite${_imagePaths.length > 1 ? 's' : ''}',
                  style: TextStyle(
                      color: Colors.green[700], fontWeight: FontWeight.w500),
                ),
              ),
              TextButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Nouveau'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _imagePaths.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => Share.shareXFiles(
                [XFile(_imagePaths[i])],
                subject: 'Image ${i + 1}',
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(File(_imagePaths[i]),
                    fit: BoxFit.cover),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FileHeader extends StatelessWidget {
  final String name;
  final VoidCallback onChange;
  const _FileHeader({required this.name, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.picture_as_pdf, color: Colors.blue),
        const SizedBox(width: 10),
        Expanded(
            child: Text(name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500))),
        TextButton(onPressed: onChange, child: const Text('Changer')),
      ],
    );
  }
}
