package com.appshub.bettbox.plugins

import android.os.Handler
import android.os.Looper
import com.appshub.bettbox.GlobalState
import com.appshub.bettbox.models.VpnOptions
import com.google.gson.Gson
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel


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

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) = when (call.method) {
        "startVpn" -> {
            val data = call.argument<String>("data")
            val options = Gson().fromJson(data, VpnOptions::class.java)
            GlobalState.getCurrentVPNPlugin()?.handleStart(options)
            result.success(true)
        }

        "stopVpn" -> {
            GlobalState.getCurrentVPNPlugin()?.handleStop()
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

        "getLocalIpAddresses" -> {
            result.success(GlobalState.getCurrentVPNPlugin()?.getLocalIpAddresses() ?: emptyList<String>())
        }

        "setQuickResponse" -> {
            val enabled = call.argument<Boolean>("enabled") ?: false
            VpnPlugin.setQuickResponse(enabled)
            result.success(true)
        }

        "init" -> {
            GlobalState.getCurrentAppPlugin()
                ?.requestNotificationsPermission()
            GlobalState.initServiceEngine()
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


    private fun handleDestroy() {
        GlobalState.destroyServiceEngine()
    }
}