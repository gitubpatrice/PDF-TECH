# Third-Party Notices — PDF Tech

PDF Tech's **own source code** is published under the [Apache License 2.0](./LICENSE).

The application also depends on third-party components. Each one remains subject to its own
license, and **not all of them are open source** — see the Syncfusion notice below. License
notices must be retained in accordance with the obligations of their respective authors.

Versions below are the **resolved** versions from `pubspec.lock`, not the constraints declared in
`pubspec.yaml`. Run `flutter pub deps` for the full transitive tree.

## ⚠️ Non-free component — Syncfusion

| Package | Version | License |
| --- | --- | --- |
| `syncfusion_flutter_pdfviewer` | 33.2.13 | Syncfusion Essential Studio® EULA |
| `syncfusion_flutter_pdf` | 33.2.13 | Syncfusion Essential Studio® EULA |
| `syncfusion_flutter_signaturepad` | 33.2.15 | Syncfusion Essential Studio® EULA |

Syncfusion components are **proprietary**. They are available either under the Syncfusion
Community License Program or under a commercial license, and may not be used under any other
terms. The full terms are at <https://www.syncfusion.com/content/downloads/syncfusion_license.pdf>.

No Syncfusion source code is contained in this repository: the packages are fetched from
pub.dev at build time. Compiled Syncfusion code **is** embedded in the distributed APK, which is
therefore not, as a whole, an Apache 2.0 artifact.

## Open-source direct dependencies

| Package | Version | License |
| --- | --- | --- |
| `files_tech_core` | 0.3.4 | Apache-2.0 (Files Tech — <https://github.com/gitubpatrice/files_tech_core>) |
| `cupertino_icons` | 1.0.9 | MIT |
| `file_picker` | 11.0.2 | MIT |
| `file_selector` | 1.1.0 | BSD-3-Clause |
| `file_selector_android` | 0.5.2+9 | BSD-3-Clause |
| `flutter_secure_storage` | 9.2.4 | BSD-3-Clause |
| `flutter_tesseract_ocr` | 0.4.31 | BSD-3-Clause |
| `google_sign_in` | 6.3.0 | BSD-3-Clause |
| `googleapis` | 13.2.0 | BSD-3-Clause |
| `http` | 1.6.0 | BSD-3-Clause |
| `image` | 4.8.0 | MIT |
| `intl` | 0.20.3 | BSD-3-Clause |
| `path` | 1.9.1 | BSD-3-Clause |
| `path_provider` | 2.1.6 | BSD-3-Clause |
| `pdfrx` | 2.4.7 | MIT |
| `pdfrx_engine` | 0.4.6 | MIT |
| `permission_handler` | 12.0.3 | MIT |
| `share_plus` | 10.1.4 | BSD-3-Clause |
| `shared_preferences` | 2.5.5 | BSD-3-Clause |
| `url_launcher` | 6.3.2 | BSD-3-Clause |

## Dev dependencies

| Package | License |
| --- | --- |
| `flutter_lints` | BSD-3-Clause |
| `flutter_launcher_icons` | MIT |

## Bundled native libraries and data

Shipped inside the APK (verified on the published `arm64-v8a` artifact):

- **Tesseract OCR** (`libtesseract.so`) — Apache-2.0 — with **Leptonica** (`libleptonica.so`,
  BSD-2-Clause), `libjpeg`, `libpngx`. Trained data `eng.traineddata` and `fra.traineddata`
  (Apache-2.0, tesseract-ocr/tessdata) are bundled locally; OCR runs entirely on-device.
- **PDFium** (`libpdfium.so`, via `pdfrx`) — BSD-3-Clause — page rendering.
- **Flutter engine** (`libflutter.so`) — BSD-3-Clause.

The application contains **no Google ML Kit** and no Google Play Services vision component.
Earlier versions used ML Kit for OCR; it was replaced by Tesseract in **v1.13.1**.

## Notices

A copy of the Apache License 2.0 is in [`LICENSE`](./LICENSE); attribution notices for this
project are in [`NOTICE`](./NOTICE).
