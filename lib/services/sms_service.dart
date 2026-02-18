import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:night_walkers_app/services/direct_sms_service.dart';

class SmsService {
  // Send location SMS to all saved emergency contacts
  static Future<void> sendLocationSms(double latitude, double longitude) async {
    try {
      // Check SMS permission
      final smsPermission = await Permission.sms.request();
      final phonePermission = await Permission.phone.request();
      if (!smsPermission.isGranted || !phonePermission.isGranted) {
        debugPrint('SMS permissions not granted');
        return;
      }

      // Load contacts
      final contacts = await _loadContacts();
      if (contacts.isEmpty) {
        debugPrint('No emergency contacts found');
        return;
      }

      // Create Google Maps link with coordinates
      final String mapsLink = 'https://maps.google.com/?q=$latitude,$longitude';
      final String message =
          'EMERGENCY: I need help! My current location is: $mapsLink';

      // Send SMS to all emergency contacts
      for (final contact in contacts) {
        final String phoneNumber = contact['number'] ?? '';
        if (phoneNumber.isNotEmpty) {
          await DirectSmsService.sendSms(to: phoneNumber, message: message);
          debugPrint('Emergency SMS sent to ${contact['name']} ($phoneNumber)');
        }
      }
    } catch (e) {
      debugPrint('Error sending SMS: $e');
    }
  }

  // Load emergency contacts from shared preferences
  static Future<List<Map<String, String>>> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = prefs.getString('emergency_contacts');

    if (contactsJson != null) {
      final decoded = jsonDecode(contactsJson) as List;
      return decoded
          .map(
            (item) => {
              'name': item['name'].toString(),
              'number': item['number'].toString(),
            },
          )
          .toList();
    }

    return [];
  }
}
