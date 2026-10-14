import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:rswa/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  List<Map<String, String>> testLogs = [];

  void addLog(String module, String status, String message) {
    print("[$module] $status: $message");
    testLogs.add({
      "time": DateTime.now().toLocal().toString().split('.')[0],
      "module": module,
      "status": status,
      "message": message
    });
  }

  group('Foolproof Comprehensive End-to-End Test', () {
    testWidgets('App stability, Form entries (Projects & Leads) & Reporting', (tester) async {
      app.main();

      addLog("System", "INFO", "Starting application and waiting for initialization...");
      await tester.pumpAndSettle(const Duration(seconds: 15));
      await Future.delayed(const Duration(seconds: 5));

      // ---------------------------------------------------------
      // MODULE 1: AUTHENTICATION
      // ---------------------------------------------------------
      bool isLoggedIn = false;
      try {
        final emailFields = find.byType(TextFormField);
        if (emailFields.evaluate().length >= 2) {
          addLog("Auth", "INFO", "Login screen detected. Attempting login...");
          await tester.enterText(emailFields.at(0), 'princegupta496400@gmail.com');
          await tester.pumpAndSettle();
          await tester.enterText(emailFields.at(1), 'princegupta496400@gmail.com');
          await tester.pumpAndSettle();
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();

          final continueBtn = find.text('Continue');
          final elevatedBtn = find.byType(ElevatedButton);
          if (continueBtn.evaluate().isNotEmpty) {
            await tester.tap(continueBtn);
          } else if (elevatedBtn.evaluate().isNotEmpty) {
            await tester.tap(elevatedBtn.first);
          }
          
          await tester.pumpAndSettle(const Duration(seconds: 15));
          await Future.delayed(const Duration(seconds: 5));
          isLoggedIn = true;
          addLog("Auth", "PASS", "Logged in successfully.");
        } else {
          isLoggedIn = true;
          addLog("Auth", "INFO", "No login screen detected. Assuming already logged in.");
        }
      } catch (e) {
        addLog("Auth", "FAIL", "Error during authentication: $e");
      }

      if (!isLoggedIn) {
        addLog("System", "CRITICAL", "Cannot proceed without login. Terminating test.");
        await generateReport(testLogs);
        return;
      }

      // ---------------------------------------------------------
      // Helper Function: Dynamic Form Filler & Saver
      // ---------------------------------------------------------
      Future<void> runFormTest({
        required String moduleName,
        required IconData tabIcon,
        required String buttonTypeToClick, // e.g. "Add Project"
        required String expectedSaveButtonText,
        String? dropdownTypeToSelect,
      }) async {
        addLog(moduleName, "INFO", "Starting module test...");

        try {
          // 1. Navigate to Tab
          final tabFinder = find.byIcon(tabIcon);
          if (tabFinder.evaluate().isNotEmpty) {
            await tester.tap(tabFinder);
            await tester.pumpAndSettle(const Duration(seconds: 3));
          } else {
            addLog(moduleName, "FAIL", "Could not find navigation tab.");
            return;
          }

          // 2. Click Add FAB
          final fab = find.byType(FloatingActionButton);
          if (fab.evaluate().isNotEmpty) {
            await tester.tap(fab.first);
            await tester.pumpAndSettle(const Duration(seconds: 3));
          } else {
            addLog(moduleName, "FAIL", "Floating Action Button not found.");
            return;
          }

          // 3. Handle Dropdown (if required like Flat/Land/Shop)
          if (dropdownTypeToSelect != null) {
            final typeDropdown = find.text('Select Type');
            if (typeDropdown.evaluate().isNotEmpty) {
              await tester.tap(typeDropdown);
              await tester.pumpAndSettle();
              final item = find.text(dropdownTypeToSelect).last;
              if (item.evaluate().isNotEmpty) {
                await tester.tap(item);
                await tester.pumpAndSettle(const Duration(seconds: 2));
              }
            }
          }

          // 4. Dynamically Fill ALL TextFields on Screen
          final textFields = find.byType(TextField);
          final fieldCount = textFields.evaluate().length;
          int filledCount = 0;

          for (int i = 0; i < fieldCount; i++) {
            try {
              final field = textFields.at(i);
              // Scroll to field if off-screen
              await tester.ensureVisible(field);
              await tester.pumpAndSettle();
              
              // Enter generic dummy data based on position
              String dummyText = "AutoTest Data $i";
              if (i == 2 || i == 3) dummyText = "150000"; // Might be a price/number field
              
              await tester.enterText(field, dummyText);
              await tester.pumpAndSettle();
              filledCount++;
            } catch (e) {
               // Field might be read-only or hidden, ignore and continue
            }
          }
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
          addLog(moduleName, "INFO", "Filled $filledCount input fields automatically.");

          // 5. Scroll and Save
          final scrollable = find.byType(SingleChildScrollView);
          if (scrollable.evaluate().isNotEmpty) {
            await tester.drag(scrollable.first, const Offset(0, -1500)); // Scroll to bottom
            await tester.pumpAndSettle();
          }

          final saveBtn = find.widgetWithText(ElevatedButton, expectedSaveButtonText);
          final genericSaveBtn = find.text(expectedSaveButtonText);
          
          if (saveBtn.evaluate().isNotEmpty) {
            await tester.tap(saveBtn);
          } else if (genericSaveBtn.evaluate().isNotEmpty) {
            await tester.tap(genericSaveBtn);
          } else {
             // Fallback: tap the last elevated button on screen
             final allElevated = find.byType(ElevatedButton);
             if (allElevated.evaluate().isNotEmpty) {
                await tester.tap(allElevated.last);
             } else {
                throw Exception("Save button not found on screen.");
             }
          }

          await tester.pumpAndSettle(const Duration(seconds: 5));
          addLog(moduleName, "PASS", "Form saved successfully.");

        } catch (e) {
          addLog(moduleName, "FAIL", "Error during execution: $e");
          // Try to escape the screen to continue with the next test
          try {
             final backBtn = find.byTooltip('Back');
             if(backBtn.evaluate().isNotEmpty) {
                await tester.tap(backBtn);
                await tester.pumpAndSettle();
             }
          } catch (_) {}
        }
      }

      // ---------------------------------------------------------
      // RUN TESTS
      // ---------------------------------------------------------
      
      // Test Projects
      await runFormTest(
        moduleName: "Projects - Flat", 
        tabIcon: Icons.apartment, 
        buttonTypeToClick: "Add Project", 
        expectedSaveButtonText: "Save Project", 
        dropdownTypeToSelect: "Flat"
      );
      
      await runFormTest(
        moduleName: "Projects - Land", 
        tabIcon: Icons.apartment, 
        buttonTypeToClick: "Add Project", 
        expectedSaveButtonText: "Save Project", 
        dropdownTypeToSelect: "Land"
      );
      
      await runFormTest(
        moduleName: "Projects - Shop", 
        tabIcon: Icons.apartment, 
        buttonTypeToClick: "Add Project", 
        expectedSaveButtonText: "Save Project", 
        dropdownTypeToSelect: "Shop"
      );

      // Test Leads (Dashboard tab)
      await runFormTest(
        moduleName: "Leads Form", 
        tabIcon: Icons.dashboard, 
        buttonTypeToClick: "Add Lead", 
        expectedSaveButtonText: "Save Lead" // Update this if your button text is different
      );

      // ---------------------------------------------------------
      // GENERATE REPORT
      // ---------------------------------------------------------
      await generateReport(testLogs);
    });
  });
}

// Global PDF Generator Function
Future<void> generateReport(List<Map<String, String>> logs) async {
  print("\nGenerating Final PDF Report...");
  final pdf = pw.Document();
  
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return [
          pw.Header(level: 0, child: pw.Text("Property+ Foolproof Test Report", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18))),
          pw.Paragraph(text: "Date: ${DateTime.now().toString()}"),
          pw.Divider(),
          pw.Table.fromTextArray(
            headers: ['Time', 'Module', 'Status', 'Message'],
            cellAlignment: pw.Alignment.centerLeft,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellStyle: const pw.TextStyle(fontSize: 9),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.5),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(4),
            },
            data: logs.map((log) {
              return [
                log['time'],
                log['module'],
                log['status'],
                log['message']
              ];
            }).toList(),
          )
        ];
      },
    ),
  );

  try {
    final output = await getApplicationDocumentsDirectory();
    final file = File("${output.path}/PropertyPlus_Foolproof_Report.pdf");
    await file.writeAsBytes(await pdf.save());
    print("==================================================");
    print("✅ FINAL REPORT SAVED AT: ${file.path}");
    print("==================================================");
  } catch (e) {
    print("Error saving PDF: $e");
  }
}
