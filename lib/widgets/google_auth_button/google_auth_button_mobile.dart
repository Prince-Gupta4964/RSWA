import 'package:flutter/material.dart';

Widget buildGoogleSignInButton({required BuildContext context, required VoidCallback onPressed}) {
  return OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 14),
      side: BorderSide(color: Colors.grey.shade300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.network('https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg', height: 20, errorBuilder: (c, e, s) => const Icon(Icons.g_mobiledata, color: Colors.blue)),
        const SizedBox(width: 12),
        const Text('Sign in with Google', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}
