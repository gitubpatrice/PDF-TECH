import 'secure_update_service.dart';

import '../core/app_info.dart';

/// Instance partagee de [SecureUpdateService] configuree pour PDF Tech.
///
/// La version est lue depuis [AppInfo.version] (source unique de verite —
/// alignee sur `pubspec.yaml`). Evite le drift constate en audit
/// incoherences v1.11.2 ou la version etait dupliquee a 3 endroits
/// (pubspec, about_screen, app_update).
const appUpdateService = SecureUpdateService(
  owner: 'gitubpatrice',
  repo: 'PDF-TECH',
  currentVersion: AppInfo.version,
);
