import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundService {
  static final AudioPlayer _player = AudioPlayer();
  static const Map<String, String> _ringtoneAliasToFile = {
    'Default Alarm': 'alarm.wav',
    'iPhone Amber Alert': 'iphone_amber_alert.mp3',
    'Emergency Siren': 'emergency_alarm_siren.mp3',
    'Message Alert': 'message_alert.mp3',
  };

  static String normalizeFilename(String? filename) {
    final String value = (filename ?? '').trim();
    if (value.isEmpty) return 'alarm.wav';
    return _ringtoneAliasToFile[value] ?? value;
  }

  static Future<void> playAlarm({String filename = 'alarm.wav', double volume = 1.0}) async {
    final normalizedFile = normalizeFilename(filename);
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(volume);
      await _player.play(AssetSource('sounds/$normalizedFile'));
    } catch (e) {
      debugPrint('Could not play alarm sound "$normalizedFile": $e');
    }
  }

  static Future<void> stopAlarm() async {
    await _player.stop();
  }
}
