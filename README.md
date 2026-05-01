# PDF Tech

[![CI](https://github.com/gitubpatrice/PDF-TECH/actions/workflows/ci.yml/badge.svg)](https://github.com/gitubpatrice/PDF-TECH/actions/workflows/ci.yml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Latest Release](https://img.shields.io/github/v/release/gitubpatrice/PDF-TECH)](https://github.com/gitubpatrice/PDF-TECH/releases/latest)
[![Flutter](https://img.shields.io/badge/Flutter-stable-02569B?logo=flutter)](https://flutter.dev)

**L'app PDF complète qui ne traque pas vos documents.**

Application Android Flutter pour lire, créer, fusionner, signer, protéger et OCR vos documents PDF — entièrement sur votre téléphone. Aucun cloud, aucun tracker, aucun compte.

## Fonctionnalités

- Lecteur PDF rapide avec recherche, zoom, table des matières
- Fusionner / diviser / extraire des pages
- Compresser un PDF
- Protéger / déprotéger (AES-256, mot de passe)
- Pivoter / réorganiser / supprimer des pages
- Filigrane texte, signature manuscrite
- Images → PDF, OCR (ML Kit local), modifier & annoter
- Création de PDF riches (titres, listes, code, images, liens)
- Picker intelligent : raccourcis colorés + tous les dossiers
- Cloud direct kDrive / Google Drive / Proton Drive

## Téléchargement

[GitHub Releases](https://github.com/gitubpatrice/PDF-TECH/releases/latest) — APK signé, distribué hors Play Store.

Site officiel : [files-tech.com/pdf-tech](https://www.files-tech.com/pdf-tech.php)

## Confidentialité

100 % local. Aucune télémétrie, aucune collecte de données, aucun partage. Code source ouvert sous licence Apache 2.0 — auditable.

Voir [PRIVACY.fr.md](PRIVACY.fr.md) et [TERMS.fr.md](TERMS.fr.md).

## Build local

```bash
git clone https://github.com/gitubpatrice/PDF-TECH.git pdf_tech
git clone https://github.com/gitubpatrice/files_tech_core.git
cd pdf_tech
flutter pub get
flutter build apk --release
```

Nécessite Flutter stable + Android SDK + JDK 17.

## Licence

Apache License 2.0 — voir [LICENSE](LICENSE) et [NOTICE](NOTICE).
