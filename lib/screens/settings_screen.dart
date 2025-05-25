import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

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
  bool _quickActivation = false;
  double _flashlightBlinkSpeed = 167.0; // milliseconds
  String _customMessage = 'This is an emergency! Please help me immediately!';
  String _selectedRingtone = 'Default Alarm';
  bool _confirmBeforeActivation = true;

  final TextEditingController _messageController = TextEditingController();

  final List<String> _ringtoneOptions = [
    'Default Alarm',
    'Siren',
    'Emergency Horn',
    'Whistle',
  ];

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
      _quickActivation = prefs.getBool('quick_activation') ?? false;
      _flashlightBlinkSpeed =
          prefs.getDouble('flashlight_blink_speed') ?? 167.0;
      _customMessage =
          prefs.getString('custom_message') ??
          'This is an emergency! Please help me immediately!';
      _selectedRingtone =
          prefs.getString('selected_ringtone') ?? 'Default Alarm';
      _confirmBeforeActivation =
          prefs.getBool('confirm_before_activation') ?? true;
      _messageController.text = _customMessage;
    });
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
                  Navigator.pop(context);
                  _loadSettings();
                  ScaffoldMessenger.of(context).showSnackBar(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
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
                subtitle: Text(_selectedRingtone),
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
                                _ringtoneOptions
                                    .map(
                                      (ringtone) => RadioListTile<String>(
                                        title: Text(ringtone),
                                        value: ringtone,
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
                                  () =>
                                      _customMessage = _messageController.text,
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

            // App Behavior Section
            _buildSection('App Behavior', [
              SwitchListTile(
                title: const Text('Quick Activation'),
                subtitle: const Text(
                  'Activate panic mode with single tap (removes confirmation)',
                ),
                value: _quickActivation,
                onChanged: (value) {
                  setState(() => _quickActivation = value);
                  _saveSetting('quick_activation', value);
                },
              ),
              if (!_quickActivation)
                SwitchListTile(
                  title: const Text('Confirmation Dialog'),
                  subtitle: const Text(
                    'Show confirmation before activating panic mode',
                  ),
                  value: _confirmBeforeActivation,
                  onChanged: (value) {
                    setState(() => _confirmBeforeActivation = value);
                    _saveSetting('confirm_before_activation', value);
                  },
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
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
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
              const ListTile(
                title: Text('App Version'),
                subtitle: Text('1.0.0'),
              ),
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
