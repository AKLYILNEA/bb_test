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
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return

        Log.i(TAG, "Self package replaced, checking for residual VPN state")

        try {
            if (VpnResidualCleaner.isZombieTunAlive()) {
                Log.i(TAG, "Zombie TUN detected, initiating cleanup...")
                
                VpnResidualCleaner.cleanResidualVpnState {
                    Log.i(TAG, "VPN residual cleanup completed")
                }
            } else {
                Log.i(TAG, "No zombie TUN detected")
            }

            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putBoolean(KEY_VPN_RUNNING, false)
                .putBoolean(KEY_TUN_RUNNING, false)
                .apply()
            
            Log.i(TAG, "VPN state flags cleared successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to handle package replace", e)
        }
    }
}
