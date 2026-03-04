package com.appshub.bettbox.plugins

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.appshub.bettbox.BettboxApplication
import com.appshub.bettbox.GlobalState
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
        private var activeChannel: MethodChannel? = null
        private val mainHandler = Handler(Looper.getMainLooper())

        fun notifyNetworkChanged() {
            mainHandler.post {
                try {
                    activeChannel?.invokeMethod("networkChanged", null)
                } catch (e: Exception) {
                    android.util.Log.e("ServicePlugin", "networkChanged notify error: ${e.message}")
                }
            }
        }

        fun notifyQuickResponse() {
            mainHandler.post {
                try {
                    activeChannel?.invokeMethod("quickResponse", null)
                } catch (e: Exception) {
                    android.util.Log.e("ServicePlugin", "quickResponse notify error: ${e.message}")
                }
            }
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        flutterMethodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "service")
        flutterMethodChannel.setMethodCallHandler(this)
        activeChannel = flutterMethodChannel
    }

    override fun onDetachedFromEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        flutterMethodChannel.setMethodCallHandler(null)
        if (activeChannel == flutterMethodChannel) {
            activeChannel = null
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
                    val context = BettboxApplication.getAppContext()
                    val prefs = context.getSharedPreferences(
                        "FlutterSharedPreferences", Context.MODE_PRIVATE
                    )
                    val flaggedForCleanup = prefs.getBoolean("flutter.needs_tun_cleanup", false)
                    val cleanupStartTime = prefs.getLong("flutter.cleanup_start_time", 0)
                    val timeSinceCleanup = System.currentTimeMillis() - cleanupStartTime
                    if (flaggedForCleanup && timeSinceCleanup < 3000) {
                        delay(500)
                    }
                    var hasResidual = VpnResidualCleaner.isZombieTunAlive()
                    if (hasResidual) {
                        VpnResidualCleaner.cleanResidualVpnStateSync()
                        hasResidual = VpnResidualCleaner.isZombieTunAlive()
                        if (hasResidual) {
                            delay(300)
                            VpnResidualCleaner.cleanResidualVpnStateSync()
                            hasResidual = VpnResidualCleaner.isZombieTunAlive()
                        }
                    }
                    prefs.edit().putBoolean("flutter.needs_tun_cleanup", false).apply()
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
