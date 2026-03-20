package com.appshub.bettbox.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.appshub.bettbox.modules.VpnResidualCleaner

class PackageReplacedReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "PackageReplacedReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        
        val pendingResult = goAsync()
        try {
            Log.i(TAG, "Package replaced, triggering VPN cleanup for Android 15+")
            
            VpnResidualCleaner.forceCleanup(context)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to handle package replace", e)
        } finally {
            pendingResult.finish()
        }
    }
}
