# PDF Tech

[![CI](https://github.com/gitubpatrice/PDF-TECH/actions/workflows/ci.yml/badge.svg)](https://github.com/gitubpatrice/PDF-TECH/actions/workflows/ci.yml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Latest Release](https://img.shields.io/github/v/release/gitubpatrice/PDF-TECH)](https://github.com/gitubpatrice/PDF-TECH/releases/latest)
[![Flutter](https://img.shields.io/badge/Flutter-stable-02569B?logo=flutter)](https://flutter.dev)

---

## Français

**Application PDF tout-en-un Android — 100 % locale, sans tracker, sans compte obligatoire.**

PDF Tech regroupe 23 outils PDF dans une seule application Flutter Android. Tous les traitements s'effectuent sur l'appareil. Aucune donnée n'est transmise à un serveur, sauf action explicite de l'utilisateur (partage, export Google Drive optionnel, vérification de mise à jour anonyme via GitHub Releases).

**Distribution** : l'application est publiée sur **GitHub Releases**. Elle n'est pas distribuée via Google Play Store.

Version actuelle : **1.13.3**.

### Fonctionnalités

23 outils intégrés :

1. Lecteur PDF (zoom, recherche, signets, table des matières, mode nuit, reprise de page)
2. Fusionner plusieurs PDFs
3. Diviser un PDF
4. Protéger par mot de passe (chiffrement AES-256)
5. Déchiffrer / supprimer un mot de passe
6. Pivoter des pages
7. Ajouter un filigrane texte
8. Créer un PDF (titres, listes, code, images, liens)
9. Compresser un PDF
10. Signature électronique manuscrite
11. Remplir un formulaire PDF
12. OCR — reconnaissance de texte avec **Tesseract** (modèles `fra` + `eng` locaux)
13. Supprimer des pages
14. Réorganiser des pages
15. Exporter les images d'un PDF
16. Modifier les métadonnées (titre, auteur, sujet, mots-clés)
17. Numéroter les pages
18. Tampon (Bates, brouillon, etc.)
19. En-tête / pied de page
20. Extraire les images d'un PDF
21. Comparer deux PDFs
22. Convertir Images → PDF
23. Annoter un PDF

### Explorateur de fichiers intégré

Depuis la version 1.13.x, le picker PDF propose un **explorateur de dossiers intégré** :

- **Mode sécurisé par défaut** : utilisation du sélecteur système Android (SAF) sans accès global au stockage.
- **Mode explorateur complet** (optionnel) : scan direct du dossier `Download` et navigation dans le stockage externe via une grille de dossiers colorés. Nécessite l'activation explicite dans les paramètres et la permission `MANAGE_EXTERNAL_STORAGE`.

### Sécurité

- **Chiffrement des métadonnées** : fichiers récents, dernières pages lues, cache de mise à jour et préférences stockés dans `FlutterSecureStorage` (Keychain/Keystore).
- **Permission d'accès stockage optionnelle** : `MANAGE_EXTERNAL_STORAGE` n'est demandée que si l'utilisateur active explicitement le « mode explorateur complet » dans les paramètres. Par défaut, l'application utilise le sélecteur système Android (SAF).
- **Anti path-traversal** : `canonicalFile` + liste blanche `allowedRoots` côté Kotlin pour tout accès `file://`.
- **Magic-bytes + cap 200 Mo** : validation du type réel des fichiers ouverts (sniffing en-tête, pas seulement extension).
- **FileProvider restrictif** : `file_paths.xml` limité aux dossiers nécessaires, `grantUriPermissions` ciblé.
- **Build release durci** : keystore dédié via variables d'environnement `PDFTECH_*`, signing v2/v3 (v1 désactivée), R8 + shrinking + obfuscation.
- **Network Security Config strict** : `usesCleartextTraffic="false"`, NSC ne whiteliste que les domaines GitHub et Google nécessaires.
- **Pas de backup ADB** : `allowBackup="false"`, `dataExtractionRules` vide.
- **RASP léger** : avertissement à l'utilisateur si un système rooté est détecté (détection native Kotlin, non bloquante).

Politique de signalement : voir [SECURITY.md](./SECURITY.md). Vérification SHA-256 publiée pour chaque APK release.

### Permissions Android

| Permission | Justification |
| --- | --- |
| `INTERNET` | Vérification de mise à jour via API GitHub Releases publique (HTTPS, anonyme). Activée également si l'utilisateur choisit Google Drive (optionnel). |
| `MANAGE_EXTERNAL_STORAGE` (optionnelle) | Permettre à l'utilisateur de parcourir et d'ouvrir des PDFs hors sandbox de l'app (Téléchargements, Documents, WhatsApp Documents, etc.). **Désactivée par défaut** : le picker utilise le SAF Android. L'accès complet s'active explicitement dans les paramètres. |

`READ_MEDIA_IMAGES` n'est **pas** demandée : la sélection d'images (outil Images → PDF) passe par le SAF / `file_picker` qui octroie l'accès via URI éphémère.

### Téléchargement

[GitHub Releases — latest](https://github.com/gitubpatrice/PDF-TECH/releases/latest) — APK signé.

Site officiel : [files-tech.com/pdf-tech](https://www.files-tech.com/pdf-tech.php)

### Confidentialité

100 % local. Aucune télémétrie, aucune collecte de données, aucun partage. Code source ouvert sous Apache 2.0 — auditable.

Voir [PRIVACY.md](PRIVACY.md) (EN) / [PRIVACY.fr.md](PRIVACY.fr.md) (FR) et [TERMS.md](TERMS.md) / [TERMS.fr.md](TERMS.fr.md) (FR).

### Build local

Prérequis : Flutter stable, Android SDK, JDK 17.

```bash
git clone https://github.com/gitubpatrice/files_tech_core.git
git clone https://github.com/gitubpatrice/PDF-TECH.git pdf_tech
cd pdf_tech
flutter pub get
flutter build apk --debug
```

Pour produire un APK release signé, définir les variables d'environnement de signature (le fichier `android/key.properties` n'est plus utilisé et ne doit jamais être versionné) :

```bash
export PDFTECH_KEY_ALIAS="..."
export PDFTECH_KEY_PASSWORD="..."
export PDFTECH_STORE_FILE="/chemin/absolu/vers/keystore.jks"
export PDFTECH_STORE_PASSWORD="..."
flutter build apk --release
```

Sans ces variables, `flutter build apk --release` échoue explicitement pour éviter qu'un APK debug ne soit livré par erreur.

---

## English

**All-in-one Android PDF app — 100 % local, no tracker, no mandatory account.**

PDF Tech bundles 23 PDF tools into a single Flutter Android app. All processing happens on the device. No data is sent to any server unless the user explicitly chooses to (share, optional Google Drive export, anonymous update check via GitHub Releases).

**Distribution** : the app is published on **GitHub Releases**. It is not distributed through the Google Play Store.

Current version : **1.13.3**.

### Features

23 built-in tools:

1. PDF reader (zoom, search, bookmarks, table of contents, night mode, page resume)
2. Merge multiple PDFs
3. Split a PDF
4. Password protect (AES-256 encryption)
5. Decrypt / remove a password
6. Rotate pages
7. Add text watermark
8. Create a PDF (headings, lists, code, images, links)
9. Compress a PDF
10. Handwritten electronic signature
11. Fill PDF forms
12. OCR — text recognition with **Tesseract** (local `fra` + `eng` models)
13. Delete pages
14. Reorder pages
15. Export images from a PDF
16. Edit metadata (title, author, subject, keywords)
17. Number pages
18. Stamp (Bates, draft, etc.)
19. Header / footer
20. Extract images from a PDF
21. Compare two PDFs
22. Convert Images → PDF
23. Annotate a PDF

### Built-in file browser

From version 1.13.x, the PDF picker provides a **built-in folder browser**:

- **Secure default mode** : uses the Android system picker (SAF) without global storage access.
- **Full browser mode** (optional) : direct scan of the `Download` folder and browsing of external storage with a colored folder grid. Requires explicit activation in settings and the `MANAGE_EXTERNAL_STORAGE` permission.

### Security

- **Encrypted metadata** : recent files, last read pages, update cache and preferences are stored in `FlutterSecureStorage` (Keychain/Keystore).
- **Optional storage permission** : `MANAGE_EXTERNAL_STORAGE` is only requested if the user explicitly enables the "full file browser mode" in settings. By default, the app uses the Android system picker (SAF).
- **Anti path-traversal** : `canonicalFile` + `allowedRoots` whitelist on the Kotlin side for every `file://` access.
- **Magic-bytes + 200 MB cap** : real file-type validation (header sniffing, not just extension).
- **Restrictive FileProvider** : `file_paths.xml` limited to required folders, targeted `grantUriPermissions`.
- **Hardened release build** : dedicated keystore via `PDFTECH_*` environment variables, signing v2/v3 (v1 disabled), R8 + shrinking + obfuscation.
- **Strict Network Security Config** : `usesCleartextTraffic="false"`, NSC only whitelists required GitHub and Google domains.
- **No ADB backup** : `allowBackup="false"`, empty `dataExtractionRules`.
- **Light RASP** : warning shown if a rooted system is detected (native Kotlin detection, non-blocking).

Disclosure policy: see [SECURITY.md](./SECURITY.md). SHA-256 checksum is published for every release APK.

### Android permissions

| Permission | Justification |
| --- | --- |
| `INTERNET` | Update check via public GitHub Releases API (HTTPS, anonymous). Also used if the user chooses Google Drive (optional). |
| `MANAGE_EXTERNAL_STORAGE` (optional) | Let the user browse and open PDFs outside the app sandbox (Downloads, Documents, WhatsApp Documents, etc.). **Disabled by default**: the picker uses the Android SAF. Full access is explicitly enabled in settings. |

`READ_MEDIA_IMAGES` is **not requested**: image selection (Images → PDF tool) uses SAF / `file_picker` which grants access through a temporary URI.

### Download

[GitHub Releases — latest](https://github.com/gitubpatrice/PDF-TECH/releases/latest) — signed APK.

Official website: [files-tech.com/pdf-tech](https://www.files-tech.com/pdf-tech.php)

### Privacy

100 % local. No telemetry, no data collection, no sharing. Open-source under Apache 2.0 — auditable.

See [PRIVACY.md](PRIVACY.md) (EN) / [PRIVACY.fr.md](PRIVACY.fr.md) (FR) and [TERMS.md](TERMS.md) / [TERMS.fr.md](TERMS.fr.md) (FR).

### Local build

Requirements: Flutter stable, Android SDK, JDK 17.

```bash
git clone https://github.com/gitubpatrice/files_tech_core.git
git clone https://github.com/gitubpatrice/PDF-TECH.git pdf_tech
cd pdf_tech
flutter pub get
flutter build apk --debug
```

To produce a signed release APK, set the signing environment variables (the `android/key.properties` file is no longer used and must never be committed):

```bash
export PDFTECH_KEY_ALIAS="..."
export PDFTECH_KEY_PASSWORD="..."
export PDFTECH_STORE_FILE="/absolute/path/to/keystore.jks"
export PDFTECH_STORE_PASSWORD="..."
flutter build apk --release
```

Without these variables, `flutter build apk --release` fails explicitly to prevent a debug APK from being shipped by mistake.

---

## Licence / License

[Apache License 2.0](LICENSE) — see also [NOTICE](NOTICE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
