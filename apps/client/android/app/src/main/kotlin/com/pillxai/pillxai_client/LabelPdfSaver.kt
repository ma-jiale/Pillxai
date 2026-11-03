package com.pillxai.pillxai_client

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class LabelPdfSaver(private val activity: Activity) {
    companion object { const val REQUEST = 6207 }
    private data class Pending(val bytes: ByteArray, val result: MethodChannel.Result)
    private var pending: Pending? = null

    fun save(call: MethodCall, result: MethodChannel.Result) {
        val bytes = call.argument<ByteArray>("bytes")
        if (pending != null || bytes == null) {
            result.error("save", "无法开始保存。", null)
            return
        }
        pending = Pending(bytes, result)
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/pdf"
            putExtra(Intent.EXTRA_TITLE, call.argument<String>("name"))
        }
        try {
            activity.startActivityForResult(intent, REQUEST)
        } catch (e: RuntimeException) {
            pending = null
            result.error("save", "无法打开系统保存窗口。", null)
        }
    }

    fun complete(code: Int, uri: Uri?) {
        val job = pending ?: return
        if (code != Activity.RESULT_OK || uri == null) {
            pending = null
            job.result.success(false)
            return
        }
        Thread {
            val saved = try {
                val stream = activity.contentResolver.openOutputStream(uri, "wt")
                    ?: throw IOException("No writable stream")
                stream.use { it.write(job.bytes) }
                true
            } catch (e: Exception) { false }
            activity.runOnUiThread {
                if (pending === job) {
                    pending = null
                    if (saved) job.result.success(true)
                    else job.result.error("save", "PDF 写入失败。", null)
                }
            }
        }.start()
    }

    fun dispose() {
        pending?.result?.error("detached", "保存窗口已关闭。", null)
        pending = null
    }
}
