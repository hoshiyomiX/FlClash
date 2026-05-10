package com.follow.clash.service.modules

import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.PowerManager
import androidx.core.content.getSystemService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

// S-11: Shared screen state singleton to consolidate duplicate BroadcastReceiver registrations.
// Both NotificationModule and SuspendModule were registering separate receivers for
// ACTION_SCREEN_ON/OFF, causing each screen event to wake the process twice.
object ScreenState {
    private var receiver: BroadcastReceiver? = null
    private val _isScreenOn = MutableStateFlow(true)
    val isScreenOn: StateFlow<Boolean> = _isScreenOn.asStateFlow()

    fun register(service: Service) {
        if (receiver != null) return
        val pm = service.getSystemService<PowerManager>()
        _isScreenOn.value = pm?.isInteractive ?: true

        receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == Intent.ACTION_SCREEN_ON) {
                    _isScreenOn.value = true
                } else if (intent?.action == Intent.ACTION_SCREEN_OFF) {
                    _isScreenOn.value = false
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        }
        service.registerReceiver(receiver, filter)
    }

    fun unregister(service: Service) {
        receiver?.let {
            try { service.unregisterReceiver(it) } catch (_: Exception) {}
        }
        receiver = null
    }
}
