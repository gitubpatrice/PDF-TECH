package com.pdftech.pdf_tech

import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Environment
import android.os.StatFs
import android.provider.OpenableColumns
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

        /// Channel de réception des PDFs ouverts depuis une autre app
        /// (Infomaniak Mail « Visualiser », gestionnaire de fichiers…).
        private const val INCOMING_CHANNEL = "com.pdftech.pdf_tech/incoming"

        /// Durée de rétention des copies importées dans cacheDir/incoming.
        /// Au-delà, purge best-effort au prochain import (évite l'accumulation
        /// sans toucher à un fichier en cours de visualisation).
        private const val INCOMING_TTL_MS = 24L * 60L * 60L * 1000L

        /// Garde-fou taille : un mail ne devrait pas livrer un PDF > 200 Mo.
        /// Empêche un content:// hostile de saturer le cache.
        private const val INCOMING_MAX_BYTES = 200L * 1024L * 1024L
    }

    /// Channel poussant le path du PDF importé vers Dart (warm start).
    private var incomingChannel: MethodChannel? = null

    /// Path du PDF capturé au lancement à froid (cold start), consommé par
    /// Dart via `getInitialPdf`. Null une fois lu.
    private var pendingPdfPath: String? = null

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

        // Réception des PDFs entrants (ACTION_VIEW / ACTION_SEND).
        // `getInitialPdf` est tiré par Dart au démarrage (cold start) ;
        // `onNewPdf` est poussé par le natif sur onNewIntent (warm start,
        // app déjà lancée — launchMode singleTop).
        incomingChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, INCOMING_CHANNEL
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "getInitialPdf") {
                    result.success(pendingPdfPath)
                    pendingPdfPath = null
                } else {
                    result.notImplemented()
                }
            }
        }
        // Intent ayant lancé l'activity (cold start). La copie est faite
        // maintenant, tant que le grant de lecture du content:// est vivant.
        handleIncomingIntent(intent, warmStart = false)

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

    /// App déjà vivante (singleTop) : un nouvel « Ouvrir avec » arrive ici.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIncomingIntent(intent, warmStart = true)
    }

    /// Extrait l'URI du PDF de l'intent, la copie dans le cache, puis :
    /// - cold start → mémorise le path pour `getInitialPdf` ;
    /// - warm start → pousse `onNewPdf` à Dart (sur le thread UI).
    private fun handleIncomingIntent(intent: Intent?, warmStart: Boolean) {
        if (intent == null) return
        @Suppress("DEPRECATION")
        val uri: Uri? = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> intent.getParcelableExtra(Intent.EXTRA_STREAM)
            else -> null
        }
        if (uri == null) return
        val path = copyIncomingToCache(uri) ?: return
        if (warmStart) {
            runOnUiThread { incomingChannel?.invokeMethod("onNewPdf", path) }
        } else {
            pendingPdfPath = path
        }
    }

    /// Copie le flux `content://`/`file://` reçu dans un sous-dossier horodaté
    /// de `cacheDir/incoming`. Le sous-dossier unique évite tout écrasement
    /// d'un fichier en cours de lecture. Le nom est durci (anti path-traversal)
    /// et la taille plafonnée. Retourne le path absolu, ou null si échec.
    private fun copyIncomingToCache(uri: Uri): String? {
        return try {
            val base = File(cacheDir, "incoming").apply { mkdirs() }
            purgeStaleIncoming(base)
            val name = resolveSafePdfName(uri)
            val dir = File(base, System.currentTimeMillis().toString()).apply { mkdirs() }
            val out = File(dir, name)
            val written = contentResolver.openInputStream(uri)?.use { input ->
                out.outputStream().use { output ->
                    val buf = ByteArray(64 * 1024)
                    var total = 0L
                    while (true) {
                        val read = input.read(buf)
                        if (read < 0) break
                        total += read
                        if (total > INCOMING_MAX_BYTES) {
                            output.close()
                            out.delete()
                            return null
                        }
                        output.write(buf, 0, read)
                    }
                    total
                }
            } ?: return null
            if (written <= 0L) { out.delete(); return null }
            out.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    /// Supprime les imports plus vieux que [INCOMING_TTL_MS]. Best-effort :
    /// une erreur d'I/O n'empêche pas l'import en cours.
    private fun purgeStaleIncoming(base: File) {
        try {
            val cutoff = System.currentTimeMillis() - INCOMING_TTL_MS
            base.listFiles()?.forEach { entry ->
                if (entry.lastModified() < cutoff) entry.deleteRecursively()
            }
        } catch (_: Exception) {
            // ignore — purge non critique
        }
    }

    /// Résout un nom de fichier sûr : DISPLAY_NAME du ContentResolver (ou
    /// dernier segment d'URI), dépouillé de toute composante de chemin,
    /// restreint à [A-Za-z0-9._-], forcé en `.pdf`.
    private fun resolveSafePdfName(uri: Uri): String {
        var raw = "document.pdf"
        try {
            if (uri.scheme == "content") {
                contentResolver.query(
                    uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null
                )?.use { c ->
                    if (c.moveToFirst()) {
                        val idx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (idx >= 0) c.getString(idx)?.let { raw = it }
                    }
                }
            } else {
                uri.lastPathSegment?.let { raw = it }
            }
        } catch (_: Exception) {
            // fallback "document.pdf"
        }
        // Retire toute composante de répertoire (anti path-traversal).
        var name = File(raw).name
        if (!name.lowercase().endsWith(".pdf")) name += ".pdf"
        name = name.replace(Regex("[^A-Za-z0-9._-]"), "_")
        if (name.isBlank() || name == ".pdf") name = "document.pdf"
        return name
    }
}
