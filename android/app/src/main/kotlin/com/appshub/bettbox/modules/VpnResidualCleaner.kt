package com.appshub.bettbox.modules

import android.content.Context
import android.net.VpnService
import android.util.Log
import com.appshub.bettbox.BettboxApplication
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
    private const val POLL_INTERVAL_MS = 200L
    private const val MAX_POLL_RETRIES = 10

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

}
