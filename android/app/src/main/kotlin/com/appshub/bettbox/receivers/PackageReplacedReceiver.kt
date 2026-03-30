package com.appshub.bettbox.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.appshub.bettbox.GlobalState
import com.appshub.bettbox.RunState

class PackageReplacedReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "PackageReplacedReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        val pending = goAsync()
        runCatching {
            Log.d(TAG, "App updated, resetting states.")
            GlobalState.updateIsStopping(false)
            GlobalState.updateRunState(RunState.STOP)
            android.net.VpnService.prepare(context)
            context.getSharedPreferences("vpn_state", Context.MODE_PRIVATE).edit().remove("stop_lock_ts").apply()
        }.onFailure { Log.e(TAG, "Reset failed", it) }
        pending.finish()
    }
}