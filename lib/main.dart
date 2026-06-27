import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'routes/app_router.dart';
import 'firebase_options.dart';
import 'viewmodels/lead_viewmodel.dart';
import 'viewmodels/cp_viewmodel.dart';
import 'viewmodels/project_viewmodel.dart'; // <-- NAYA: ProjectViewModel import kiya

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const RSWAApp());
}

class RSWAApp extends StatelessWidget {
  const RSWAApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LeadViewModel()),
        ChangeNotifierProvider(create: (_) => CPViewModel()),
        ChangeNotifierProvider(create: (_) => ProjectViewModel()), // <-- NAYA: Project Provider add kiya
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