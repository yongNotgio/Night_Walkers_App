package com.example.night_walkers_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.app.Service
import android.content.pm.PackageManager
import android.content.Intent
import android.content.IntentFilter
import android.database.ContentObserver
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.media.AudioManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.provider.Settings
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import androidx.core.content.ContextCompat
import androidx.core.location.LocationManagerCompat
import org.json.JSONArray
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

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
    private var mediaPlayer: MediaPlayer? = null
    private var cameraManager: CameraManager? = null
    private var flashCameraId: String? = null
    private var isTorchOn = false
    private var flashBlinkRunnable: Runnable? = null
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
        cameraManager = getSystemService(CAMERA_SERVICE) as? CameraManager
        flashCameraId = findFlashCameraId()
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
            .setContentTitle("NightWalkers background mode")
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

        playConfiguredAlarmFromFlutterAssets()
        startFlashBlink()
        sendEmergencySmsToSavedContacts()

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
        stopConfiguredAlarm()
        stopFlashBlink()
        val vibrator = getSystemService(VIBRATOR_SERVICE) as? Vibrator
        vibrator?.cancel()
        updateNotification(0)
    }

    private fun playConfiguredAlarmFromFlutterAssets() {
        stopConfiguredAlarm()
        val selected = getFlutterPref("selected_ringtone")?.trim().orEmpty()
        val filename = when (selected) {
            "", "Default Alarm" -> "alarm.wav"
            "iPhone Amber Alert" -> "iphone_amber_alert.mp3"
            "Emergency Siren" -> "emergency_alarm_siren.mp3"
            "Message Alert" -> "message_alert.mp3"
            else -> selected
        }
        val assetPath = "flutter_assets/assets/sounds/$filename"
        runCatching {
            assets.openFd(assetPath).use { afd ->
                mediaPlayer = MediaPlayer().apply {
                    setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                    isLooping = true
                    setAudioStreamType(AudioManager.STREAM_ALARM)
                    prepare()
                    start()
                }
            }
        }.onFailure {
            // Fallback to default bundled alarm if selected asset can't be opened.
            runCatching {
                assets.openFd("flutter_assets/assets/sounds/alarm.wav").use { afd ->
                    mediaPlayer = MediaPlayer().apply {
                        setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                        isLooping = true
                        setAudioStreamType(AudioManager.STREAM_ALARM)
                        prepare()
                        start()
                    }
                }
            }
        }
    }

    private fun stopConfiguredAlarm() {
        runCatching { mediaPlayer?.stop() }
        runCatching { mediaPlayer?.release() }
        mediaPlayer = null
    }

    private fun findFlashCameraId(): String? {
        val manager = cameraManager ?: return null
        return runCatching {
            manager.cameraIdList.firstOrNull { id ->
                val chars = manager.getCameraCharacteristics(id)
                chars.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
            }
        }.getOrNull()
    }

    private fun startFlashBlink() {
        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            return
        }
        val manager = cameraManager ?: return
        val cameraId = flashCameraId ?: return

        val blinkMs = getFlutterPref("flashlight_blink_speed")?.toLongOrNull() ?: 167L
        val interval = blinkMs.coerceIn(50L, 1000L)

        flashBlinkRunnable?.let { mainHandler.removeCallbacks(it) }
        flashBlinkRunnable = object : Runnable {
            override fun run() {
                if (!isAlarmActive) return
                isTorchOn = !isTorchOn
                runCatching { manager.setTorchMode(cameraId, isTorchOn) }
                mainHandler.postDelayed(this, interval)
            }
        }
        mainHandler.post(flashBlinkRunnable!!)
    }

    private fun stopFlashBlink() {
        flashBlinkRunnable?.let { mainHandler.removeCallbacks(it) }
        flashBlinkRunnable = null
        if (isTorchOn) {
            val manager = cameraManager
            val cameraId = flashCameraId
            if (manager != null && cameraId != null) {
                runCatching { manager.setTorchMode(cameraId, false) }
            }
        }
        isTorchOn = false
    }

    private fun getFlutterPref(key: String): String? {
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val direct = prefs.getString(key, null)
        if (!direct.isNullOrBlank()) return direct
        return prefs.getString("flutter.$key", null)
    }

    private fun sendEmergencySmsToSavedContacts() {
        // Run on a background thread so we can wait for a fresh location fix
        // without blocking the main thread.
        Thread {
            sendEmergencySmsBlocking()
        }.start()
    }

    private fun sendEmergencySmsBlocking() {
        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
            return
        }

        val contactsJson = getFlutterPref("emergency_contacts") ?: return
        val numbers = mutableListOf<String>()
        runCatching {
            val arr = JSONArray(contactsJson)
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue
                val raw = obj.optString("number", "").trim()
                if (raw.isNotEmpty()) numbers.add(raw)
            }
        }
        if (numbers.isEmpty()) return

        val baseMessage = getFlutterPref("custom_message")?.takeIf { it.isNotBlank() }
            ?: "This is an emergency! Please help me immediately!"
        val locationSuffix = buildLocationSuffixWithFreshFix()
        val message = if (locationSuffix.isNotEmpty()) "$baseMessage$locationSuffix" else baseMessage

        val smsManager = getSmsManager()
        for (number in numbers) {
            runCatching {
                val parts = smsManager.divideMessage(message)
                if (parts.size > 1) {
                    smsManager.sendMultipartTextMessage(number, null, ArrayList(parts), null, null)
                } else {
                    smsManager.sendTextMessage(number, null, message, null, null)
                }
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun getSmsManager(): SmsManager {
        val defaultSubId = SmsManager.getDefaultSmsSubscriptionId()
        if (defaultSubId != SubscriptionManager.INVALID_SUBSCRIPTION_ID) {
            runCatching { return SmsManager.getSmsManagerForSubscriptionId(defaultSubId) }
        }
        val subscriptionManager = getSystemService(SubscriptionManager::class.java)
        val activeSubId = runCatching {
            subscriptionManager?.activeSubscriptionInfoList
                ?.firstOrNull()
                ?.subscriptionId
        }.getOrNull()
        if (activeSubId != null && activeSubId != SubscriptionManager.INVALID_SUBSCRIPTION_ID) {
            runCatching { return SmsManager.getSmsManagerForSubscriptionId(activeSubId) }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = getSystemService(SmsManager::class.java)
            if (manager != null) return manager
        }
        return SmsManager.getDefault()
    }

    /**
     * Tries to get a fresh location fix, falling back to the cached location.
     * Blocks the calling thread for up to ~8 seconds while waiting for GPS.
     * Must NOT be called on the main thread.
     */
    private fun buildLocationSuffixWithFreshFix(): String {
        val fineGranted = ContextCompat.checkSelfPermission(
            this,
            android.Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        val coarseGranted = ContextCompat.checkSelfPermission(
            this,
            android.Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        if (!fineGranted && !coarseGranted) return ""

        val locationManager = getSystemService(LOCATION_SERVICE) as? LocationManager ?: return ""
        if (!LocationManagerCompat.isLocationEnabled(locationManager)) return ""

        // Try cached location first — if it's recent enough (< 2 min), use it.
        val cached = getBestLastKnownLocation(locationManager)
        if (cached != null && (System.currentTimeMillis() - cached.time) < 120_000L) {
            return formatLocationSuffix(cached)
        }

        // Request a fresh fix with a timeout.
        val freshLocation = requestFreshLocation(locationManager, fineGranted)
        if (freshLocation != null) {
            return formatLocationSuffix(freshLocation)
        }

        // Last resort: use stale cached location if any.
        if (cached != null) {
            return formatLocationSuffix(cached)
        }
        return ""
    }

    private fun formatLocationSuffix(location: Location): String {
        return " My location coordinates are: Latitude ${location.latitude}, Longitude ${location.longitude}."
    }

    /**
     * Requests a single fresh location fix, blocking for up to [timeoutSeconds] seconds.
     */
    private fun requestFreshLocation(locationManager: LocationManager, hasFinePermission: Boolean): Location? {
        val provider = if (hasFinePermission && locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
            LocationManager.GPS_PROVIDER
        } else if (locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
            LocationManager.NETWORK_PROVIDER
        } else if (locationManager.isProviderEnabled(LocationManager.PASSIVE_PROVIDER)) {
            LocationManager.PASSIVE_PROVIDER
        } else {
            return null
        }

        val latch = CountDownLatch(1)
        var result: Location? = null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // API 30+: use getCurrentLocation which is designed for single fixes.
            runCatching {
                locationManager.getCurrentLocation(
                    provider,
                    null, // CancellationSignal
                    mainExecutor
                ) { location ->
                    result = location
                    latch.countDown()
                }
            }.onFailure { latch.countDown() }
        } else {
            // Older APIs: use requestSingleUpdate.
            val locationListener = object : LocationListener {
                override fun onLocationChanged(location: Location) {
                    result = location
                    latch.countDown()
                    runCatching { locationManager.removeUpdates(this) }
                }
                @Deprecated("Deprecated in API")
                override fun onStatusChanged(provider: String?, status: Int, extras: android.os.Bundle?) {}
                override fun onProviderEnabled(provider: String) {}
                override fun onProviderDisabled(provider: String) {
                    latch.countDown()
                }
            }
            runCatching {
                mainHandler.post {
                    runCatching {
                        @Suppress("DEPRECATION")
                        locationManager.requestSingleUpdate(provider, locationListener, Looper.getMainLooper())
                    }.onFailure { latch.countDown() }
                }
            }.onFailure { latch.countDown() }
        }

        // Wait up to 8 seconds for a fix.
        latch.await(8, TimeUnit.SECONDS)
        return result
    }

    private fun getBestLastKnownLocation(locationManager: LocationManager): Location? {
        val providers = runCatching { locationManager.getProviders(true) }.getOrDefault(emptyList())
        if (providers.isEmpty()) return null

        var best: Location? = null
        for (provider in providers) {
            val loc = runCatching { locationManager.getLastKnownLocation(provider) }.getOrNull() ?: continue
            if (best == null || loc.time > best!!.time) {
                best = loc
            }
        }
        return best
    }
}
