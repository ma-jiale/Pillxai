package com.pillxai.pillxai_client

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.net.URL
import java.security.MessageDigest
import java.util.UUID
import java.util.concurrent.Executors
import javax.net.ssl.HttpsURLConnection

/** Downloads are process-owned; installation is locked by the serialized terminal runtime. */
object AppUpdater {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var downloading = false
    private var installing = false
    private var downloadedBytes = 0L
    private var downloadError: String? = null
    private var confirmation: Intent? = null
    private fun prefs(context: Context) = context.getSharedPreferences("app_updates", Context.MODE_PRIVATE)
    private fun directory(context: Context) = File(context.noBackupFilesDir, "updates").also { it.mkdirs() }
    private fun apk(context: Context) = File(directory(context), "update.apk")
    @Suppress("DEPRECATION")
    private fun version(info: PackageInfo): Long = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
    @Suppress("DEPRECATION")
    private fun installed(context: Context) = context.packageManager.getPackageInfo(context.packageName, PackageManager.GET_SIGNATURES)

    fun handle(activity: Activity, service: TerminalService?, call: MethodCall, result: MethodChannel.Result) {
        try {
            val context = activity.applicationContext
            when (call.method) {
                "info" -> result.success(info(context))
                "autoDownload" -> {
                    check(prefs(context).edit().putBoolean("auto", call.arguments as Boolean).commit()) { "更新设置保存失败。" }
                    result.success(null)
                }
                "download" -> {
                    check(!downloading && !installing && !prefs(context).contains("token")) { "已有更新操作正在进行。" }
                    val args = JSONObject(call.arguments as Map<*, *>)
                    validateManifest(context, args)
                    val url = URL(args.getString("url"))
                    require(url.protocol == "https" && url.userInfo == null && url.ref == null) { "更新下载必须使用 HTTPS。" }
                    downloading = true
                    downloadedBytes = 0
                    downloadError = null
                    prefs(context).edit().remove("ready").apply()
                    worker.execute {
                        var failure: String? = null
                        try { download(context, args) } catch (error: Exception) {
                            failure = error.message ?: "下载失败，请重试。"
                            File(directory(context), "update.part").delete()
                        }
                        main.post { downloading = false; downloadError = failure }
                    }
                    result.success(null)
                }
                "permission" -> {
                    if (Build.VERSION.SDK_INT >= 26 && !context.packageManager.canRequestPackageInstalls()) {
                        activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:${context.packageName}")))
                    }
                    result.success(null)
                }
                "install" -> install(context, service, result)
                "confirm" -> {
                    val intent = confirmation ?: error("安装确认已失效，请取消后重新安装。")
                    activity.startActivity(intent)
                    confirmation = null
                    result.success(null)
                }
                "reconcile", "cancelInstall" -> {
                    check(!installing) { "正在准备安装，请稍候。" }
                    val settings = prefs(context)
                    val id = settings.getInt("session", -1)
                    val session = context.packageManager.packageInstaller.getSessionInfo(id)
                    val replaced = version(installed(context)) >= settings.getLong("target", Long.MAX_VALUE)
                    if ((call.method == "cancelInstall" || replaced) && session != null) {
                        context.packageManager.packageInstaller.abandonSession(id)
                        confirmation = null
                    }
                    val finished = call.method == "cancelInstall" || session == null || replaced
                    if (finished) unlock(context, service, result) else result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: Exception) { result.error("update", error.message ?: "更新操作失败。", null) }
    }

    private fun info(context: Context): Map<String, Any?> {
        val current = installed(context)
        val settings = prefs(context)
        val ready = settings.getString("ready", null)?.let { JSONObject(it) }
        val validReady = ready?.takeIf { apk(context).isFile && it.optLong("version_code") > version(current) }
        return mapOf(
            "version_name" to current.versionName, "version_code" to version(current),
            "package_name" to context.packageName, "sdk" to Build.VERSION.SDK_INT,
            "abis" to Build.SUPPORTED_ABIS.toList(), "auto_download" to settings.getBoolean("auto", true),
            "can_install" to (Build.VERSION.SDK_INT < 26 || context.packageManager.canRequestPackageInstalls()),
            "downloading" to downloading, "downloaded_bytes" to downloadedBytes,
            "error" to downloadError, "ready_sha256" to validReady?.optString("sha256"),
            "installing" to (installing || settings.contains("token")),
            "confirmation_ready" to (confirmation != null),
            "install_status" to settings.getString("status", null),
        )
    }

    private fun validateManifest(context: Context, manifest: JSONObject) {
        require(manifest.getString("package_name") == context.packageName) { "安装包不属于当前应用。" }
        require(manifest.getLong("version_code") > version(installed(context))) { "安装包版本必须高于当前版本。" }
        require(manifest.getLong("size_bytes") in 1..536870912L) { "安装包大小无效。" }
        require(Regex("[0-9a-f]{64}").matches(manifest.getString("sha256"))) { "安装包校验信息无效。" }
        require(manifest.getInt("min_android_sdk") <= Build.VERSION.SDK_INT) { "此版本不支持当前 Android 系统。" }
        val abis = manifest.getJSONArray("abis")
        require((0 until abis.length()).any { abis.getString(it) in Build.SUPPORTED_ABIS }) { "此版本不支持当前处理器。" }
    }

    private fun download(context: Context, manifest: JSONObject) {
        val file = File(directory(context), "update.part")
        val size = manifest.getLong("size_bytes")
        check(directory(context).usableSpace > size * 2 + 33554432) { "存储空间不足，请清理后重试。" }
        val connection = URL(manifest.getString("url")).openConnection() as HttpsURLConnection
        connection.instanceFollowRedirects = false
        connection.connectTimeout = 15000
        connection.readTimeout = 30000
        connection.setRequestProperty("Accept-Encoding", "identity")
        try {
            check(connection.responseCode == 200) { "安装包下载失败，请重新检查更新。" }
            check(connection.contentLengthLong == -1L || connection.contentLengthLong == size) { "安装包长度不匹配。" }
            connection.inputStream.use { input ->
                file.outputStream().use { output ->
                    val buffer = ByteArray(65536)
                    var total = 0L
                    while (true) {
                        val read = input.read(buffer)
                        if (read == -1) break
                        total += read
                        check(total <= size) { "安装包超出声明大小。" }
                        output.write(buffer, 0, read)
                        val progress = total
                        main.post { downloadedBytes = progress }
                    }
                    output.fd.sync()
                    check(total == size) { "安装包下载不完整，请重试。" }
                }
            }
            verifyApk(context, file, manifest)
            check(file.renameTo(apk(context))) { "无法保存安装包，请检查存储。" }
            check(prefs(context).edit().putString("ready", manifest.toString()).commit()) { "安装包信息保存失败。" }
        } finally { connection.disconnect() }
    }

    @Suppress("DEPRECATION")
    internal fun verifyApk(context: Context, file: File, manifest: JSONObject) {
        validateManifest(context, manifest)
        check(file.length() == manifest.getLong("size_bytes")) { "安装包大小校验失败。" }
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(65536)
            while (true) {
                val count = input.read(buffer)
                if (count == -1) break
                digest.update(buffer, 0, count)
            }
        }
        check(digest.digest().joinToString("") { "%02x".format(it) } == manifest.getString("sha256")) { "安装包完整性校验失败。" }
        val candidate = context.packageManager.getPackageArchiveInfo(file.absolutePath, PackageManager.GET_SIGNATURES)
            ?: error("安装包无法解析。")
        check(candidate.packageName == context.packageName && version(candidate) == manifest.getLong("version_code") &&
            candidate.versionName == manifest.getString("version_name")) { "安装包身份或版本与发布信息不符。" }
        val expected = installed(context).signatures?.map { it.toCharsString() }?.toSet()
        val actual = candidate.signatures?.map { it.toCharsString() }?.toSet()
        check(!expected.isNullOrEmpty() && actual == expected) { "安装包签名不匹配，请联系维护人员；不要卸载应用。" }
        if (Build.VERSION.SDK_INT >= 24) {
            check((candidate.applicationInfo?.minSdkVersion ?: Int.MAX_VALUE) <= Build.VERSION.SDK_INT) { "安装包要求更高的 Android 版本。" }
        }
    }

    private fun install(context: Context, service: TerminalService?, result: MethodChannel.Result) {
        check(service != null) { "本机执行服务尚未就绪。" }
        check(!downloading && !installing && !prefs(context).contains("token")) { "已有更新操作正在进行。" }
        check(Build.VERSION.SDK_INT < 26 || context.packageManager.canRequestPackageInstalls()) { "请先允许安装应用更新。" }
        val manifest = JSONObject(prefs(context).getString("ready", null) ?: error("请先下载更新。"))
        installing = true
        worker.execute {
            try {
                verifyApk(context, apk(context), manifest)
                main.post {
                    val token = UUID.randomUUID().toString()
                    val saved = prefs(context).edit().putString("token", token)
                        .putLong("target", manifest.getLong("version_code")).putString("status", "preparing").commit()
                    if (!saved) {
                        installing = false
                        result.error("update", "安装状态保存失败。", null)
                        return@post
                    }
                    service.command(mapOf("operation" to "update_lock", "data" to mapOf("token" to token)), object : MethodChannel.Result {
                        override fun success(value: Any?) { commit(context, manifest, result) }
                        override fun error(code: String, message: String?, details: Any?) {
                            // Even a failed disconnect may have acquired the durable lock.
                            prefs(context).edit().putString("status", "failed").apply()
                            installing = false
                            result.error(code, message, details)
                        }
                        override fun notImplemented() = error("update", "执行服务不支持更新保护。", null)
                    })
                }
            } catch (error: Exception) {
                main.post { installing = false; result.error("update", error.message, null) }
            }
        }
    }

    private fun commit(context: Context, manifest: JSONObject, result: MethodChannel.Result) {
        worker.execute {
            try {
                val installer = context.packageManager.packageInstaller
                val parameters = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
                parameters.setAppPackageName(context.packageName)
                parameters.setSize(manifest.getLong("size_bytes"))
                if (Build.VERSION.SDK_INT >= 31) parameters.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_REQUIRED)
                val id = installer.createSession(parameters)
                check(prefs(context).edit().putInt("session", id).putString("status", "installing").commit()) { "安装会话保存失败。" }
                installer.openSession(id).use { session ->
                    apk(context).inputStream().use { input ->
                        session.openWrite("base.apk", 0, manifest.getLong("size_bytes")).use { output ->
                            input.copyTo(output)
                            session.fsync(output)
                        }
                    }
                    val intent = Intent(context, UpdateInstallReceiver::class.java).setAction("${context.packageName}.UPDATE_STATUS")
                    val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                        (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0)
                    session.commit(PendingIntent.getBroadcast(context, id, intent, flags).intentSender)
                }
                main.post { installing = false; result.success(null) }
            } catch (error: Exception) {
                // Keep the durable lock until explicit reconciliation/abandonment.
                main.post { installing = false; result.error("update", error.message, null) }
            }
        }
    }

    private fun unlock(context: Context, service: TerminalService?, result: MethodChannel.Result) {
        val token = prefs(context).getString("token", null)
        if (token == null) { result.success(null); return }
        check(service != null) { "请等待执行服务就绪后重试。" }
        service.command(mapOf("operation" to "view"), object : MethodChannel.Result {
            override fun success(value: Any?) {
                val lock = JSONObject(value as String).optString("update_lock", "")
                if (lock.isEmpty() || lock == "null") { clear(context); result.success(null); return }
                service.command(mapOf("operation" to "update_unlock", "data" to mapOf("token" to token)), object : MethodChannel.Result {
                    override fun success(value: Any?) { clear(context); result.success(null) }
                    override fun error(code: String, message: String?, details: Any?) = result.error(code, message, details)
                    override fun notImplemented() = result.notImplemented()
                })
            }
            override fun error(code: String, message: String?, details: Any?) = result.error(code, message, details)
            override fun notImplemented() = result.notImplemented()
        })
    }

    private fun clear(context: Context) {
        check(prefs(context).edit().remove("token").remove("target").remove("session").commit()) { "更新状态保存失败。" }
        confirmation = null
    }

    @Suppress("DEPRECATION")
    fun receive(context: Context, intent: Intent) {
        val settings = prefs(context)
        if (intent.getIntExtra(PackageInstaller.EXTRA_SESSION_ID, -2) != settings.getInt("session", -1)) return
        val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)
        if (status == PackageInstaller.STATUS_PENDING_USER_ACTION) {
            confirmation = intent.getParcelableExtra(Intent.EXTRA_INTENT)
            settings.edit().putString("status", "confirmation").apply()
        } else {
            confirmation = null
            settings.edit().putString("status", if (status == PackageInstaller.STATUS_SUCCESS) "success" else "failed")
                .remove("session").commit()
        }
    }
}

class UpdateInstallReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) { AppUpdater.receive(context, intent) }
}
