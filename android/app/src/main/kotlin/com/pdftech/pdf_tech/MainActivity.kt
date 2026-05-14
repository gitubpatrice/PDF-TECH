package com.pdftech.pdf_tech

import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Environment
import android.os.StatFs
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    companion object {
        /// F3 v1.12.4 — Whitelist explicite des packages cibles autorisés
        /// pour `sendToPackage`. Avant : Dart pouvait envoyer N'IMPORTE
        /// quel pkg. Désormais on impose la liste connue (apps cloud déclarées
        /// dans `<queries>` du manifest).
        private val ALLOWED_SHARE_PACKAGES = setOf(
            "com.infomaniak.drive",
            "me.proton.android.drive",
            "com.google.android.apps.docs",
        )
    }

    /// Racines autorisées pour sendToPackage. Le path passé par Dart est
    /// canonicalisé (suit symlinks) puis comparé. Empêche un path forgé de
    /// pointer vers /data/data/<other-app>/ ou /etc/passwd.
    private val allowedRoots: List<File> by lazy {
        // F1 v1.12.4 — Retrait de `File("/storage")` : couvrait toute SD/OTG +
        // /storage/emulated/0/Android/data/<autre-pkg>/, ce qui rendait
        // possible un confused-deputy (Dart envoie un path forgé pointant
        // vers les données d'une autre app → FileProvider partage l'URI vers
        // app cloud). On garde uniquement les racines légitimement
        // accessibles à PDF Tech.
        listOfNotNull(
            Environment.getExternalStorageDirectory().canonicalFile,
            filesDir.canonicalFile,
            cacheDir.canonicalFile,
            getExternalFilesDir(null)?.canonicalFile,
        )
    }

    private fun isAllowedPath(path: String): Boolean {
        return try {
            val canonical = File(path).canonicalFile
            val abs = canonical.absolutePath
            // F1 v1.12.4 — Blacklist explicite des dossiers data/obb d'autres
            // apps via SD card (paths qui passeraient l'allowedRoots
            // `externalStorageDirectory` mais qui ne sont pas légitimement à
            // nous). Cohérent avec RFT v2.13.1 / RFT v2.12.0 F5.
            val pkgFiles = "/Android/data/$packageName"
            val pkgObb = "/Android/obb/$packageName"
            if (abs.contains("/Android/data/") && !abs.contains(pkgFiles)) return false
            if (abs.contains("/Android/obb/") && !abs.contains(pkgObb)) return false
            allowedRoots.any { root ->
                abs == root.absolutePath ||
                abs.startsWith(root.absolutePath + File.separator)
            }
        } catch (_: Exception) {
            false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.pdftech.pdf_tech/settings")
            .setMethodCallHandler { call, result ->
                if (call.method == "openUnknownSources") {
                    try {
                        val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                    } catch (_: Exception) {
                        startActivity(Intent(Settings.ACTION_SECURITY_SETTINGS))
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }

        // Envoi d'un fichier vers une app cible (kDrive, Proton Drive, Google Drive…)
        // via ACTION_SEND + setPackage. FileProvider expose l'URI en lecture.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.pdftech.pdf_tech/share")
            .setMethodCallHandler { call, result ->
                if (call.method == "sendToPackage") {
                    val path = call.argument<String>("path")
                    val mime = call.argument<String>("mime") ?: "application/pdf"
                    val pkg  = call.argument<String>("package")
                    if (path == null || pkg == null) {
                        result.error("NO_ARGS", "path/package manquant", null)
                        return@setMethodCallHandler
                    }
                    if (!isAllowedPath(path)) {
                        result.error("FORBIDDEN", "Chemin hors zone autorisée", null)
                        return@setMethodCallHandler
                    }
                    // F3 v1.12.4 — Whitelist Kotlin du package cible. Avant :
                    // Dart pouvait envoyer n'importe quel pkg, le `<queries>`
                    // du manifest restait la seule contrainte.
                    if (pkg !in ALLOWED_SHARE_PACKAGES) {
                        result.error("FORBIDDEN_PKG", "Package non autorisé", null)
                        return@setMethodCallHandler
                    }
                    try {
                        // F11 v1.12.4 — catch précis NameNotFoundException
                        // au lieu d'Exception large (qui avalait aussi des
                        // SecurityException avec message trompeur).
                        val installed = try {
                            packageManager.getPackageInfo(pkg, 0); true
                        } catch (_: PackageManager.NameNotFoundException) { false }
                        if (!installed) {
                            result.error("NOT_INSTALLED",
                                "Application non installée : $pkg", null)
                            return@setMethodCallHandler
                        }
                        val file = File(path)
                        val uri: Uri = FileProvider.getUriForFile(
                            this, "$packageName.fileprovider", file)
                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = mime
                            putExtra(Intent.EXTRA_STREAM, uri)
                            // F3 v1.12.4 — `clipData` lié à l'URI : limite
                            // strictement le grant aux URIs déclarées, même
                            // si l'app cible introduit un component supplant.
                            clipData = ClipData.newRawUri("pdf", uri)
                            setPackage(pkg)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("SEND_ERROR", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }

        // F1 v1.12.2 — FLAG_SECURE on/off pour bloquer screenshots / aperçu
        // task switcher pendant saisie password PDF, signature manuscrite,
        // viewer de PDF déchiffré. setFlags doit être appelé sur le thread UI
        // d'où runOnUiThread + check sécurité (Window peut être null si appelé
        // pendant une transition d'activity).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
                "com.pdftech.pdf_tech/secure_window")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        runOnUiThread {
                            try {
                                if (enabled) {
                                    window.setFlags(
                                        WindowManager.LayoutParams.FLAG_SECURE,
                                        WindowManager.LayoutParams.FLAG_SECURE,
                                    )
                                } else {
                                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                                }
                                result.success(null)
                            } catch (e: Exception) {
                                result.error("SECURE_WINDOW_ERROR", e.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.pdftech.pdf_tech/storage")
            .setMethodCallHandler { call, result ->
                if (call.method == "getStorageInfo") {
                    try {
                        val stat = StatFs(Environment.getExternalStorageDirectory().path)
                        val total = stat.blockCountLong * stat.blockSizeLong
                        val free  = stat.availableBlocksLong * stat.blockSizeLong
                        result.success(mapOf("total" to total, "free" to free))
                    } catch (e: Exception) {
                        result.error("STORAGE_ERROR", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
