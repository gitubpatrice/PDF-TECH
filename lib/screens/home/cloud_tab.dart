import 'package:flutter/material.dart';
import '../cloud/google_drive_screen.dart';

/// Onglet "Cloud" du HomeScreen — listing des intégrations cloud disponibles
/// (Google Drive aujourd'hui, Dropbox bientôt).
class CloudTab extends StatelessWidget {
  const CloudTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Stockage cloud',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Connectez vos comptes pour accéder à vos PDFs depuis le cloud.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const Icon(
              Icons.add_to_drive,
              color: Colors.blue,
              size: 32,
            ),
            title: const Text('Google Drive'),
            subtitle: const Text('Upload, téléchargement, partage'),
            trailing: FilledButton.tonal(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GoogleDriveScreen()),
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const Icon(
              Icons.cloud_queue,
              color: Color(0xFF0061FE),
              size: 32,
            ),
            title: const Text('Dropbox'),
            subtitle: const Text('Bientôt disponible'),
            trailing: FilledButton.tonal(
              onPressed: null,
              child: Text('Bientôt'),
            ),
          ),
        ),
      ],
    );
  }
}
