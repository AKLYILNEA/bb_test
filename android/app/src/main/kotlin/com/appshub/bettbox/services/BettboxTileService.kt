package com.appshub.bettbox.services

import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi
import androidx.lifecycle.Observer
import com.appshub.bettbox.GlobalState
import com.appshub.bettbox.RunState

@RequiresApi(Build.VERSION_CODES.N)
class BettboxTileService : TileService() {

    private val observer = Observer<RunState> { updateTile(it) }

    private fun updateTile(runState: RunState) {
        qsTile?.apply {
            state = when (runState) {
                RunState.START -> Tile.STATE_ACTIVE
                RunState.PENDING -> Tile.STATE_UNAVAILABLE
                RunState.STOP -> Tile.STATE_INACTIVE
            }
            updateTile()
        }
    }

    override fun onStartListening() {
        super.onStartListening()
        GlobalState.syncStatus()
        updateTile(GlobalState.currentRunState)
        GlobalState.runState.removeObserver(observer)
        GlobalState.runState.observeForever(observer)
    }

    override fun onStopListening() {
        GlobalState.runState.removeObserver(observer)
        super.onStopListening()
    }

    override fun onClick() {
        super.onClick()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            GlobalState.handleToggle()
        } else {
            when {
                isLocked -> unlockAndRun { GlobalState.handleToggle() }
                else -> GlobalState.handleToggle()
            }
        }
    }

    override fun onDestroy() {
        GlobalState.runState.removeObserver(observer)
        super.onDestroy()
    }
}
