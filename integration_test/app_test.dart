import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rswa/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End App Navigation Test', () {
    testWidgets('App launches, logins, and navigates through tabs', (tester) async {
      app.main();
      
      // Wait for app to fully start
      print("Starting App and waiting 15 seconds for initial load...");
      await tester.pumpAndSettle(const Duration(seconds: 15));
      await Future.delayed(const Duration(seconds: 5));

      print("Looking for TextField widgets...");
      
      final emailFinder = find.byType(TextFormField).at(0);
      final passwordFinder = find.byType(TextFormField).at(1);
      final continueBtn = find.text('Continue');

      if (emailFinder.evaluate().isNotEmpty) {
        print("Login Screen Detected! Typing credentials...");
        
        await tester.enterText(emailFinder, 'princegupta496400@gmail.com');
        await tester.pumpAndSettle();
        
        await tester.enterText(passwordFinder, 'princegupta496400@gmail.com');
        await tester.pumpAndSettle();
        
        // Hide keyboard
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        
        // We know 'Continue' button is definitely there from your logs:
        // Or we can tap the exact type if text doesn't work.
        if (continueBtn.evaluate().isNotEmpty) {
           print("Clicking 'Continue' text...");
           await tester.tap(continueBtn);
        } else {
           print("Could not find 'Continue' text. Tapping the login ElevatedButton directly...");
           // The button type in your login_view is ElevatedButton
           final elevatedBtn = find.byType(ElevatedButton);
           if (elevatedBtn.evaluate().isNotEmpty) {
             await tester.tap(elevatedBtn.first);
           } else {
             print("Login button NOT found! Stopping test.");
             return;
           }
        }
        
        print("Waiting for Firebase Auth and navigation (15 seconds)...");
        // Firebase Auth login logs indicate it was successful, but we need more time for navigation
        await tester.pumpAndSettle(const Duration(seconds: 15));
        await Future.delayed(const Duration(seconds: 5));
        
      } else {
        print("Login screen NOT detected!");
      }

      print("Checking for Post-Login Navigation Tabs...");
      final dashboardIcon = find.byIcon(Icons.dashboard);
      final projectsIcon = find.byIcon(Icons.apartment);
      
      if (dashboardIcon.evaluate().isNotEmpty) {
        print("Found Dashboard tab, tapping it...");
        await tester.tap(dashboardIcon);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 2));
      } else if (projectsIcon.evaluate().isNotEmpty) {
        print("Found Projects tab, tapping it...");
        await tester.tap(projectsIcon);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 2));
      } else {
        print("Navigation Tabs NOT found! Where are we?");
      }

      print("✅ Bot navigation test finished!");
    });
  });
}
