# ML Kit - script Latin uniquement, ignorer les autres scripts optionnels
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Flutter / Dart
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.editing.** { *; }
-dontwarn io.flutter.embedding.**

# Plugins natifs utilisés
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class dev.fluttercommunity.plus.share.** { *; }
-keep class dev.fluttercommunity.plus.device_info.** { *; }
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Syncfusion (utilise reflection sur certains types PDF)
-keep class com.syncfusion.** { *; }
-dontwarn com.syncfusion.**

# Google APIs (Drive)
-keep class com.google.api.** { *; }
-keep class com.google.auth.** { *; }
-dontwarn com.google.api.**
-dontwarn com.google.auth.**

# google_sign_in
-keep class io.flutter.plugins.googlesignin.** { *; }

# pdfx
-keep class io.scer.pdfx.** { *; }

# Conserver les annotations utilisées par certains plugins via reflection
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod, RuntimeVisibleAnnotations
