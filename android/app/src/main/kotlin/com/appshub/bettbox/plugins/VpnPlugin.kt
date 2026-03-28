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
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import java.util.Collections
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.net.InetSocketAddress
import java.util.concurrent.ConcurrentHashMap
import kotlin.concurrent.withLock

data object VpnPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var flutterMethodChannel: MethodChannel
    private var bettBoxService: BaseServiceInterface? = null
    private var options: VpnOptions? = null

    private var isBind = false
    @Volatile
    private var isBinding = false

    private var job = SupervisorJob()
    private var scope = CoroutineScope(Dispatchers.Default + job as kotlin.coroutines.CoroutineContext)
    private var lastStartForegroundParams: StartForegroundParams? = null
    private val uidPageNameMap = ConcurrentHashMap<Int, String>()
    private var suspendModule: SuspendModule? = null

    private var quickResponseEnabled = false
    private var disconnectCount = 0
    private var disconnectWindowStart = 0L
    private val disconnectWindowMs = 5000L
    private val maxDisconnectsInWindow = 2
    private var lastNetworkType: Int? = null

    val networks: MutableSet<Network> = Collections.newSetFromMap(ConcurrentHashMap())

    private val connectivity by lazy {
        BettboxApplication.getAppContext().getSystemService<ConnectivityManager>()
    }

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(className: ComponentName, service: IBinder) {
            isBind = true
            isBinding = false
            bettBoxService = when (service) {
                is BettboxVpnService.LocalBinder -> service.getService()
                is BettboxService.LocalBinder -> service.getService()
                else -> throw Exception("invalid binder")
            }
            handleStartService()
        }

        override fun onServiceDisconnected(arg: ComponentName) {
            isBind = false
            isBinding = false
            bettBoxService = null
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        job.cancel()
        job = SupervisorJob()
        scope = CoroutineScope(Dispatchers.Default + job as kotlin.coroutines.CoroutineContext)

        scope.launch { registerNetworkCallback() }
        flutterMethodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "vpn")
        flutterMethodChannel.setMethodCallHandler(this)

        if (GlobalState.currentRunState == RunState.START && bettBoxService == null) {
            android.util.Log.d("VpnPlugin", "VPN is running but service connection lost, rebinding...")
            options?.let { bindService() }
        }
    }

    override fun onDetachedFromEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        job.cancel()
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

            "status" -> {
                result.success(GlobalState.currentRunState == RunState.START)
            }

            else -> {
                result.notImplemented()
            }
        }
    }
    
    fun setQuickResponse(enabled: Boolean) {
        quickResponseEnabled = enabled
    }

    fun getLocalIpAddresses(): List<String> {
        val ipAddresses = mutableListOf<String>()
        try {
            for (network in networks) {
                val linkProperties = connectivity?.getLinkProperties(network) ?: continue
                val addresses = linkProperties.linkAddresses
                for (linkAddress in addresses) {
                    val address = linkAddress.address
                    if (address != null && !address.isLoopbackAddress) {
                        val hostAddress = address.hostAddress
                        if (hostAddress != null && !hostAddress.contains(":")) {
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
        onUpdateNetwork()
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
        try {
            networks.clear()
            connectivity?.registerNetworkCallback(request, callback)
        } catch (e: Exception) {
            android.util.Log.e("VpnPlugin", "Failed to register network callback: ${e.message}")
        }
    }

    private fun unRegisterNetworkCallback() {
        try {
            connectivity?.unregisterNetworkCallback(callback)
        } catch (e: Exception) {
            android.util.Log.e("VpnPlugin", "Failed to unregister network callback: ${e.message}")
        } finally {
            networks.clear()
            onUpdateNetwork()
        }
    }
    
    private fun handleNetworkChange() {
        val currentNetworkType = getCurrentNetworkType()
        if (lastNetworkType == null) {
            lastNetworkType = currentNetworkType
            return
        }
        
        if (currentNetworkType != lastNetworkType) {
            lastNetworkType = currentNetworkType
            
            ServicePlugin.notifyNetworkChanged()
            
            if (!quickResponseEnabled) return
            if (GlobalState.currentRunState != RunState.START) return

            val now = System.currentTimeMillis()
            
            if (now - disconnectWindowStart > disconnectWindowMs) {
                disconnectWindowStart = now
                disconnectCount = 0
            }
            
            if (disconnectCount < maxDisconnectsInWindow) {
                disconnectCount++
                android.util.Log.d("VpnPlugin", "Quick Response: Network changed, closing connections ($disconnectCount/$maxDisconnectsInWindow)")
                scope.launch {
                    withContext(Dispatchers.Main) {
                        flutterMethodChannel.invokeMethod("closeConnections", null)
                    }
                }
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

    fun updateNotificationIcon() {
        scope.launch {
            try {
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

    fun getStatus(): Boolean {
        return GlobalState.runLock.withLock {
            GlobalState.currentRunState == RunState.START && bettBoxService != null
        }
    }

    private fun handleStartService() {
        if (GlobalState.isCurrentlyStopping()) {
            android.util.Log.w("VpnPlugin", "VPN is in stopping state, ignore start request")
            return
        }
        if (bettBoxService == null) {
            bindService()
            return
        }
        
        scope.launch {
            try {
                val prepareIntent = try {
                    android.net.VpnService.prepare(BettboxApplication.getAppContext())
                } catch (e: Exception) {
                    null
                }

                if (prepareIntent != null) {
                    android.util.Log.w("VpnPlugin", "VPN permission required before start")
                    GlobalState.updateRunState(RunState.STOP)
                    withContext(Dispatchers.Main) {
                        GlobalState.getCurrentAppPlugin()?.requestVpnPermission {
                            handleStartService()
                        }
                    }
                    return@launch
                }

                val currentOptions = options
                val startAllowed = GlobalState.runLock.withLock {
                    if (GlobalState.currentRunState == RunState.START) {
                        android.util.Log.d("VpnPlugin", "Service already running, refreshing notification")
                        scope.launch { startForeground() }
                        return@withLock false
                    }
                    if (currentOptions == null) {
                        android.util.Log.e("VpnPlugin", "Start failed: options is null")
                        GlobalState.updateRunState(RunState.STOP)
                        return@withLock false
                    }
                    GlobalState.updateRunState(RunState.START)
                    lastStartForegroundParams = null
                    true
                }

                if (!startAllowed || currentOptions == null) return@launch

                var fd: Int? = 0
                try {
                    fd = bettBoxService?.start(currentOptions)
                } catch (e: Exception) {
                    android.util.Log.e("VpnPlugin", "First start attempt failed: ${e.message}")
                }

                if (fd == null || (currentOptions.enable && fd == 0)) {
                    android.util.Log.w("VpnPlugin", "VPN establish failed, retrying...")
                    delay(300)
                    try {
                        fd = bettBoxService?.start(currentOptions)
                    } catch (e: Exception) {
                        android.util.Log.e("VpnPlugin", "Retry start failed: ${e.message}")
                    }
                }

                if (fd == null || (currentOptions.enable && fd == 0)) {
                    android.util.Log.e("VpnPlugin", "VPN start failed after all attempts")
                    GlobalState.runLock.withLock { GlobalState.updateRunState(RunState.STOP) }
                    ServicePlugin.notifyVpnStartFailed()
                    return@launch
                }

                GlobalState.runLock.withLock {
                    if (GlobalState.currentRunState != RunState.START) {
                        bettBoxService?.stop()
                        return@withLock
                    }

                    com.appshub.bettbox.core.Core.startTun(
                        fd = fd ?: 0,
                        protect = this@VpnPlugin::protect,
                        resolverProcess = this@VpnPlugin::resolverProcess,
                    )
                    
                    scope.launch { startForeground() }
                    
                    if (currentOptions.dozeSuspend) {
                        suspendModule?.uninstall()
                        suspendModule = SuspendModule(BettboxApplication.getAppContext())
                        suspendModule?.install()
                    }
                }
            } catch (e: Exception) {
                android.util.Log.e("VpnPlugin", "Fatal error in start flow: ${e.message}")
                GlobalState.updateRunState(RunState.STOP)
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

    fun handleStop(force: Boolean = false) {
        GlobalState.runLock.withLock {
            if (!force && GlobalState.currentRunState == RunState.STOP) return
            GlobalState.updateIsStopping(true)
            GlobalState.updateRunState(RunState.STOP)
            lastStartForegroundParams = null
            suspendModule?.uninstall()
            suspendModule = null
            Core.stopTun()
            bettBoxService?.stop()

            if (force) {
                BettboxApplication.getAppContext().stopService(
                    Intent(BettboxApplication.getAppContext(), BettboxVpnService::class.java)
                )
            }

            scope.launch {
                delay(300)
                GlobalState.updateIsStopping(false)
                delay(200)
                withContext(Dispatchers.Main) {
                    GlobalState.handleTryDestroy()
                }
            }
        }
    }

    fun handleSmartStop() {
        GlobalState.runLock.withLock {
            if (GlobalState.currentRunState == RunState.STOP) return
            GlobalState.updateRunState(RunState.STOP)
            GlobalState.isSmartStopped = true
            suspendModule?.uninstall()
            suspendModule = null
            Core.stopTun()
            scope.launch {
                startForeground()
            }
        }
    }

    fun handleSmartResume(options: VpnOptions): Boolean {
        scope.launch {
            val startAllowed = GlobalState.runLock.withLock {
                if (GlobalState.currentRunState == RunState.START) return@withLock false
                GlobalState.isSmartStopped = false
                this@VpnPlugin.options = options
                
                if (bettBoxService == null) {
                    bindService()
                    return@withLock false
                }
                
                GlobalState.updateRunState(RunState.START)
                lastStartForegroundParams = null
                true
            }
            if (!startAllowed) return@launch
            
            var fd: Int? = 0
            try {
                fd = bettBoxService?.start(options)
            } catch (e: Exception) {
                android.util.Log.e("VpnPlugin", "Smart resume start failed with exception: ${e.message}")
            }
            
            GlobalState.runLock.withLock {
                if (GlobalState.currentRunState != RunState.START) {
                    bettBoxService?.stop()
                    return@withLock
                }
                Core.startTun(
                    fd = fd ?: 0,
                    protect = this@VpnPlugin::protect,
                    resolverProcess = this@VpnPlugin::resolverProcess,
                )
                scope.launch { startForeground() }
                if (options.dozeSuspend == true) {
                    suspendModule?.uninstall()
                    suspendModule = SuspendModule(BettboxApplication.getAppContext())
                    suspendModule?.install()
                }
            }
        }
        return true
    }

    private fun bindService() {
        if (isBinding) return
        isBinding = true

        try {
            if (isBind) {
                BettboxApplication.getAppContext().unbindService(connection)
                isBind = false
            }
            val intent = Intent(
                BettboxApplication.getAppContext(),
                if (options?.enable == true) BettboxVpnService::class.java else BettboxService::class.java
            )
            val res = BettboxApplication.getAppContext().bindService(intent, connection, Context.BIND_AUTO_CREATE)
            if (!res) {
                isBinding = false
                android.util.Log.e("VpnPlugin", "bindService returned false (rejected by system)")
            }
        } catch (e: Exception) {
            isBinding = false
            android.util.Log.e("VpnPlugin", "bindService error: ${e.message}")
        }
    }
}