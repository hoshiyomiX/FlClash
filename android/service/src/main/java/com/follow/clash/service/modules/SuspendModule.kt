package com.follow.clash.service.modules

import android.app.Service
import android.os.PowerManager
import androidx.core.content.getSystemService
import com.follow.clash.core.Core
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

// S-11: Now uses shared ScreenState singleton instead of registering its own BroadcastReceiver.
// This eliminates the duplicate wake-up per screen event.

class SuspendModule(private val service: Service) : Module() {
    private val scope = CoroutineScope(Dispatchers.Default)

    val isDeviceIdleMode: Boolean
        get() {
            return service.getSystemService<PowerManager>()?.isDeviceIdleMode ?: true
        }

    private fun onUpdate(isScreenOn: Boolean) {
        if (isScreenOn) {
            Core.suspended(false)
            return
        }
        Core.suspended(isDeviceIdleMode)
    }

    override fun onInstall() {
        scope.launch {
            // S-11: Use shared ScreenState instead of separate BroadcastReceiver
            ScreenState.isScreenOn.collect { screenOn ->
                onUpdate(screenOn)
            }
        }
    }

    override fun onUninstall() {
        scope.cancel()
    }
}
