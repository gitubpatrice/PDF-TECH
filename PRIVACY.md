# Privacy Policy — PDF Tech

**Document version** : 7 May 2026
**App** : PDF Tech
**Website** : https://www.files-tech.com
**Contact** : contact@files-tech.com
**Source code** : https://github.com/gitubpatrice/PDF-TECH
**Code license** : Apache License 2.0

---

## 1. Purpose

This Privacy Policy explains how the **PDF Tech** application handles user data, files and permissions. It may be displayed inside the application, in the GitHub repository, and linked from a Google Play listing or from the official website.

## 2. User-friendly summary

- ✅ **No advertising** in the application.
- ✅ **No tracker**, audience measurement, behavioural analytics or profiling.
- ✅ **No account** specific to the application.
- ✅ Files opened, created or processed **stay on the user's device**.
- ✅ Files or contents are transmitted **only after an explicit user action** (sharing, export) or when the user voluntarily uses a third-party service.

**Core principle** : PDF Tech processes PDF documents primarily locally on the device, under the user's control (read, annotate, create, share, sign, OCR).

## 3. Data controller / developer

- **Developer** : Files Tech / Patrice
- **Website** : https://www.files-tech.com
- **Privacy contact** : contact@files-tech.com
- **Source repository** : https://github.com/gitubpatrice/PDF-TECH
- **Source code license** : Apache License 2.0

## 4. Data accessed or processed

| Data type                       | Use                                                                                              | Processing location                |
| ------------------------------- | ------------------------------------------------------------------------------------------------ | ---------------------------------- |
| PDF documents and selected files | Reading, display, annotation, creation, signature, OCR, export or sharing on user request. | Mainly local on the device.       |
| Network technical data           | Functions triggered by the user: sharing, email, update check via GitHub Releases.              | Relevant third-party service.     |
| Local preferences               | Storing settings, recent items, display preferences.                                              | Local storage on the device.       |

## 5. No advertising, no trackers, no analytics

The developer declares that the application:

- contains no advertising;
- contains no advertising tracker;
- contains no audience measurement;
- contains no behavioural analytics;
- contains no profiling system.

The application **does not sell** user data.

## 6. Sharing and data transmission

Files or contents are transmitted to a third party only in the following cases:

- explicit user action (Share button, export);
- voluntary use of a third-party service (Android share sheet, email, etc.);
- applicable legal obligation.

Android share, email or external app functions follow the user's own choices and the rules of those services.

### App-specific notes

- Signature or annotation features ease document work but the user must verify the legal scope of signed documents.
- Update check queries the public GitHub Releases API (HTTPS, no authentication, no cookie). No user identifier is transmitted.
- Google Drive integration is **optional** and triggered only by the user. It uses Google Sign-In (OAuth 2.0). The OAuth token is stored locally on the device and used to upload, download or share PDFs that the user explicitly designates. Revocation is handled from the user's Google account.

## 7. Retention and deletion

Files remain under the user's control, on the device or in the locations chosen by the user. Deletion of a file, of preferences or of the application depends on Android features and the chosen storage location. Since no app-specific account is created, there is no user account to delete inside the application.

## 8. Security

The application aims to limit processing to what is necessary and to favour local processing. The user should:

- protect their device with a suitable lock screen;
- keep Android up to date;
- keep useful backups;
- avoid opening files from untrusted sources.

See [SECURITY.md](./SECURITY.md) for the vulnerability disclosure policy.

## 9. Android permissions

| Permission / access                         | Reason                                                                                                |
| ------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `INTERNET`                                  | Update check via the public GitHub Releases API. Also used if the user opts in to Google Drive (optional). No other server-side network use. |
| `MANAGE_EXTERNAL_STORAGE`                   | Allow the user to browse and open PDFs **anywhere on the device** — including locations that are outside the app sandbox and outside the Storage Access Framework's per-file scope: `Download/`, `Documents/`, WhatsApp / Telegram document folders, and the global "Find all my PDFs" recursive scan. |
| ML Kit Latin text recognition (bundled)     | Run OCR on PDF pages from files chosen by the user. Local ML Kit model (no external transmission).   |

`READ_MEDIA_IMAGES` is **not** requested. Image selection for the Images → PDF feature uses the Storage Access Framework (`file_picker`), which grants access via a temporary URI without a runtime permission.

### Why MANAGE_EXTERNAL_STORAGE rather than the Storage Access Framework alone

The Storage Access Framework (SAF, exposed via `file_picker`) only grants access to **one file or one tree** at a time, after an explicit user pick. PDF Tech also needs to:

- list PDFs in `Download/`, `Documents/`, `Android/media/com.whatsapp/...` and `Android/media/org.telegram.messenger/...` **without** forcing the user to navigate the SAF picker each time;
- run a **recursive scan** of the device storage ("Find all my PDFs") to surface PDFs the user may have forgotten where they saved.

These workflows are not technically possible with SAF alone. `MANAGE_EXTERNAL_STORAGE` is therefore requested with an explanatory dialog. The permission is **only used locally to list and read PDF files** — no file is uploaded, no path is sent off-device. The user can revoke it at any time from Android Settings, and the app continues to work via the SAF picker fallback (`Choisir…` tile / FAB).

## 10. Children

The application is not specifically targeted at children and contains no declared mechanism for behavioural advertising or profiling.

## 11. Changes

This policy may be updated as the application evolves. The date at the top of the document indicates the current version. Substantive changes are made available via the GitHub repository.

## 12. Contact

For any question regarding privacy, security or data:

📧 **contact@files-tech.com**
