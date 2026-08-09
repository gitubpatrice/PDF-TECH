# Tesseract (flutter_tesseract_ocr) : aucune regle necessaire ici. TessBaseAPI declare des
# methodes natives, et proguard-android-optimize.txt applique deja
# `-keepclasseswithmembernames class * { native <methods>; }`, ce qui preserve le nom de la classe
# indispensable a la resolution JNI. Verifie sur l'APK v1.13.5 publie et minifie :
# Lcom/googlecode/tesseract/android/TessBaseAPI; y figure sous son nom complet.

# Flutter / Dart
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.editing.** { *; }
-dontwarn io.flutter.embedding.**

# Plugins natifs utilises
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class dev.fluttercommunity.plus.share.** { *; }

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

# Conserver les annotations utilisees par certains plugins via reflection
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod, RuntimeVisibleAnnotations
