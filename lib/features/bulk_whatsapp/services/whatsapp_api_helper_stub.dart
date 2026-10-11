import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:convert';

Future<bool> sendWhatsAppGetRequest(Uri uri) async {
  try {
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return true;
    } else {
      debugPrint('Failed to send message: ${response.body}');
      return false;
    }
  } catch (e) {
    debugPrint('Error sending WhatsApp message: $e');
    return false;
  }
}

Future<bool> sendWhatsAppPostRequest(Uri uri, Map<String, dynamic> body, String token) async {
  try {
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Access-Token': token,
      },
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      return true;
    } else {
      debugPrint('Failed to send POST message: ${response.body}');
      return false;
    }
  } catch (e) {
    debugPrint('Error sending POST WhatsApp message: $e');
    return false;
  }
}
