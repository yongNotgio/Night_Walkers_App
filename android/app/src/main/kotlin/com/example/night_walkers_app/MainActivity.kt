package com.example.night_walkers_app

import android.content.Intent
import android.content.IntentFilter
import android.content.BroadcastReceiver
import android.app.ActivityManager
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "night_walkers/direct_sms"
    private var directSmsChannel: MethodChannel? = null

    private val volumeTriggerReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: android.content.Context?, intent: Intent?) {
            if (intent?.action == VolumeTriggerService.ACTION_TRIGGER) {
                directSmsChannel?.invokeMethod("onVolumeTrigger", null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        directSmsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        directSmsChannel?.setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendDirectSms" -> {
                        val to = call.argument<String>("to")
                        val message = call.argument<String>("message")
                        val subId = call.argument<Int>("subscriptionId")

                        if (to.isNullOrBlank() || message.isNullOrEmpty()) {
                            result.error("invalid_args", "to and message are required", null)
                            return@setMethodCallHandler
                        }

                        try {
                            val (smsManager, source) = getSmsManager(subId)
                            val parts = smsManager.divideMessage(message)
                            if (parts.size > 1) {
                                smsManager.sendMultipartTextMessage(
                                    to,
                                    null,
                                    ArrayList(parts),
                                    null,
                                    null
                                )
                            } else {
                                smsManager.sendTextMessage(to, null, message, null, null)
                            }
                            result.success(mapOf("success" to true, "managerSource" to source))
                        } catch (e: Exception) {
                            result.error("direct_sms_failed", e.message, e.toString())
                        }
                    }

                    "getSmsManagerDiagnostics" -> {
                        try {
                            val systemSmsManagerAvailable = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                getSystemService(SmsManager::class.java) != null
                            } else {
                                true
                            }
                            val sendToIntent = Intent(Intent.ACTION_SENDTO).apply {
                                data = Uri.parse("smsto:123")
                            }
                            val canResolveSmsIntent =
                                sendToIntent.resolveActivity(packageManager) != null

                            result.success(
                                mapOf(
                                    "sdkInt" to Build.VERSION.SDK_INT,
                                    "defaultSmsSubscriptionId" to SmsManager.getDefaultSmsSubscriptionId(),
                                    "invalidSubscriptionId" to SubscriptionManager.INVALID_SUBSCRIPTION_ID,
                                    "hasTelephonyFeature" to packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY),
                                    "systemSmsManagerAvailable" to systemSmsManagerAvailable,
                                    "canResolveSmsIntent" to canResolveSmsIntent,
                                )
                            )
                        } catch (e: Exception) {
                            result.error("diagnostics_failed", e.message, e.toString())
                        }
                    }

                    "setBackgroundVolumeTriggerEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        try {
                            if (enabled) {
                                val intent = Intent(this, VolumeTriggerService::class.java)
                                ContextCompat.startForegroundService(this, intent)
                            } else {
                                stopService(Intent(this, VolumeTriggerService::class.java))
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("background_trigger_failed", e.message, e.toString())
                        }
                    }

                    "isBackgroundVolumeTriggerRunning" -> {
                        try {
                            val running = isServiceRunning(VolumeTriggerService::class.java)
                            result.success(running)
                        } catch (e: Exception) {
                            result.error("background_trigger_status_failed", e.message, e.toString())
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        registerReceiver(
            volumeTriggerReceiver,
            IntentFilter(VolumeTriggerService.ACTION_TRIGGER)
        )
    }

    override fun onDestroy() {
        runCatching { unregisterReceiver(volumeTriggerReceiver) }
        directSmsChannel = null
        super.onDestroy()
    }

    @Suppress("DEPRECATION")
    private fun getSmsManager(subId: Int?): Pair<SmsManager, String> {
        val targetSubId = when {
            subId != null && subId != SubscriptionManager.INVALID_SUBSCRIPTION_ID -> subId
            else -> SmsManager.getDefaultSmsSubscriptionId()
        }

        if (targetSubId != SubscriptionManager.INVALID_SUBSCRIPTION_ID) {
            return Pair(
                SmsManager.getSmsManagerForSubscriptionId(targetSubId),
                "subscription:$targetSubId"
            )
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val fromSystemService = getSystemService(SmsManager::class.java)
            if (fromSystemService != null) {
                return Pair(fromSystemService, "systemService")
            }
        }

        return Pair(SmsManager.getDefault(), "getDefault")
    }

    @Suppress("DEPRECATION")
    private fun isServiceRunning(serviceClass: Class<*>): Boolean {
        val manager = getSystemService(ACTIVITY_SERVICE) as ActivityManager
        for (service in manager.getRunningServices(Int.MAX_VALUE)) {
            if (serviceClass.name == service.service.className) {
                return true
            }
        }
        return false
    }
}
