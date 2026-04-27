import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/pdf_tools_service.dart';
import '../../widgets/result_sheet.dart';

class ProtectScreen extends StatefulWidget {
  const ProtectScreen({super.key});

  @override
  State<ProtectScreen> createState() => _ProtectScreenState();
}

class _ProtectScreenState extends State<ProtectScreen> {
  String? _filePath;
  String? _fileName;
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _processing = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result?.files.single.path == null) return;
    setState(() {
      _filePath = result!.files.single.path;
      _fileName = result.files.single.name;
    });
  }

  Future<void> _protect() async {
    if (_filePath == null) return;
    if (_passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Entrez un mot de passe')));
      return;
    }
    if (_passwordCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Les mots de passe ne correspondent pas')));
      return;
    }
    setState(() => _processing = true);
    try {
      final output = await PdfToolsService()
          .protectPdf(_filePath!, _passwordCtrl.text);
      if (!mounted) return;
      await showResultSheet(context,
          outputPath: output, operationLabel: 'PDF protégé par mot de passe');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Protéger par mot de passe')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                leading: Icon(Icons.picture_as_pdf,
                    color: Theme.of(context).colorScheme.primary, size: 32),
                title: Text(_fileName ?? 'Aucun fichier sélectionné'),
                trailing: TextButton(onPressed: _pickFile, child: const Text('Choisir')),
                onTap: _pickFile,
              ),
            ),
            if (_filePath != null) ...[
              const SizedBox(height: 24),
              Text('Définir le mot de passe',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure1,
                enableSuggestions: false,
                autocorrect: false,
                keyboardType: TextInputType.visiblePassword,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure1 ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure1 = !_obscure1),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmCtrl,
                obscureText: _obscure2,
                enableSuggestions: false,
                autocorrect: false,
                keyboardType: TextInputType.visiblePassword,
                decoration: InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure2 ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Le PDF résultant nécessitera ce mot de passe pour être ouvert.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: _processing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.lock),
                label: Text(_processing ? 'Protection en cours…' : 'Protéger le PDF'),
                onPressed: (_processing || _filePath == null) ? null : _protect,
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}
