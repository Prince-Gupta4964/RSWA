import 'package:flutter/material.dart';

class ContactPickerService {
  static Future<bool> isSupported() async => false;

  static Future<List<Map<String, String>>> pickContacts({
    required BuildContext context,
    bool multiple = true,
  }) async {
    return [];
  }
}
