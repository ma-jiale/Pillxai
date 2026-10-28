package com.pillxai.pillxai_client

import android.Manifest
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** RFCOMM byte transport only. No machine commands, reconnects or business state. */
class BluetoothConnection(private val context: Context) {
    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor()
    private val guard = Any()
    private val buffer = ByteArrayOutputStream()
    @Volatile private var socket: BluetoothSocket? = null
    @Volatile private var failure: String? = null
    private val adapter get() = context.getSystemService(BluetoothManager::class.java)?.adapter

    fun permitted(): Boolean = Build.VERSION.SDK_INT < 31 ||
        context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED

    @Suppress("MissingPermission")
    fun ports(): List<Map<String, String>> {
        if (!permitted()) return emptyList()
        return adapter?.bondedDevices?.sortedBy { it.address }?.map {
            mapOf("address" to it.address, "name" to (it.name ?: "蓝牙设备"))
        } ?: emptyList()
    }

    @Suppress("MissingPermission")
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "ports" -> result.success(ports())
                "close" -> { close(); result.success(null) }
                "read" -> {
                    failure?.let { throw IllegalStateException(it) }
                    check(socket != null) { "蓝牙未连接。" }
                    val bytes = synchronized(guard) { buffer.toByteArray().also { buffer.reset() } }
                    result.success(bytes)
                }
                "open" -> {
                    check(permitted()) { "请允许附近设备权限。" }
                    val bluetooth = adapter ?: error("此设备不支持经典蓝牙。")
                    check(bluetooth.isEnabled) { "请在系统设置中开启蓝牙。" }
                    val address = call.argument<String>("address") ?: error("请选择已配对设备。")
                    check(bluetooth.bondedDevices.any { it.address == address }) {
                        "请先在系统蓝牙设置中配对 HC-06，再选择该设备。"
                    }
                    close()
                    val next = bluetooth.getRemoteDevice(address).createRfcommSocketToServiceRecord(
                        UUID.fromString("00001101-0000-1000-8000-00805F9B34FB"))
                    socket = next
                    bounded(result, 10000L) {
                        next.connect()
                        check(socket === next) { "连接已取消。" }
                        Thread({ receive(next) }, "pillxai-rfcomm-reader").start()
                    }
                }
                "write" -> {
                    val bytes = call.arguments as ByteArray
                    val current = socket ?: error("蓝牙未连接。")
                    bounded(result, 3000L) {
                        failure?.let { error(it) }
                        check(socket === current) { "蓝牙连接已变化。" }
                        current.outputStream.write(bytes)
                        current.outputStream.flush()
                    }
                }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("bluetooth", error.message ?: "蓝牙操作失败。", null)
        }
    }

    private fun bounded(result: MethodChannel.Result, timeout: Long, action: () -> Unit) {
        val finished = AtomicBoolean(false)
        val timeoutAction = Runnable {
            if (finished.compareAndSet(false, true)) {
                close()
                failure = "蓝牙操作超时，结果未知；请核对现场，不会自动重发。"
                result.error("bluetooth_timeout", failure, null)
            }
        }
        main.postDelayed(timeoutAction, timeout)
        io.execute {
            val problem = try { action(); null } catch (error: Exception) { error }
            main.post {
                if (finished.compareAndSet(false, true)) {
                    main.removeCallbacks(timeoutAction)
                    if (problem == null) result.success(null)
                    else {
                        close()
                        failure = "蓝牙通信失败，请检查设备电源、连接及现场。"
                        result.error("bluetooth_io", failure, null)
                    }
                }
            }
        }
    }

    private fun receive(current: BluetoothSocket) {
        val chunk = ByteArray(4096)
        try {
            while (socket === current) {
                val count = current.inputStream.read(chunk)
                check(count >= 0) { "设备已断开。" }
                synchronized(guard) {
                    if (socket !== current) return
                    check(buffer.size() + count <= 65536) { "接收缓冲区已满。" }
                    buffer.write(chunk, 0, count)
                }
            }
        } catch (_: Exception) {
            synchronized(guard) {
                if (socket === current) {
                    failure = "蓝牙连接已中断，请停止投料并核对现场。"
                    try { current.close() } catch (_: Exception) {}
                }
            }
        }
    }

    fun close() {
        val current = socket
        socket = null
        try { current?.close() } catch (_: Exception) {}
        synchronized(guard) { buffer.reset(); failure = null }
    }

    fun dispose() { close(); io.shutdownNow() }
}
