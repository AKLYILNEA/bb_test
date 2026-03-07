package com.appshub.bettbox.plugins

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class TilePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "tile")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        handleDetached()
        channel.setMethodCallHandler(null)
    }

    fun handleStart() {
        safeInvokeMethod("start")
    }

    fun handleStop() {
        safeInvokeMethod("stop")
    }

    fun handleReconnectIpc() {
        safeInvokeMethod("reconnectIpc")
    }

    private fun handleDetached() {
        safeInvokeMethod("detached")
    }

    private fun safeInvokeMethod(method: String) {
        mainHandler.post {
            try {
                channel.invokeMethod(method, null)
            } catch (e: Exception) {
                android.util.Log.e("TilePlugin", "Failed to invoke $method: ${e.message}")
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        result.notImplemented()
    }
}