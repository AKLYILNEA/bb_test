package com.appshub.bettbox.plugins

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.IBinder
import androidx.core.content.getSystemService
import com.appshub.bettbox.BettboxApplication
import com.appshub.bettbox.GlobalState
import com.appshub.bettbox.RunState
import com.appshub.bettbox.core.Core
import com.appshub.bettbox.extensions.awaitResult
import com.appshub.bettbox.extensions.resolveDns
import com.appshub.bettbox.models.StartForegroundParams
import com.appshub.bettbox.models.VpnOptions
import com.appshub.bettbox.modules.SuspendModule
import com.appshub.bettbox.services.BaseServiceInterface
import com.appshub.bettbox.services.BettboxService
import com.appshub.bettbox.services.BettboxVpnService
import com.google.gson.Gson
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.net.InetSocketAddress
import kotlin.concurrent.withLock

data object VpnPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var flutterMethodChannel: MethodChannel
    private var bettBoxService: BaseServiceInterface? = null
    private var options: VpnOptions? = null
    private var isBind: Boolean = false
    private lateinit var scope: CoroutineScope
    private var lastStartForegroundParams: StartForegroundParams? = null
    private val uidPageNameMap = java.util.concurrent.ConcurrentHashMap<Int, String>()
    private var suspendModule: SuspendModule? = null
    
    // Quick Response: Network change debounce
    private var quickResponseEnabled = false
    private var disconnectCount = 0
    private var disconnectWindowStart = 0L
    private val disconnectWindowMs = 5000L // 5s window
    private val maxDisconnectsInWindow = 2
    private var lastNetworkType: Int? = null

    private val connectivity by lazy {
        BettboxApplication.getAppContext().getSystemService<ConnectivityManager>()
    }

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(className: ComponentName, service: IBinder) {
            isBind = true
            bettBoxService = when (service) {
                is BettboxVpnService.LocalBinder -> service.getService()
                is BettboxService.LocalBinder -> service.getService()
                else -> throw Exception("invalid binder")
            }
            handleStartService()
        }

        override fun onServiceDisconnected(arg: ComponentName) {
            isBind = false
            bettBoxService = null
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        scope = CoroutineScope(Dispatchers.Default)
        scope.launch {
            registerNetworkCallback()
        }
        flutterMethodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "vpn")
        flutterMethodChannel.setMethodCallHandler(this)
        
        // Rebind if VPN running but connection lost
        if (GlobalState.currentRunState == RunState.START && bettBoxService == null) {
            android.util.Log.d("VpnPlugin", "VPN is running but service connection lost, rebinding...")
            // Rebind with saved options
            if (options != null) {
                bindService()
            }
        }
    }

    override fun onDetachedFromEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        unRegisterNetworkCallback()
        flutterMethodChannel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                try {
                    val data = call.argument<String>("data")
                    if (data == null) {
                        result.error("INVALID_ARGUMENT", "data parameter is required", null)
                        return
                    }
                    val vpnOptions = Gson().fromJson(data, VpnOptions::class.java)
                    result.success(handleStart(vpnOptions))
                } catch (e: Exception) {
                    android.util.Log.e("VpnPlugin", "Failed to start VPN: ${e.message}")
                    result.error("PARSE_ERROR", "Failed to parse VpnOptions: ${e.message}", null)
                }
            }

            "stop" -> {
                handleStop()
                result.success(true)
            }

            "getLocalIpAddresses" -> {
                result.success(getLocalIpAddresses())
            }

            "setSmartStopped" -> {
                val value = call.argument<Boolean>("value") ?: false
                GlobalState.isSmartStopped = value
                result.success(true)
            }

            "isSmartStopped" -> {
                result.success(GlobalState.isSmartStopped)
            }

            "smartStop" -> {
                handleSmartStop()
                result.success(true)
            }

            "smartResume" -> {
                val data = call.argument<String>("data")
                result.success(handleSmartResume(Gson().fromJson(data, VpnOptions::class.java)))
            }
            
            "setQuickResponse" -> {
                quickResponseEnabled = call.argument<Boolean>("enabled") ?: false
                result.success(true)
            }

            else -> {
                result.notImplemented()
            }
        }
    }
    
    fun setQuickResponse(enabled: Boolean) {
        quickResponseEnabled = enabled
    }

    /**
     * Get local IP addresses from all non-VPN networks.
     * This is more reliable than connectivity_plus when VPN is running.
     */
    fun getLocalIpAddresses(): List<String> {
        val ipAddresses = mutableListOf<String>()
        try {
            for (network in networks) {
                val linkProperties = connectivity?.getLinkProperties(network) ?: continue
                val addresses = linkProperties?.linkAddresses ?: continue
                for (linkAddress in addresses) {
                    val address = linkAddress.address
                    if (address != null && !address.isLoopbackAddress) {
                        val hostAddress = address.hostAddress
                        if (hostAddress != null && !hostAddress.contains(":")) {
                            // Only IPv4 addresses
                            ipAddresses.add(hostAddress)
                        }
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("VpnPlugin", "getLocalIpAddresses error: ${e.message}")
        }
        return ipAddresses
    }

    fun handleStart(options: VpnOptions): Boolean {
        onUpdateNetwork();
        if (options.enable != this.options?.enable) {
            this.bettBoxService = null
        }
        this.options = options
        when (options.enable) {
            true -> handleStartVpn()
            false -> handleStartService()
        }
        return true
    }

    private fun handleStartVpn() {
        GlobalState.getCurrentAppPlugin()?.requestVpnPermission {
            handleStartService()
        }
    }

    fun requestGc() {
        flutterMethodChannel.invokeMethod("gc", null)
    }

    val networks = mutableSetOf<Network>()

    fun onUpdateNetwork() {
        val dns = networks.flatMap { network ->
            connectivity?.resolveDns(network) ?: emptyList()
        }.toSet().joinToString(",")
        scope.launch {
            withContext(Dispatchers.Main) {
                flutterMethodChannel.invokeMethod("dnsChanged", dns)
            }
        }
    }

    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            networks.add(network)
            onUpdateNetwork()
            handleNetworkChange()
        }

        override fun onLost(network: Network) {
            networks.remove(network)
            onUpdateNetwork()
            handleNetworkChange()
        }
    }

    private val request = NetworkRequest.Builder().apply {
        addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
        addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
    }.build()

    private fun registerNetworkCallback() {
        networks.clear()
        connectivity?.registerNetworkCallback(request, callback)
    }

    private fun unRegisterNetworkCallback() {
        connectivity?.unregisterNetworkCallback(callback)
        networks.clear()
        onUpdateNetwork()
    }
    
    private fun handleNetworkChange() {
        val currentNetworkType = getCurrentNetworkType()
        if (lastNetworkType == null) {
            lastNetworkType = currentNetworkType
            return
        }
        
        // Network type changed (WiFi <-> Mobile)
        if (currentNetworkType != lastNetworkType) {
            lastNetworkType = currentNetworkType
            
            ServicePlugin.notifyNetworkChanged()
            
            if (!quickResponseEnabled) return
            if (GlobalState.currentRunState != RunState.START) return

            val now = System.currentTimeMillis()
            
            // Reset window if expired
            if (now - disconnectWindowStart > disconnectWindowMs) {
                disconnectWindowStart = now
                disconnectCount = 0
            }
            
            // Check if within limit
            if (disconnectCount < maxDisconnectsInWindow) {
                disconnectCount++
                android.util.Log.d("VpnPlugin", "Quick Response: Network changed, disconnecting ($disconnectCount/$maxDisconnectsInWindow)")
                handleStop()
            } else {
                android.util.Log.d("VpnPlugin", "Quick Response: Disconnect limit reached, ignoring")
            }
        }
    }
    
    private fun getCurrentNetworkType(): Int {
        val activeNetwork = connectivity?.activeNetwork ?: return -1
        val caps = connectivity?.getNetworkCapabilities(activeNetwork) ?: return -1
        return when {
            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> 1
            caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> 2
            else -> 0
        }
    }

    private suspend fun startForeground() {
        val shouldUpdate = GlobalState.runLock.withLock {
            GlobalState.currentRunState == RunState.START || GlobalState.isSmartStopped
        }
        if (!shouldUpdate) return
        val data = try {
            withTimeoutOrNull(1200L) {
                flutterMethodChannel.awaitResult<String>("getStartForegroundParams")
            }
        } catch (e: Exception) {
            android.util.Log.e("VpnPlugin", "getStartForegroundParams timeout: ${e.message}")
            null
        }

        val startForegroundParams = try {
            data?.let { Gson().fromJson(it, StartForegroundParams::class.java) }
        } catch (e: Exception) {
            android.util.Log.e("VpnPlugin", "Failed to parse StartForegroundParams: ${e.message}")
            null
        } ?: lastStartForegroundParams ?: StartForegroundParams(title = "", content = "")

        val shouldNotify = GlobalState.runLock.withLock {
            if (lastStartForegroundParams != startForegroundParams) {
                lastStartForegroundParams = startForegroundParams
                true
            } else {
                false
            }
        }
        if (shouldNotify) {
            try {
                bettBoxService?.startForeground(
                    startForegroundParams.title,
                    startForegroundParams.content,
                )
            } catch (e: Exception) {
                android.util.Log.e("VpnPlugin", "startForeground error: ${e.message}")
            }
        }
    }

    /**
     * Force update notification icon
     */
    fun updateNotificationIcon() {
        scope.launch {
            try {
                // Recreate notification for new icon
                lastStartForegroundParams?.let { params ->
                    (bettBoxService as? BettboxService)?.resetNotificationBuilder()
                    (bettBoxService as? BettboxVpnService)?.resetNotificationBuilder()
                    bettBoxService?.startForeground(params.title, params.content)
                }
            } catch (e: Exception) {
                android.util.Log.e("VpnPlugin", "updateNotificationIcon error: ${e.message}")
            }
        }
    }


    suspend fun getStatus(): Boolean? {
        return withContext(Dispatchers.Default) {
            flutterMethodChannel.awaitResult<Boolean>("status", null)
        }
    }

    private fun handleStartService() {
        if (bettBoxService == null) {
            bindService()
            return
        }
        GlobalState.runLock.withLock {
            if (GlobalState.currentRunState == RunState.START) {
                // Service running, update notice
                android.util.Log.d("VpnPlugin", "Service reconnected, updating notification")
                scope.launch {
                    startForeground()
                }
                return
            }
            val currentOptions = options
            if (currentOptions == null) {
                android.util.Log.e("VpnPlugin", "Start service failed: options is null")
                GlobalState.updateRunState(RunState.STOP)
                return
            }
            GlobalState.updateRunState(RunState.START)
            lastStartForegroundParams = null
            val fd = bettBoxService?.start(currentOptions)
            Core.startTun(
                fd = fd ?: 0,
                protect = this::protect,
                resolverProcess = this::resolverProcess,
            )
            // Update notice on start
            scope.launch {
                startForeground()
            }
            // Install SuspendModule if dozeSuspend is enabled
            if (options?.dozeSuspend == true) {
                suspendModule?.uninstall()
                suspendModule = SuspendModule(BettboxApplication.getAppContext())
                suspendModule?.install()
            }
        }
    }

    private fun protect(fd: Int): Boolean {
        return try {
            (bettBoxService as? BettboxVpnService)?.protect(fd) == true
        } catch (e: Exception) {
            android.util.Log.e("VpnPlugin", "protect error: ${e.message}")
            false
        }
    }

    private fun resolverProcess(
        protocol: Int,
        source: InetSocketAddress,
        target: InetSocketAddress,
        uid: Int,
    ): String {
        return try {
            val nextUid = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                connectivity?.getConnectionOwnerUid(protocol, source, target) ?: -1
            } else {
                uid
            }
            if (nextUid == -1) {
                return ""
            }
            if (!uidPageNameMap.containsKey(nextUid)) {
                uidPageNameMap[nextUid] =
                    BettboxApplication.getAppContext().packageManager?.getPackagesForUid(nextUid)
                        ?.firstOrNull() ?: ""
            }
            uidPageNameMap[nextUid] ?: ""
        } catch (e: Exception) {
            android.util.Log.e("VpnPlugin", "resolverProcess error: ${e.message}")
            ""
        }
    }

    fun handleStop() {
        GlobalState.runLock.withLock {
            if (GlobalState.currentRunState == RunState.STOP) return
            GlobalState.updateRunState(RunState.STOP)
            lastStartForegroundParams = null
            // Uninstall SuspendModule
            suspendModule?.uninstall()
            suspendModule = null
            // Stop TUN first to clear routes
            Core.stopTun()
            // Then stop service
            bettBoxService?.stop()
            GlobalState.handleTryDestroy()
        }
    }

    /**
     * Smart stop: Stop the TUN but keep the foreground service running.
     * Used by Smart Auto Stop feature to maintain notification while VPN is paused.
     */
    fun handleSmartStop() {
        GlobalState.runLock.withLock {
            if (GlobalState.currentRunState == RunState.STOP) return
            GlobalState.updateRunState(RunState.STOP)
            GlobalState.isSmartStopped = true
            // Uninstall SuspendModule
            suspendModule?.uninstall()
            suspendModule = null
            // Stop TUN but keep service running
            Core.stopTun()
            // Update notification to show "SmartAutoStopServiceRunning"
            scope.launch {
                startForeground()
            }
        }
    }

    /**
     * Smart resume: Resume VPN from smart-stopped state.
     * Restarts the TUN without rebinding the service.
     */
    fun handleSmartResume(options: VpnOptions): Boolean {
        GlobalState.runLock.withLock {
            if (GlobalState.currentRunState == RunState.START) return true
            GlobalState.isSmartStopped = false
            this.options = options
            
            if (bettBoxService == null) {
                // Service was destroyed, need to rebind
                bindService()
                return true
            }
            
            GlobalState.updateRunState(RunState.START)
            lastStartForegroundParams = null
            val fd = bettBoxService?.start(options)
            Core.startTun(
                fd = fd ?: 0,
                protect = this::protect,
                resolverProcess = this::resolverProcess,
            )
            // Update notification to "Service running"
            scope.launch {
                startForeground()
            }
            // Install SuspendModule if dozeSuspend is enabled
            if (options.dozeSuspend == true) {
                suspendModule?.uninstall()
                suspendModule = SuspendModule(BettboxApplication.getAppContext())
                suspendModule?.install()
            }
            return true
        }
    }

    private fun bindService() {
        if (isBind) {
            BettboxApplication.getAppContext().unbindService(connection)
        }
        val intent = when (options?.enable == true) {
            true -> Intent(BettboxApplication.getAppContext(), BettboxVpnService::class.java)
            false -> Intent(BettboxApplication.getAppContext(), BettboxService::class.java)
        }
        BettboxApplication.getAppContext().bindService(intent, connection, Context.BIND_AUTO_CREATE)
    }
}
