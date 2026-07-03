package com.salessphere.app

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.annotation.RequiresApi
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

// `local_auth` shows the BiometricPrompt via an Android Fragment, which
// requires the host activity to be a FragmentActivity. `FlutterActivity`
// extends Activity (not FragmentActivity), so we use the
// FragmentActivity-flavored entrypoint instead.
class MainActivity : FlutterFragmentActivity() {

    private val downloadsChannel = "com.salessphere.app/downloads"

    // Sub-folder under Downloads so exported documents stay grouped.
    private val subDir = "SalesSphere"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            downloadsChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToDownloads" -> handleSave(
                    call.argument("fileName"),
                    call.argument("bytes"),
                    call.argument("mimeType"),
                    result,
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun handleSave(
        fileName: String?,
        bytes: ByteArray?,
        mimeType: String?,
        result: MethodChannel.Result,
    ) {
        if (fileName.isNullOrEmpty() || bytes == null) {
            result.error("INVALID_ARGS", "fileName and bytes are required", null)
            return
        }
        val mime = mimeType ?: "application/pdf"
        try {
            val path = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                saveScoped(fileName, bytes, mime)
            } else {
                saveLegacy(fileName, bytes)
            }
            result.success(path)
        } catch (e: SecurityException) {
            // Pre-Android-10: the legacy storage grant is missing. The Dart
            // side requests it and retries.
            result.error("PERMISSION_REQUIRED", e.message, null)
        } catch (e: Exception) {
            result.error("SAVE_FAILED", e.message, null)
        }
    }

    // Android 10+: write through MediaStore into the public Downloads
    // collection (scoped storage, permissionless) and mirror an app-specific
    // copy so the saved file has a real path an external viewer can open.
    @RequiresApi(Build.VERSION_CODES.Q)
    private fun saveScoped(fileName: String, bytes: ByteArray, mime: String): String {
        val resolver = contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, mime)
            put(
                MediaStore.MediaColumns.RELATIVE_PATH,
                Environment.DIRECTORY_DOWNLOADS + "/" + subDir,
            )
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }

        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("MediaStore insert returned null")

        resolver.openOutputStream(uri)?.use { it.write(bytes) }
            ?: throw IllegalStateException("Could not open MediaStore stream")

        values.clear()
        values.put(MediaStore.MediaColumns.IS_PENDING, 0)
        resolver.update(uri, values, null, null)

        // Return an openable app-specific copy (a MediaStore content URI
        // isn't a file path the viewer plugin can hand off).
        return writeAppCopy(fileName, bytes)
    }

    // Android 9 and below: write straight to the public Downloads directory.
    // Needs the legacy WRITE_EXTERNAL_STORAGE grant (declared maxSdk=28).
    private fun saveLegacy(fileName: String, bytes: ByteArray): String {
        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.WRITE_EXTERNAL_STORAGE,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            throw SecurityException("WRITE_EXTERNAL_STORAGE not granted")
        }
        val dir = File(
            Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_DOWNLOADS,
            ),
            subDir,
        )
        if (!dir.exists()) dir.mkdirs()
        val file = File(dir, fileName)
        FileOutputStream(file).use { it.write(bytes) }
        return file.absolutePath
    }

    private fun writeAppCopy(fileName: String, bytes: ByteArray): String {
        val base = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: filesDir
        val dir = File(base, subDir)
        if (!dir.exists()) dir.mkdirs()
        val file = File(dir, fileName)
        FileOutputStream(file).use { it.write(bytes) }
        return file.absolutePath
    }
}
