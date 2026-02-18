import 'package:flutter/material.dart';
import 'package:night_walkers_app/screens/contacts_screen.dart';
import 'package:night_walkers_app/screens/settings_screen.dart';
import 'package:night_walkers_app/widgets/panic_button.dart';
import 'package:night_walkers_app/widgets/status_dashboard.dart';
import 'package:night_walkers_app/screens/map_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:night_walkers_app/services/flashlight_service.dart';
import 'package:night_walkers_app/services/sound_service.dart';
import 'package:night_walkers_app/services/direct_sms_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Settings state
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _flashlightEnabled = true;
  bool _autoLocationShare = true;
  bool _quickActivation = false;
  double _flashlightBlinkSpeed = 167.0;
  String _customMessage = 'This is an emergency! Please help me immediately!';
  String _selectedRingtone = 'alarm.wav';
  bool _confirmBeforeActivation = true;
  bool _flashlightOn = false;
  bool _sendLocationAsPlainText = true;
  bool _batterySaverEnabled = false;
  bool _alwaysMaxVolume = false;
  double _alarmVolume = 1.0;
  bool _call911Enabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
      _flashlightEnabled = prefs.getBool('flashlight_enabled') ?? true;
      _autoLocationShare = prefs.getBool('auto_location_share') ?? true;
      _quickActivation = prefs.getBool('quick_activation') ?? false;
      _flashlightBlinkSpeed = prefs.getDouble('flashlight_blink_speed') ?? 167.0;
      _customMessage = prefs.getString('custom_message') ?? 'This is an emergency! Please help me immediately!';
      final storedRingtone = prefs.getString('selected_ringtone');
      _selectedRingtone = SoundService.normalizeFilename(storedRingtone);
      _confirmBeforeActivation = prefs.getBool('confirm_before_activation') ?? true;
      _sendLocationAsPlainText = prefs.getBool('send_location_as_plain_text') ?? true;
      _batterySaverEnabled = prefs.getBool('battery_saver_enabled') ?? false;
      _alwaysMaxVolume = prefs.getBool('always_max_volume') ?? false;
      _alarmVolume = prefs.getDouble('alarm_volume') ?? 1.0;
      _call911Enabled = prefs.getBool('call_911_enabled') ?? false;
    });
    final storedRingtone = prefs.getString('selected_ringtone');
    if (storedRingtone != _selectedRingtone) {
      await prefs.setString('selected_ringtone', _selectedRingtone);
    }
  }

  List<Widget> get _screens => <Widget>[
    Column(
      children: [
        if (_batterySaverEnabled)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.35)),
            ),
            child: Text(
              'Battery Saver Mode Active',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9A3412),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: const StatusDashboard(),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ValueListenableBuilder<int>(
                valueListenable: DirectSmsService.volumeTriggerToken,
                builder: (context, token, _) => PanicButton(
                  soundEnabled: _soundEnabled,
                  vibrationEnabled: _vibrationEnabled,
                  flashlightEnabled: _flashlightEnabled,
                  flashlightBlinkSpeed: _flashlightBlinkSpeed,
                  selectedRingtone: _selectedRingtone,
                  autoLocationShare: _autoLocationShare,
                  customMessage: _customMessage,
                  quickActivation: _quickActivation,
                  confirmBeforeActivation: _confirmBeforeActivation,
                  sendLocationAsPlainText: _sendLocationAsPlainText,
                  batterySaverEnabled: _batterySaverEnabled,
                  alwaysMaxVolume: _alwaysMaxVolume,
                  alarmVolume: _alarmVolume,
                  call911Enabled: _call911Enabled,
                  externalTriggerToken: token,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    const MapScreen(),
    const ContactsScreen(),
    const SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    if (index == 0) {
      _loadSettings();
    }
  }

  Future<void> _toggleFlashlight() async {
    if (_flashlightOn) {
      await FlashlightService.turnOff();
    } else {
      await FlashlightService.turnOn();
    }
    setState(() {
      _flashlightOn = !_flashlightOn;
    });
  }

  Future<void> _toggleBatterySaver() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _batterySaverEnabled = !_batterySaverEnabled;
    });
    await prefs.setBool('battery_saver_enabled', _batterySaverEnabled);
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Night Walkers', 'Map', 'Contacts', 'Settings'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          if (_selectedIndex == 0)
            IconButton(
              icon: Icon(
                _batterySaverEnabled ? Icons.battery_saver : Icons.battery_alert_outlined,
                color: _batterySaverEnabled ? Colors.green : Colors.orange,
              ),
              tooltip: _batterySaverEnabled ? 'Battery Saver On' : 'Battery Saver Off',
              onPressed: _toggleBatterySaver,
            ),
          if (_selectedIndex == 0)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'About Battery Saver Mode',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Battery Saver Mode'),
                    content: const Text(
                          'Enabling Battery Saver Mode optimizes features like flashlight blinking speed and UI to conserve battery during emergencies. Recommended when battery is low.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: _screens[_selectedIndex],
      floatingActionButton: _selectedIndex == 0
          ? Padding(
              padding: const EdgeInsets.only(bottom: 70.0),
              child: FloatingActionButton(
                onPressed: _toggleFlashlight,
                backgroundColor: _flashlightOn ? Colors.amber : const Color(0xFF0F4C81),
                tooltip: _flashlightOn ? 'Turn Flashlight Off' : 'Turn Flashlight On',
                child: Icon(
                  _flashlightOn ? Icons.flashlight_on : Icons.flashlight_off,
                  color: _flashlightOn ? Colors.black : Colors.white,
                ),
              ),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Map'),
          NavigationDestination(
            icon: Icon(Icons.contact_phone_outlined),
            selectedIcon: Icon(Icons.contact_phone),
            label: 'Contacts',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
