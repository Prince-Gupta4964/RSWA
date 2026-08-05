import 'package:flutter/material.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin & Super Admin Panel"),
        backgroundColor: Colors.amber.shade800,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Manage roles, users, and dynamic forms from here.'),
      ),
    );
  }
}
