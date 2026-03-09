package com.appshub.bettbox.modules

import android.util.Log
import kotlinx.coroutines.delay
import java.net.NetworkInterface

object VpnResidualCleaner {
    private const val TAG = "VpnResidualCleaner"
    private const val ZOMBIE_IP = "198.51.100.1"
    private const val POLL_INTERVAL_MS = 250L

    private fun scanTunInterfaces(): List<Pair<String, List<String>>> {
        return try {
            val interfaces = NetworkInterface.getNetworkInterfaces() ?: return emptyList()
            val result = mutableListOf<Pair<String, List<String>>>()
            for (intf in interfaces) {
                if (!intf.name.startsWith("tun", ignoreCase = true)) continue

                val addresses = mutableListOf<String>()
                val inetAddresses = intf.inetAddresses
                while (inetAddresses.hasMoreElements()) {
                    val inetAddress = inetAddresses.nextElement()
                    if (!inetAddress.isLoopbackAddress) {
                        addresses.add(inetAddress.hostAddress ?: "")
                    }
                }

                val isInterfaceUp = try {
                    intf.isUp
                } catch (_: Exception) {
                    false
                }

                if (addresses.isNotEmpty() || isInterfaceUp) {
                    result.add(intf.name to addresses)
                }
            }
            result
        } catch (e: Exception) {
            Log.w(TAG, "Error scanning tun interfaces: ${e.message}")
            emptyList()
        }
    }

    private fun hasAnyTunInterfaceInternal(): Boolean {
        return scanTunInterfaces().isNotEmpty()
    }

    private fun hasZombieTunAliveInternal(): Boolean {
        return scanTunInterfaces().any { (_, addresses) ->
            addresses.any { address ->
                address.substringBefore('%') == ZOMBIE_IP
            }
        }
    }

    fun hasAnyTunInterface(): Boolean {
        val interfaces = scanTunInterfaces()
        if (interfaces.isNotEmpty()) {
            Log.d(
                TAG,
                "Detected tun interfaces: ${interfaces.joinToString { "${it.first}=${it.second.joinToString()}" }}"
            )
            return true
        }
        return false
    }

    fun isZombieTunAlive(): Boolean {
        val hasZombie = hasZombieTunAliveInternal()
        if (hasZombie) {
            Log.d(TAG, "Found zombie TUN interface with sentinel IP $ZOMBIE_IP")
        }
        return hasZombie
    }

    suspend fun waitForTunRelease(checkAnyTun: Boolean, timeoutMs: Long): Boolean {
        val attempts = (timeoutMs / POLL_INTERVAL_MS).toInt().coerceAtLeast(1)
        repeat(attempts) {
            val stillPresent = if (checkAnyTun) {
                hasAnyTunInterfaceInternal()
            } else {
                hasZombieTunAliveInternal()
            }
            if (!stillPresent) {
                return true
            }
            delay(POLL_INTERVAL_MS)
        }

        return if (checkAnyTun) {
            !hasAnyTunInterfaceInternal()
        } else {
            !hasZombieTunAliveInternal()
        }
    }
}
