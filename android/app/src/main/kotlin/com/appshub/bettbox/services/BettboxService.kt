package com.appshub.bettbox.services

import android.annotation.SuppressLint
import android.app.Service
import android.content.Intent
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.text.SpannableString
import android.text.Spanned
import android.text.style.RelativeSizeSpan
import androidx.core.app.NotificationCompat
import com.appshub.bettbox.GlobalState
import com.appshub.bettbox.models.VpnOptions

class BettboxService : Service(), BaseServiceInterface {

    private var cachedBuilder: NotificationCompat.Builder? = null
    private val binder = LocalBinder()

    inner class LocalBinder : Binder() {
        fun getService() = this@BettboxService
    }

    override suspend fun start(options: VpnOptions) = 0

    override fun stop() {
        stopSelf()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        }
    }

    fun resetNotificationBuilder() {
        cachedBuilder = null
    }

    private suspend fun notificationBuilder() =
        cachedBuilder ?: createBettboxNotificationBuilder().await().also { cachedBuilder = it }

    @SuppressLint("ForegroundServiceType")
    override suspend fun startForeground(title: String, content: String) {
        ensureNotificationChannel()
        val safeTitle = title.ifBlank { "Bettbox" }
        val safeContent = content.trim()
        val builder = notificationBuilder()
        val notification = if (safeContent.isBlank()) {
            builder.setContentTitle(safeTitle).setContentText(null).build()
        } else {
            val separator = " ‹ "
            val combinedText = "$safeTitle$separator$safeContent"
            val spannable = SpannableString(combinedText).apply {
                val startIndex = safeTitle.length + separator.length
                if (startIndex < combinedText.length) {
                    setSpan(
                        RelativeSizeSpan(0.80f),
                        startIndex,
                        combinedText.length,
                        Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
                    )
                }
            }
            builder.setContentTitle(spannable).setContentText(null).build()
        }
        this.startForeground(notification)
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        GlobalState.getCurrentVPNPlugin()?.requestGc()
    }

    override fun onBind(intent: Intent): IBinder = binder

    override fun onDestroy() {
        stop()
        super.onDestroy()
    }
}
