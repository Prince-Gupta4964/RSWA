import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Ensure the package name matches your project name in pubspec.yaml
import 'package:rswa/main.dart';

void main() {
  testWidgets('App loads and shows Dashboard smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame using the new class name
    await tester.pumpWidget(const RSWAApp());

    // Wait for GoRouter to finish its initial navigation animation
    await tester.pumpAndSettle();

    // Verify that our Dashboard screen has loaded by finding the 'Dashboard' text
    expect(find.text('Dashboard'), findsWidgets);
  });
}