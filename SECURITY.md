# Politique de sécurité — PDF Tech

## Historique des durcissements

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
