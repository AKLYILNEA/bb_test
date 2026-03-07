package com.appshub.bettbox.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.appshub.bettbox.GlobalState

/**
 * Boot receiver to handle auto-launch functionality on device boot
 *
 * Instead of launching the UI (which is blocked on Android 10+),
 * it silently initializes the service engine in the background.
 */
class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootReceiver"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val AUTO_LAUNCH_KEY = "flutter.autoLaunch"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) {
            return
        }

        Log.d(TAG, "Device boot completed, checking autoLaunch setting")

        try {
            // Read autoLaunch setting from SharedPreferences
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val autoLaunch = prefs.getBoolean(AUTO_LAUNCH_KEY, false)

            Log.d(TAG, "AutoLaunch setting: $autoLaunch")

            if (autoLaunch) {
                Log.d(TAG, "AutoLaunch enabled, triggering silent background boot")

                // Use GlobalState to initialize the background Flutter engine.
                // This bypasses the Android 10+ background activity restriction
                // and provides a smoother user experience.
                // We pass "boot" flag to distinguish from Tile start.
                GlobalState.initServiceEngine(listOf("boot"))
                
                Log.d(TAG, "Service engine initialization with 'boot' flag requested")
            } else {
                Log.d(TAG, "AutoLaunch disabled, skipping background boot")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in BootReceiver", e)
        }
    }
}
