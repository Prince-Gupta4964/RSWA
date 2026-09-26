import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'routes/app_router.dart';
import 'firebase_options.dart';
import 'viewmodels/lead_viewmodel.dart';
import 'viewmodels/cp_viewmodel.dart';
import 'viewmodels/project_viewmodel.dart';
import 'viewmodels/auth_viewmodel.dart'; // <-- NAYA: AuthViewModel import kiya
import 'viewmodels/app_configuration_viewmodel.dart';
import 'viewmodels/user_management_viewmodel.dart';
import 'viewmodels/builder_viewmodel.dart';
import 'viewmodels/recycle_bin_viewmodel.dart'; // 🚀 NAYA
import 'package:firebase_messaging/firebase_messaging.dart'; // 🚀 NAYA
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // 🚀 NAYA

// 🚀 NAYA: High Importance Channel for Android Lock Screen & Status Bar heads-up banner
const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'This channel is used for important task notifications.',
  importance: Importance.max,
  playSound: true,
);

final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("FCM: Background message received: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    debugPrint("AUTH: Initializing Firebase...");
    
    // Explicitly initialize with options for the current platform
    final options = DefaultFirebaseOptions.currentPlatform;
    await Firebase.initializeApp(options: options);
    
    // 🚀 NAYA: Verify initialization before proceeding
    bool initialized = false;
    int attempts = 0;
    while (!initialized && attempts < 10) {
      try {
        final app = Firebase.app();
        debugPrint("AUTH: Firebase initialized successfully: ${app.name}");
        initialized = true;
      } catch (e) {
        attempts++;
        debugPrint("AUTH: Waiting for Firebase registration (attempt $attempts)...");
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    if (!initialized) {
      throw Exception("Firebase failed to register the [DEFAULT] app on Web.");
    }

    try {
      debugPrint("Initializing Google Sign-In...");
      if (kIsWeb) {
        await GoogleSignIn.instance.initialize(
          clientId: '813321513896-q4flaf1mmvsael4561q5es06leqcsesj.apps.googleusercontent.com',
        );
      } else {
        await GoogleSignIn.instance.initialize(
          serverClientId: '813321513896-q4flaf1mmvsael4561q5es06leqcsesj.apps.googleusercontent.com',
        );
      }
    } catch (e) {
      debugPrint("Google Sign-In Init Error: $e");
    }

    // 🚀 NAYA: FCM Push Notification & Local Notifications Setup for Lock Screen / Status Bar
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      if (!kIsWeb) {
        final messaging = FirebaseMessaging.instance;
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
        const initSettings = InitializationSettings(android: androidInit);
        await _flutterLocalNotificationsPlugin.initialize(initSettings);

        await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_channel);

        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          final notification = message.notification;
          if (notification != null) {
            _flutterLocalNotificationsPlugin.show(
              notification.hashCode,
              notification.title,
              notification.body,
              NotificationDetails(
                android: AndroidNotificationDetails(
                  _channel.id,
                  _channel.name,
                  channelDescription: _channel.description,
                  icon: '@mipmap/ic_launcher',
                  importance: Importance.max,
                  priority: Priority.high,
                  playSound: true,
                ),
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint("FCM Setup Error: $e");
    }
    
    runApp(const RSWAApp());
  } catch (e) {
    debugPrint("CRITICAL INITIALIZATION ERROR: $e");
    // Show a simple error app if everything fails
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text("App failed to load. Please refresh.\nDetails: $e", textAlign: TextAlign.center),
          ),
        ),
      ),
    ));
  }
}

class RSWAApp extends StatelessWidget {
  const RSWAApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LeadViewModel()),
        ChangeNotifierProvider(create: (_) => CPViewModel()),
        ChangeNotifierProvider(create: (_) => ProjectViewModel()),
        ChangeNotifierProvider(create: (_) => AuthViewModel()), // <-- NAYA: Auth Provider add kiya
        ChangeNotifierProvider(create: (_) => AppConfigurationViewModel()),
        ChangeNotifierProvider(create: (_) => UserManagementViewModel()),
        ChangeNotifierProvider(create: (_) => BuilderViewModel()),
        ChangeNotifierProvider(create: (_) => RecycleBinViewModel()), // 🚀 NAYA
      ],
      child: MaterialApp.router(
        title: 'Property Plus',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF6B22)),
          useMaterial3: true,
        ),
        routerConfig: AppRouter.router,
      ),
    );
  }
}
