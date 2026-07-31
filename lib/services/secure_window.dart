import 'dart:async';

import 'package:flutter/foundation.dart';
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
///
/// F1 v1.13.2 — file d'attente séquentielle : les appels `enable()`/
/// `disable()` sont traités dans l'ordre strict, sans race condition sur
/// le refcount. Le `_refCount` n'est jamais lu/écrit en concurrence.
class SecureWindow {
  static const _channel = MethodChannel('com.pdftech.pdf_tech/secure_window');

  static final List<_SecureOp> _queue = [];
  static bool _processing = false;
  static int _refCount = 0;

  /// Active FLAG_SECURE. Refcount-aware : plusieurs écrans sensibles
  /// empilés peuvent appeler `enable()` sans que le premier qui dispose
  /// ne désactive pour les autres.
  static Future<void> enable() => _enqueue(true);

  /// Désactive FLAG_SECURE quand le dernier écran sensible se ferme.
  static Future<void> disable() => _enqueue(false);

  static Future<void> _enqueue(bool enable) {
    final completer = Completer<void>();
    _queue.add(_SecureOp(enable, completer));
    // Ne pas await ici : le caller attendra le Completer, le worker tourne
    // indépendamment mais séquentiellement.
    unawaited(_processQueue());
    return completer.future;
  }

  static Future<void> _processQueue() async {
    if (_processing) return;
    _processing = true;
    while (_queue.isNotEmpty) {
      final op = _queue.removeAt(0);
      try {
        await _apply(op.enable);
        op.completer.complete();
      } catch (e) {
        // FLAG_SECURE est best-effort : on ne laisse pas échouer l'UI si le
        // MethodChannel n'est pas disponible (tests, platformes non supportées).
        op.completer.complete();
        // Propager silencieusement en debug uniquement.
        debugPrint('[SecureWindow] best-effort failure: $e');
      }
    }
    _processing = false;
  }

  static Future<void> _apply(bool enable) async {
    if (enable) {
      _refCount++;
      if (_refCount == 1) {
        await _channel.invokeMethod('setSecure', {'enabled': true});
      }
    } else {
      if (_refCount <= 0) return;
      _refCount--;
      if (_refCount == 0) {
        await _channel.invokeMethod('setSecure', {'enabled': false});
      }
    }
  }
}

class _SecureOp {
  final bool enable;
  final Completer<void> completer;
  _SecureOp(this.enable, this.completer);
}
