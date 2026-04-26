package com.xuyan.xuyan

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class ApkPatchPlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "ApkPatchPlugin"
        private const val CHANNEL = "com.xuyan.xuyan/apk_patch"

        fun registerWith(flutterEngine: FlutterEngine, appContext: Context) {
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            channel.setMethodCallHandler(ApkPatchPlugin(appContext))
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Log.d(TAG, "onMethodCall: ${call.method}")
        when (call.method) {
            "applyPatch" -> handleApplyPatch(call, result)
            "installApk" -> handleInstallApk(call, result)
            "getApkPath" -> handleGetApkPath(result)
            "isPatchSupported" -> result.success(true)
            else -> result.notImplemented()
        }
    }

    private fun handleApplyPatch(call: MethodCall, result: MethodChannel.Result) {
        val oldApkPath = call.argument<String>("oldApkPath")
        val patchPath = call.argument<String>("patchPath")
        val newApkPath = call.argument<String>("newApkPath")

        Log.d(TAG, "applyPatch: old=$oldApkPath, patch=$patchPath, new=$newApkPath")

        if (oldApkPath == null || patchPath == null || newApkPath == null) {
            result.error("INVALID_ARGS", "Missing arguments", null)
            return
        }

        val oldFile = File(oldApkPath)
        val patchFile = File(patchPath)
        val newFile = File(newApkPath)

        if (!oldFile.exists()) {
            Log.e(TAG, "Old APK not found: $oldApkPath")
            result.error("OLD_APK_MISSING", "Old APK not found: $oldApkPath", null)
            return
        }
        if (!patchFile.exists()) {
            Log.e(TAG, "Patch file not found: $patchPath")
            result.error("PATCH_MISSING", "Patch file not found: $patchPath", null)
            return
        }

        // Ensure output directory exists
        newFile.parentFile?.mkdirs()

        // Try pure Kotlin implementation first (works on Android 10+/16)
        Log.d(TAG, "Using pure Kotlin BsPatch")
        try {
            if (BsPatch.applyPatch(oldFile, patchFile, newFile)) {
                Log.d(TAG, "Pure Kotlin patch successful, size=${newFile.length()}")
                result.success(newApkPath)
                return
            }
            Log.w(TAG, "Pure Kotlin patch returned false, trying native fallback")
        } catch (e: Exception) {
            Log.w(TAG, "Pure Kotlin patch failed: ${e.message}", e)
        }

        // Fallback to native binary (may fail on Android 10+ due to SELinux)
        Log.d(TAG, "Trying native bspatch fallback")
        try {
            val bspatchPath = extractBspatch()
            if (bspatchPath == null) {
                result.error("EXTRACT_FAILED", "Pure Kotlin patch failed and bspatch binary not available", null)
                return
            }

            val process = ProcessBuilder()
                .command(bspatchPath, oldApkPath, newApkPath, patchPath)
                .redirectErrorStream(true)
                .start()

            val output = StringBuilder()
            process.inputStream.bufferedReader().use { reader ->
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    output.append(line).append("\n")
                }
            }

            val exitCode = process.waitFor()
            Log.d(TAG, "Native bspatch exit code: $exitCode")

            if (exitCode == 0 && newFile.exists() && newFile.length() > 0) {
                Log.d(TAG, "Native patch successful, size=${newFile.length()}")
                result.success(newApkPath)
            } else {
                Log.e(TAG, "Native patch failed: exit=$exitCode, output=${output}")
                result.error("PATCH_FAILED", "bspatch exit $exitCode: ${output}", null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Native patch error", e)
            result.error("PATCH_ERROR", e.message, null)
        }
    }

    private fun handleInstallApk(call: MethodCall, result: MethodChannel.Result) {
        val apkPath = call.argument<String>("apkPath")
        Log.d(TAG, "installApk: $apkPath")

        if (apkPath == null) {
            result.error("INVALID_ARGS", "Missing apkPath", null)
            return
        }

        val apkFile = File(apkPath)
        if (!apkFile.exists()) {
            Log.e(TAG, "APK not found: $apkPath")
            result.error("FILE_NOT_FOUND", "APK not found", null)
            return
        }

        Log.d(TAG, "APK size: ${apkFile.length()}")

        try {
            val success = installApk(apkPath)
            Log.d(TAG, "installApk result: $success")
            result.success(success)
        } catch (e: Exception) {
            Log.e(TAG, "Install error", e)
            result.error("INSTALL_ERROR", e.message, null)
        }
    }

    private fun handleGetApkPath(result: MethodChannel.Result) {
        try {
            val apkPath = context.packageManager.getApplicationInfo(context.packageName, 0).sourceDir
            Log.d(TAG, "Current APK path: $apkPath")
            result.success(apkPath)
        } catch (e: Exception) {
            Log.e(TAG, "Get APK path error", e)
            result.error("APK_PATH_ERROR", e.message, null)
        }
    }

    private fun extractBspatch(): String? {
        return try {
            val filesDir = context.filesDir
            val bspatchFile = File(filesDir, "bspatch")

            if (bspatchFile.exists() && bspatchFile.canExecute()) {
                return bspatchFile.absolutePath
            }

            val is64bit = Build.SUPPORTED_ABIS.any { it.contains("64") }
            val assetName = if (is64bit) "bspatch-arm64" else "bspatch-arm32"

            context.assets.open(assetName).use { input ->
                bspatchFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            }

            bspatchFile.setExecutable(true)
            bspatchFile.absolutePath
        } catch (e: Exception) {
            Log.e(TAG, "Extract bspatch error", e)
            null
        }
    }

    private fun installApk(apkPath: String): Boolean {
        return try {
            val apkFile = File(apkPath)
            Log.d(TAG, "Installing: ${apkFile.path}, size=${apkFile.length()}")

            val intent = Intent(Intent.ACTION_VIEW)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK

            val uri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                val authority = "${context.packageName}.fileprovider"
                FileProvider.getUriForFile(context, authority, apkFile)
            } else {
                Uri.fromFile(apkFile)
            }

            Log.d(TAG, "Install URI: $uri")
            intent.setDataAndType(uri, "application/vnd.android.package-archive")
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            Log.e(TAG, "Install APK failed", e)
            false
        }
    }
}
