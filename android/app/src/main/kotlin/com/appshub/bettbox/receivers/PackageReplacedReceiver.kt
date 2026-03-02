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
            Log.i(TAG, "Self package replaced, cleaning up stale state")

            // Destroy Service Engine so the new APP launch recreates it cleanly.
            // This ensures Go Core listener uses the new .so, not the stale one.
            GlobalState.destroyServiceEngine()

            // Reset VPN state flags
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putBoolean(KEY_VPN_RUNNING, false)
                .putBoolean(KEY_TUN_RUNNING, false)
                .apply()

            // Flag zombie TUN for cleanup on next APP launch (foreground context)
            if (VpnResidualCleaner.isZombieTunAlive()) {
                Log.i(TAG, "Zombie TUN detected, flagged for cleanup on next APP launch")
                prefs.edit().putBoolean("needs_tun_cleanup", true).apply()
            }

            Log.i(TAG, "Package replaced cleanup done")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to handle package replace", e)
        } finally {
            pendingResult.finish()
        }
    }
}
