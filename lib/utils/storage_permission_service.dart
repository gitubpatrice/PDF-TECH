import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service de gestion de la permission [MANAGE_EXTERNAL_STORAGE].
///
/// Cette permission est nécessaire pour qu’un gestionnaire de PDFs puisse
/// scanner et lire des documents répartis sur l’ensemble du stockage externe
/// (Download, Documents, dossiers de messageries…). Elle n’est pas requise
/// par Google Play pour cette app ; la cible est GitHub/F-Droid.
class StoragePermissionService {
  StoragePermissionService._();

  /// Vérifie si la permission est déjà accordée.
  static Future<bool> isGranted() async {
    if (Platform.isAndroid) {
      return Permission.manageExternalStorage.isGranted;
    }
    return true;
  }

  /// Demande la permission. Retourne `true` si accordée, `false` sinon.
  static Future<bool> request() async {
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.request();
      return status.isGranted;
    }
    return true;
  }

  /// Ouvre les paramètres Android pour que l’utilisateur active manuellement
  /// la permission (écran "Tous les fichiers et médias").
  static Future<void> openSettings() async {
    await openAppSettings();
  }

  /// Demande la permission avec une explication si refusée, et ouvre les
  /// paramètres en dernier recours. Retourne `true` si accordée.
  static Future<bool> requestWithDialog(BuildContext context) async {
    if (await isGranted()) return true;
    if (!context.mounted) return false;

    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Accès aux fichiers'),
        content: const Text(
          'PDF Tech a besoin d’accéder à l’ensemble de vos fichiers PDFs '
          '(Download, Documents, etc.) pour les afficher et les gérer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Refuser'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Autoriser'),
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
          'L’autorisation a été refusée. Ouvrir les paramètres pour l’activer '
          'manuellement ? Sans cette permission, seul le sélecteur système '
          'reste disponible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Paramètres'),
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
