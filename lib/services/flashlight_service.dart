import 'package:torch_light/torch_light.dart';
import 'package:flutter/foundation.dart';

class FlashlightService {
  static Future<void> turnOn() async {
    try {
      await TorchLight.enableTorch();
    } catch (e) {
      debugPrint('Could not turn on flashlight: $e');
    }
  }

  static Future<void> turnOff() async {
    try {
      await TorchLight.disableTorch();
    } catch (e) {
      debugPrint('Could not turn off flashlight: $e');
    }
  }

  static Future<void> toggle(bool on) async {
    if (on) {
      await turnOn();
    } else {
      await turnOff();
    }
  }
}
