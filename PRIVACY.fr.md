# Politique de confidentialité — PDF Tech

**Version du document** : 7 mai 2026
**App** : PDF Tech
**Site officiel** : https://www.files-tech.com
**Contact** : contact@files-tech.com
**Code source** : https://github.com/gitubpatrice/PDF-TECH
**Licence du code** : Apache License 2.0

---

## 1. Objet

La présente Politique de confidentialité explique comment l'application **PDF Tech** traite les données, fichiers et permissions de l'utilisateur.

## 2. Résumé pour l'utilisateur

- ✅ **Aucune publicité** dans l'application.
- ✅ **Aucun traceur**, mesure d'audience, analyse comportementale ou profilage.
- ✅ **Aucun compte** propre à l'application.
- ✅ Les fichiers ouverts, créés ou traités **restent sur l'appareil**.
- ✅ Les transmissions interviennent **uniquement après une action explicite** de l'utilisateur (partage, export) ou lors de l'utilisation volontaire d'un service tiers.

**Principe général** : PDF Tech traite les documents PDF principalement localement sur l'appareil, sous le contrôle de l'utilisateur (lecture, annotation, création, partage, signature, OCR).

## 3. Responsable / développeur

- **Développeur** : Files Tech / Patrice
- **Site internet** : https://www.files-tech.com
- **Contact confidentialité** : contact@files-tech.com
- **Dépôt source** : https://github.com/gitubpatrice/PDF-TECH
- **Licence du code source** : Apache License 2.0

## 4. Données accessibles ou traitées

| Type de donnée                  | Utilisation                                                                                          | Lieu de traitement                  |
| ------------------------------- | ---------------------------------------------------------------------------------------------------- | ----------------------------------- |
| Documents PDF et fichiers sélectionnés | Lecture, affichage, annotation, création, signature, OCR, export ou partage à la demande de l'utilisateur. | Principalement local sur l'appareil. |
| Données techniques réseau       | Fonctions déclenchées par l'utilisateur : partage, email, mise à jour via GitHub Releases.           | Service tiers concerné.             |
| Préférences locales             | Conservation de réglages, éléments récents, préférences d'affichage.                                 | Stockage local sur l'appareil.      |

## 5. Absence de publicité, traceurs et analyse

Le développeur déclare que l'application :

- ne contient pas de publicité ;
- ne contient pas de traceur publicitaire ;
- ne contient pas de mesure d'audience ;
- ne contient pas d'analyse comportementale ;
- ne contient pas de système de profilage.

L'application **ne vend pas** les données de l'utilisateur.

## 6. Partage et transmission de données

Les fichiers ou contenus ne sont transmis à un tiers que dans les cas suivants :

- action explicite de l'utilisateur (bouton « Partager », export) ;
- utilisation volontaire d'un service tiers ;
- obligation légale applicable.

### Précisions

- Les fonctions de signature ou d'annotation facilitent le travail documentaire, mais l'utilisateur doit vérifier la portée juridique de ses documents signés.
- La vérification de mises à jour interroge l'API GitHub Releases publique (HTTPS, sans authentification, sans cookie). Aucun identifiant utilisateur n'est transmis.
- L'intégration Google Drive est **optionnelle** et déclenchée par l'utilisateur. Elle s'appuie sur Google Sign-In (OAuth 2.0). Le jeton OAuth est stocké localement sur l'appareil et n'est utilisé que pour les opérations d'upload, de téléchargement ou de partage demandées par l'utilisateur. La révocation s'effectue depuis le compte Google de l'utilisateur.

## 7. Conservation et suppression

Les fichiers restent sous le contrôle de l'utilisateur. Aucun compte propre à l'application n'étant créé, il n'existe pas de compte à supprimer dans l'application.

## 8. Sécurité

L'application limite le traitement au nécessaire et privilégie le traitement local. L'utilisateur doit protéger son appareil, maintenir Android à jour, conserver des sauvegardes et éviter les fichiers de sources non fiables.

Voir [SECURITY.md](./SECURITY.md) pour la politique de signalement.

## 9. Permissions Android

| Permission / accès                          | Raison                                                                                              |
| ------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `INTERNET`                                  | Vérification de mises à jour via l'API GitHub Releases publique. Également utilisée si l'utilisateur active Google Drive (optionnel). Pas d'autre usage réseau. |
| `MANAGE_EXTERNAL_STORAGE`                   | Permettre à l'utilisateur de parcourir et ouvrir des PDFs (Téléchargements, Documents, etc.) hors du sandbox de l'app. |
| ML Kit Latin (groupé)                       | OCR sur les pages PDF, à partir de fichiers choisis par l'utilisateur. Modèle local.                |

`READ_MEDIA_IMAGES` n'est **pas** demandée. La sélection d'images (outil Images → PDF) passe par le Storage Access Framework (`file_picker`) qui octroie l'accès via une URI éphémère, sans permission runtime.

## 10. Enfants

L'application n'est pas spécifiquement destinée aux enfants et ne contient pas de mécanisme de publicité comportementale ou de profilage.

## 11. Modifications

Cette politique peut être mise à jour lors de l'évolution de l'application. La date en tête indique la version en vigueur.

## 12. Contact

📧 **contact@files-tech.com**
