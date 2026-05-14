import 'package:flutter/material.dart';
import 'package:files_tech_core/files_tech_core.dart';
import '../../services/pdf_tools_service.dart';
import '../../services/secure_window.dart';
import '../../utils/snack_utils.dart';
import '../../widgets/pdf_file_header.dart';
import '../../widgets/pdf_picker_screen.dart';
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
  void initState() {
    super.initState();
    // F1 v1.12.2 — bloque captures + aperçu task switcher pendant
    // saisie password.
    SecureWindow.enable();
  }

  @override
  void dispose() {
    SecureWindow.disable();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final path = await PdfPickerScreen.pickOne(
      context,
      title: 'Choisir le PDF à protéger',
    );
    if (path == null) return;
    setState(() {
      _filePath = path;
      _fileName = PathUtils.fileName(path);
    });
  }

  Future<void> _protect() async {
    if (_filePath == null) return;
    if (_passwordCtrl.text.isEmpty) {
      showInfoSnack(context, 'Entrez un mot de passe');
      return;
    }
    if (_passwordCtrl.text != _confirmCtrl.text) {
      showInfoSnack(context, 'Les mots de passe ne correspondent pas');
      return;
    }
    setState(() => _processing = true);
    try {
      final output = await PdfToolsService().protectPdf(
        _filePath!,
        _passwordCtrl.text,
      );
      // Audit failles P1 : effacer immédiatement les mots de passe des
      // controllers après usage (decrypt_screen.dart fait déjà pareil).
      // Évite qu'un screenshot, un dump heap ou un retour arrière ne
      // ré-expose le mot de passe en clair.
      _passwordCtrl.clear();
      _confirmCtrl.clear();
      if (!mounted) return;
      await showResultSheet(
        context,
        outputPath: output,
        operationLabel: 'PDF protégé par mot de passe',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
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
            PdfFilePickerCard(fileName: _fileName, onPick: _pickFile),
            if (_filePath != null) ...[
              const SizedBox(height: 24),
              Text(
                'Définir le mot de passe',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure1,
                enableSuggestions: false,
                autocorrect: false,
                // U4 v1.12.4 — anti Autofill Android + anti copy clipboard
                // manager quand masqué.
                autofillHints: const <String>[],
                enableInteractiveSelection: !_obscure1,
                keyboardType: TextInputType.visiblePassword,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: 'Afficher / masquer',
                    icon: Icon(
                      _obscure1 ? Icons.visibility : Icons.visibility_off,
                    ),
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
                autofillHints: const <String>[],
                enableInteractiveSelection: !_obscure2,
                keyboardType: TextInputType.visiblePassword,
                decoration: InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure2 ? Icons.visibility : Icons.visibility_off,
                    ),
                    tooltip: _obscure2 ? 'Afficher' : 'Masquer',
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
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.lock),
                label: Text(
                  _processing ? 'Protection en cours…' : 'Protéger le PDF',
                ),
                onPressed: (_processing || _filePath == null) ? null : _protect,
              ),
            ),
            SizedBox(height: MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ),
    );
  }
}
