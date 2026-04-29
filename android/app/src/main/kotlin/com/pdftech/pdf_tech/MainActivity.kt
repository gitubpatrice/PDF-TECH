package com.pdftech.pdf_tech

import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.os.StatFs
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    /// Racines autorisées pour sendToPackage. Le path passé par Dart est
    /// canonicalisé (suit symlinks) puis comparé. Empêche un path forgé de
    /// pointer vers /data/data/<other-app>/ ou /etc/passwd.
    private val allowedRoots: List<File> by lazy {
        listOfNotNull(
            Environment.getExternalStorageDirectory().canonicalFile,
            File("/storage").canonicalFile,
            filesDir.canonicalFile,
            cacheDir.canonicalFile,
            getExternalFilesDir(null)?.canonicalFile,
        )
    }

    private fun isAllowedPath(path: String): Boolean {
        return try {
            val canonical = File(path).canonicalFile
            allowedRoots.any { root ->
                canonical.absolutePath == root.absolutePath ||
                canonical.absolutePath.startsWith(root.absolutePath + File.separator)
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
                    try {
                        val installed = try {
                            packageManager.getPackageInfo(pkg, 0); true
                        } catch (_: Exception) { false }
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
