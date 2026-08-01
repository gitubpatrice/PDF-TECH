# Plan d'audit PDF Tech v1.13.4+ — Objectif 95/100 (OWASP Mobile 2024 / MASVS v2)

**Date** : 2026-08-01  
**Application** : PDF Tech (Flutter + Android natif)  
**Scope** : `J:/applications/pdf_tech` + dépendance path `J:/applications/files_tech_core`  
**Méthodologie** : OWASP Mobile Top 10 2024 + MASVS v2, revue de code source statique  
**Note** : cet audit ne porte que sur le code source. Aucun APK final n'a été décompilé / instrumenté ; les manifests fusionnés des plugins n'ont pas été audités dynamiquement.

---

## 1. Synthèse des scores

| État | Score estimé | Commentaire |
|---|---|---|
| Audit v1 (état AVANT corrections) | **66/100** | Rapports `audit-final.md`, `owasp-report.md`, `code-audit-report.md` |
| État ACTUEL après les corrections déjà appliquées | **~84/100** | Secrets de signature, fallback debug, v1 signing, minSdk, debugPrint, messages Drive corrigés |
| Objectif cible | **95/100** | Nécessite les 8 à 10 actions ci-dessous |
| Écart à combler | **~11 points** | Principalement M6 (sur-permission), M7 (RASP), M9 (stockage métadonnées) |

**Formule de scoring conservée** (pondération M1×2, moyenne des 10 catégories) :

```text
Actuel  ≈ (9×2 + 8 + 9 + 9 + 8 + 8 + 7 + 9 + 8 + 9) / 11 = 84/100
Cible   = (10×2 + 9 + 10 + 10 + 9 + 9 + 9 + 10 + 9 + 10) / 11 = 95/100
```

---

## 2. Top 10 points bloquants pour atteindre 95/100

| # | OWASP | Sévérité | Fichier(s) | Ligne(s) | Points de score impactés | Résumé |
|---|---|---|---|---|---|---|
| 1 | M6 | **Haute** | `android/app/src/main/AndroidManifest.xml` | 14 | M6 8→9 | `MANAGE_EXTERNAL_STORAGE` toujours déclarée. Même justifiée pour F-Droid, elle pénalise le score OWASP M6 et la conformité Play/MASVS. |
| 2 | M7 | **Moyenne** | Code natif / Dart global | — | M7 7→9 | Aucune détection root/émulateur/Frida, aucune vérification d'intégrité du binaire. Le `SECURITY.md` prétend à un avertissement RASP mais le code ne l'implémente pas. |
| 3 | M9 | **Moyenne** | `lib/features/pdf_viewer/services/last_page_service.dart`, `lib/main.dart`, `files_tech_core/lib/src/recents/recent_files_service.dart`, `files_tech_core/lib/src/update/update_service.dart` | 25, 41, 53 / 226, 273, 287 / 27, 100 / 83, 97 | M9 8→9 | Métadonnées utilisateur (noms/paths de PDF, page lue, mode thème) stockées en clair dans `SharedPreferences`. |
| 4 | M8/M6 | **Moyenne** | `android/app/src/main/kotlin/.../MainActivity.kt` | 69, 214 | M8 9→10, M6 8→9 | `Environment.getExternalStorageDirectory()` dépréciée API 29 utilisée pour `allowedRoots` et `getStorageInfo`. Maintient la dépendance à `MANAGE_EXTERNAL_STORAGE`. |
| 5 | M8/M6 | **Moyenne** | `lib/widgets/pdf_picker_screen.dart`, `lib/screens/home/home_tab.dart` | 305, 323 / 190 | M8 9→10, M6 8→9 | `getExternalStorageDirectory()` de `path_provider` utilisé pour accéder à `/sdcard/Download` et à la racine externe. |
| 6 | M5 | **Basse** | `android/app/src/main/res/xml/network_security_config.xml` | 8-14 | M5 8→9 | Pas de certificate pinning sur les endpoints GitHub de mise à jour ; domaine `googleapis.com` avec `includeSubdomains="true"` trop large. |
| 7 | M9 | **Basse** | `lib/screens/pdf_folder_screen.dart` | 234 | M9 8→9 | `debugPrint` non protégé par `kDebugMode` ; fuite de chemin utilisateur en logcat release. |
| 8 | M9 | **Basse** | `files_tech_core/lib/src/update/update_service.dart` | 141-143 | M9 8→9 | `catch (_) { return null; }` silencieux sur le check de mise à jour. Absorbe timeouts, MITM, payload inattendu sans log. |
| 9 | M2 | **Info** | `android/app/proguard-rules.pro` | 14-17, 35 | M2 8→9 | Règles `-keep` pour plugins non déclarés dans `pubspec.yaml` (`flutter_secure_storage`, `device_info_plus`, `pdfx`, `filepicker`). Alourdit la revue d'obfuscation. |
| 10 | M2/M8 | **Info** | `lib/widgets/pdf_picker_screen.dart`, `lib/screens/tools/create_pdf_screen.dart`, `lib/screens/tools/images_to_pdf_screen.dart`, `lib/screens/tools/pdf_annotate_screen.dart`, `lib/utils/saf_picker.dart` | divers | M2 8→9 | `file_picker` et `file_selector` coexistent. Deux plugins pour la même fonction SAF augmentent la surface de confiance. |
| 11 | M7 | **Moyenne** | `test/` | 1 test widget + 3 tests unitaires | M7 7→9 | Couverture de tests très faible sur les mécanismes de sécurité critiques (path traversal, validation PDF, isolation, canal natif). |

---

## 3. Findings détaillés et corrections concrètes

### 3.1 M6 — `MANAGE_EXTERNAL_STORAGE` toujours déclarée (Haute)

- **Fichier** : `android/app/src/main/AndroidManifest.xml:14`
- **Ligne** :
  ```xml
  <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE"
      tools:ignore="ScopedStorage" />
  ```
- **Impact** : permission "All files access". Même si justifiée pour un gestionnaire de PDFs hors Play Store, elle reste un privilège très élevé. Elle pénalise M6 et empêche un score > 9/10 sur cette catégorie.
- **Correction concrète** :
  1. **Option A (idéale pour 95/100)** : supprimer la permission et migrer entièrement vers SAF (`file_selector` / `ACTION_OPEN_DOCUMENT[_TREE]`) + persistance d'URI. Le code est déjà partiellement en fallback SAF.
  2. **Option B (réaliste pour F-Droid)** : la conserver mais déplacer son utilisation derrière un toggle utilisateur explicite, documenter la justification dans `PRIVACY.md` et `SECURITY.md`, et limiter le scan récursif à `Download/` + `Documents/` + dossiers médias connus.
- **Effort** : Option A = 1-2 jours ; Option B = 2-4h.

### 3.2 M7 — Absence de RASP / root detection / anti-tampering (Moyenne)

- **Fichier** : `SECURITY.md:203` (mention incorrecte d'un avertissement RASP) ; code global.
- **Impact** : pas de détection d'appareil rooté, d'émulateur, de Frida/Xposed, ni de vérification d'intégrité du binaire. Pour un score 95/100, MASVS v2 et OWASP M7 attendent au minimum une bibliothèque de détection de root (RootBeer) et/ou une vérification de signature native.
- **Correction concrète** :
  ```kotlin
  // android/app/src/main/kotlin/com/pdftech/pdf_tech/MainActivity.kt
  // Détection RootBeer basique + vérification signature
  private fun isDeviceTrustworthy(): Boolean {
      val rootBeer = RootBeer(context)
      return !rootBeer.isRooted && isValidSignature()
  }
  ```
  Et en Dart, afficher un avertissement non bloquant (important pour F-Droid : ne pas bloquer les utilisateurs rootés) mais réel.
- **Effort** : 1/2 - 1 jour.

### 3.3 M9 — Métadonnées utilisateur en clair dans `SharedPreferences` (Moyenne)

- **Fichiers / lignes** :
  - `lib/features/pdf_viewer/services/last_page_service.dart:25,41,53` (`last_page_*`, `last_page_lru_v1`)
  - `lib/main.dart:226,273,287` (`first_launch_done`, `theme_mode`)
  - `files_tech_core/lib/src/recents/recent_files_service.dart:27,100` (`recent_files` : paths + noms + tailles + dates)
  - `files_tech_core/lib/src/update/update_service.dart:83,97` (`update_last_check_ms_*`)
- **Impact** : sur un appareil rooté ou un backup local, un attaquant peut lire l'historique de lecture, les noms de fichiers PDF sensibles, les dates d'accès. Ce n'est pas un secret applicatif mais une fuite de métadonnées.
- **Correction concrète** :
  1. Migrer les données sensibles vers `flutter_secure_storage` ou `encrypted_shared_preferences` avec une clé gérée par Android Keystore.
  2. Ou chiffrer la liste JSON localement avant `prefs.setStringList(key, encrypted)` avec une clé dérivée de `AndroidKeyStore` / `Keychain`.
  3. Conserver `theme_mode` et `first_launch_done` en clair (non sensibles).
- **Effort** : 1 jour.

### 3.4 M8/M6 — API de stockage externe dépréciées (Moyenne)

- **Fichier natif** : `android/app/src/main/kotlin/com/pdftech/pdf_tech/MainActivity.kt:69,214`
- **Lignes** :
  ```kotlin
  Environment.getExternalStorageDirectory().canonicalFile
  val stat = StatFs(Environment.getExternalStorageDirectory().path)
  ```
- **Fichiers Dart** : `lib/widgets/pdf_picker_screen.dart:305,323` et `lib/screens/home/home_tab.dart:190` (`getExternalStorageDirectory()`)
- **Impact** : API dépréciées depuis API 29. Renforcent la dépendance à `MANAGE_EXTERNAL_STORAGE`. Sur Android 10+, elles peuvent retourner des paths inexploitables sans la permission.
- **Correction concrète** :
  - Pour `getStorageInfo` : utiliser `StorageManager` ou `StorageStatsManager` avec `getExternalStorageDirs()` / `getUuidForPath()`.
  - Pour le scan : passer à SAF (`file_selector` + `getDirectoryPath()`) ou `getExternalFilesDirectory()`.
  - Retirer `Environment.getExternalStorageDirectory()` de `allowedRoots` ; restreindre à `filesDir`, `cacheDir`, `getExternalFilesDir(null)` et aux URI SAF choisies par l'utilisateur.
- **Effort** : 1 jour.

### 3.5 M5 — Certificate pinning et domaines larges (Basse)

- **Fichier** : `android/app/src/main/res/xml/network_security_config.xml:8-14`
- **Code actuel** :
  ```xml
  <domain-config>
      <domain includeSubdomains="false">api.github.com</domain>
      <domain includeSubdomains="true">googleapis.com</domain>
      <trust-anchors>
          <certificates src="system" />
      </trust-anchors>
  </domain-config>
  ```
- **Impact** : aucun pinning ; `googleapis.com` avec sous-domaines est très large. Cela n'est pas exploitable de manière triviale mais c'est un point de défense en profondeur manquant.
- **Correction concrète** :
  ```xml
  <domain-config>
      <domain includeSubdomains="false">api.github.com</domain>
      <domain includeSubdomains="true">objects.githubusercontent.com</domain>
      <pin-set expiration="2027-06-01">
          <pin digest="SHA-256">HASH_PRIMARY</pin>
          <pin digest="SHA-256">HASH_BACKUP</pin>
      </pin-set>
  </domain-config>
  ```
  Pour Google Drive, privilégier le SDK officiel (`google_sign_in` + `googleapis`) qui gère ses propres certificats ; ne pas ajouter `googleapis.com` large dans le manifest.
- **Effort** : 2-4h (maintenance des hashes à renouveler).

### 3.6 M9 — `debugPrint` non protégé dans `pdf_folder_screen` (Basse)

- **Fichier** : `lib/screens/pdf_folder_screen.dart:234`
- **Code actuel** :
  ```dart
  debugPrint('[PdfFolderScreen] tapped: ${f.path}');
  ```
- **Impact** : fuite du chemin absolu du fichier dans logcat en release.
- **Correction concrète** :
  ```dart
  if (kDebugMode) debugPrint('[PdfFolderScreen] tapped: ${f.path}');
  ```
- **Effort** : < 5 min.

### 3.7 M9 — Catch silencieux sur `UpdateService` (Basse)

- **Fichier** : `files_tech_core/lib/src/update/update_service.dart:141-143`
- **Code actuel** :
  ```dart
  } catch (_) {
    return null;
  }
  ```
- **Impact** : timeouts, MITM, compte GitHub compromis publiant un payload inattendu sont absorbés sans trace.
- **Correction concrète** : ajouter un log conditionnel et/ou un callback `onError` optionnel :
  ```dart
  } catch (e, st) {
    if (kDebugMode) debugPrint('[UpdateService] check failed: $e\n$st');
    return null;
  }
  ```
  (Cela ne change pas le comportement par défaut.)
- **Effort** : < 30 min.

### 3.8 M2 — Règles ProGuard fantômes (Info)

- **Fichier** : `android/app/proguard-rules.pro:14-17, 35`
- **Lignes concernées** :
  ```proguard
  -keep class com.it_nomads.fluttersecurestorage.** { *; }
  -keep class com.mr.flutter.plugin.filepicker.** { *; }
  -keep class dev.fluttercommunity.plus.device_info.** { *; }
  -keep class io.scer.pdfx.** { *; }
  ```
- **Impact** : ces plugins ne sont pas dans `pubspec.yaml`. Ils alourdissent la revue de sécurité et peuvent induire en erreur sur la surface de confiance réelle.
- **Correction concrète** : supprimer les règles obsolètes ; ne garder que les plugins actuellement utilisés (`syncfusion`, `google_sign_in`, `googleapis`, `share_plus`, `file_picker`, `mlkit`, `flutter`).
- **Effort** : < 30 min.

### 3.9 M2/M8 — Duplication `file_picker` + `file_selector` (Info)

- **Fichiers** :
  - `file_selector` : `lib/utils/saf_picker.dart`
  - `file_picker` : `lib/widgets/pdf_picker_screen.dart`, `lib/screens/tools/create_pdf_screen.dart`, `lib/screens/tools/images_to_pdf_screen.dart`, `lib/screens/tools/pdf_annotate_screen.dart`
- **Impact** : deux plugins pour la même fonctionnalité de sélection de fichiers. Double surface de confiance, double maintenance, double risque de divergence de comportement.
- **Correction concrète** : standardiser sur `file_selector` (plus proche de SAF natif) ou `file_picker` (plus riche). Migrer les 4 call sites restants vers le plugin choisi.
- **Effort** : 1/2 jour.

### 3.10 M7 — Couverture de tests insuffisante (Moyenne)

- **Fichiers** : `test/widget_test.dart`, `test/pdf_tools_service_test.dart`, `test/image_bounds_test.dart`, `test/audit_v1_12_5_test.dart`
- **Impact** : seuls 4 tests existent. Aucun test sur les mécanismes de sécurité critiques : `MainActivity.isAllowedPath`, path traversal Drive, validation des intents entrants, permissions, canal `sendToPackage`, chiffrement des préférences, etc.
- **Correction concrète** : ajouter au minimum :
  - `test/security/main_activity_path_test.dart` (mock channel ou instrumented test) pour `isAllowedPath` ;
  - `test/security/recent_files_test.dart` pour la sanitisation ;
  - `test/security/google_drive_sanitize_test.dart` pour les noms avec `/` et `..` ;
  - `test/security/update_service_test.dart` pour la whitelist d'hôtes et la regex semver ;
  - tests instrumentés pour `MANAGE_EXTERNAL_STORAGE` / SAF fallback.
- **Effort** : 1 jour.

### 3.11 Autres points mineurs observés

- **`showErrorSnack(context, e)`** : dans `lib/features/pdf_viewer/pdf_viewer_screen.dart:118` et `lib/screens/tools/create_pdf_screen.dart:310`, les exceptions peuvent être affichées brutes. Bien que la plupart des exceptions soient des `PdfValidationException` avec messages contrôlés, il est préférable de mapper les exceptions inconnues vers un message générique.
- **`share_service.dart`** : `Share.shareXFiles` laisse `share_plus` gérer ses copies de cache. Vérifier que son `FileProvider` interne est bien scopé (standard) ; rien à corriger dans le code, mais à documenter.
- **Méthode `getInitialPdf` / `onNewPdf`** : le natif copie le PDF dans `cacheDir/incoming` puis expose le path. C'est correct, mais il faut s'assurer que `cacheDir` n'est pas inclus dans les backups (il est déjà couvert par `data_extraction_rules.xml` excluant `external` et `cache`).

---

## 4. Score estimé après corrections

Si les 11 actions ci-dessus sont appliquées, le score consolidé estimé est :

| Catégorie | Score actuel estimé | Score cible | Changement |
|---|---|---|---|
| M1 — Improper Credential Usage | 9/10 | 10/10 | keystore hors dépôt + build fail sans env -> parfait |
| M2 — Inadequate Supply Chain Security | 8/10 | 9/10 | ProGuard nettoyé, dépendances standardisées |
| M3 — Insecure Authentication/Authorization | 9/10 | 10/10 | OAuth scope `drive.file`, révocation OK |
| M4 — Insufficient Input/Output Validation | 9/10 | 10/10 | validation PDF, path, intents OK |
| M5 — Insecure Communication | 8/10 | 9/10 | pinning ajouté, domaines restreints |
| M6 — Inadequate Privacy Controls | 8/10 | 9/10 | MANAGE_EXTERNAL_STORAGE optionalisée / SAF |
| M7 — Insufficient Binary Protections | 7/10 | 9/10 | RASP / root detection + tests ajoutés |
| M8 — Security Misconfiguration | 9/10 | 10/10 | API dépréciées retirées, minSdk pinné, v1 off |
| M9 — Insecure Data Storage | 8/10 | 9/10 | SharedPreferences sensibles chiffrées, debugPrint corrigés |
| M10 — Insufficient Cryptography | 9/10 | 10/10 | AES-256, passwords `Random.secure()` |

```text
Score consolidé cible = (10×2 + 9 + 10 + 10 + 9 + 9 + 9 + 10 + 9 + 10) / 11 = 95/100
```

---

## 5. Plan d'action priorisé (ordre de réalisation recommandé)

| # | Action | Sévérité | Effort | Fichier(s) principal(aux) |
|---|---|---|---|---|
| 1 | Corriger le `debugPrint` non protégé dans `pdf_folder_screen.dart` | Basse | 5 min | `lib/screens/pdf_folder_screen.dart:234` |
| 2 | Ajouter `kDebugMode` log dans `UpdateService` | Basse | 30 min | `files_tech_core/lib/src/update/update_service.dart:141` |
| 3 | Nettoyer les règles ProGuard fantômes | Info | 30 min | `android/app/proguard-rules.pro` |
| 4 | Standardiser `file_picker` vs `file_selector` | Info | 1/2 jour | `pubspec.yaml`, `lib/widgets/pdf_picker_screen.dart`, `lib/screens/tools/*` |
| 5 | Ajouter certificate pinning et restreindre `googleapis.com` | Basse | 2-4h | `android/app/src/main/res/xml/network_security_config.xml` |
| 6 | Chiffrer les préférences sensibles (récents, last page) | Moyenne | 1 jour | `lib/features/pdf_viewer/services/last_page_service.dart`, `files_tech_core/lib/src/recents/recent_files_service.dart` |
| 7 | Migrer `Environment.getExternalStorageDirectory()` et `getExternalStorageDirectory()` | Moyenne | 1 jour | `MainActivity.kt`, `lib/widgets/pdf_picker_screen.dart`, `lib/screens/home/home_tab.dart` |
| 8 | Optionaliser ou supprimer `MANAGE_EXTERNAL_STORAGE` | Haute | 1-2 jours | `AndroidManifest.xml`, `StoragePermissionService`, `PdfPickerScreen`, `HomeTab` |
| 9 | Ajouter root detection / RASP basique | Moyenne | 1 jour | `MainActivity.kt`, `SECURITY.md`, code Dart |
| 10 | Étoffer la couverture de tests sécurité | Moyenne | 1 jour | `test/security/` |

---

## 6. Conclusion

PDF Tech est déjà **bien durcie** : secrets de signature hors dépôt, build release qui échoue sans credentials, v1 signing désactivé, `minSdk` pinné, logs protégés, messages d'erreur génériques, FileProvider scopé, validation PDF, anti path-traversal, AES-256, `FLAG_SECURE`, etc. Ces corrections méritent un gain de **~18 points** par rapport au précédent audit (66 -> 84).

Pour franchir la barre des **95/100**, il reste à traiter les **aspects de confiance runtime et de stockage** :
- retirer/optionaliser la sur-permission `MANAGE_EXTERNAL_STORAGE` ;
- migrer les API de stockage dépréciées ;
- chiffrer les métadonnées sensibles ;
- ajouter une détection root/anti-tampering ;
- compléter le pinning TLS et la couverture de tests.

Aucun finding **critique** n'a été identifié dans l'état actuel du code source. Les points restants sont des **durcissements** cohérents avec un objectif de distribution de confiance (F-Droid/GitHub Releases).

---

*Rapport généré automatiquement par analyse statique du code source. Aucun fichier de code n'a été modifié.*
