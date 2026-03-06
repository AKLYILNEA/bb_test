package com.appshub.bettbox.services

import android.annotation.SuppressLint
import android.content.Intent
import android.net.ProxyInfo
import android.net.VpnService
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.os.Parcel
import android.os.RemoteException
import android.util.Log
import androidx.core.app.NotificationCompat
import com.appshub.bettbox.GlobalState
import com.appshub.bettbox.plugins.VpnPlugin
import com.appshub.bettbox.extensions.getIpv4RouteAddress
import com.appshub.bettbox.extensions.getIpv6RouteAddress
import com.appshub.bettbox.extensions.toCIDR
import com.appshub.bettbox.models.AccessControlMode
import com.appshub.bettbox.models.VpnOptions
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch


class BettboxVpnService : VpnService(), BaseServiceInterface {
    override fun onCreate() {
        super.onCreate()
        GlobalState.initServiceEngine()
    }

    override suspend fun start(options: VpnOptions): Int {
        if (com.appshub.bettbox.modules.VpnResidualCleaner.isZombieTunAlive()) {
            try {
                Log.d("BettboxVpnService", "Found zombie TUN, applying cleanup profile")
                val builder = Builder()
                    .setSession("bettbox_cleanup")
                    .addAddress("10.255.255.254", 30)
                val interface_ = builder.establish()
                interface_?.close()
                Log.d("BettboxVpnService", "Cleanup profile closed, waiting for system to remove interface")
                
                var retryCount = 0
                while (retryCount < 10) {
                    kotlinx.coroutines.delay(200)
                    retryCount++
                    if (!com.appshub.bettbox.modules.VpnResidualCleaner.isZombieTunAlive()) {
                        Log.d("BettboxVpnService", "Zombie TUN disappeared")
                        break
                    }
                }
            } catch (e: Exception) {
                Log.e("BettboxVpnService", "Cleanup error: ${e.message}")
            }
        }

        return with(Builder()) {
            if (options.ipv4Address.isNotEmpty()) {
                val cidr = options.ipv4Address.toCIDR()
                addAddress(cidr.address, cidr.prefixLength)
                Log.d(
                    "addAddress",
                    "address: ${cidr.address} prefixLength:${cidr.prefixLength}"
                )
                val routeAddress = options.getIpv4RouteAddress()
                if (routeAddress.isNotEmpty()) {
                    try {
                        routeAddress.forEach { i ->
                            Log.d(
                                "addRoute4",
                                "address: ${i.address} prefixLength:${i.prefixLength}"
                            )
                            addRoute(i.address, i.prefixLength)
                        }
                    } catch (_: Exception) {
                        addRoute("0.0.0.0", 0)
                    }
                } else {
                    addRoute("0.0.0.0", 0)
                }
            } else {
                addRoute("0.0.0.0", 0)
            }
            try {
                if (options.ipv6Address.isNotEmpty()) {
                    val cidr = options.ipv6Address.toCIDR()
                    Log.d(
                        "addAddress6",
                        "address: ${cidr.address} prefixLength:${cidr.prefixLength}"
                    )
                    addAddress(cidr.address, cidr.prefixLength)
                    val routeAddress = options.getIpv6RouteAddress()
                    if (routeAddress.isNotEmpty()) {
                        try {
                            routeAddress.forEach { i ->
                                Log.d(
                                    "addRoute6",
                                    "address: ${i.address} prefixLength:${i.prefixLength}"
                                )
                                addRoute(i.address, i.prefixLength)
                            }
                        } catch (_: Exception) {
                            addRoute("::", 0)
                        }
                    } else {
                        addRoute("::", 0)
                    }
                }
            }catch (_:Exception){
                Log.d(
                    "addAddress6",
                    "IPv6 is not supported."
                )
            }
            if (options.dnsServerAddress.isNotBlank()) {
                try {
                    addDnsServer(options.dnsServerAddress)
                } catch (e: Exception) {
                    Log.e("BettboxVpnService", "Invalid DNS: ${options.dnsServerAddress}")
                }
            }
            val validMtu = if (options.mtu in 1280..65535) options.mtu else 1480
            setMtu(validMtu)
            options.accessControl.let { accessControl ->
                if (accessControl.enable) {
                    when (accessControl.mode) {
                        AccessControlMode.acceptSelected -> {
                            (accessControl.acceptList + packageName).forEach {
                                addAllowedApplication(it)
                            }
                        }

                        AccessControlMode.rejectSelected -> {
                            (accessControl.rejectList - packageName).forEach {
                                addDisallowedApplication(it)
                            }
                        }
                    }
                }
            }
            setSession("Bettbox")
            setBlocking(false)
            if (Build.VERSION.SDK_INT >= 29) {
                setMetered(false)
            }
            if (options.allowBypass) {
                allowBypass()
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && options.systemProxy) {
                setHttpProxy(
                    ProxyInfo.buildDirectProxy(
                        "127.0.0.1",
                        options.port,
                        options.bypassDomain
                    )
                )
            }
            val fd = establish()?.detachFd()
            if (fd == null) {
                Log.e("BettboxVpnService", "Establish VPN rejected by system")
                return 0
            }
            return fd
        }
    }

    override fun stop() {
        stopSelf()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        }
    }

    private var cachedBuilder: NotificationCompat.Builder? = null

    fun resetNotificationBuilder() {
        cachedBuilder = null
    }

    private suspend fun notificationBuilder(): NotificationCompat.Builder {
        if (cachedBuilder == null) {
            cachedBuilder = createBettboxNotificationBuilder().await()
        }
        return cachedBuilder!!
    }

    @SuppressLint("ForegroundServiceType")
    override suspend fun startForeground(title: String, content: String) {
        ensureNotificationChannel()
        val safeTitle = if (title.isBlank()) "Bettbox" else title
        val safeContent = content.trim()
        val builder = notificationBuilder()
        val notification = if (safeContent.isBlank()) {
            builder.setContentTitle(safeTitle).setContentText(null).build()
        } else {
            val separator = " ︙ "
            val combinedText = "$safeTitle$separator$safeContent"
            val spannable = android.text.SpannableString(combinedText)
            val startIndex = safeTitle.length + separator.length
            if (startIndex < combinedText.length) {
                spannable.setSpan(
                    android.text.style.RelativeSizeSpan(0.80f),
                    startIndex,
                    combinedText.length,
                    android.text.Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
                )
            }
            builder.setContentTitle(spannable).setContentText(null).build()
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            try {
                startForeground(
                    GlobalState.NOTIFICATION_ID,
                    notification,
                    android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED
                )
            } catch (e: Exception) {
                // Fallback to dataSync for compatibility
                try {
                    startForeground(
                        GlobalState.NOTIFICATION_ID,
                        notification,
                        android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                    )
                } catch (e2: Exception) {
                    // Final fallback without type
                    startForeground(GlobalState.NOTIFICATION_ID, notification)
                }
            }
        } else {
            // Android 13 - dataSync
            startForeground(GlobalState.NOTIFICATION_ID, notification)
        }
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        GlobalState.getCurrentVPNPlugin()?.requestGc()
    }

    private val binder = LocalBinder()

    inner class LocalBinder : Binder() {
        fun getService(): BettboxVpnService = this@BettboxVpnService

        override fun onTransact(code: Int, data: Parcel, reply: Parcel?, flags: Int): Boolean {
            try {
                val isSuccess = super.onTransact(code, data, reply, flags)
                if (!isSuccess) {
                    CoroutineScope(Dispatchers.Main).launch {
                        GlobalState.getCurrentTilePlugin()?.handleStop()
                    }
                }
                return isSuccess
            } catch (e: RemoteException) {
                throw e
            }
        }
    }

    override fun onBind(intent: Intent): IBinder {
        return binder
    }

    override fun onUnbind(intent: Intent?): Boolean {
        return super.onUnbind(intent)
    }

    override fun onRevoke() {
        Log.d("BettboxVpnService", "VPN revoked by system")
        VpnPlugin.handleStop(force = true)
        super.onRevoke()
    }

    override fun onDestroy() {
        stop()
        super.onDestroy()
    }
}
