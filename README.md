# PDF Tech

[![CI](https://github.com/gitubpatrice/PDF-TECH/actions/workflows/ci.yml/badge.svg)](https://github.com/gitubpatrice/PDF-TECH/actions/workflows/ci.yml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Latest Release](https://img.shields.io/github/v/release/gitubpatrice/PDF-TECH)](https://github.com/gitubpatrice/PDF-TECH/releases/latest)
[![Flutter](https://img.shields.io/badge/Flutter-stable-02569B?logo=flutter)](https://flutter.dev)

**Application PDF tout-en-un Android — 100 % locale, sans tracker, sans compte.**

PDF Tech regroupe 23 outils PDF dans une seule application Flutter Android. Tous les traitements s'effectuent sur l'appareil. Aucune donnée n'est transmise à un serveur, sauf action explicite de l'utilisateur (partage, export Google Drive optionnel, vérification de mise à jour anonyme).

Version actuelle : **1.9.2**.

## Fonctionnalités

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
12. OCR — reconnaissance de texte (ML Kit Latin, modèle local)
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

## Sécurité

- **Anti path-traversal** : `canonicalFile` + liste blanche `allowedRoots` côté Kotlin pour tout accès `file://`.
- **Magic-bytes + cap 200 Mo** : validation du type réel des fichiers ouverts (sniffing en-tête, pas seulement extension).
- **FileProvider restrictif** : `file_paths.xml` limité aux dossiers nécessaires, `grantUriPermissions` ciblé.
- **Build release durci** : keystore dédié via `key.properties`, signing v2/v3, R8 + shrinking + obfuscation.
- **Network Security Config strict** : `usesCleartextTraffic="false"`, NSC ne whiteliste que les domaines GitHub et Google nécessaires.
- **Pas de backup ADB** : `allowBackup="false"`, `dataExtractionRules` vide.
- **RASP léger** : avertissement à l'utilisateur si root / debug actif.

Politique de signalement : voir [SECURITY.md](./SECURITY.md). Vérification SHA-256 publiée pour chaque APK release.

## Permissions Android

| Permission | Justification |
| --- | --- |
| `INTERNET` | Vérification de mise à jour via API GitHub Releases publique (HTTPS, anonyme). Activée également si l'utilisateur choisit Google Drive (optionnel). |
| `MANAGE_EXTERNAL_STORAGE` | Permettre à l'utilisateur de parcourir et d'ouvrir des PDFs hors sandbox de l'app (Téléchargements, Documents, WhatsApp Documents, etc.). Sans cette permission, le Play Store de fichiers PDF est limité au scoped storage. |

`READ_MEDIA_IMAGES` n'est **pas** demandée : la sélection d'images (outil Images → PDF) passe par le SAF / `file_picker` qui octroie l'accès via URI éphémère.

## Téléchargement

[GitHub Releases — latest](https://github.com/gitubpatrice/PDF-TECH/releases/latest) — APK signé, distribué hors Play Store.

Site officiel : [files-tech.com/pdf-tech](https://www.files-tech.com/pdf-tech.php)

## Confidentialité

100 % local. Aucune télémétrie, aucune collecte de données, aucun partage. Code source ouvert sous Apache 2.0 — auditable.

Voir [PRIVACY.md](PRIVACY.md) (EN) / [PRIVACY.fr.md](PRIVACY.fr.md) (FR) et [TERMS.md](TERMS.md) / [TERMS.fr.md](TERMS.fr.md).

## Build local

Prérequis : Flutter stable, Android SDK, JDK 17.

```bash
git clone https://github.com/gitubpatrice/files_tech_core.git
git clone https://github.com/gitubpatrice/PDF-TECH.git pdf_tech
cd pdf_tech
flutter pub get
flutter build apk --release
```

Pour produire un APK signé release, créer `android/key.properties` :

```properties
storePassword=…
keyPassword=…
keyAlias=…
storeFile=/chemin/absolu/vers/keystore.jks
```

Sans ce fichier, `flutter build apk --release` retombe sur la signature debug (build local de test uniquement).

## Licence

[Apache License 2.0](LICENSE) — voir aussi [NOTICE](NOTICE) et [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
