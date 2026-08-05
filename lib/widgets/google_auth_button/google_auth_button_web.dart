import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

Widget buildGoogleSignInButton({required BuildContext context, required VoidCallback onPressed}) {
  return Container(
    constraints: const BoxConstraints(maxWidth: 400),
    child: web.renderButton(
      configuration: web.GSIButtonConfiguration(
        minimumWidth: MediaQuery.of(context).size.width - 48,
        theme: web.GSIButtonTheme.outline,
        size: web.GSIButtonSize.large,
      ),
    ),
  );
}
