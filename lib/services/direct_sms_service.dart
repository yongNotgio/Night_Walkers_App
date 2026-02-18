import 'package:flutter/services.dart';

class DirectSmsService {
  static const MethodChannel _channel = MethodChannel('night_walkers/direct_sms');

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
}
