package com.appshub.bettbox.modules

import android.content.Context
import android.net.VpnService
import android.util.Log
import com.appshub.bettbox.BettboxApplication
import com.appshub.bettbox.services.CleanupVpnService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.net.Inet4Address
import java.net.NetworkInterface

object VpnResidualCleaner {
    private const val TAG = "VpnResidualCleaner"
    
    private const val ZOMBIE_IP = "198.51.100.1"
    
    private const val CLEANUP_TIMEOUT_MS = 2000L
    private const val POLL_INTERVAL_MS = 100L
    private const val MAX_POLL_RETRIES = 20

    fun isZombieTunAlive(): Boolean {
        return try {
            val interfaces = NetworkInterface.getNetworkInterfaces() ?: return false
            for (intf in interfaces) {
                if (!intf.name.startsWith("tun", ignoreCase = true)) continue
                
                val enumIpAddr = intf.inetAddresses
                for (inetAddress in enumIpAddr) {
                    if (inetAddress !is Inet4Address) continue
                    
                    if (inetAddress.hostAddress == ZOMBIE_IP) {
                        Log.d(TAG, "Found zombie TUN interface: ${intf.name} with IP $ZOMBIE_IP")
                        return true
                    }
                }
            }
            false
        } catch (e: Exception) {
            Log.w(TAG, "Error checking zombie TUN: ${e.message}")
            false
        }
    }

    fun cleanResidualVpnState(onCleaned: () -> Unit) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                withTimeoutOrNull(CLEANUP_TIMEOUT_MS) {
                    performCleanup()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Cleanup failed: ${e.message}", e)
            } finally {
                withContext(Dispatchers.Main) {
                    onCleaned()
                }
            }
        }
    }

    private suspend fun performCleanup() {
        val context = BettboxApplication.getAppContext()
        
        Log.d(TAG, "Starting cleanup process...")
        
        try {
            val intent = android.content.Intent(context, CleanupVpnService::class.java)
            context.startService(intent)
            
            delay(500)
            
            context.stopService(intent)
            
            Log.d(TAG, "Triggered VPN cleanup via CleanupVpnService")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to start CleanupVpnService: ${e.message}")
        }

        var retryCount = 0
        while (retryCount < MAX_POLL_RETRIES) {
            if (!isZombieTunAlive()) {
                Log.d(TAG, "Success: Zombie TUN ($ZOMBIE_IP) destroyed in ${retryCount * POLL_INTERVAL_MS}ms.")
                return
            }
            delay(POLL_INTERVAL_MS)
            retryCount++
        }
        
        Log.w(TAG, "Warning: Timeout waiting for zombie TUN to disappear after ${CLEANUP_TIMEOUT_MS}ms.")
    }

    suspend fun cleanResidualVpnStateSync(): Boolean = withContext(Dispatchers.IO) {
        try {
            withTimeoutOrNull(CLEANUP_TIMEOUT_MS) {
                performCleanup()
            }
            !isZombieTunAlive()
        } catch (e: Exception) {
            Log.e(TAG, "Sync cleanup failed: ${e.message}", e)
            false
        }
    }
}
