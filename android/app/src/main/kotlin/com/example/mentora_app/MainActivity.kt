package com.example.mentora_app

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun getRenderMode(): RenderMode = RenderMode.texture

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mentora/file_share")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareFile" -> shareFile(call.arguments as? Map<*, *>, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun shareFile(arguments: Map<*, *>?, result: MethodChannel.Result) {
        val path = arguments?.get("path") as? String
        val fileName = arguments?.get("fileName") as? String ?: "model.litertlm"
        val mimeType = arguments?.get("mimeType") as? String ?: "application/octet-stream"

        if (path.isNullOrBlank()) {
            result.error("missing_path", "No file path was provided.", null)
            return
        }

        val file = File(path)
        if (!file.exists()) {
            result.error("missing_file", "The file does not exist.", path)
            return
        }

        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            file,
        )

        val shareIntent = Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TITLE, fileName)
            putExtra(Intent.EXTRA_SUBJECT, fileName)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        val chooser = Intent.createChooser(shareIntent, "Share $fileName")
        startActivity(chooser)
        result.success(null)
    }
}
