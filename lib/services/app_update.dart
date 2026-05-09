import 'package:files_tech_core/files_tech_core.dart';

import '../core/app_info.dart';

/// Instance partagée de [UpdateService] configurée pour PDF Tech.
///
/// La version est lue depuis [AppInfo.version] (source unique de vérité —
/// alignée sur `pubspec.yaml`). Évite le drift constaté en audit
/// incohérences v1.11.2 où la version était dupliquée à 3 endroits
/// (pubspec, about_screen, app_update).
const appUpdateService = UpdateService(
  owner: 'gitubpatrice',
  repo: 'PDF-TECH',
  currentVersion: AppInfo.version,
);
