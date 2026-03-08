package com.appshub.bettbox.plugins

import android.os.Handler
import android.os.Looper
import com.appshub.bettbox.GlobalState
import com.appshub.bettbox.RunState
import com.appshub.bettbox.models.VpnOptions
import com.appshub.bettbox.modules.VpnResidualCleaner
import com.google.gson.Gson
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch


class ServicePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var flutterMethodChannel: MethodChannel

    companion object {
        private val activeChannels = mutableListOf<MethodChannel>()
        private val mainHandler = Handler(Looper.getMainLooper())

        fun notifyNetworkChanged() {
            mainHandler.post {
                activeChannels.toList().forEach { channel ->
                    try {
                        channel.invokeMethod("networkChanged", null)
                    } catch (e: Exception) {
                        android.util.Log.e("ServicePlugin", "networkChanged notify error: ${e.message}")
                    }
                }
            }
        }

        fun notifyQuickResponse() {
            mainHandler.post {
                activeChannels.toList().forEach { channel ->
                    try {
                        channel.invokeMethod("quickResponse", null)
                    } catch (e: Exception) {
                        android.util.Log.e("ServicePlugin", "quickResponse notify error: ${e.message}")
                    }
                }
            }
        }

        fun notifyVpnStartFailed() {
            mainHandler.post {
                activeChannels.toList().forEach { channel ->
                    try {
                        channel.invokeMethod("vpnStartFailed", null)
                    } catch (e: Exception) {
                        android.util.Log.e("ServicePlugin", "vpnStartFailed notify error: ${e.message}")
                    }
                }
            }
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        flutterMethodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "service")
        flutterMethodChannel.setMethodCallHandler(this)
        synchronized(activeChannels) {
            activeChannels.add(flutterMethodChannel)
        }
    }

    override fun onDetachedFromEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        flutterMethodChannel.setMethodCallHandler(null)
        synchronized(activeChannels) {
            activeChannels.remove(flutterMethodChannel)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startVpn" -> {
            val data = call.argument<String>("data")
            if (data == "null" || data == null) {
                result.error("INVALID_ARGUMENT", "options data is null", null)
            } else {
                val options = Gson().fromJson(data, VpnOptions::class.java)
                if (options != null) {
                    GlobalState.getCurrentVPNPlugin()?.handleStart(options)
                }
                result.success(true)
            }
        }

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
            val value = call.argument<Boolean>("value") ?: false
            GlobalState.isSmartStopped = value
            result.success(true)
        }

            "isSmartStopped" -> {
            result.success(GlobalState.isSmartStopped)
        }

            "getLocalIpAddresses" -> {
            result.success(GlobalState.getCurrentVPNPlugin()?.getLocalIpAddresses() ?: emptyList<String>())
        }

            "setQuickResponse" -> {
            val enabled = call.argument<Boolean>("enabled") ?: false
            VpnPlugin.setQuickResponse(enabled)
            result.success(true)
        }

            "checkAndCleanResidualVpn" -> {
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    val hasResidual = VpnResidualCleaner.isZombieTunAlive()
                    mainHandler.post { result.success(hasResidual) }
                } catch (e: Exception) {
                    mainHandler.post { result.error("CLEANUP_ERROR", e.message, null) }
                }
            }
        }

            "init" -> {
            GlobalState.getCurrentAppPlugin()
                ?.requestNotificationsPermission()
            GlobalState.initServiceEngine()
            result.success(true)
        }

            "isServiceEngineRunning" -> {
            result.success(GlobalState.isServiceEngineRunning())
        }
            
            "status" -> {
            result.success(GlobalState.currentRunState == RunState.START)
        }

            "reconnectIpc" -> {
            GlobalState.reconnectIpc()
            result.success(true)
        }

            "destroy" -> {
            handleDestroy()
            result.success(true)
        }

            else -> {
            result.notImplemented()
        }
        }
    }


    private fun handleDestroy() {
        GlobalState.destroyServiceEngine()
    }
}
