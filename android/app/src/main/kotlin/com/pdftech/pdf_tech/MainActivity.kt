package com.pdftech.pdf_tech

import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.os.StatFs
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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
