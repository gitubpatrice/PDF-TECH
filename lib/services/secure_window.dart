import 'package:flutter/services.dart';

/// Pose / retire `WindowManager.LayoutParams.FLAG_SECURE` sur la fenêtre
/// principale via un MethodChannel Kotlin.
///
/// Effets :
/// - Bloque captures d'écran et enregistrement écran
/// - Masque l'aperçu dans Recent Apps (vignette noire)
///
/// À appeler avec [enable] quand un contenu sensible est affiché (saisie
/// password PDF, signature manuscrite, viewer de PDF déchiffré) et
/// [disable] au dispose.
///
/// F1 v1.12.2 — comble l'absence FLAG_SECURE révélée par l'audit
/// vulnérabilités (claim doc faux). Aligné sur le pattern Read Files
/// Tech `lib/services/secure_window.dart`.
class SecureWindow {
  static const _channel = MethodChannel('com.pdftech.pdf_tech/secure_window');
  static int _refCount = 0;

  /// Active FLAG_SECURE. Refcount-aware : plusieurs écrans sensibles
  /// empilés peuvent appeler `enable()` sans que le premier qui dispose
  /// ne désactive pour les autres.
  static Future<void> enable() async {
    _refCount++;
    if (_refCount == 1) {
      try {
        await _channel.invokeMethod('setSecure', {'enabled': true});
      } catch (_) {
        /* silent — non bloquant */
      }
    }
  }

  /// Désactive FLAG_SECURE quand le dernier écran sensible se ferme.
  static Future<void> disable() async {
    if (_refCount <= 0) return;
    _refCount--;
    if (_refCount == 0) {
      try {
        await _channel.invokeMethod('setSecure', {'enabled': false});
      } catch (_) {
        /* silent */
      }
    }
  }
}
