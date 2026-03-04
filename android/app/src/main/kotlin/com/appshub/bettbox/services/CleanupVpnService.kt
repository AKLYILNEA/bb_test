package com.appshub.bettbox.services

import android.app.Notification
import android.net.VpnService
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.appshub.bettbox.GlobalState
import com.appshub.bettbox.R

class CleanupVpnService : VpnService() {
    companion object {
        private const val TAG = "CleanupVpnService"
        private const val NOTIFICATION_ID = 999
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "CleanupVpnService created")
    }

    override fun onStartCommand(intent: android.content.Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "CleanupVpnService started")
        startForeground()
        Thread { cleanup() }.start()
        return START_NOT_STICKY
    }

    private fun startForeground() {
        ensureNotificationChannel()
        val notification = NotificationCompat.Builder(this, GlobalState.NOTIFICATION_CHANNEL)
            .setSmallIcon(R.drawable.ic)
            .setContentTitle("Bettbox")
            .setContentText("Bettbox Cleaning")
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setOngoing(true)
            .setSilent(true)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            try {
                startForeground(NOTIFICATION_ID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED)
            } catch (_: Exception) {
                startForeground(NOTIFICATION_ID, notification)
            }
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun cleanup() {
        try {
            val builder = Builder()
                .setSession("bettbox_cleanup")
                .addAddress("10.255.255.254", 30)
            val interface_ = builder.establish()
            if (interface_ != null) {
                Log.d(TAG, "VPN interface established for cleanup")
                interface_.close()
                Log.d(TAG, "VPN interface closed")
            } else {
                Log.w(TAG, "Failed to establish VPN interface")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Cleanup error: ${e.message}")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        }
        stopSelf()
    }

    override fun onDestroy() {
        Log.d(TAG, "CleanupVpnService destroyed")
        super.onDestroy()
    }
}
