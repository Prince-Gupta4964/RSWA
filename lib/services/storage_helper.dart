import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageHelper {
  static const String _sessionKey = 'rswa_session_user_id';

  /// Saves the user ID to persistent storage (SharedPrefs/LocalStorage)
  static Future<void> saveSession(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, userId);
      debugPrint('STORAGE: Session saved for $userId');
    } catch (e) {
      debugPrint('STORAGE ERROR (Save): $e');
    }
  }

  /// Retrieves the saved user ID. Works across refresh on Web.
  static Future<String?> getSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_sessionKey);
      debugPrint('STORAGE: Retrieved session ID: $id');
      return id;
    } catch (e) {
      debugPrint('STORAGE ERROR (Get): $e');
      return null;
    }
  }

  /// Clears the session on Logout.
  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      debugPrint('STORAGE: Session cleared');
    } catch (e) {
      debugPrint('STORAGE ERROR (Clear): $e');
    }
  }

  /// Utility for hard-refreshing the web app
  static void reloadApp() {
    if (kIsWeb) {
      // Since dart:html is discouraged, we can use a native JS call if needed,
      // but usually GoRouter handles navigation. If a full reload is required:
      // WidgetsBinding.instance.addPostFrameCallback((_) => window.location.reload());
    }
  }
}
