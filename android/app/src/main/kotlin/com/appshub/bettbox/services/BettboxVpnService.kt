package com.appshub.bettbox.services

import android.annotation.SuppressLint
import android.content.Context
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
import com.appshub.bettbox.modules.VpnResidualCleaner
import com.appshub.bettbox.plugins.VpnPlugin
import com.appshub.bettbox.extensions.getIpv4RouteAddress
import com.appshub.bettbox.extensions.getIpv6RouteAddress
import com.appshub.bettbox.extensions.toCIDR
import com.appshub.bettbox.models.AccessControlMode
import com.appshub.bettbox.models.VpnOptions
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch


class BettboxVpnService : VpnService(), BaseServiceInterface {
    companion object {
        private const val TAG = "BettboxVpnService"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_NEEDS_TUN_CLEANUP = "flutter.needs_tun_cleanup"
        private const val KEY_VPN_RUNNING_BEFORE_UPGRADE = "flutter.vpn_running_before_upgrade"
    }
    override fun onCreate() {
        super.onCreate()
        GlobalState.initServiceEngine()
    }

    override suspend fun start(options: VpnOptions): Int {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val shouldForceCleanup = prefs.getBoolean(KEY_NEEDS_TUN_CLEANUP, false)

        try {
            val prepareIntent = android.net.VpnService.prepare(this)
            if (prepareIntent != null) {
                Log.w(TAG, "Hack: VpnService.prepare() returned non-null!")
            } else {
                Log.d(TAG, "Hack: System VPN state cleared successfully.")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Hack Prepare failed: ${e.message}")
        }

        val hasZombieTun = VpnResidualCleaner.isZombieTunAlive()
        if (shouldForceCleanup || hasZombieTun) {
            val released = performResidualCleanup(forceFullCleanup = shouldForceCleanup)
            prefs.edit()
                .putBoolean(KEY_NEEDS_TUN_CLEANUP, !released && shouldForceCleanup)
                .putBoolean(KEY_VPN_RUNNING_BEFORE_UPGRADE, false)
                .apply()
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


    private suspend fun performResidualCleanup(forceFullCleanup: Boolean): Boolean {
        return try {
            Log.d(TAG, "Starting residual VPN cleanup, forceFullCleanup=$forceFullCleanup")
            val cleanupInterface = Builder()
                .setSession("bettbox_cleanup")
                .addAddress("192.0.2.1", 24)
                .addRoute("0.0.0.0", 0)
                .apply {
                    setBlocking(true)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        setMetered(false)
                    }
                    try {
                        addDnsServer("1.1.1.1")
                    } catch (_: Exception) {}
                }
                .establish()

            delay(if (forceFullCleanup) 800 else 300)
            cleanupInterface?.close()
            Log.d(TAG, "Cleanup profile closed, waiting for system to release stale VPN state")

            val released = VpnResidualCleaner.waitForTunRelease(
                checkAnyTun = forceFullCleanup,
                timeoutMs = if (forceFullCleanup) 6000L else 3000L
            )
            if (released) {
                Log.d(TAG, "Residual VPN cleanup completed")
            } else {
                Log.w(TAG, "Residual VPN cleanup timed out")
            }
            released
        } catch (e: Exception) {
            Log.e(TAG, "Cleanup error: ${e.message}")
            false
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

        this.startForeground(notification)
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
        try {
            if (GlobalState.isServiceEngineRunning()) {
                VpnPlugin.handleStop(force = true)
            } else {
                stop()
            }
        } catch (e: Exception) {
            Log.e("BettboxVpnService", "Error during onRevoke cleanup: ${e.message}")
            stop()
        }
        super.onRevoke()
    }

    override fun onDestroy() {
        stop()
        super.onDestroy()
    }
}
