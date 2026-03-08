package com.appshub.bettbox.services

import android.annotation.SuppressLint
import android.app.Notification
import android.app.Notification.FOREGROUND_SERVICE_IMMEDIATE
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
import android.os.Build
import androidx.core.app.NotificationCompat
import com.appshub.bettbox.GlobalState
import com.appshub.bettbox.MainActivity
import com.appshub.bettbox.R
import com.appshub.bettbox.extensions.getActionPendingIntent
import com.appshub.bettbox.models.VpnOptions
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async

interface BaseServiceInterface {

    suspend fun start(options: VpnOptions): Int

    fun stop()

    suspend fun startForeground(title: String, content: String)
}

fun Service.createBettboxNotificationBuilder(): Deferred<NotificationCompat.Builder> =
    CoroutineScope(Dispatchers.Main).async {
        // 检测启用的 Activity
        val packageManager = packageManager
        val defaultComponent = android.content.ComponentName(
            packageName,
            "com.appshub.bettbox.MainActivity"
        )
        val lightComponent = android.content.ComponentName(
            packageName,
            "com.appshub.bettbox.MainActivityLight"
        )
        
        // 获取 Activity 状态
        val defaultState = try {
            packageManager.getComponentEnabledSetting(defaultComponent)
        } catch (e: Exception) {
            android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_DEFAULT
        }
        
        val lightState = try {
            packageManager.getComponentEnabledSetting(lightComponent)
        } catch (e: Exception) {
            android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_DEFAULT
        }
        
        // 选择目标 Activity
        val targetComponent = when {
            // Light 启用
            lightState == android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> {
                android.util.Log.d("Notification", "Using MainActivityLight (ENABLED)")
                lightComponent
            }
            // Light 禁用
            lightState == android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_DISABLED -> {
                android.util.Log.d("Notification", "Using MainActivity (Light DISABLED)")
                defaultComponent
            }
            // Default 启用
            defaultState == android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> {
                android.util.Log.d("Notification", "Using MainActivity (ENABLED)")
                defaultComponent
            }
            // Default 禁用
            defaultState == android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_DISABLED -> {
                android.util.Log.d("Notification", "Using MainActivityLight (Default DISABLED)")
                lightComponent
            }
            // 检查 Manifest
            else -> {
                try {
                    // 检查 Light Activity
                    val lightActivityInfo = packageManager.getActivityInfo(lightComponent, 0)
                    if (lightActivityInfo.enabled) {
                        android.util.Log.d("Notification", "Using MainActivityLight (Manifest enabled)")
                        lightComponent
                    } else {
                        android.util.Log.d("Notification", "Using MainActivity (Manifest default)")
                        defaultComponent
                    }
                } catch (e: Exception) {
                    android.util.Log.d("Notification", "Using MainActivity (fallback)")
                    defaultComponent
                }
            }
        }
        
        // 构建 Intent
        val intent = Intent().apply {
            component = targetComponent
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            // 确保可靠打开
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        
        android.util.Log.d("Notification", "Created intent for: ${targetComponent.className}")

        val pendingIntent = if (Build.VERSION.SDK_INT >= 31) {
            PendingIntent.getActivity(
                this@createBettboxNotificationBuilder,
                0,
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
        } else {
            PendingIntent.getActivity(
                this@createBettboxNotificationBuilder, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT
            )
        }

        with(
            NotificationCompat.Builder(
                this@createBettboxNotificationBuilder, GlobalState.NOTIFICATION_CHANNEL
            )
        ) {
            // 通知图标
            setSmallIcon(R.drawable.ic)
            setContentTitle("Bettbox")
            setContentIntent(pendingIntent)
            setCategory(NotificationCompat.CATEGORY_SERVICE)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                foregroundServiceBehavior = FOREGROUND_SERVICE_IMMEDIATE
            }
            setOngoing(true)
            setShowWhen(false)
            setOnlyAlertOnce(true)
        }
    }

// Check if Light icon is enabled
private fun Service.isLightIconEnabled(): Boolean {
    return try {
        val lightComponent = android.content.ComponentName(
            packageName,
            "com.appshub.bettbox.MainActivityLight"
        )
        val state = packageManager.getComponentEnabledSetting(lightComponent)
        state == android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_ENABLED
    } catch (e: Exception) {
        false
    }
}

fun Service.ensureNotificationChannel() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        val manager = getSystemService(NotificationManager::class.java)
        var channel = manager?.getNotificationChannel(GlobalState.NOTIFICATION_CHANNEL)
        if (channel == null) {
            channel = NotificationChannel(
                GlobalState.NOTIFICATION_CHANNEL, "SERVICE_CHANNEL", NotificationManager.IMPORTANCE_LOW
            )
            manager?.createNotificationChannel(channel)
        }
    }
}


@SuppressLint("ForegroundServiceType")
fun Service.startForeground(notification: Notification) {
    ensureNotificationChannel()
    try {
        val sdkInt = Build.VERSION.SDK_INT
        
        if (sdkInt >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) { // API 34 及以上 (Android 14+)
            val foregroundServiceType = if (this is android.net.VpnService) {
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC or 1024
            } else {
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            }
            
            startForeground(
                GlobalState.NOTIFICATION_ID, 
                notification, 
                foregroundServiceType
            )
        } 
        else if (sdkInt >= Build.VERSION_CODES.Q) { 
            startForeground(
                GlobalState.NOTIFICATION_ID, 
                notification, 
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } 
        else { 
            startForeground(GlobalState.NOTIFICATION_ID, notification)
        }
    } catch (e: Exception) {
        android.util.Log.e("BaseServiceInterface", "startForeground failed: ${e.message}")
        try {
            startForeground(GlobalState.NOTIFICATION_ID, notification)
        } catch (e2: Exception) {
            android.util.Log.e("BaseServiceInterface", "Final fallback failed: ${e2.message}")
        }
    }
}
