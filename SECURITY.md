# Politique de sécurité — PDF Tech

## Historique des durcissements

- **v1.12.4** (2026-05-13) — Audit expert post-v1.12.3 : 24 corrections
  (F1-F3 + F5 + F10-F15 sécu / U1-U5 + U7 + U8 + U18 UX / P1.3 + P2.1 + P3.1 perf).
  Tous tests verts (6/6), `flutter analyze` 0 issue.

  **Sécurité (HIGH + MEDIUM)** :
  - **F1** — `MainActivity.kt` : retrait de `File("/storage")` de
    `allowedRoots` + blacklist explicite `/Android/data/<autre-pkg>/`.
    Avant : Dart pouvait envoyer un path forgé pointant vers les données
    d'une autre app → FileProvider partage vers app cloud (confused
    deputy). Cohérent avec RFT v2.13.1 F5.
  - **F2** — `pdf_viewer_screen` cap LRU 200 entrées sur les clés
    `last_page_*` (purge oldest au boot via index `last_page_lru_v1`).
    Avant : scanner 5000 PDFs gonflait SharedPreferences à plusieurs Mo
    jamais purgés.
  - **F3** — `sendToPackage` : whitelist Kotlin `ALLOWED_SHARE_PACKAGES`
    (kDrive / Drive / Proton uniquement) + `clipData = ClipData.newRawUri`
    pour grant strictement limité à l'URI. Avant : Dart pouvait passer
    n'importe quel pkg, le `<queries>` du manifest restait la seule
    contrainte. Aussi : catch précis `NameNotFoundException` (F11).
  - **F5** — `pdf_viewer_screen._promptPassword` : `SecureWindow.enable()`
    posé AVANT `showDialog`. Avant : 0-200 ms de saisie password
    capturables par Recents / MediaProjection (le flag n'était posé
    qu'après `Navigator.pop`). Cohérent avec Notes Tech F8 v1.0.9.

  **Sécurité (LOW)** :
  - **F10** — `signature_screen` : `ImageBounds.assertSafeBounds` avant
    `PdfBitmap` (defense-in-depth uniforme avec F5 v1.12.2).
  - **F11** — `MainActivity.sendToPackage` catch
    `PackageManager.NameNotFoundException` précis au lieu d'Exception
    large (qui avalait `SecurityException` avec message trompeur).
  - **F12** — `_saveLastPage` débouncé 500 ms + flush final en `dispose`.
    Avant : 1 `setInt` par page traversée sur scroll rapide.
  - **F13** — `compare_screen._loadPage` wrap `try/finally` autour de
    `pdfx.PdfDocument.openFile` (anti leak FD natif sur `render`/`_rawToPng`
    qui throw).
  - **F14** — Idem `reorder_pages_screen._loadThumbnails`.
  - **F15** — `home_screen._checkUpdate` `debugPrint` gardé par
    `kDebugMode` (anti leak path/URL dans logcat release).

  **UX / a11y** :
  - **U1** — `showErrorSnack` désormais rendu avec `backgroundColor:
    cs.errorContainer` + texte `cs.onErrorContainer`. Avant : snack
    erreur visuellement identique à `showInfoSnack` (problème daltonien
    + lecture rapide).
  - **U2** — Light theme : `snackBarTheme.behavior = SnackBarBehavior.floating`
    (avant : `snack_utils` mentait en light, snack non floating) +
    `cardTheme`/`inputDecorationTheme` Material 3 cohérents avec dark.
  - **U3** — Dialog destructif decrypt_screen : `autofocus: true` sur
    Annuler (safe default Enter) + `FilledButton.tonal` avec
    `cs.errorContainer/onErrorContainer` au lieu de `Colors.amber`
    hardcoded (compatible dark + daltonien).
  - **U4** — Champs mot de passe (3 sites : pdf_viewer, protect, decrypt) :
    ajout `autofillHints: const <String>[]` (anti Samsung Pass / Google
    Autofill) + `enableInteractiveSelection: !obscure` (anti
    sélection/copie quand masqué).
  - **U5** — Tooltips ajoutés sur `PopupMenuButton` du viewer (zoom) et
    home_tab (actions fichier).
  - **U7** — `ocr_screen` progression wrap `Semantics(liveRegion: true,
    value: 'Page X sur Y (Z%)')` : TalkBack annonce désormais
    l'avancement (avant : 30s+ de silence pendant OCR long).
  - **U8** — `HapticFeedback.selectionClick()` sur save annotation
    pdf_viewer (pattern AI Tech v0.9.1 U4 propagé).
  - **U18** — Renommage "Retirer" → "Retirer de la liste" sur le menu
    fichier home (l'icône `delete_outline` + label court suggérait
    suppression disque ; précise désormais que seule la liste est
    affectée).

  **Performance** :
  - **P1.3** — `try/finally` autour des 4 isolates PDF (`metadata`,
    `header_footer`, `page_numbers`, `form_fill flatten`). Avant :
    un throw sur `saveSync()` laissait `PdfDocument` non disposé →
    leak FD natif Syncfusion jusqu'au GC parent. Pattern G16 v1.12.3
    déjà appliqué à `_analyzeFields`, propagé aux 4 derniers sites.
  - **P2.1** — `home_screen` `DateFormat('dd/MM/yyyy')` hissé en
    `static final _dfDMY` (avant : alloué à chaque appel `_formatDate`,
    invoqué par chaque carte récent/favori au rebuild parent).
  - **P3.1** — `about_screen` `Image.asset` avec `cacheWidth: 240` /
    `cacheHeight: 240` (avant : PNG 1024×1024 décodé pleine résolution
    pour afficher 80 dp → ~3-4 Mo RAM permanent gaspillés).

  Aucun changement de format fichier. Compatible v1.12.0+.

- **v1.12.3** (2026-05-12) — Audit expert zéro-vuln/zéro-faille G1-G16 :
  OCR/export_images/form_fill `try/finally` (anti leak FD natif), signature
  null-guard, `ImageBounds` étendu aux écrans Annoter + Créer (anti
  image-bomb 50000×50000), cap cumulatif `extract_images` (500 Mo),
  `export_images` clamp 1..6000 + close DANS finally, `decrypt_screen`
  → `showResultSheet` (corrige régression v1.12.2 où "Partager" pointait
  vers fichier purgé), guard try/catch sur `_checkUpdate` au boot.
  Dead code retiré (`flutter_markdown`, `ImageAnnoSentinel`,
  `pdfIsolatePendingCount`). `dart analyze` 0 issue, 6/6 tests.
- **v1.12.2** (2026-05-09) — F1-F17 : SecureWindow MethodChannel câblé,
  PDFs déchiffrés routés vers `cache/decrypted/` purgé au boot + lifecycle,
  atomic write 10 sites, cap 500 Mo merge, ImageBounds (probe IHDR/SOF),
  OCR close/finally, OCR nom unique horodaté.

## Versions supportées

Seule la dernière version publiée sur GitHub Releases est activement maintenue côté sécurité.

| Version       | Supportée  |
| ------------- | ---------- |
| 1.12.x        | ✅          |
| 1.11.x        | ⚠️ best-effort |
| < 1.11.0      | ❌          |

## Signaler une vulnérabilité

Si vous découvrez une vulnérabilité de sécurité dans PDF Tech, **merci de ne PAS ouvrir d'issue publique sur GitHub**. À la place :

📧 **Envoyez un email à : contact@files-tech.com**

Indiquez dans le sujet : `[SECURITY] PDF Tech — <description courte>`.

Merci d'inclure :

- Une description claire de la vulnérabilité
- Les étapes pour la reproduire
- L'impact potentiel
- La version affectée (visible dans l'écran « À propos » de l'app)
- Si possible, une suggestion de correctif

## Délai de réponse

- Accusé de réception : sous 7 jours
- Évaluation initiale : sous 30 jours
- Correctif : selon la criticité (critique → patch sous 30 jours, majeur → version mineure suivante, mineur → backlog)

## Divulgation responsable

Merci de ne pas divulguer publiquement la vulnérabilité avant qu'un correctif ne soit publié et qu'un délai raisonnable de mise à jour ait été laissé aux utilisateurs (typiquement 30 jours après la publication du correctif).

## Vérification de l'intégrité d'un APK

Chaque release publiée sur GitHub contient un hash SHA-256 attendu pour l'APK arm64-v8a dans les notes. Avant install, vous pouvez vérifier :

```bash
sha256sum app-arm64-v8a-release.apk
```

Le résultat doit correspondre exactement à la valeur publiée. Sinon, ne pas installer l'APK.

## Périmètre

Vulnérabilités acceptées :

- Élévation de privilèges, contournement d'autorisations
- Lecture/écriture arbitraire hors du sandbox de l'app
- Path traversal, zip-slip, injections
- Crash exploitable (DoS persistant)
- Fuite de données utilisateur

Hors périmètre :

- Bugs UX sans impact sécurité
- Vulnérabilités dans des dépendances tierces déjà reportées en amont
- Attaques nécessitant un appareil rooté/compromis (l'app affiche un avertissement RASP si détecté)
- Attaques physiques sur l'appareil déverrouillé
