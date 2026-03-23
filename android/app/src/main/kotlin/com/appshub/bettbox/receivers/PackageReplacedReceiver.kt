package com.appshub.bettbox.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.appshub.bettbox.GlobalState
import com.appshub.bettbox.RunState
import com.appshub.bettbox.services.BettboxVpnService

class PackageReplacedReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "PackageReplacedReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return

        val pendingResult = goAsync()
        try {
            val stopIntent = Intent(context, BettboxVpnService::class.java).apply {
                action = "ACTION_FORCE_STOP"
            }
            context.startService(stopIntent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send force stop signal", e)
            context.stopService(Intent(context, BettboxVpnService::class.java))
            runCatching { com.appshub.bettbox.core.Core.stopTun() }
        } finally {
            pendingResult.finish()
        }
    }
}