import 'package:flutter/material.dart';
import 'package:night_walkers_app/screens/contacts_screen.dart';
import 'package:night_walkers_app/screens/settings_screen.dart';
import 'package:night_walkers_app/widgets/panic_button.dart';
import 'package:night_walkers_app/widgets/status_dashboard.dart';
import 'package:night_walkers_app/screens/map_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:night_walkers_app/services/flashlight_service.dart';
import 'package:night_walkers_app/services/sound_service.dart';

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
      _sendLocationAsPlainText = prefs.getBool('send_location_as_plain_text') ?? false;
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
        if (_batterySaverEnabled) // Show text when battery saver is enabled
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.error.withOpacity(0.2), // Subtle background color
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0), // Added horizontal padding
            child: Text(
              'Battery Saver Mode Active',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.error,
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
              padding: const EdgeInsets.all(16.0), // Added padding here around the panic button
              child: PanicButton(
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
    const Color unselectedColor = Colors.black;
    const Color selectedColor = Color(0xFFB39DDB); // Light purple color

    return Scaffold(
      appBar: AppBar(
        title: _selectedIndex == 0 ? const Text('Night Walkers App') : null,
        actions: [
          // Battery Saver Toggle Button
          if (_selectedIndex == 0) // Only show on the home screen here
            IconButton(
              icon: Icon(
                _batterySaverEnabled ? Icons.battery_saver : Icons.battery_alert_outlined,
                color: _batterySaverEnabled ? Colors.greenAccent : Colors.amberAccent,
              ),
              tooltip: _batterySaverEnabled ? 'Battery Saver On' : 'Battery Saver Off',
              onPressed: _toggleBatterySaver,
            ),
          if (_selectedIndex == 0) // Only show on the home screen
            IconButton(
              icon: const Icon(Icons.info_outline, color: Color.fromARGB(179, 0, 0, 0)), // Info icon
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
                        onPressed: () => Navigator.pop(context),
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
                backgroundColor: _flashlightOn ? Colors.yellow : Colors.grey[800],
                tooltip: _flashlightOn ? 'Turn Flashlight Off' : 'Turn Flashlight On',
                child: Icon(
                  _flashlightOn ? Icons.flashlight_on : Icons.flashlight_off,
                  color: _flashlightOn ? Colors.black : Colors.white,
                ),
              ),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: selectedColor,
        unselectedItemColor: unselectedColor,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.maps_home_work_outlined),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contact_phone),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_applications),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
