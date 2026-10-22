import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';
import '../routes/app_router.dart';

const AndroidNotificationChannel _notificationChannel =
    AndroidNotificationChannel(
      'task_notifications',
      'Task notifications',
      description: 'Notifications about assigned tasks and reminders',
      importance: Importance.max,
    );

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<QuerySnapshot>? _firestoreNotificationSub;

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize() async {
    if (_isMobile) {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _localNotifications.initialize(settings);

      final androidNotifications = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidNotifications?.createNotificationChannel(
        _notificationChannel,
      );
    }

    if (!_isMobile) return;

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
        );

    _messageSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundNotification,
      onError: (Object error) {
        debugPrint('Foreground notification error: $error');
      },
    );
    _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) await _saveToken(user.uid, token);
      },
      onError: (Object error) {
        debugPrint('FCM token refresh error: $error');
      },
    );
  }

  Future<void> registerDevice(String uid) async {
    await listenToUserNotifications(uid);
    if (!_isMobile) return;

    final permission = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (permission.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Notification permission was denied for $uid.');
      return;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('FCM did not return a device token for $uid.');
      return;
    }
    await _saveToken(uid, token);
  }

  Future<void> listenToUserNotifications(String uid) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      String userName = '';
      String userEmail = '';
      if (userDoc.exists) {
        final data = userDoc.data();
        userName = (data?['name'] ?? data?['fullName'] ?? '').toString().trim();
        userEmail = (data?['email'] ?? '').toString().trim();
      } else {
        final legacy = await FirebaseFirestore.instance.collection('users').where('uid', isEqualTo: uid).limit(1).get();
        if (legacy.docs.isNotEmpty) {
          final data = legacy.docs.first.data();
          userName = (data['name'] ?? data['fullName'] ?? '').toString().trim();
          userEmail = (data['email'] ?? '').toString().trim();
        }
      }

      if (userName.isEmpty && userEmail.isEmpty) return;

      _firestoreNotificationSub?.cancel();
      _firestoreNotificationSub = FirebaseFirestore.instance
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data == null) continue;
            final recipient = (data['recipientName'] ?? '').toString().trim().toLowerCase();
            final title = data['title']?.toString() ?? 'New Notification';
            final body = data['body']?.toString() ?? '';

            if ((userName.isNotEmpty && recipient == userName.toLowerCase()) ||
                (userEmail.isNotEmpty && recipient == userEmail.toLowerCase()) ||
                recipient == uid.toLowerCase()) {
              _showLocalAlert(title, body, change.doc.id);
            }
          }
        }
      });
    } catch (e) {
      debugPrint('Error listening to notifications: $e');
    }
  }

  Future<void> _showLocalAlert(String title, String body, String docId) async {
    if (_isMobile) {
      await _localNotifications.show(
        docId.hashCode,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_notifications',
            'Task notifications',
            channelDescription: 'Notifications about assigned tasks and reminders',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker',
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    }

    try {
      final context = AppRouter.rootNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                      Text(body, style: const TextStyle(fontSize: 12, color: Colors.white70), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFFF6B22),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                AppRouter.router.push('/map');
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error showing in-app notification banner: $e');
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    final users = FirebaseFirestore.instance.collection('users');
    final userRef = users.doc(uid);
    final user = await userRef.get();
    if (user.exists) {
      await userRef.set({
        'fcmToken': token,
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));
      return;
    }

    final legacyProfile = await users
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (legacyProfile.docs.isEmpty) {
      throw StateError('No staff profile found for authenticated user $uid.');
    }

    await legacyProfile.docs.first.reference.set({
      'fcmToken': token,
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (!_isMobile) return;
    if (message.data['type'] == 'flash') return;
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      message.hashCode,
      notification.title ?? 'Task Manager',
      notification.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_notifications',
          'Task notifications',
          channelDescription: 'Notifications about assigned tasks and reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> dispose() async {
    await _messageSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _firestoreNotificationSub?.cancel();
  }
}
