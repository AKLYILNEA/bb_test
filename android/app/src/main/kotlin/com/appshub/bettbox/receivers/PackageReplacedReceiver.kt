package com.appshub.bettbox.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.appshub.bettbox.modules.VpnResidualCleaner

class PackageReplacedReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "PackageReplacedReceiver"
        private const val PREFS_NAME = "FlutterSharedPreferences"

        private const val KEY_VPN_RUNNING = "flutter.is_vpn_running"
        private const val KEY_TUN_RUNNING = "flutter.is_tun_running"
        private const val KEY_NEEDS_TUN_CLEANUP = "flutter.needs_tun_cleanup"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return

        val pendingResult = goAsync()

        try {
            Log.i(TAG, "Self package replaced, checking for residual VPN state")

            val hasZombieTun = VpnResidualCleaner.isZombieTunAlive()
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

            prefs.edit()
                .putBoolean(KEY_VPN_RUNNING, false)
                .putBoolean(KEY_TUN_RUNNING, false)
                .putBoolean(KEY_NEEDS_TUN_CLEANUP, hasZombieTun)
                .apply()

            if (hasZombieTun) {
                Log.i(TAG, "Zombie TUN detected, flagged for cleanup on next APP launch")
            } else {
                Log.i(TAG, "No zombie TUN detected")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to handle package replace", e)
        } finally {
            pendingResult.finish()
        }
    }
}
