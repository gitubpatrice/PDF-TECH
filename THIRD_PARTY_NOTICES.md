# Third-Party Notices — PDF Tech

This product includes the following open-source dependencies. Each component remains subject to its own license. License notices must be retained in compliance with the obligations of the respective authors and publishers.

The main source code of the project is placed under [Apache License 2.0](./LICENSE).

## Direct Flutter / Dart dependencies

Versions are those declared in `pubspec.yaml` at the time of writing. Run `flutter pub deps` for the exact resolved tree.

| # | Package                            | Version  | License (typical)        | Repository                                                            |
| - | ---------------------------------- | -------- | ------------------------ | --------------------------------------------------------------------- |
| 1 | `cupertino_icons`                  | ^1.0.8   | MIT                      | https://github.com/flutter/packages                                   |
| 2 | `syncfusion_flutter_pdfviewer`     | ^27.1.48 | Syncfusion EULA          | https://pub.dev/packages/syncfusion_flutter_pdfviewer                 |
| 3 | `syncfusion_flutter_pdf`           | ^27.1.48 | Syncfusion EULA          | https://pub.dev/packages/syncfusion_flutter_pdf                       |
| 4 | `syncfusion_flutter_signaturepad`  | ^27.0.0  | Syncfusion EULA          | https://pub.dev/packages/syncfusion_flutter_signaturepad              |
| 5 | `file_picker`                      | ^8.1.2   | MIT                      | https://github.com/miguelpruivo/flutter_file_picker                   |
| 6 | `path_provider`                    | ^2.1.4   | BSD-3-Clause             | https://github.com/flutter/packages                                   |
| 7 | `permission_handler`               | ^11.3.1  | MIT                      | https://github.com/baseflow/flutter-permission-handler                |
| 8 | `share_plus`                       | ^10.0.3  | BSD-3-Clause             | https://github.com/fluttercommunity/plus_plugins                      |
| 9 | `shared_preferences`               | ^2.3.2   | BSD-3-Clause             | https://github.com/flutter/packages                                   |
| 10 | `google_sign_in`                  | ^6.2.1   | BSD-3-Clause             | https://github.com/flutter/packages                                   |
| 11 | `googleapis`                      | ^13.2.0  | BSD-3-Clause             | https://github.com/google/googleapis.dart                             |
| 12 | `http`                            | ^1.2.0   | BSD-3-Clause             | https://github.com/dart-lang/http                                     |
| 13 | `intl`                            | ^0.19.0  | BSD-3-Clause             | https://github.com/dart-lang/i18n                                     |
| 14 | `pdfx`                            | ^2.6.0   | MIT                      | https://github.com/ScerIO/packages.flutter                            |
| 15 | `google_mlkit_text_recognition`   | ^0.13.0  | MIT                      | https://github.com/flutter-ml/google_ml_kit_flutter                   |

## Dev dependencies

| # | Package                  | Version  | License        |
| - | ------------------------ | -------- | -------------- |
| 1 | `flutter_lints`          | ^6.0.0   | BSD-3-Clause   |
| 2 | `flutter_launcher_icons` | ^0.13.1  | MIT            |
| 3 | `image`                  | ^4.1.3   | MIT            |

## Native ML model

- **Google ML Kit Text Recognition (Latin script)** — used locally for OCR. The model is bundled with the application and is not transmitted externally. Subject to Google ML Kit Terms of Service.

## Notices

A copy of the Apache License 2.0 is provided in the [`LICENSE`](./LICENSE) file. The [`NOTICE`](./NOTICE) file contains attribution notices for this project.

If a third-party package requires a specific notice in your distribution, please refer to that package's repository and bundled `LICENSE` / `NOTICE` files. The Flutter build process embeds these notices in the final APK; they can be inspected via `flutter packages pub deps` and the per-package metadata.
