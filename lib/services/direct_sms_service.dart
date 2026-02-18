import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class DirectSmsService {
  static const MethodChannel _channel = MethodChannel('night_walkers/direct_sms');
  static final ValueNotifier<int> volumeTriggerToken = ValueNotifier<int>(0);

  static Future<Map<String, dynamic>> sendSms({
    required String to,
    required String message,
    int? subscriptionId,
  }) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'sendDirectSms',
      {
        'to': to,
        'message': message,
        'subscriptionId': subscriptionId,
      },
    );
    return Map<String, dynamic>.from(result ?? const <String, dynamic>{});
  }

  static Future<Map<String, dynamic>> getDiagnostics() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getSmsManagerDiagnostics',
    );
    return Map<String, dynamic>.from(result ?? const <String, dynamic>{});
  }

  static void initializeVolumeTriggerListener() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onVolumeTrigger') {
        volumeTriggerToken.value = volumeTriggerToken.value + 1;
      }
    });
  }

  static Future<void> setBackgroundVolumeTriggerEnabled(bool enabled) async {
    await _channel.invokeMethod(
      'setBackgroundVolumeTriggerEnabled',
      {'enabled': enabled},
    );
  }

  static Future<bool> isBackgroundVolumeTriggerRunning() async {
    final result = await _channel.invokeMethod<bool>('isBackgroundVolumeTriggerRunning');
    return result ?? false;
  }
}
