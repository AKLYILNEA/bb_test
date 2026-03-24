package com.appshub.bettbox.plugins

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class TilePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        private const val TAG = "TilePlugin"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "tile").apply {
            setMethodCallHandler(this@TilePlugin)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        safeInvokeMethod("detached")
        channel.setMethodCallHandler(null)
    }

    fun handleStart() = safeInvokeMethod("start")
    fun handleStop() = safeInvokeMethod("stop")
    fun handleReconnectIpc() = safeInvokeMethod("reconnectIpc")

    private fun safeInvokeMethod(method: String) {
        mainHandler.post {
            runCatching { channel.invokeMethod(method, null) }
                .onFailure { Log.e(TAG, "Failed to invoke $method: ${it.message}") }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) = result.notImplemented()
}
