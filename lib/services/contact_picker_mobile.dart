import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../views/cp_network/contact_picker_sheet.dart';

class ContactPickerService {
  static Future<bool> isSupported() async => true;

  static Future<List<Map<String, String>>> pickContacts({
    required BuildContext context,
    bool multiple = true,
  }) async {
    // 1. Request Permission
    final status = await Permission.contacts.request();
    
    if (!status.isGranted) {
      if (status.isPermanentlyDenied) {
        throw Exception("Contacts access is permanently blocked. Please enable it in App Settings.");
      }
      throw Exception("Permission denied. We need contact access to import partners.");
    }

    // 2. Open Custom UI
    if (!context.mounted) return [];
    final List<Contact>? selected = await showModalBottomSheet<List<Contact>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ContactPickerSheet(),
    );

    if (selected == null || selected.isEmpty) return [];

    // 3. Map to standard format
    return selected.map((c) => {
      'name': c.displayName,
      'tel': c.phones.isNotEmpty ? c.phones.first.number : '',
      'email': c.emails.isNotEmpty ? c.emails.first.address : '',
    }).map((m) => m.map((k, v) => MapEntry(k, v ?? ''))).toList();
  }
}
