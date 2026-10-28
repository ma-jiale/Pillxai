package com.pillxai.pillxai_client

import android.app.*
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.*
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File

/** Owns the execution engine independently of the UI Activity. Never auto-restarts. */
class TerminalService : Service() {
    inner class LocalBinder : Binder() { val service get() = this@TerminalService }
    private val binder = LocalBinder()
    private val main = Handler(Looper.getMainLooper())
    private lateinit var engine: FlutterEngine
    private lateinit var runtime: MethodChannel
    private lateinit var bluetooth: BluetoothConnection
    private lateinit var wakeLock: PowerManager.WakeLock
    private val waiters = mutableListOf<MethodChannel.Result>()
    private var ready = false
    private var failure: String? = null
    private var foreground = false
    private var lastHeartbeat = 0L
    private var needsWake = false
    private var lastNotice = ""
    var latest = "{}"
        private set
    var listener: ((String) -> Unit)? = null

    private val watchdog = object : Runnable {
        override fun run() {
            // Renew a bounded wake lock only while a healthy engine needs device progress.
            if (needsWake && SystemClock.elapsedRealtime() - lastHeartbeat < 15000) {
                wakeLock.acquire(90000)
            } else if (wakeLock.isHeld) wakeLock.release()
            main.postDelayed(this, 30000)
        }
    }

    override fun onCreate() {
        super.onCreate()
        bluetooth = BluetoothConnection(this)
        wakeLock = getSystemService(PowerManager::class.java)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Pillxai:execution")
            .also { it.setReferenceCounted(false) }
        if (Build.VERSION.SDK_INT >= 26) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel("execution", "摆药设备运行", NotificationManager.IMPORTANCE_LOW))
        }
        main.post(watchdog)
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(this)
            loader.ensureInitializationComplete(this, null)
            engine = FlutterEngine(this)
            runtime = MethodChannel(engine.dartExecutor.binaryMessenger, "pillxai/runtime")
            runtime.setMethodCallHandler { call, result ->
                when (call.method) {
                    "directory" -> result.success(File(noBackupFilesDir, "terminal").absolutePath)
                    "ready" -> {
                        ready = true
                        waiters.toList().forEach { it.success(latest) }
                        waiters.clear()
                        result.success(null)
                    }
                    "failed" -> {
                        fail(call.arguments as? String ?: "执行服务启动失败。")
                        result.success(null)
                    }
                    "update" -> {
                        accept(call.arguments as String)
                        result.success(null)
                    }
                    "heartbeat" -> { lastHeartbeat = SystemClock.elapsedRealtime(); result.success(null) }
                    else -> result.notImplemented()
                }
            }
            MethodChannel(engine.dartExecutor.binaryMessenger, "pillxai/bluetooth")
                .setMethodCallHandler(bluetooth::handle)
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "terminalServiceMain"))
        } catch (_: Exception) { fail("执行服务初始化失败，请检查应用及本机存储。") }
    }

    private fun fail(message: String) {
        failure = message
        waiters.toList().forEach { it.error("terminal", message, null) }
        waiters.clear()
        listener?.invoke(JSONObject().put("worker_error", message).toString())
    }

    fun awaitReady(result: MethodChannel.Result) {
        when {
            failure != null -> result.error("terminal", failure, null)
            ready -> result.success(latest)
            else -> waiters.add(result)
        }
    }

    fun removeWaiters() {
        waiters.toList().forEach { it.error("detached", "界面已关闭，后台任务不受影响。", null) }
        waiters.clear()
    }

    private fun accept(value: String) {
        val view = JSONObject(value)
        if (!view.has("worker_error")) latest = value
        lastHeartbeat = SystemClock.elapsedRealtime()
        val state = view.optJSONObject("state")
        val phase = state?.optString("phase") ?: "idle"
        needsWake = state?.optBoolean("connected") == true &&
            phase !in listOf("idle", "completed", "cancelled", "deleting", "recovery")
        if (needsWake) wakeLock.acquire(90000)
        else if (wakeLock.isHeld) wakeLock.release()
        val text = when {
            view.has("worker_error") -> "执行服务异常，请立即核对现场"
            phase == "recovery" -> "执行中断，请返回应用核对现场"
            phase == "paused" -> "摆药已暂停"
            phase == "collecting" || phase == "closing" -> "等待取盒与设备就绪"
            phase == "completed" || phase == "cancelled" -> "任务已结束，等待记录同步"
            phase == "running" || phase == "starting" -> "正在摆药"
            state?.optBoolean("connected") == true -> "设备已连接"
            else -> "设备已断开"
        }
        if (foreground && text != lastNotice) {
            lastNotice = text
            getSystemService(NotificationManager::class.java).notify(101, notification(text))
        }
        listener?.invoke(value)
    }

    private fun notification(text: String): Notification {
        val open = PendingIntent.getActivity(this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "execution")
            else Notification.Builder(this)
        return builder.setSmallIcon(R.drawable.ic_terminal_notification)
            .setContentTitle("Pillxai").setContentText(text).setContentIntent(open)
            .setOngoing(true).setOnlyAlertOnce(true).setVisibility(Notification.VISIBILITY_PRIVATE)
            .setCategory(Notification.CATEGORY_SERVICE).build()
    }

    fun command(arguments: Map<*, *>, result: MethodChannel.Result) {
        if (!ready || failure != null) { result.error("terminal", failure ?: "执行服务尚未就绪。", null); return }
        val operation = arguments["operation"] as String
        try {
            if (operation == "connect") {
                check(bluetooth.permitted()) { "请先允许附近设备权限。" }
                val intent = Intent(this, TerminalService::class.java)
                if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
                if (Build.VERSION.SDK_INT >= 29) startForeground(101, notification("正在连接设备"),
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
                else startForeground(101, notification("正在连接设备"))
                foreground = true
            }
            runtime.invokeMethod("command", arguments, object : MethodChannel.Result {
                override fun success(value: Any?) {
                    result.success(value)
                    if (operation == "shutdown") {
                        foreground = false
                        stopForeground(STOP_FOREGROUND_REMOVE)
                        stopSelf()
                    }
                }
                override fun error(code: String, message: String?, details: Any?) = result.error(code, message, details)
                override fun notImplemented() = result.notImplemented()
            })
        } catch (error: Exception) { result.error("terminal", error.message, null) }
    }

    override fun onBind(intent: Intent?): IBinder = binder
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_NOT_STICKY
    // Removing the recent-app card is not a confirmed physical stop. Keep the service;
    // force-stop/process death instead requires recovery from SQLite on the next launch.
    override fun onTaskRemoved(rootIntent: Intent?) { super.onTaskRemoved(rootIntent) }
    override fun onDestroy() {
        listener = null
        removeWaiters()
        main.removeCallbacks(watchdog)
        if (wakeLock.isHeld) wakeLock.release()
        bluetooth.dispose()
        if (::engine.isInitialized) engine.destroy()
        super.onDestroy()
    }
}
