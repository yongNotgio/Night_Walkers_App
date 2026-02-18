import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:another_telephony/telephony.dart';
import 'dart:convert';
import 'package:night_walkers_app/services/direct_sms_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Settings variables
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _flashlightEnabled = true;
  bool _autoLocationShare = true;
  double _flashlightBlinkSpeed = 167.0; // milliseconds
  String _customMessage = 'This is an emergency! Please help me immediately!';
  String _selectedRingtone = 'alarm.wav';
  bool _sendLocationAsPlainText = true;
  bool _batterySaverEnabled = false;
  bool _alwaysMaxVolume = false;
  double _alarmVolume = 1.0;
  bool _call911Enabled = false;
  bool _backgroundModeEnabled = false;

  final TextEditingController _messageController = TextEditingController();
  final Telephony _telephony = Telephony.instance;

  final Map<String, String> _ringtoneOptions = {
    'Default Alarm': 'alarm.wav',
    'iPhone Amber Alert': 'iphone_amber_alert.mp3',
    'Emergency Siren': 'emergency_alarm_siren.mp3',
    'Message Alert': 'message_alert.mp3',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
      _flashlightEnabled = prefs.getBool('flashlight_enabled') ?? true;
      _autoLocationShare = prefs.getBool('auto_location_share') ?? true;
      _flashlightBlinkSpeed =
          prefs.getDouble('flashlight_blink_speed') ?? 167.0;
      _customMessage =
          prefs.getString('custom_message') ??
          'This is an emergency! Please help me immediately!';
      final storedRingtone = prefs.getString('selected_ringtone');
      _selectedRingtone = _normalizeRingtoneValue(storedRingtone);
      _messageController.text = _customMessage;
      _sendLocationAsPlainText =
          prefs.getBool('send_location_as_plain_text') ?? true;
      _batterySaverEnabled = prefs.getBool('battery_saver_enabled') ?? false;
      _alwaysMaxVolume = prefs.getBool('always_max_volume') ?? false;
      _alarmVolume = prefs.getDouble('alarm_volume') ?? 1.0;
      _call911Enabled = prefs.getBool('call_911_enabled') ?? false;
      _backgroundModeEnabled =
          prefs.getBool('background_mode_enabled') ?? false;
    });
    final storedRingtone = prefs.getString('selected_ringtone');
    if (storedRingtone != _selectedRingtone) {
      await prefs.setString('selected_ringtone', _selectedRingtone);
    }
  }

  String _normalizeRingtoneValue(String? value) {
    if (value == null || value.isEmpty) return 'alarm.wav';
    return _ringtoneOptions[value] ?? value;
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  void _resetToDefaults() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset Settings'),
            content: const Text(
              'Are you sure you want to reset all settings to default values?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  if (!mounted) return;
                  Navigator.pop(this.context);
                  _loadSettings();
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Settings reset to defaults')),
                  );
                },
                child: const Text('Reset', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  void _testPanicFeatures() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Test Panic Features'),
            content: const Text(
              'This will test the sound, vibration, and flashlight features without sending SMS alerts.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Here you would call your test functions
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Testing panic features...')),
                  );
                },
                child: const Text('Test'),
              ),
            ],
          ),
    );
  }

  Future<void> _setBackgroundMode(bool enabled) async {
    setState(() => _backgroundModeEnabled = enabled);
    if (enabled) {
      final notificationPermission = await Permission.notification.request();
      if (!notificationPermission.isGranted) {
        if (!mounted) return;
        setState(() => _backgroundModeEnabled = false);
        await _saveSetting('background_mode_enabled', false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notification permission is required for background mode.',
            ),
          ),
        );
        return;
      }
    }

    await _saveSetting('background_mode_enabled', enabled);
    try {
      await DirectSmsService.setBackgroundVolumeTriggerEnabled(enabled);
      final running = await DirectSmsService.isBackgroundVolumeTriggerRunning();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? (running
                    ? 'Background mode enabled. Press volume down 3 times quickly to trigger alarm.'
                    : 'Background mode requested, but service is not running.')
                : (running
                    ? 'Background mode toggle off requested, but service still appears running.'
                    : 'Background mode disabled.'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not toggle background mode: $e')),
      );
    }
  }

  Future<void> _showSmsDiagnostics({required bool sendTest}) async {
    final report = await _collectSmsDiagnostics(sendTest: sendTest);
    if (!mounted) return;
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(
              sendTest ? 'SMS Diagnostics (With Send Test)' : 'SMS Diagnostics',
            ),
            content: SingleChildScrollView(
              child: SelectableText(
                report,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
              if (!sendTest)
                TextButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    await _showSmsDiagnostics(sendTest: true);
                  },
                  child: const Text('Run Send Test'),
                ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _showSmsDiagnostics(sendTest: false);
                },
                child: const Text('Refresh'),
              ),
            ],
          ),
    );
  }

  Future<String> _collectSmsDiagnostics({required bool sendTest}) async {
    final buffer = StringBuffer();
    buffer.writeln('Time: ${DateTime.now().toIso8601String()}');
    buffer.writeln(
      'Mode: ${sendTest ? 'Diagnostics + send test' : 'Diagnostics only'}',
    );
    buffer.writeln('');

    final pluginPermissionResult = await _probe(
      () => _telephony.requestPhoneAndSmsPermissions,
    );
    final smsStatus = await Permission.sms.status;
    final phoneStatus = await Permission.phone.status;

    buffer.writeln('Permissions');
    buffer.writeln(
      '  Plugin requestPhoneAndSmsPermissions: $pluginPermissionResult',
    );
    buffer.writeln('  permission_handler.sms: $smsStatus');
    buffer.writeln('  permission_handler.phone: $phoneStatus');
    buffer.writeln('');

    final isSmsCapable = await _probe(() => _telephony.isSmsCapable);
    final simState = await _probe(() => _telephony.simState);
    final simOperator = await _probe(() => _telephony.simOperator);
    final simOperatorName = await _probe(() => _telephony.simOperatorName);
    final networkOperator = await _probe(() => _telephony.networkOperator);
    final networkOperatorName = await _probe(
      () => _telephony.networkOperatorName,
    );
    final phoneType = await _probe(() => _telephony.phoneType);
    final dataNetworkType = await _probe(() => _telephony.dataNetworkType);
    final serviceState = await _probe(() => _telephony.serviceState);
    final isNetworkRoaming = await _probe(() => _telephony.isNetworkRoaming);
    final nativeSmsDiagnostics = await _probe(
      () => DirectSmsService.getDiagnostics(),
    );

    buffer.writeln('Telephony');
    buffer.writeln('  isSmsCapable: $isSmsCapable');
    buffer.writeln('  simState: $simState');
    buffer.writeln('  simOperator: $simOperator');
    buffer.writeln('  simOperatorName: $simOperatorName');
    buffer.writeln('  networkOperator: $networkOperator');
    buffer.writeln('  networkOperatorName: $networkOperatorName');
    buffer.writeln('  phoneType: $phoneType');
    buffer.writeln('  dataNetworkType: $dataNetworkType');
    buffer.writeln('  serviceState: $serviceState');
    buffer.writeln('  isNetworkRoaming: $isNetworkRoaming');
    buffer.writeln('');
    buffer.writeln('Native SMS Manager');
    buffer.writeln('  diagnostics: $nativeSmsDiagnostics');
    buffer.writeln('');

    final prefs = await SharedPreferences.getInstance();
    final contactsJson = prefs.getString('emergency_contacts');
    List<Map<String, String>> contacts = [];
    if (contactsJson != null) {
      final decoded = jsonDecode(contactsJson) as List;
      contacts =
          decoded
              .map(
                (item) => {
                  'name': item['name'].toString(),
                  'number': item['number'].toString(),
                },
              )
              .toList();
    }
    buffer.writeln('Contacts');
    buffer.writeln('  saved_contacts_count: ${contacts.length}');
    if (contacts.isNotEmpty) {
      buffer.writeln(
        '  first_contact: ${contacts.first['name']} (${contacts.first['number']})',
      );
    }
    buffer.writeln('');

    if (sendTest) {
      String? firstNumber;
      for (final contact in contacts) {
        final number = (contact['number'] ?? '').trim();
        if (number.isNotEmpty) {
          firstNumber = number;
          break;
        }
      }
      if (firstNumber == null) {
        buffer.writeln('Send Test');
        buffer.writeln('  result: skipped (no emergency contact number saved)');
      } else {
        final String targetNumber = firstNumber;
        final message =
            'NightWalkers SMS diagnostics test: ${DateTime.now().toIso8601String()}';
        final sendError = await _captureError(
          () => DirectSmsService.sendSms(to: targetNumber, message: message),
        );
        buffer.writeln('Send Test');
        buffer.writeln('  to: $targetNumber');
        buffer.writeln(
          sendError == null
              ? '  result: sendSms call succeeded (carrier delivery still not guaranteed)'
              : '  result: failed -> $sendError',
        );
      }
    }

    return buffer.toString();
  }

  Future<Object?> _probe(Future<Object?> Function() action) async {
    try {
      return await action();
    } catch (e) {
      return 'error: $e';
    }
  }

  Future<String?> _captureError(Future<Object?> Function() action) async {
    try {
      await action();
      return null;
    } catch (e) {
      return '$e';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emergency Features Section
          _buildSection('Emergency Features', [
            SwitchListTile(
              title: const Text('Sound Alert'),
              subtitle: const Text(
                'Play alarm sound when panic button is activated',
              ),
              value: _soundEnabled,
              onChanged: (value) {
                setState(() => _soundEnabled = value);
                _saveSetting('sound_enabled', value);
              },
            ),
            SwitchListTile(
              title: const Text('Vibration'),
              subtitle: const Text('Vibrate device during emergency'),
              value: _vibrationEnabled,
              onChanged: (value) {
                setState(() => _vibrationEnabled = value);
                _saveSetting('vibration_enabled', value);
              },
            ),
            SwitchListTile(
              title: const Text('Flashlight Strobe'),
              subtitle: const Text('Flash device light as distress signal'),
              value: _flashlightEnabled,
              onChanged: (value) {
                setState(() => _flashlightEnabled = value);
                _saveSetting('flashlight_enabled', value);
              },
            ),
            if (_flashlightEnabled) ...[
              ListTile(
                title: const Text('Flashlight Blink Speed'),
                subtitle: Slider(
                  value: _flashlightBlinkSpeed,
                  min: 50.0,
                  max: 500.0,
                  divisions: 9,
                  label: '${_flashlightBlinkSpeed.round()}ms',
                  onChanged: (value) {
                    setState(() => _flashlightBlinkSpeed = value);
                    _saveSetting('flashlight_blink_speed', value);
                  },
                ),
              ),
            ],
            ListTile(
              title: const Text('Alert Sound'),
              subtitle: Text(
                _ringtoneOptions.entries
                    .firstWhere(
                      (e) => e.value == _selectedRingtone,
                      orElse:
                          () => const MapEntry('Default Alarm', 'alarm.wav'),
                    )
                    .key,
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Select Alert Sound'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children:
                              _ringtoneOptions.entries
                                  .map(
                                    (entry) => RadioListTile<String>(
                                      title: Text(entry.key),
                                      value: entry.value,
                                      groupValue: _selectedRingtone,
                                      onChanged: (value) {
                                        setState(
                                          () => _selectedRingtone = value!,
                                        );
                                        _saveSetting(
                                          'selected_ringtone',
                                          value!,
                                        );
                                        Navigator.pop(context);
                                      },
                                    ),
                                  )
                                  .toList(),
                        ),
                      ),
                );
              },
            ),
            SwitchListTile(
              title: const Text('Automatic 911 Call'),
              subtitle: const Text(
                'Automatically call 911 when panic button is activated',
              ),
              value: _call911Enabled,
              onChanged: (value) {
                setState(() => _call911Enabled = value);
                _saveSetting('call_911_enabled', value);
              },
            ),
          ]),

          // Alarm Volume Controls
          _buildSection('Alarm Volume', [
            SwitchListTile(
              title: const Text('Always Max Volume'),
              subtitle: const Text('Play alarm at maximum volume'),
              value: _alwaysMaxVolume,
              onChanged: (value) {
                setState(() => _alwaysMaxVolume = value);
                _saveSetting('always_max_volume', value);
              },
            ),
            ListTile(
              title: const Text('Custom Alarm Volume'),
              subtitle: Slider(
                value: _alarmVolume,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                label: '${(_alarmVolume * 100).round()}%',
                onChanged:
                    _alwaysMaxVolume
                        ? null
                        : (value) {
                          setState(() => _alarmVolume = value);
                          _saveSetting('alarm_volume', value);
                        },
              ),
              // Disables the ListTile if Always Max Volume is on
              enabled: !_alwaysMaxVolume,
            ),
          ]),

          // Location & SMS Section
          _buildSection('Location & SMS', [
            SwitchListTile(
              title: const Text('Auto Location Sharing'),
              subtitle: const Text(
                'Automatically share location when panic button is pressed',
              ),
              value: _autoLocationShare,
              onChanged: (value) {
                setState(() => _autoLocationShare = value);
                _saveSetting('auto_location_share', value);
              },
            ),
            SwitchListTile(
              title: const Text('Send Location as Plain Text'),
              subtitle: const Text(
                'Send latitude and longitude coordinates as text instead of a link (might help with sending issues)',
              ),
              value: _sendLocationAsPlainText,
              onChanged: (value) {
                setState(() => _sendLocationAsPlainText = value);
                _saveSetting('send_location_as_plain_text', value);
              },
            ),
            ListTile(
              title: const Text('Custom Emergency Message'),
              subtitle: const Text(
                'Customize the message sent to emergency contacts',
              ),
              trailing: const Icon(Icons.edit),
              onTap: () {
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Edit Emergency Message'),
                        content: TextField(
                          controller: _messageController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Enter your emergency message...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(
                                () => _customMessage = _messageController.text,
                              );
                              _saveSetting(
                                'custom_message',
                                _messageController.text,
                              );
                              Navigator.pop(context);
                            },
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                );
              },
            ),
          ]),

          // Battery Saver Section
          _buildSection('Battery Saver', [
            SwitchListTile(
              title: const Text('Enable Battery Saver Mode'),
              subtitle: const Text(
                'Optimize features to conserve battery during emergencies',
              ),
              value: _batterySaverEnabled,
              onChanged: (value) {
                setState(() => _batterySaverEnabled = value);
                _saveSetting('battery_saver_enabled', value);
              },
            ),
          ]),

          // App Behavior Section
          _buildSection('App Behavior', [
            SwitchListTile(
              title: const Text('Background Mode'),
              subtitle: const Text(
                'When minimized, press volume down 3 times quickly to trigger the alarm (Android).',
              ),
              value: _backgroundModeEnabled,
              onChanged: _setBackgroundMode,
            ),
          ]),

          // Permissions Section
          _buildSection('Permissions', [
            ListTile(
              title: const Text('App Permissions'),
              subtitle: const Text('Manage app permissions'),
              trailing: const Icon(Icons.security),
              onTap: () => openAppSettings(),
            ),
            ListTile(
              title: const Text('SMS Diagnostics'),
              subtitle: const Text(
                'Check SIM, permissions, telephony state, and run a direct SMS test',
              ),
              trailing: const Icon(Icons.sms_outlined),
              onTap: () => _showSmsDiagnostics(sendTest: false),
            ),
            ListTile(
              title: const Text('Test Features'),
              subtitle: const Text(
                'Test panic features without sending alerts',
              ),
              trailing: const Icon(Icons.play_arrow),
              onTap: _testPanicFeatures,
            ),
          ]),

          // Data & Privacy Section
          _buildSection('Data & Privacy', [
            ListTile(
              title: const Text('Export Emergency Contacts'),
              subtitle: const Text('Backup your emergency contacts'),
              trailing: const Icon(Icons.download),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Export feature coming soon')),
                );
              },
            ),
            ListTile(
              title: const Text('Clear All Data'),
              subtitle: const Text('Remove all app data and settings'),
              trailing: const Icon(Icons.delete_forever, color: Colors.red),
              onTap: () {
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Clear All Data'),
                        content: const Text(
                          'This will delete all emergency contacts, settings, and app data. This action cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () async {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.clear();
                              if (!mounted) return;
                              Navigator.pop(this.context);
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text('All data cleared'),
                                ),
                              );
                            },
                            child: const Text(
                              'Clear',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                );
              },
            ),
          ]),

          // About Section
          _buildSection('About', [
            const ListTile(title: Text('App Version'), subtitle: Text('6.1.0')),
            ListTile(
              title: const Text('Reset to Defaults'),
              subtitle: const Text('Reset all settings to default values'),
              trailing: const Icon(Icons.refresh),
              onTap: _resetToDefaults,
            ),
            const ListTile(
              title: Text('Emergency Disclaimer'),
              subtitle: Text(
                'This app is a safety tool. Always contact local emergency services (911) for immediate help.',
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(child: Column(children: children)),
        const SizedBox(height: 8),
      ],
    );
  }
}
