package com.appshub.bettbox.core

import android.util.Log
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.URL

data object Core {
    private external fun startTun(
        fd: Int,
        cb: TunInterface
    )

    private external fun suspend(suspended: Int)

    private fun parseInetSocketAddress(address: String): InetSocketAddress {
        val url = URL("https://$address")

        return InetSocketAddress(InetAddress.getByName(url.host), url.port)
    }

    fun startTun(
        fd: Int,
        protect: (Int) -> Boolean,
        resolverProcess: (protocol: Int, source: InetSocketAddress, target: InetSocketAddress, uid: Int) -> String
    ) {
        startTun(fd, object : TunInterface {
            override fun protect(fd: Int) {
                try {
                    protect(fd)
                } catch (e: Exception) {
                    Log.e("Core", "protect JNI callback error: ${e.message}")
                }
            }

            override fun resolverProcess(
                protocol: Int,
                source: String,
                target: String,
                uid: Int
            ): String {
                return try {
                    resolverProcess(
                        protocol,
                        parseInetSocketAddress(source),
                        parseInetSocketAddress(target),
                        uid,
                    )
                } catch (e: Exception) {
                    Log.e("Core", "resolverProcess JNI callback error: ${e.message}")
                    ""
                }
            }
        });
    }

    fun suspended(value: Boolean) {
        try {
            Log.d("Core", "suspended called with value: $value")
            suspend(if (value) 1 else 0)
            Log.d("Core", "suspend JNI call completed")
        } catch (e: Exception) {
            Log.e("Core", "Error calling suspend: ${e.message}", e)
        }
    }

    external fun stopTun()

    init {
        System.loadLibrary("core")
    }
}