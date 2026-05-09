/// Helpers de SnackBar. Le thème global pose déjà
/// `behavior: SnackBarBehavior.floating` (`main.dart::snackBarTheme`),
/// donc inutile de le redéclarer côté call-site.
///
/// Usage :
/// ```dart
/// // Au lieu de :
/// // ScaffoldMessenger.of(context).showSnackBar(
/// //   SnackBar(content: Text('Erreur : $e')),
/// // );
/// showErrorSnack(context, e);
/// // ou
/// showInfoSnack(context, 'Sauvegardé');
/// ```
library;

import 'package:flutter/material.dart';

/// Affiche un SnackBar d'erreur. Préfixe "Erreur : " ajouté
/// automatiquement (pattern dupliqué dans 28 sites de l'app avant
/// extraction). [error] peut être une Exception, un String, etc. —
/// `toString()` est appelé.
void showErrorSnack(BuildContext context, Object error, {Duration? duration}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text('Erreur : $error'),
      duration: duration ?? const Duration(seconds: 4),
    ),
  );
}

/// Affiche un SnackBar informatif (succès, action terminée, etc.).
void showInfoSnack(
  BuildContext context,
  String message, {
  Duration? duration,
  SnackBarAction? action,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration ?? const Duration(seconds: 4),
      action: action,
    ),
  );
}

/// Variante pour les flux async où l'appelant a capturé
/// [ScaffoldMessenger] AVANT un `await` afin de ne pas dépendre du
/// `BuildContext` après la frontière asynchrone.
extension SnackbarMessengerExt on ScaffoldMessengerState {
  void showErrorSnack(Object error, {Duration? duration}) {
    showSnackBar(
      SnackBar(
        content: Text('Erreur : $error'),
        duration: duration ?? const Duration(seconds: 4),
      ),
    );
  }

  void showInfoSnack(String message, {Duration? duration}) {
    showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration ?? const Duration(seconds: 4),
      ),
    );
  }
}
