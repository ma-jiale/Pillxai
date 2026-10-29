package com.pillxai.pillxai_client

import android.app.Activity
import android.app.Instrumentation
import android.content.*
import android.os.Bundle
import android.os.IBinder
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** Emulator-only integration harness; refuses the real client package. No hardware or API calls. */
class OtaInstrumentation : Instrumentation() {
    private lateinit var arguments: Bundle
    private lateinit var activity: Activity
    private lateinit var service: TerminalService
    private var serviceConnection: ServiceConnection? = null

    override fun onCreate(arguments: Bundle?) {
        this.arguments = arguments ?: Bundle()
        super.onCreate(arguments)
        start()
    }

    private fun call(action: (MethodChannel.Result) -> Unit): Any? {
        val done = CountDownLatch(1)
        var value: Any? = null
        var failure: String? = null
        runOnMainSync {
            action(object : MethodChannel.Result {
                override fun success(result: Any?) { value = result; done.countDown() }
                override fun error(code: String, message: String?, details: Any?) { failure = "$code: $message"; done.countDown() }
                override fun notImplemented() { failure = "not implemented"; done.countDown() }
            })
        }
        check(done.await(45, TimeUnit.SECONDS)) { "Native callback timed out" }
        check(failure == null) { failure!! }
        return value
    }

    private fun command(operation: String, data: Map<String, Any?> = emptyMap()) =
        call { service.command(mapOf("operation" to operation, "data" to data), it) }
    private fun update(method: String) = call { AppUpdater.handle(activity, service, MethodCall(method, null), it) }
    private fun view() = JSONObject(command("view") as String)
    private fun rejected(action: () -> Unit) {
        var rejected = false
        try { action() } catch (_: IllegalStateException) { rejected = true }
        check(rejected) { "Expected operation to be rejected" }
    }

    private fun manifest(file: File): JSONObject {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(65536)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        return JSONObject().put("package_name", targetContext.packageName)
            .put("version_name", "0.2.0").put("version_code", 1002)
            .put("size_bytes", file.length()).put("sha256", digest.digest().joinToString("") { "%02x".format(it) })
            .put("min_android_sdk", 24).put("abis", org.json.JSONArray(listOf("x86_64")))
    }

    override fun onStart() {
        try {
            check(targetContext.packageName == "com.pillxai.pillxai_client.runtimecheck") { "Only the isolated runtimecheck package is allowed" }
            check(android.os.Build.HARDWARE in listOf("ranchu", "goldfish")) { "Emulator only" }
            activity = startActivitySync(Intent(targetContext, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            val bound = CountDownLatch(1)
            serviceConnection = object : ServiceConnection {
                override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
                    service = (binder as TerminalService.LocalBinder).service
                    bound.countDown()
                }
                override fun onServiceDisconnected(name: ComponentName?) {}
            }
            targetContext.bindService(Intent(targetContext, TerminalService::class.java), serviceConnection!!, Context.BIND_AUTO_CREATE)
            check(bound.await(30, TimeUnit.SECONDS))
            call { service.awaitReady(it) }
            val mode = arguments.getString("mode", "verify")
            val prefs = targetContext.getSharedPreferences("app_updates", Context.MODE_PRIVATE)
            val sentinel = File(targetContext.filesDir, "ota-sentinel")
            if (mode == "recovery") {
                update("reconcile")
                check(view().isNull("update_lock"))
                check(sentinel.readText() == "preserve across APK replacement")
                check(!prefs.getBoolean("auto", true))
                check(view().getJSONObject("configuration").getString("port") == "simulation-only")
                command("claim_intent", mapOf("id" to "probe"))
                command("claim_intent")
            } else {
                val dir = File(targetContext.noBackupFilesDir, "updates").also { it.mkdirs() }
                val candidate = File(dir, "update.apk")
                context.assets.open("upgrade.apk").use { input -> candidate.outputStream().use { input.copyTo(it) } }
                val release = manifest(candidate)
                AppUpdater.verifyApk(targetContext, candidate, release)
                if (mode == "verify") {
                    rejected { AppUpdater.verifyApk(targetContext, candidate, JSONObject(release.toString()).put("sha256", "0".repeat(64))) }
                    rejected { AppUpdater.verifyApk(targetContext, candidate, JSONObject(release.toString()).put("version_name", "wrong")) }
                    val wrongSigner = File(dir, "wrong-signer.apk")
                    context.assets.open("wrong-signer.apk").use { input -> wrongSigner.outputStream().use { input.copyTo(it) } }
                    rejected { AppUpdater.verifyApk(targetContext, wrongSigner, manifest(wrongSigner)) }
                    wrongSigner.delete()
                    command("claim_intent", mapOf("id" to "outstanding"))
                    rejected { command("update_lock", mapOf("token" to "blocked")) }
                    command("claim_intent")
                    command("configure", mapOf("mode" to "simulator", "port" to "simulation-only"))
                    command("update_lock", mapOf("token" to "native-check"))
                    rejected { command("claim_intent", mapOf("id" to "must-not-start")) }
                    command("update_unlock", mapOf("token" to "native-check"))
                    sentinel.writeText("preserve across APK replacement")
                    prefs.edit().putBoolean("auto", false).commit()
                } else {
                    prefs.edit().putString("ready", release.toString()).commit()
                    update("install")
                    check(!view().isNull("update_lock"))
                    val deadline = System.currentTimeMillis() + 30000
                    while ((update("info") as Map<*, *>)["confirmation_ready"] != true) {
                        check(System.currentTimeMillis() < deadline) { "No installer confirmation received" }
                        Thread.sleep(200)
                    }
                    if (mode == "cancel") {
                        update("cancelInstall")
                        check(view().isNull("update_lock"))
                        check(sentinel.exists())
                    } else {
                        update("confirm")
                        sendStatus(0, Bundle().apply { putString("stream", "OTA_CONFIRMATION_OPEN\n") })
                        // The driver confirms Android's installer; replacement terminates this process.
                        Thread.sleep(120000)
                        error("APK replacement did not terminate the old application")
                    }
                }
            }
            finish(Activity.RESULT_OK, Bundle().apply { putString("stream", "OTA_NATIVE_${mode.uppercase()}_PASSED\n") })
        } catch (failure: Throwable) {
            finish(Activity.RESULT_CANCELED, Bundle().apply { putString("stream", "OTA_NATIVE_FAILED: ${failure.stackTraceToString()}\n") })
        } finally {
            serviceConnection?.let { targetContext.unbindService(it) }
        }
    }
}
