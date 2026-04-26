import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';

import '../../services/google_drive_service.dart';
import '../../services/recent_files_service.dart';
import '../pdf_viewer_screen.dart';

class GoogleDriveScreen extends StatefulWidget {
  const GoogleDriveScreen({super.key});

  @override
  State<GoogleDriveScreen> createState() => _GoogleDriveScreenState();
}

class _GoogleDriveScreenState extends State<GoogleDriveScreen> {
  final _service = GoogleDriveService();
  final _recents = RecentFilesService();

  bool _checkingAuth = true;
  bool _signedIn = false;
  String? _userEmail;

  bool _loadingFiles = false;
  List<drive.File> _files = [];

  bool _uploading = false;
  String? _downloadingId;

  @override
  void initState() {
    super.initState();
    _checkSignIn();
  }

  Future<void> _checkSignIn() async {
    setState(() => _checkingAuth = true);
    try {
      final signedIn = await _service.isSignedIn();
      if (signedIn) {
        setState(() {
          _signedIn = true;
          _userEmail = _service.currentUser?.email;
        });
        await _loadFiles();
      } else {
        setState(() => _signedIn = false);
      }
    } catch (_) {
      setState(() => _signedIn = false);
    } finally {
      if (mounted) setState(() => _checkingAuth = false);
    }
  }

  Future<void> _signIn() async {
    setState(() => _checkingAuth = true);
    try {
      final account = await _service.signIn();
      if (account == null) {
        setState(() => _checkingAuth = false);
        return;
      }
      setState(() {
        _signedIn = true;
        _userEmail = account.email;
        _checkingAuth = false;
      });
      await _loadFiles();
    } catch (e) {
      if (!mounted) return;
      setState(() => _checkingAuth = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur de connexion : $e')));
    }
  }

  Future<void> _signOut() async {
    await _service.signOut();
    setState(() {
      _signedIn = false;
      _userEmail = null;
      _files = [];
    });
  }

  Future<void> _loadFiles() async {
    setState(() => _loadingFiles = true);
    try {
      final files = await _service.listPdfFiles();
      if (mounted) setState(() => _files = files);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur chargement : $e')));
    } finally {
      if (mounted) setState(() => _loadingFiles = false);
    }
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result?.files.single.path == null) return;
    final path = result!.files.single.path!;
    setState(() => _uploading = true);
    try {
      await _service.uploadFile(path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fichier envoyé sur Google Drive')),
      );
      await _loadFiles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur upload : $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _download(drive.File driveFile) async {
    setState(() => _downloadingId = driveFile.id);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final localPath =
          await _service.downloadFile(driveFile, dir.path);
      if (!mounted) return;
      final recentList = await _recents.load();
      await _recents.addOrUpdate(recentList, localPath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Téléchargement terminé')),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            path: localPath,
            title: driveFile.name ?? 'document.pdf',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur téléchargement : $e')));
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  String _formatSize(String? sizeStr) {
    if (sizeStr == null) return '';
    final bytes = int.tryParse(sizeStr);
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} Ko';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} Mo';
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_checkingAuth) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_signedIn) {
      return _buildSignInView();
    }

    return _buildDriveView();
  }

  Widget _buildSignInView() {
    return Scaffold(
      appBar: AppBar(title: const Text('Google Drive')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_to_drive, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              Text(
                'Google Drive',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Accédez à vos fichiers PDF stockés sur Google Drive, '
                'téléchargez-les pour les consulter ou envoyez vos PDF locaux '
                'vers le cloud.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Se connecter avec Google'),
                  onPressed: _signIn,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Nécessite une configuration Google Cloud (voir documentation)',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDriveView() {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Google Drive', style: TextStyle(fontSize: 16)),
            if (_userEmail != null)
              Text(
                _userEmail!,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
            onPressed: _loadingFiles ? null : _loadFiles,
          ),
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Envoyer un PDF',
        onPressed: _uploading ? null : _upload,
        child: _uploading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.upload),
      ),
      body: _loadingFiles
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadFiles,
                  child: ListView.builder(
                    itemCount: _files.length,
                    itemBuilder: (context, index) {
                      final file = _files[index];
                      final isDownloading = _downloadingId == file.id;
                      return ListTile(
                        leading: const Icon(Icons.picture_as_pdf,
                            color: Colors.red, size: 32),
                        title: Text(
                          file.name ?? 'Sans nom',
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          [
                            _formatSize(file.size),
                            _formatDate(file.modifiedTime),
                          ]
                              .where((s) => s.isNotEmpty)
                              .join('  ·  '),
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: isDownloading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                tooltip: 'Télécharger',
                                icon: const Icon(Icons.download_outlined),
                                onPressed: () => _download(file),
                              ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Aucun PDF sur Drive',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Appuyez sur le bouton + pour envoyer un PDF.',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }
}
