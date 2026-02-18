package com.example.night_walkers_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.app.Service
import android.content.Intent
import android.content.IntentFilter
import android.database.ContentObserver
import android.media.AudioManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.provider.Settings

class VolumeTriggerService : Service() {
    companion object {
        const val ACTION_TRIGGER = "com.example.night_walkers_app.VOLUME_TRIGGER"
        const val ACTION_STOP_ALARM = "com.example.night_walkers_app.STOP_ALARM"
        private const val CHANNEL_ID = "volume_trigger_channel"
        private const val NOTIFICATION_ID = 2201
        private const val WINDOW_MS = 4000L
        private const val REQUIRED_PRESSES = 3
    }

    private lateinit var audioManager: AudioManager
    private lateinit var notificationManager: NotificationManager
    private val trackedStreams = listOf(
        AudioManager.STREAM_MUSIC,
        AudioManager.STREAM_RING,
        AudioManager.STREAM_NOTIFICATION,
        AudioManager.STREAM_ALARM
    )
    private val mainHandler = Handler(Looper.getMainLooper())
    private val lastVolumes = mutableMapOf<Int, Int>()
    private var pressCount = 0
    private var firstPressAt = 0L
    private var ringtone: Ringtone? = null
    private var isAlarmActive = false

    private val volumeChangedReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: android.content.Context?, intent: Intent?) {
            if (intent?.action == "android.media.VOLUME_CHANGED_ACTION") {
                onVolumeChanged()
            }
        }
    }

    private val volumeObserver = object : ContentObserver(Handler(Looper.getMainLooper())) {
        override fun onChange(selfChange: Boolean) {
            super.onChange(selfChange)
            onVolumeChanged()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP_ALARM) {
            stopBackgroundAlarm()
        }
        return START_STICKY
    }

    override fun onCreate() {
        super.onCreate()
        audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
        notificationManager = getSystemService(NotificationManager::class.java)
        trackedStreams.forEach { stream ->
            lastVolumes[stream] = currentVolume(stream)
        }
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification(0))
        contentResolver.registerContentObserver(
            Settings.System.CONTENT_URI,
            true,
            volumeObserver
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(
                volumeChangedReceiver,
                IntentFilter("android.media.VOLUME_CHANGED_ACTION"),
                RECEIVER_NOT_EXPORTED
            )
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(
                volumeChangedReceiver,
                IntentFilter("android.media.VOLUME_CHANGED_ACTION")
            )
        }
    }

    override fun onDestroy() {
        contentResolver.unregisterContentObserver(volumeObserver)
        runCatching { unregisterReceiver(volumeChangedReceiver) }
        super.onDestroy()
    }

    private fun currentVolume(streamType: Int): Int {
        return audioManager.getStreamVolume(streamType)
    }

    private fun onVolumeChanged() {
        val now = System.currentTimeMillis()
        var detectedVolumeDown = false

        for (stream in trackedStreams) {
            val current = currentVolume(stream)
            val previous = lastVolumes[stream]
            if (previous != null && current < previous) {
                detectedVolumeDown = true
            }
            lastVolumes[stream] = current
        }

        if (!detectedVolumeDown) return

        if (now - firstPressAt > WINDOW_MS) {
            firstPressAt = now
            pressCount = 1
        } else {
            pressCount += 1
        }
        updateNotification(pressCount)

        if (pressCount >= REQUIRED_PRESSES) {
            pressCount = 0
            firstPressAt = 0L
            updateNotification(0)
            triggerBackgroundAlarm()
            sendBroadcast(Intent(ACTION_TRIGGER))
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Background Trigger",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors volume-down presses to trigger panic alarm."
            }
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(currentPressCount: Int): Notification {
        val statusText = if (currentPressCount > 0) {
            "Detected presses: $currentPressCount/$REQUIRED_PRESSES"
        } else {
            "Press volume down 3 times quickly to trigger alarm."
        }
        val stopIntent = Intent(this, VolumeTriggerService::class.java).apply {
            action = ACTION_STOP_ALARM
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            2202,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("Night Walkers background mode")
            .setContentText(statusText)
            .setSmallIcon(android.R.drawable.ic_lock_silent_mode_off)
            .setOngoing(true)
            .addAction(
                Notification.Action.Builder(
                    android.R.drawable.ic_media_pause,
                    "Stop Alarm",
                    stopPendingIntent
                ).build()
            )
            .build()
    }

    private fun updateNotification(currentPressCount: Int) {
        notificationManager.notify(NOTIFICATION_ID, buildNotification(currentPressCount))
    }

    private fun triggerBackgroundAlarm() {
        if (isAlarmActive) return
        isAlarmActive = true

        val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        ringtone = RingtoneManager.getRingtone(this, alarmUri)?.apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                isLooping = true
            }
            play()
        }

        val vibrator = getSystemService(VIBRATOR_SERVICE) as? Vibrator
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator?.vibrate(
                VibrationEffect.createWaveform(longArrayOf(0, 500, 500), 0)
            )
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(longArrayOf(0, 500, 500), 0)
        }

        // Auto-stop native alarm to avoid indefinite ringing if app is not opened.
        mainHandler.postDelayed({ stopBackgroundAlarm() }, 30000L)
    }

    private fun stopBackgroundAlarm() {
        if (!isAlarmActive) return
        isAlarmActive = false
        runCatching { ringtone?.stop() }
        ringtone = null
        val vibrator = getSystemService(VIBRATOR_SERVICE) as? Vibrator
        vibrator?.cancel()
        updateNotification(0)
    }
}
