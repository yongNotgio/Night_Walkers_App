import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:night_walkers_app/services/direct_sms_service.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Map<String, String>> contacts = [];

  final TextEditingController nameController = TextEditingController();
  final TextEditingController numberController = TextEditingController();
  int? editingIndex;

  @override
  void initState() {
    super.initState();
    loadContacts();
  }

  @override
  void dispose() {
    nameController.dispose();
    numberController.dispose();
    super.dispose();
  }

  Future<void> saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactList = contacts
        .map((e) => {'name': e['name']!, 'number': e['number']!})
        .toList();
    final contactsJson = jsonEncode(contactList);
    await prefs.setString('emergency_contacts', contactsJson);
  }

  Future<void> loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = prefs.getString('emergency_contacts');
    if (contactsJson != null) {
      final decoded = jsonDecode(contactsJson) as List;
      setState(() {
        contacts = decoded
            .map((item) => {
                  'name': item['name'].toString(),
                  'number': item['number'].toString(),
                })
            .toList();
      });
    }
  }

  void addOrUpdateContact() {
    final name = nameController.text.trim();
    final number = numberController.text.trim();

    if (name.isEmpty || number.isEmpty) return;

    setState(() {
      if (editingIndex == null) {
        contacts.add({'name': name, 'number': number});
      } else {
        contacts[editingIndex!] = {'name': name, 'number': number};
        editingIndex = null;
      }
      nameController.clear();
      numberController.clear();
    });

    saveContacts();
  }

  String _normalizePhoneForCompare(String input) {
    return input.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  Future<void> _importFromPhoneContacts() async {
    final hasPermission = await FlutterContacts.requestPermission(readonly: true);
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contacts permission denied')),
      );
      return;
    }

    final picked = await FlutterContacts.openExternalPick();
    if (picked == null) return;
    if (!mounted) return;

    if (picked.phones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected contact has no phone number')),
      );
      return;
    }

    String selectedNumber = picked.phones.first.number;
    if (picked.phones.length > 1) {
      final number = await showModalBottomSheet<String>(
        context: context,
        builder:
            (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text('Select number for ${picked.displayName}'),
                  ),
                  ...picked.phones.map(
                    (phone) => ListTile(
                      leading: const Icon(Icons.phone),
                      title: Text(phone.number),
                      onTap: () => Navigator.pop(context, phone.number),
                    ),
                  ),
                ],
              ),
            ),
      );
      if (number == null || number.trim().isEmpty) return;
      selectedNumber = number;
    }
    if (!mounted) return;

    final normalizedImported = _normalizePhoneForCompare(selectedNumber.trim());
    final duplicateExists = contacts.any(
      (contact) =>
          _normalizePhoneForCompare(contact['number'] ?? '') ==
          normalizedImported,
    );

    if (duplicateExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This number is already in your emergency contacts')),
      );
      return;
    }

    setState(() {
      contacts.add({
        'name': picked.displayName.isEmpty ? 'Unnamed Contact' : picked.displayName,
        'number': selectedNumber.trim(),
      });
    });
    await saveContacts();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imported ${picked.displayName}')),
    );
  }

  void startEdit(int index) {
    setState(() {
      editingIndex = index;
      nameController.text = contacts[index]['name'] ?? '';
      numberController.text = contacts[index]['number'] ?? '';
    });
  }

  void deleteContact(int index) {
    setState(() {
      contacts.removeAt(index);
      if (editingIndex == index) {
        editingIndex = null;
        nameController.clear();
        numberController.clear();
      }
    });
    saveContacts();
  }

  Future<void> sendEmergencySms(String number, String message) async {
    final smsPermission = await Permission.sms.request();
    final phonePermission = await Permission.phone.request();
    if (!mounted) return;
    if (smsPermission.isGranted && phonePermission.isGranted) {
      await DirectSmsService.sendSms(to: number, message: message);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("SMS sent to $number")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("SMS/Phone permission denied")),
      );
    }
  }

  void sendAlertToAllContacts() {
    const message = "This is an emergency! Please help me immediately!";
    for (var contact in contacts) {
      final number = contact['number'];
      if (number != null) {
        sendEmergencySms(number, message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Contacts')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2.0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add Emergency Contact',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: numberController,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: addOrUpdateContact,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                      ),
                      child: Text(
                        editingIndex == null ? 'Add Contact' : 'Update Contact',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _importFromPhoneContacts,
                      icon: const Icon(Icons.contact_phone),
                      label: const Text('Import from Phone'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Saved Contacts:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: contacts.length,
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  return Card(
                    elevation: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 5.0),
                    child: ListTile(
                      title: Text(
                        contact['name'] ?? '',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(contact['number'] ?? ''),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => startEdit(index),
                            color: Colors.blue,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => deleteContact(index),
                            color: Colors.red,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
