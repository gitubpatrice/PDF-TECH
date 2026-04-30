import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/pdf_tools_service.dart';
import '../../widgets/pdf_picker_screen.dart';

class DecryptScreen extends StatefulWidget {
  const DecryptScreen({super.key});

  @override
  State<DecryptScreen> createState() => _DecryptScreenState();
}

class _DecryptScreenState extends State<DecryptScreen> {
  String? _path;
  String? _name;
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _isProcessing = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final path = await PdfPickerScreen.pickOne(context,
        title: 'Choisir le PDF à déchiffrer');
    if (path == null) return;
    setState(() {
      _path = path;
      _name = path.split(RegExp(r'[/\\]')).last;
      _passwordCtrl.clear();
    });
  }

  Future<void> _decrypt() async {
    if (_path == null || _passwordCtrl.text.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);

    // Avertissement explicite : le fichier de sortie sera EN CLAIR et persistant
    // sur le téléphone — l'utilisateur doit en être conscient.
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded,
            color: Colors.amber, size: 36),
        title: const Text('Le PDF déchiffré sera en clair'),
        content: const Text(
          'Le fichier de sortie ne sera plus protégé par mot de passe. '
          'Il sera enregistré dans le stockage de l\'app et restera accessible '
          'jusqu\'à ce que vous le supprimiez.\n\n'
          'Pensez à le supprimer après usage si le contenu est sensible.',
          style: TextStyle(fontSize: 12),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('J\'ai compris')),
        ],
      ),
    );
    if (go != true || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      final outPath = await PdfToolsService()
          .decryptPdf(_path!, _passwordCtrl.text);

      if (!mounted) return;
      setState(() => _isProcessing = false);
      messenger.showSnackBar(SnackBar(
        content: const Text('PDF déchiffré avec succès'),
        action: SnackBarAction(
          label: 'Partager',
          onPressed: () => Share.shareXFiles([XFile(outPath)]),
        ),
      ));
      setState(() {
        _path = null;
        _name = null;
        _passwordCtrl.clear();
      });
    } on PdfValidationException catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Mot de passe incorrect ou PDF non chiffré'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Déchiffrer un PDF')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Illustration + description
            Center(
              child: Icon(Icons.lock_open_outlined,
                  size: 72,
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Retirez le mot de passe d\'un PDF protégé\n(vous devez connaître le mot de passe)',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),

            // Fichier
            Text('Fichier PDF',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _path == null
                ? SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Choisir un PDF'),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48)),
                    ),
                  )
                : ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.picture_as_pdf,
                          color: Colors.red, size: 22),
                    ),
                    title: Text(_name!,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                    trailing: TextButton(
                        onPressed: _pickFile,
                        child: const Text('Changer')),
                  ),
            const SizedBox(height: 24),

            // Mot de passe
            Text('Mot de passe actuel',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              enableSuggestions: false,
              autocorrect: false,
              keyboardType: TextInputType.visiblePassword,
              decoration: InputDecoration(
                hintText: 'Entrez le mot de passe du PDF',
                prefixIcon: const Icon(Icons.key_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),

            // Bouton déchiffrer
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    (_path != null && !_isProcessing) ? _decrypt : null,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.lock_open_outlined),
                label: Text(
                    _isProcessing ? 'Déchiffrement…' : 'Déchiffrer le PDF'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
