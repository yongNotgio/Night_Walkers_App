import 'package:flutter/material.dart';
import 'dart:async';
import 'package:vibration/vibration.dart';
import 'package:night_walkers_app/services/flashlight_service.dart';
import 'package:night_walkers_app/services/sound_service.dart';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:volume_controller/volume_controller.dart';
import 'package:night_walkers_app/widgets/panic_countdown_overlay.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:night_walkers_app/services/direct_sms_service.dart';

class PanicButton extends StatefulWidget {
  final bool soundEnabled;    
  final bool vibrationEnabled;
  final bool flashlightEnabled;
  final double flashlightBlinkSpeed;
  final String selectedRingtone;
  final bool autoLocationShare;
  final String customMessage;
  final bool quickActivation;
  final bool confirmBeforeActivation;
  final bool sendLocationAsPlainText;
  final bool batterySaverEnabled;
  final bool alwaysMaxVolume;
  final double alarmVolume;
  final bool call911Enabled;
  final int externalTriggerToken;

  const PanicButton({
    super.key,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.flashlightEnabled,
    required this.flashlightBlinkSpeed,
    required this.selectedRingtone,
    required this.autoLocationShare,
    required this.customMessage,
    required this.quickActivation,
    required this.confirmBeforeActivation,
    required this.sendLocationAsPlainText,
    required this.batterySaverEnabled,
    required this.alwaysMaxVolume,
    required this.alarmVolume,
    required this.call911Enabled,
    this.externalTriggerToken = 0,
  });

  @override
  State<PanicButton> createState() => _PanicButtonState();
}

class _PanicButtonState extends State<PanicButton> {
  bool _isBlinking = false;
  bool _isRed = true;
  Timer? _blinkTimer;
  double _initialVolume = 0.0;

  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
  _snackBarController;

  final Color neonRed = Colors.redAccent.shade100;
  final Color dimRed = Colors.redAccent.shade100.withAlpha(51);

  void _startBlinking() async {
    bool confirmed = true; // Assume confirmed by default ....

    if (!widget.quickActivation && widget.confirmBeforeActivation) {
      // Show SA USEER PanicCountdownOverlay
      final result = await showDialog<bool>( // Get the result directly
        context: context,
        barrierDismissible: false, // MUNI GA Prevent dismissing by tapping outsiE
        builder: (context) => PanicCountdownOverlay(
          onCountdownComplete: () {
            // The overlay will pop itself with true on completion
            Navigator.of(context).pop(true); // Add pop back for completion
          },
          onCancel: () {
            // Call _stopBlinking BEFORE popping the dialog
            _stopBlinking(); 
            Navigator.of(context).pop(false); // Pop with false on cancellation
          },
        ),
      );

      confirmed = result ?? false; // Assign the result to confirmed, handle null case

      // If confirmed is false (cancelled), the stopping is handled by the onCancel callback.
      // We just need to prevent the activation logic below from running.
      if (confirmed == false) {
        return; 
      }
       // If confirmed is true, proceed with the activation logic below.
    }

    // Proceed with activation only if confirmed is true (or if no confirmation was needed)
    if (confirmed == true) {
      setState(() {
        _isBlinking = true; 
        _isRed = true;
      });

      if (widget.flashlightEnabled) {
        await FlashlightService.turnOn();
      }
      if (widget.soundEnabled) {
        _initialVolume = await VolumeController.instance.getVolume();
        final double targetVolume = widget.alwaysMaxVolume ? 1.0 : widget.alarmVolume;
        await VolumeController.instance.setVolume(targetVolume);
        SoundService.playAlarm(filename: widget.selectedRingtone, volume: 1.0);
      }
      if (!mounted) return;

      _snackBarController = ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Long press the button to stop the alarm!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          backgroundColor: Colors.redAccent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          duration: const Duration(seconds: 5),
        ),
      );

      _blinkTimer?.cancel();
      if (widget.flashlightEnabled) {
        final int blinkSpeed = widget.batterySaverEnabled ? 500 : widget.flashlightBlinkSpeed.round();
        _blinkTimer = Timer.periodic(
          Duration(milliseconds: blinkSpeed),
          (timer) async {
            setState(() {
              _isRed = !_isRed;
            });
            await FlashlightService.toggle(_isRed);
          },
        );
      }

      if (widget.vibrationEnabled) {
        _vibrate();
      }

      Position? position;
      if (widget.autoLocationShare) {
        position = await _getCurrentLocation();
      }
      String message = widget.customMessage;
      if (position != null) {
        message +=
            ' My location coordinates are: Latitude ${position.latitude}, Longitude ${position.longitude}';
      }
      if (widget.autoLocationShare) {
        try {
          await _sendEmergencySmsToAllContacts(message);
        } catch (e) {
          debugPrint('Failed to send SMS: $e');
        }
      }

      if (widget.call911Enabled) {
        _initiate911Call();
      }
    }
  }

  void _stopBlinking() {
    _blinkTimer?.cancel();
    setState(() {
      _isBlinking = false;
      _isRed = true;
      Vibration.cancel();
    });

    FlashlightService.turnOff();
    SoundService.stopAlarm();

    VolumeController.instance.setVolume(_initialVolume);

    if (mounted) {
      try {
        _snackBarController?.close();
      } catch (_) {
        // Ignore errors if already closed or context is gone
      }
    }
    _snackBarController = null;
  }

  Future<void> _vibrate() async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(pattern: [0, 500, 500, 500, 500, 500], repeat: 0);
    }
  }

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return null;
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled.')),
      );
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (!mounted) return null;
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (!mounted) return null;
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied.')),
        );
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission permanently denied.'),
        ),
      );
      return null;
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> _sendEmergencySmsToAllContacts(String message) async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = prefs.getString('emergency_contacts');
    if (contactsJson == null) return;
    final contacts = (jsonDecode(contactsJson) as List)
        .map((item) => {
              'name': item['name'].toString(),
              'number': item['number'].toString(),
            })
        .toList();
    final numbers = contacts
        .map((contact) => contact['number'])
        .whereType<String>()
        .where((number) => number.trim().isNotEmpty)
        .toList();
    if (numbers.isEmpty) return;

    final smsPermission = await Permission.sms.request();
    final phonePermission = await Permission.phone.request();
    if (!smsPermission.isGranted || !phonePermission.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS/Phone permission denied. Direct SMS unavailable.')),
        );
      }
      return;
    }

    int sentCount = 0;
    for (var contact in contacts) {
      final number = contact['number'];
      if (number != null) {
        try {
          await DirectSmsService.sendSms(to: number, message: message);
          sentCount++;
          debugPrint('Emergency SMS sent to ${contact['name']} ($number)');
        } catch (e) {
          debugPrint('Error sending SMS via native direct channel: $e');
        }
      }
    }
    if (mounted) {
      if (sentCount == contacts.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Emergency SMS sent to all contacts")),
        );
      } else if (sentCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Emergency SMS sent to $sentCount of ${contacts.length} contacts")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Direct SMS failed on this device.')),
        );
      }
    }
  }

  Future<void> _initiate911Call() async {
    const url = 'tel:911';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      // Handle error: could not launch URL
      debugPrint('Could not launch $url');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not initiate 911 call.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    if (mounted) {
      try {
        _snackBarController?.close();
      } catch (_) {
        // Ignore errors if already closed or context is gone
      }
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PanicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.externalTriggerToken != oldWidget.externalTriggerToken &&
        widget.externalTriggerToken > 0 &&
        !_isBlinking) {
      _startBlinking();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color baseColor = widget.batterySaverEnabled ? Colors.grey.shade900 : Colors.redAccent.shade100;
    final Color activeColor = widget.batterySaverEnabled ? Colors.grey.shade700 : const Color.fromARGB(255, 255, 0, 0);
    final Color inactiveColor = widget.batterySaverEnabled ? Colors.grey.shade800 : Colors.white;

    final Color currentColor =
        _isBlinking
            ? (_isRed ? baseColor : activeColor)
            : inactiveColor;

    final List<Shadow> glow = (widget.batterySaverEnabled || !_isBlinking || !_isRed)
        ? []
        : [
            const Shadow(
              color: Color.fromARGB(255, 215, 25, 25),
              blurRadius: 30,
            ),
          ];

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              widget.batterySaverEnabled ? Colors.grey.shade900 : Colors.redAccent.shade100,
              widget.batterySaverEnabled ? Colors.grey.shade800 : Colors.red.shade700,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            if (!widget.batterySaverEnabled)
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.5),
                blurRadius: 40,
                spreadRadius: 10,
                offset: const Offset(0, 12),
              ),
            BoxShadow(
              color: widget.batterySaverEnabled ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.2),
              blurRadius: widget.batterySaverEnabled ? 5 : 8,
              spreadRadius: widget.batterySaverEnabled ? 0 : 1,
              offset: widget.batterySaverEnabled ? const Offset(0, 4) : const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: widget.batterySaverEnabled ? Colors.grey.shade600 : Colors.white.withOpacity(0.7),
            width: widget.batterySaverEnabled ? 2 : 4,
          ),
        ),
        child: GestureDetector(
          onLongPress: _isBlinking ? _stopBlinking : null,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            elevation: 12,
            child: InkWell(
              customBorder: const CircleBorder(),
              splashColor: Colors.white24,
              onTap: _isBlinking ? null : _startBlinking,
              child: Padding(
                padding: const EdgeInsets.all(60),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning,
                      color: currentColor,
                      size: 90,
                      shadows: glow,
                    ),
                    const SizedBox(height: 10),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 150),
                      style: TextStyle(
                        color: currentColor,
                        fontSize: 90,
                        fontWeight: FontWeight.bold,
                        shadows: glow,
                      ),
                      child: const Text('SOS'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
