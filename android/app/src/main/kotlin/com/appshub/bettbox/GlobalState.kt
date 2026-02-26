package com.appshub.bettbox

import android.os.SystemClock
import androidx.lifecycle.MutableLiveData
import com.appshub.bettbox.plugins.AppPlugin
import com.appshub.bettbox.plugins.TilePlugin
import com.appshub.bettbox.plugins.VpnPlugin
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

enum class RunState {
    START,
    PENDING,
    STOP
}


object GlobalState {
    val runLock = ReentrantLock()

    const val NOTIFICATION_CHANNEL = "Bettbox"

    const val NOTIFICATION_ID = 1

    private const val TOGGLE_DEBOUNCE_MS = 1000L
    @Volatile
    private var lastToggleAt = 0L

    @Volatile
    var currentRunState: RunState = RunState.STOP
        private set

    val runState: MutableLiveData<RunState> = MutableLiveData<RunState>(RunState.STOP)

    fun updateRunState(newState: RunState) {
        currentRunState = newState
        try {
            if (android.os.Looper.myLooper() == android.os.Looper.getMainLooper()) {
                runState.value = newState
            } else {
                runState.postValue(newState)
            }
        } catch (e: Exception) {
            runState.postValue(newState)
        }
    }
    var flutterEngine: FlutterEngine? = null
    private var serviceEngine: FlutterEngine? = null
    
    // Smart Auto Stop state - when true, VPN was stopped by smart auto stop feature
    @Volatile
    var isSmartStopped: Boolean = false

    fun getCurrentAppPlugin(): AppPlugin? {
        val currentEngine = if (flutterEngine != null) flutterEngine else serviceEngine
        return currentEngine?.plugins?.get(AppPlugin::class.java) as AppPlugin?
    }

    fun syncStatus() {
        CoroutineScope(Dispatchers.Default).launch {
            val status = try {
                VpnPlugin.getStatus() ?: false
            } catch (e: Exception) {
                false
            }
            withContext(Dispatchers.Main){
                val newState = if (status) RunState.START else RunState.STOP
                updateRunState(newState)
            }
        }
    }

    suspend fun getText(text: String): String {
        return getCurrentAppPlugin()?.getText(text) ?: ""
    }

    fun getCurrentTilePlugin(): TilePlugin? {
        val currentEngine = if (flutterEngine != null) flutterEngine else serviceEngine
        return currentEngine?.plugins?.get(TilePlugin::class.java) as TilePlugin?
    }

    fun getCurrentVPNPlugin(): VpnPlugin? {
        return serviceEngine?.plugins?.get(VpnPlugin::class.java) as VpnPlugin?
    }

    fun handleToggle() {
        if (!acquireToggleSlot()) return
        val starting = handleStart(skipDebounce = true)
        if (!starting) {
            handleStop(skipDebounce = true)
        }
    }

    fun handleStart(skipDebounce: Boolean = false): Boolean {
        if (!skipDebounce && !acquireToggleSlot()) return false
        if (currentRunState == RunState.STOP) {
            updateRunState(RunState.PENDING)
            runLock.lock()
            try {
                val tilePlugin = getCurrentTilePlugin()
                if (tilePlugin != null) {
                    tilePlugin.handleStart()
                } else {
                    initServiceEngine()
                }
            } finally {
                runLock.unlock()
            }
            return true
        }
        return false
    }

    fun handleStop(skipDebounce: Boolean = false) {
        if (!skipDebounce && !acquireToggleSlot()) return
        if (currentRunState == RunState.START) {
            updateRunState(RunState.PENDING)
            runLock.lock()
            try {
                getCurrentTilePlugin()?.handleStop()
            } finally {
                runLock.unlock()
            }
        }
    }

    private fun acquireToggleSlot(): Boolean {
        val now = SystemClock.elapsedRealtime()
        synchronized(this) {
            if (now - lastToggleAt < TOGGLE_DEBOUNCE_MS) {
                return false
            }
            lastToggleAt = now
            return true
        }
    }

    fun handleTryDestroy() {
        if (flutterEngine == null) {
            destroyServiceEngine()
        }
    }

    fun destroyServiceEngine() {
        runLock.withLock {
            serviceEngine?.destroy()
            serviceEngine = null
        }
    }

    fun initServiceEngine() {
        if (serviceEngine != null) return
        destroyServiceEngine()
        runLock.withLock {
            serviceEngine = FlutterEngine(BettboxApplication.getAppContext())
            serviceEngine?.plugins?.add(VpnPlugin)
            serviceEngine?.plugins?.add(AppPlugin())
            serviceEngine?.plugins?.add(ServicePlugin)
            serviceEngine?.plugins?.add(TilePlugin())
            val vpnService = DartExecutor.DartEntrypoint(
                FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                "_service"
            )
            serviceEngine?.dartExecutor?.executeDartEntrypoint(
                vpnService,
                if (flutterEngine == null) listOf("quick") else null
            )
        }
    }
}


