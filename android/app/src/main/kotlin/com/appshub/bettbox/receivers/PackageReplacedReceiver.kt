package com.appshub.bettbox.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.appshub.bettbox.GlobalState
import com.appshub.bettbox.modules.VpnResidualCleaner

class PackageReplacedReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "PackageReplacedReceiver"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_VPN_RUNNING = "flutter.is_vpn_running"
        private const val KEY_TUN_RUNNING = "flutter.is_tun_running"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        val pendingResult = goAsync()
        try {
            Log.i(TAG, "Package replaced, cleaning up")
            GlobalState.destroyServiceEngine()
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putBoolean(KEY_VPN_RUNNING, false)
                .putBoolean(KEY_TUN_RUNNING, false)
                .apply()
            if (VpnResidualCleaner.isZombieTunAlive()) {
                Log.i(TAG, "Zombie TUN detected, will be cleaned on next VPN start")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to handle package replace", e)
        } finally {
            pendingResult.finish()
        }
    }
}
