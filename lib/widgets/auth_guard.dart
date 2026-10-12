import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../views/auth/login_view.dart';

class AuthGuard extends StatelessWidget {
  final Widget child;

  const AuthGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);

    // Never block UI on session check - render immediately
    if (authVM.isCheckingSession && !authVM.isAuthenticated) {
      return child;
    }

    if (!authVM.isAuthenticated && !authVM.isCheckingSession) {
      return const LoginView();
    }

    return child;
  }
}
