package com.pillxai.pillxai_client

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

/** Foreground discovery and pairing only; never sends dispenser commands. */
@Suppress("MissingPermission", "DEPRECATION")
class BluetoothSetup(private val context: Context) {
    private val main = Handler(Looper.getMainLooper())
    private val adapter get() = context.getSystemService(BluetoothManager::class.java)?.adapter
    private var pending: MethodChannel.Result? = null
    private var receiver: BroadcastReceiver? = null
    private var timeout: Runnable? = null
    private var discovering = false

    private fun listen(filter: IntentFilter, handler: (Intent) -> Unit) {
        val listener = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent != null) try { handler(intent) } catch (error: Exception) {
                    finish(error = error.message ?: "蓝牙操作失败，请重试。")
                }
            }
        }
        if (Build.VERSION.SDK_INT >= 33) context.registerReceiver(listener, filter, Context.RECEIVER_EXPORTED)
        else context.registerReceiver(listener, filter)
        receiver = listener
    }

    private fun finish(value: String? = null, error: String? = null) {
        val result = pending ?: return
        pending = null
        timeout?.let { main.removeCallbacks(it) }
        timeout = null
        receiver?.let { context.unregisterReceiver(it) }
        receiver = null
        if (discovering) try { adapter?.cancelDiscovery() } catch (_: SecurityException) {}
        discovering = false
        if (error != null) result.error("bluetooth_setup", error, null) else result.success(value)
    }

    private fun begin(result: MethodChannel.Result, action: (BluetoothAdapter) -> Unit) {
        if (pending != null) { result.error("busy", "正在处理设备，请稍候。", null); return }
        pending = result
        try {
            val bluetooth = adapter ?: error("此平板不支持蓝牙。")
            check(bluetooth.isEnabled) { "请先开启平板蓝牙，再重试。" }
            action(bluetooth)
        } catch (error: Exception) { finish(error = error.message ?: "蓝牙操作失败。") }
    }

    fun discover(result: MethodChannel.Result) = begin(result) { bluetooth ->
        val found = linkedMapOf<String, Map<String, Any>>()
        fun add(device: BluetoothDevice) {
            val name = device.name ?: return
            // Only names used by the confirmed dispensers; generic HC-06 modules
            // are not sufficient evidence that an unrelated device is a dispenser.
            if (!name.startsWith("PillDispenser", ignoreCase = true) &&
                !name.startsWith("dispenser", ignoreCase = true)) return
            found[device.address] = mapOf("address" to device.address, "name" to name,
                "paired" to (device.bondState == BluetoothDevice.BOND_BONDED))
        }
        bluetooth.bondedDevices.forEach { add(it) }
        bluetooth.cancelDiscovery()
        listen(IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_FOUND)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
        }) { intent ->
            if (intent.action == BluetoothDevice.ACTION_FOUND) {
                intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)?.let { add(it) }
            } else finish(JSONArray(found.values.toList()).toString())
        }
        discovering = true
        check(bluetooth.startDiscovery()) { "搜索未能开始，请稍后重试。" }
        timeout = Runnable { finish(JSONArray(found.values.toList()).toString()) }
        main.postDelayed(timeout!!, 16000L)
    }

    fun pair(address: String, result: MethodChannel.Result) = begin(result) { bluetooth ->
        require(BluetoothAdapter.checkBluetoothAddress(address)) { "设备地址无效，请重新搜索。" }
        val device = bluetooth.getRemoteDevice(address)
        bluetooth.cancelDiscovery()
        if (device.bondState == BluetoothDevice.BOND_BONDED) { finish("null"); return@begin }
        listen(IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_PAIRING_REQUEST)
            addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
        }) { intent ->
            val target = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
            if (target?.address == address) {
                if (intent.action == BluetoothDevice.ACTION_PAIRING_REQUEST &&
                    intent.getIntExtra(BluetoothDevice.EXTRA_PAIRING_VARIANT, -1) == BluetoothDevice.PAIRING_VARIANT_PIN) {
                    // Some Android builds still require a system confirmation.
                    try { device.setPin("1234".toByteArray(Charsets.US_ASCII)) } catch (_: SecurityException) {}
                } else if (intent.action == BluetoothDevice.ACTION_BOND_STATE_CHANGED) {
                    when (device.bondState) {
                        BluetoothDevice.BOND_BONDED -> finish("null")
                        BluetoothDevice.BOND_NONE -> finish(error = "配对未完成，请重试；默认配对码为 1234。")
                    }
                }
            }
        }
        timeout = Runnable { finish(error = "配对等待超时，请查看系统配对提示后重试；默认配对码为 1234。") }
        main.postDelayed(timeout!!, 60000L)
        if (device.bondState != BluetoothDevice.BOND_BONDING)
            check(device.createBond()) { "无法开始配对，请重试。" }
    }

    fun dispose() { finish(error = "页面已关闭，请重新添加设备。") }
}
