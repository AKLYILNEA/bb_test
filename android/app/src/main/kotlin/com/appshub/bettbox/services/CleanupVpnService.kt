package com.appshub.bettbox.services

import android.net.VpnService
import android.util.Log

class CleanupVpnService : VpnService() {
    companion object {
        private const val TAG = "CleanupVpnService"
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "CleanupVpnService created")
    }

    override fun onStartCommand(intent: android.content.Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "CleanupVpnService started")
        
        try {
            val builder = Builder()
                .setSession("bettbox_cleanup")
                .addAddress("10.255.255.254", 30)
            
            val interface_ = builder.establish()
            if (interface_ != null) {
                Log.d(TAG, "Temporary VPN interface established for cleanup")
                interface_.close()
                Log.d(TAG, "Temporary VPN interface closed")
            } else {
                Log.w(TAG, "Failed to establish temporary VPN interface")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error during cleanup VPN setup: ${e.message}")
        }
        
        stopSelf()
        
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "CleanupVpnService destroyed")
    }
}
