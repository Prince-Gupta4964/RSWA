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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    debugPrint("Initializing Firebase...");
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (kIsWeb) {
      try {
        debugPrint("Initializing Google Sign-In...");
        await GoogleSignIn.instance.initialize(
          clientId: '813321513896-q4flaf1mmvsael4561q5es06leqcsesj.apps.googleusercontent.com',
        );
      } catch (e) {
        debugPrint("Google Sign-In Init Error: $e");
      }
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
      ],
      child: MaterialApp.router(
        title: 'RSWA',
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
