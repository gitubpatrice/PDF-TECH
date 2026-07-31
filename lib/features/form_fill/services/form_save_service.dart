import 'dart:async';

import 'package:flutter/services.dart' show HapticFeedback;
import 'package:pdf_tech/utils/atomic_write.dart';

/// Service responsable de la sauvegarde atomique d'un document PDF rempli.
class FormSaveService {
  const FormSaveService();

  /// Sauvegarde [bytes] à l'emplacement [path].
  Future<void> save(String path, List<int> bytes) async {
    // **Atomique** (audit failles P0 v1.12) : write tmp + rename pour
    // éviter la corruption du PDF original sur crash mid-write.
    await atomicWriteBytes(path, bytes);
    await HapticFeedback.selectionClick();
  }
}
