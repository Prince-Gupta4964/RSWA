import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:convert';

Future<bool> sendWhatsAppGetRequest(Uri uri) async {
  try {
    // SECURITY NOTE: Using public CORS proxies exposes your API Token to third parties.
    // For Production Web, you must use your own proxy server or test directly on Android/iOS.
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return true;
    } else {
      debugPrint('Failed to send GET message: ${response.body}');
      return false;
    }
  } catch (e) {
    debugPrint('CORS ERROR ON WEB: $e');
    debugPrint('Please run the app on Android/Emulator to send WhatsApp messages.');
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
    debugPrint('CORS ERROR ON WEB: $e');
    debugPrint('Please run the app on Android/Emulator to send WhatsApp messages.');
    return false;
  }
}
