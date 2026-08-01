import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service de detection root/jailbreak.
///
/// Utilise un MethodChannel natif (Kotlin) pour verifier quelques signes
/// classiques de systeme modifie :
/// - tags de build test-keys
/// - presence de binaires/packages root connus
/// - variables systeme inhabituelles
///
/// Le resultat est informatif : l'app continue de fonctionner mais affiche
/// un avertissement a l'utilisateur.
class RootDetectionService {
  RootDetectionService._();

  static const _channel = MethodChannel('com.pdftech.pdf_tech/root');

  static Future<bool> isRooted() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      final rooted = await _channel.invokeMethod<bool>('isRooted');
      return rooted ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('[RootDetectionService] error: $e');
      return false;
    }
  }
}
