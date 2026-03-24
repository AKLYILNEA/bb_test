package com.appshub.bettbox.modules

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.core.content.getSystemService
import com.appshub.bettbox.core.Core

class SuspendModule(private val context: Context) {
    companion object {
        private const val TAG = "SuspendModule"
    }

    private var isInstalled = false
    private var isSuspended = false

    private val powerManager: PowerManager? by lazy { context.getSystemService<PowerManager>() }

    private fun isScreenOn(): Boolean = powerManager?.isInteractive ?: true

    private val isDeviceIdleMode: Boolean
        get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && powerManager?.isDeviceIdleMode == true

    private fun updateSuspendState() {
        val screenOn = isScreenOn()
        val deviceIdle = isDeviceIdleMode

        Log.d(TAG, "updateSuspendState - screenOn: $screenOn, deviceIdle: $deviceIdle, isSuspended: $isSuspended")

        when {
            !screenOn && deviceIdle && !isSuspended -> {
                Log.i(TAG, "Entering Doze - Suspending core")
                Core.suspended(true)
                isSuspended = true
            }
            (screenOn || !deviceIdle) && isSuspended -> {
                Log.i(TAG, "Exiting Doze (screenOn: $screenOn, deviceIdle: $deviceIdle) - Resuming core")
                Core.suspended(false)
                isSuspended = false
            }
        }
    }

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_ON, Intent.ACTION_SCREEN_OFF,
                PowerManager.ACTION_DEVICE_IDLE_MODE_CHANGED -> {
                    Log.d(TAG, "Received ${intent.action}")
                    updateSuspendState()
                }
            }
        }
    }

    fun install() {
        if (isInstalled) return
        isInstalled = true
        isSuspended = false

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                addAction(PowerManager.ACTION_DEVICE_IDLE_MODE_CHANGED)
            }
        }
        context.registerReceiver(receiver, filter)
        updateSuspendState()
        Log.i(TAG, "SuspendModule installed - SDK: ${Build.VERSION.SDK_INT}")
    }

    fun uninstall() {
        if (!isInstalled) return
        isInstalled = false

        runCatching {
            context.unregisterReceiver(receiver)
            if (isSuspended) {
                Log.i(TAG, "Uninstalling - Resume from suspend")
                Core.suspended(false)
                isSuspended = false
            }
        }.onFailure { Log.w(TAG, "Failed to unregister receiver: ${it.message}") }
        Log.i(TAG, "SuspendModule uninstalled")
    }
}
