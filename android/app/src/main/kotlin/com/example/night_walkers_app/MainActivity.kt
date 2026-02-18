package com.example.night_walkers_app

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "night_walkers/direct_sms"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
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

                    else -> result.notImplemented()
                }
            }
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
}
