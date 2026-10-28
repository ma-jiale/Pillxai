package com.pillxai.pillxai_client

import android.Manifest
import android.content.*
import android.content.pm.PackageManager
import android.os.Build
import android.os.IBinder
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private var service: TerminalService? = null
    private var binding = false
    private var visible = false
    private lateinit var terminal: MethodChannel
    private val initializers = mutableListOf<MethodChannel.Result>()
    private var permissionContinuation: (() -> Unit)? = null
    private var permissionResult: MethodChannel.Result? = null
    private var resumePermissionAction: (() -> Unit)? = null
    private var resumePermissionResult: MethodChannel.Result? = null
    private val bluetoothSetup by lazy { BluetoothSetup(this) }
    private var requestedPermissions = emptyList<String>()

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            service = (binder as TerminalService.LocalBinder).service
            service!!.listener = { terminal.invokeMethod("update", it) }
            initializers.toList().forEach { service!!.awaitReady(it) }
            initializers.clear()
        }
        override fun onServiceDisconnected(name: ComponentName?) {
            service = null
            terminal.invokeMethod("update", JSONObject().put("worker_error",
                "本机服务已中断，请重新打开应用并核对现场；不会自动重发。").toString())
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        terminal = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pillxai/terminal")
        terminal.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    val current = service
                    if (current != null) current.awaitReady(result)
                    else {
                        initializers.add(result)
                        if (!binding) {
                            binding = bindService(Intent(this, TerminalService::class.java), connection, BIND_AUTO_CREATE)
                            if (!binding) {
                                initializers.toList().forEach { it.error("terminal", "无法启动本机服务。", null) }
                                initializers.clear()
                            }
                        }
                    }
                }
                "command" -> {
                    val arguments = call.arguments as Map<*, *>
                    val operation = arguments["operation"] as String
                    val run = {
                        when (operation) {
                            "request_access" -> result.success("null")
                            "discover_devices", "pair_device" -> {
                                val snapshot = JSONObject(service?.latest ?: "{}")
                                if (!snapshot.isNull("task") || !snapshot.isNull("claim_intent")) {
                                    result.error("busy", "请先完成当前摆药，再添加设备。", null)
                                } else if (operation == "discover_devices") bluetoothSetup.discover(result)
                                else bluetoothSetup.pair((arguments["data"] as Map<*, *>)["address"] as String, result)
                            }
                            else -> dispatch(arguments, result)
                        }
                    }
                    if (operation in listOf("connect", "request_access", "discover_devices", "pair_device"))
                        withPermissions(result, operation in listOf("discover_devices", "pair_device"), run)
                    else run()
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pillxai/window")
            .setMethodCallHandler { call, result ->
                if (call.method == "background") {
                    moveTaskToBack(true)
                    result.success(null)
                } else if (call.method == "close") {
                    val snapshot = JSONObject(service?.latest ?: "{}")
                    if (!snapshot.isNull("task") || !snapshot.isNull("claim_intent")) {
                        result.error("busy", "本机仍有任务，请登录原账号并核对现场后结束。", null)
                    } else {
                        result.success(null)
                        finishAndRemoveTask()
                    }
                } else result.notImplemented()
            }
    }

    private fun dispatch(arguments: Map<*, *>, result: MethodChannel.Result) {
        val current = service
        if (current == null) { result.error("terminal", "本机服务未连接，请重新打开应用。", null); return }
        current.command(arguments, object : MethodChannel.Result {
            override fun success(value: Any?) {
                result.success(value)
                if (arguments["operation"] == "shutdown") detach()
            }
            override fun error(code: String, message: String?, details: Any?) = result.error(code, message, details)
            override fun notImplemented() = result.notImplemented()
        })
    }

    private fun withPermissions(result: MethodChannel.Result, scanning: Boolean, action: () -> Unit) {
        if (!visible) { result.error("background", "请回到应用后连接设备。", null); return }
        if (permissionContinuation != null || resumePermissionAction != null) { result.error("permission", "请先处理系统权限提示。", null); return }
        val permissions = mutableListOf<String>()
        if (scanning) {
            val scan = if (Build.VERSION.SDK_INT >= 31) Manifest.permission.BLUETOOTH_SCAN
                else Manifest.permission.ACCESS_FINE_LOCATION
            if (checkSelfPermission(scan) != PackageManager.PERMISSION_GRANTED) permissions.add(scan)
        }
        if (Build.VERSION.SDK_INT >= 31 && checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED)
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED)
            permissions.add(Manifest.permission.POST_NOTIFICATIONS)
        if (permissions.isEmpty()) action()
        else {
            permissionContinuation = action
            permissionResult = result
            requestedPermissions = permissions.filter { it != Manifest.permission.POST_NOTIFICATIONS }
            requestPermissions(permissions.toTypedArray(), 6206)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != 6206) return
        val action = permissionContinuation
        val result = permissionResult
        permissionContinuation = null
        permissionResult = null
        if (requestedPermissions.any { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED })
            result?.error("permission", "附近设备权限未允许，请在应用权限中开启后重试。", null)
        else if (!visible) {
            resumePermissionAction = action
            resumePermissionResult = result
        }
        else action?.invoke()
        // Notification denial does not prohibit a connected-device foreground service.
    }

    override fun onResume() {
        super.onResume()
        visible = true
        val action = resumePermissionAction
        resumePermissionAction = null
        resumePermissionResult = null
        action?.invoke()
    }
    override fun onPause() { visible = false; super.onPause() }
    private fun detach() {
        service?.listener = null
        service?.removeWaiters()
        service = null
        if (binding) { unbindService(connection); binding = false }
    }
    override fun onDestroy() {
        bluetoothSetup.dispose()
        permissionResult?.error("detached", "界面已关闭，请重新操作。", null)
        resumePermissionResult?.error("detached", "界面已关闭，请重新操作。", null)
        initializers.toList().forEach { it.error("detached", "界面已关闭。", null) }
        initializers.clear()
        detach()
        super.onDestroy()
    }
}
