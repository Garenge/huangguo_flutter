package com.huangguo.huangguo_flutter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.StatFs

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "huangguo/storage_usage")
            .setMethodCallHandler { call, result ->
                if (call.method == "read") {
                    readStorageUsage(result)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun readStorageUsage(result: MethodChannel.Result) {
        val roots = mutableListOf(applicationInfo.dataDir, applicationInfo.sourceDir)
        applicationInfo.splitSourceDirs?.let { roots.addAll(it) }
        getExternalFilesDirs(null).filterNotNull().forEach { roots.add(it.absolutePath) }
        externalCacheDirs.filterNotNull().forEach { roots.add(it.absolutePath) }
        val usage = mutableMapOf<String, Any>(
            "appRoots" to roots,
            "includesApplication" to true
        )
        try {
            val disk = StatFs(filesDir.absolutePath)
            usage["totalBytes"] = disk.totalBytes
            usage["availableBytes"] = disk.availableBytes
        } catch (error: Exception) {
            android.util.Log.w("MainActivity.kt", "readStorageUsage: 无法读取设备空间", error)
        }
        result.success(usage)
    }
}
