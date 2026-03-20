package com.appshub.bettbox.modules

import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.util.Log
import com.appshub.bettbox.TempActivity
import com.appshub.bettbox.extensions.wrapAction

object VpnResidualCleaner {
    private const val TAG = "VpnResidualCleaner"

    fun forceCleanup(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            Log.d(TAG, "Skip cleanup: Android version < 15")
            return
        }

        Log.i(TAG, "Starting force cleanup for Android 15+")

        try {
            val prepareIntent = VpnService.prepare(context)
            if (prepareIntent != null) {
                Log.w(TAG, "VpnService.prepare() returned non-null, VPN permission needed")
            } else {
                Log.d(TAG, "VpnService.prepare() succeeded, system VPN state cleared")
            }
        } catch (e: Exception) {
            Log.e(TAG, "VpnService.prepare() failed: ${e.message}")
        }

        try {
            val stopIntent = Intent(context, TempActivity::class.java).apply {
                action = context.wrapAction("STOP")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_MULTIPLE_TASK
            }
            context.startActivity(stopIntent)
            Log.i(TAG, "TempActivity STOP triggered")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start TempActivity: ${e.message}")
        }
    }
}
