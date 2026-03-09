package com.appshub.bettbox.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.appshub.bettbox.GlobalState
import com.appshub.bettbox.RunState
import com.appshub.bettbox.modules.VpnResidualCleaner
import com.appshub.bettbox.services.BettboxService
import com.appshub.bettbox.services.BettboxVpnService

class PackageReplacedReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "PackageReplacedReceiver"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_VPN_RUNNING = "flutter.is_vpn_running"
        private const val KEY_TUN_RUNNING = "flutter.is_tun_running"
        private const val KEY_NEEDS_TUN_CLEANUP = "flutter.needs_tun_cleanup"
        private const val KEY_VPN_RUNNING_BEFORE_UPGRADE = "flutter.vpn_running_before_upgrade"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        val pendingResult = goAsync()
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val wasVpnRunning =
                prefs.getBoolean(KEY_VPN_RUNNING, false) ||
                prefs.getBoolean(KEY_TUN_RUNNING, false)
            val hasResidualTun = VpnResidualCleaner.hasAnyTunInterface()
            val needsCleanup = wasVpnRunning || hasResidualTun

            Log.i(
                TAG,
                "Package replaced, vpnBeforeUpgrade=$wasVpnRunning, residualTun=$hasResidualTun, needsCleanup=$needsCleanup"
            )

            context.stopService(Intent(context, BettboxVpnService::class.java))
            context.stopService(Intent(context, BettboxService::class.java))
            GlobalState.isSmartStopped = false
            GlobalState.updateRunState(RunState.STOP)
            GlobalState.destroyServiceEngine()

            prefs.edit()
                .putBoolean(KEY_VPN_RUNNING, false)
                .putBoolean(KEY_TUN_RUNNING, false)
                .putBoolean(KEY_VPN_RUNNING_BEFORE_UPGRADE, wasVpnRunning)
                .putBoolean(KEY_NEEDS_TUN_CLEANUP, needsCleanup)
                .apply()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to handle package replace", e)
        } finally {
            pendingResult.finish()
        }
    }
}
