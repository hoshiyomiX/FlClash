package com.follow.clash.service.modules

import android.app.Notification.FOREGROUND_SERVICE_IMMEDIATE
import android.app.Service
import android.app.Service.STOP_FOREGROUND_REMOVE
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.getSystemService
import com.follow.clash.common.Components
import com.follow.clash.common.GlobalState
import com.follow.clash.common.QuickAction
import com.follow.clash.common.quickIntent
import com.follow.clash.common.startForeground
import com.follow.clash.common.tickerFlow
import com.follow.clash.common.toPendingIntent
import com.follow.clash.core.Core
import com.follow.clash.service.R
import com.follow.clash.service.State
import com.follow.clash.service.models.NotificationParams
import com.follow.clash.service.models.getSpeedTrafficText
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.launch

data class ExtendedNotificationParams(
    val title: String,
    val stopText: String,
    val onlyStatisticsProxy: Boolean,
    val contentText: String,
)

val NotificationParams.extended: ExtendedNotificationParams
    get() = ExtendedNotificationParams(
        title, stopText, onlyStatisticsProxy, Core.getSpeedTrafficText(onlyStatisticsProxy)
    )

class NotificationModule(private val service: Service) : Module() {
    private val scope = CoroutineScope(Dispatchers.Default)

    // S-02: track whether startForeground has been called at least once
    private var isFirstUpdate = true

    override fun onInstall() {
        // S-11: Register shared screen state (single BroadcastReceiver for all modules)
        ScreenState.register(service)
        scope.launch {
            // Initial notification
            val initialParams = State.notificationParamsFlow.value?.extended
            if (initialParams != null) {
                update(initialParams)
            } else {
                update(NotificationParams().extended)
            }

            // S-02 + S-11: Only run ticker when screen is on using shared ScreenState
            // When screen is off, flowOf(empty) emits nothing (no JNI calls)
            ScreenState.isScreenOn.flatMapLatest { screenOn ->
                if (screenOn) tickerFlow(1000, 0) else flowOf()
            }.collect { _ ->
                val params = State.notificationParamsFlow.value?.extended
                if (params != null) {
                    update(params)
                }
            }
        }
    }

    private val notificationBuilder: NotificationCompat.Builder by lazy {
        val intent = Intent().setComponent(Components.MAIN_ACTIVITY)
        with(
            NotificationCompat.Builder(
                service, GlobalState.NOTIFICATION_CHANNEL
            )
        ) {
            setSmallIcon(R.drawable.ic)
            setContentTitle("FlClash EX")
            setContentIntent(intent.toPendingIntent)
            setPriority(NotificationCompat.PRIORITY_HIGH)
            setCategory(NotificationCompat.CATEGORY_SERVICE)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                foregroundServiceBehavior = FOREGROUND_SERVICE_IMMEDIATE
            }
            setOngoing(true)
            setShowWhen(true)
            setOnlyAlertOnce(true)
        }
    }

    private fun update(params: ExtendedNotificationParams) {
        val notification = with(notificationBuilder) {
            setContentTitle(params.title)
            setContentText(params.contentText)
            clearActions()
            addAction(
                0, params.stopText, QuickAction.STOP.quickIntent.toPendingIntent
            ).build()
        }
        // S-03: call startForeground only once, then use notify() for updates
        // This reduces 86,400 IPC calls/day to just 1
        if (isFirstUpdate) {
            service.startForeground(notification)
            isFirstUpdate = false
        } else {
            val manager = service.getSystemService<android.app.NotificationManager>()
            manager?.notify(GlobalState.NOTIFICATION_ID, notification)
        }
    }

    override fun onUninstall() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            service.stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            service.stopForeground(true)
        }
        // S-11: Unregister shared screen state
        ScreenState.unregister(service)
        scope.cancel()
    }
}