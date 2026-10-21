import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../views/cp_network/contact_picker_sheet.dart';

class ContactPickerService {
  static Future<bool> isSupported() async => true;

  static Future<List<Map<String, String>>> pickContacts({
    required BuildContext context,
    bool multiple = true,
  }) async {
    final status = await Permission.contacts.request();
    
    if (!status.isGranted) {
      if (status.isPermanentlyDenied) {
        throw Exception("Contacts access is permanently blocked. Please enable it in App Settings.");
      }
      throw Exception("Permission denied. We need contact access to import partners.");
    }

    if (!context.mounted) return [];
    final List<Map<String, String>>? selected = await showModalBottomSheet<List<Map<String, String>>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ContactPickerSheet(),
    );

    return selected ?? [];
  }
}
