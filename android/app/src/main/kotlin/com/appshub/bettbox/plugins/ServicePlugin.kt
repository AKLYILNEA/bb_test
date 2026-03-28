package com.appshub.bettbox.plugins

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.appshub.bettbox.GlobalState
import com.appshub.bettbox.RunState
import com.appshub.bettbox.models.VpnOptions
import com.google.gson.Gson
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class ServicePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel

    companion object {
        private val activeChannels = mutableListOf<MethodChannel>()
        private val mainHandler = Handler(Looper.getMainLooper())
        private const val TAG = "ServicePlugin"

        private fun notify(method: String) {
            mainHandler.post {
                activeChannels.toList().forEach { ch ->
                    runCatching { ch.invokeMethod(method, null) }
                        .onFailure { Log.e(TAG, "$method notify error: ${it.message}") }
                }
            }
        }

        fun notifyNetworkChanged() = notify("networkChanged")
        fun notifyQuickResponse() = notify("quickResponse")
        fun notifyVpnStartFailed() = notify("vpnStartFailed")
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "service").apply {
            setMethodCallHandler(this@ServicePlugin)
        }
        synchronized(activeChannels) { activeChannels.add(channel) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        synchronized(activeChannels) { activeChannels.remove(channel) }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startVpn" -> handleStartVpn(call, result)
            "stopVpn" -> {
                VpnPlugin.handleStop(force = true)
                result.success(true)
            }
            "smartStop" -> {
                GlobalState.getCurrentVPNPlugin()?.handleSmartStop()
                result.success(true)
            }
            "smartResume" -> {
                val data = call.argument<String>("data")
                val options = Gson().fromJson(data, VpnOptions::class.java)
                GlobalState.getCurrentVPNPlugin()?.handleSmartResume(options)
                result.success(true)
            }
            "setSmartStopped" -> {
                GlobalState.isSmartStopped = call.argument<Boolean>("value") ?: false
                result.success(true)
            }
            "isSmartStopped" -> result.success(GlobalState.isSmartStopped)
            "getLocalIpAddresses" -> result.success(GlobalState.getCurrentVPNPlugin()?.getLocalIpAddresses().orEmpty())
            "setQuickResponse" -> {
                VpnPlugin.setQuickResponse(call.argument<Boolean>("enabled") ?: false)
                result.success(true)
            }
            "init" -> {
                GlobalState.getCurrentAppPlugin()?.requestNotificationsPermission()
                GlobalState.initServiceEngine()
                result.success(true)
            }
            "isServiceEngineRunning" -> result.success(GlobalState.isServiceEngineRunning())
            "status" -> result.success(GlobalState.currentRunState == RunState.START)
            "reconnectIpc" -> {
                GlobalState.reconnectIpc()
                result.success(true)
            }
            "destroy" -> {
                GlobalState.destroyServiceEngine()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun handleStartVpn(call: MethodCall, result: MethodChannel.Result) {
        val data = call.argument<String>("data")
        if (data.isNullOrBlank() || data == "null") {
            result.error("INVALID_ARGUMENT", "options data is null", null)
            return
        }
        runCatching { Gson().fromJson(data, VpnOptions::class.java) }
            .onSuccess { options ->
                GlobalState.getCurrentVPNPlugin()?.handleStart(options)
                result.success(true)
            }
            .onFailure { result.error("PARSE_ERROR", it.message, null) }
    }
}
