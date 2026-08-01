import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service de gestion de la permission [MANAGE_EXTERNAL_STORAGE].
///
/// Cette permission est optionnelle. Elle permet a un gestionnaire de PDFs de
/// scanner et de lire des documents repartis sur l'ensemble du stockage externe
/// (Download, Documents, dossiers de messageries...) pour une experience fluide.
/// Si l'utilisateur la refuse, l'application continue de fonctionner via le
/// Storage Access Framework (SAF). La permission n'est pas requise par Google
/// Play pour cette app ; la cible est GitHub/F-Droid.
class StoragePermissionService {
  StoragePermissionService._();

  /// Verifie si la permission est deja accordee.
  static Future<bool> isGranted() async {
    if (Platform.isAndroid) {
      return Permission.manageExternalStorage.isGranted;
    }
    return true;
  }

  /// Demande la permission. Retourne `true` si accordee, `false` sinon.
  static Future<bool> request() async {
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.request();
      return status.isGranted;
    }
    return true;
  }

  /// Ouvre les parametres Android pour que l'utilisateur active manuellement
  /// la permission (ecran "Tous les fichiers et medias").
  static Future<void> openSettings() async {
    await openAppSettings();
  }

  /// Demande la permission avec une explication complete.
  ///
  /// L'utilisateur peut refuser la premiere fois, ou refuser definitivement.
  /// Dans les deux cas, un fallback vers le selecteur systeme (SAF) est
  /// propose afin que l'app reste fonctionnelle sans acces global au stockage.
  /// Retourne `true` si la permission est accordee, `false` sinon.
  static Future<bool> requestWithDialog(BuildContext context) async {
    if (await isGranted()) return true;
    if (!context.mounted) return false;

    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Acces au stockage'),
        content: const Text(
          'PDF Tech peut parcourir l\'ensemble de vos fichiers PDFs '
          '(Download, Documents, etc.) pour les afficher et les gerer.\n\n'
          'Cette autorisation est optionnelle : si vous refusez, vous '
          'pourrez toujours ouvrir vos PDFs via le selecteur de fichiers '
          'Android.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Refuser (mode selecteur)'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Autoriser l\'acces complet'),
          ),
        ],
      ),
    );

    if (approved != true) return false;
    if (await request()) return true;

    if (!context.mounted) return false;
    final openSettingsNow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Permission requise'),
        content: const Text(
          'L\'autorisation a ete refusee. Ouvrir les parametres pour l\'activer '
          'manuellement ?\n\n'
          'Sinon, PDF Tech continuera d\'utiliser le selecteur de fichiers '
          'Android (SAF) pour ouvrir vos documents.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Utiliser le selecteur'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Parametres'),
          ),
        ],
      ),
    );

    if (openSettingsNow == true) {
      await openSettings();
    }
    return isGranted();
  }
}
