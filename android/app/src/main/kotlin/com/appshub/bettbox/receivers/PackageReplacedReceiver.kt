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
            Log.d(TAG, "App updated. Resetting VPN states.")
            
            GlobalState.updateIsStopping(false)
            GlobalState.updateRunState(RunState.STOP)
            
            val sp = context.getSharedPreferences("vpn_state", Context.MODE_PRIVATE)
            sp.edit().remove("stop_lock_ts").apply()

        } catch (e: Exception) {
            Log.e(TAG, "Failed to reset state after package replaced", e)
        } finally {
            pendingResult.finish()
        }
    }
}