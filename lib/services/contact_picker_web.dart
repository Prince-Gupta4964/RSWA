import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

@JS()
extension type WebContactResult(JSObject _) {
  external JSArray<JSString>? get name;
  external JSArray<JSString>? get email;
  external JSArray<JSString>? get tel;
}

class ContactPickerService {
  /// Checks if the Contact Picker API is supported by the current browser.
  static Future<bool> isSupported() async {
    try {
      final nav = web.window.navigator as JSObject;
      final hasContacts = _checkProperty(nav, 'contacts'.toJS).toDart;
      return hasContacts;
    } catch (e) {
      return false;
    }
  }

  /// Opens the native browser contact picker and returns selected contacts.
  static Future<List<Map<String, String>>> pickContacts({
    required BuildContext context,
    bool multiple = true,
  }) async {
    if (!await isSupported()) {
      final isSecure = web.window.isSecureContext;
      if (!isSecure) {
        throw Exception("Security Error: Contact Picker requires HTTPS.");
      }
      throw Exception("Contact Picker API not supported in this browser.");
    }

    try {
      final nav = web.window.navigator as JSObject;
      final contactsApi = _getProperty(nav, 'contacts'.toJS);

      final List<JSString> propsList = [
        'name'.toJS,
        'email'.toJS,
        'tel'.toJS,
      ];
      final props = propsList.toJS;
      
      final options = {'multiple': multiple}.jsify() as JSObject;

      final selectMethod = _getProperty(contactsApi, 'select'.toJS) as JSFunction;
      final promise = selectMethod.callAsFunction(contactsApi, props, options) as JSPromise;
      
      final results = await promise.toDart;
      
      final List<Map<String, String>> dartResults = [];
      
      if (results != null) {
        final jsList = results as JSArray;
        final List<JSAny?> list = jsList.toDart;
        
        for (final item in list) {
          if (item == null) continue;
          final res = item as WebContactResult;
          
          String name = "Unknown";
          final nameArr = res.name?.toDart;
          if (nameArr != null && nameArr.isNotEmpty) {
            name = nameArr.first.toDart;
          }
              
          String email = "";
          final emailArr = res.email?.toDart;
          if (emailArr != null && emailArr.isNotEmpty) {
            email = emailArr.first.toDart;
          }
              
          String tel = "";
          final telArr = res.tel?.toDart;
          if (telArr != null && telArr.isNotEmpty) {
            tel = telArr.first.toDart;
          }
          
          dartResults.add({
            'name': name,
            'email': email,
            'tel': tel,
          });
        }
      }
      
      return dartResults;
    } catch (e) {
      debugPrint("Web Contact Picker Runtime Error: $e");
      return [];
    }
  }
}

@JS('Reflect.has')
external JSBoolean _checkProperty(JSObject obj, JSString prop);

@JS('Reflect.get')
external JSObject _getProperty(JSObject obj, JSString prop);
