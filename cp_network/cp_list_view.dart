import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/cp_viewmodel.dart';
import '../../viewmodels/lead_viewmodel.dart'; // <-- NAYA: Leads track karne ke liye

class CPListView extends StatelessWidget {
  const CPListView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // CP aur Lead dono ViewModels connect kiye
    final cpVM = Provider.of<CPViewModel>(context);
    final leadVM = Provider.of<LeadViewModel>(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(), // Dashboard pe wapas jane ke liye
        ),
        title: const Text(
          'Channel Partners',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: cpVM.isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B22)))
          : cpVM.cps.isEmpty
          ? const Center(child: Text("No Channel Partners found. Click + to add!"))
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: cpVM.cps.length,
        itemBuilder: (context, index) {
          final cp = cpVM.cps[index];

          // Status ke hisaab se color
          Color statusColor = cp.status == 'Active' ? Colors.green : Colors.orange;

          // --- REAL-TIME TRACKING: Count how many leads this CP brought ---
          final int leadCount = leadVM.leads.where((lead) {
            final source = lead.rawData['source']?.toString().toLowerCase() ?? '';
            final caller = lead.rawData['caller']?.toString().toLowerCase() ?? '';
            final cpNameStr = cp.cpName.toLowerCase();
            return source == cpNameStr || caller == cpNameStr;
          }).length;

          return Card(
            color: Colors.white,
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              // --- NAYA: Card pe click karte hi CP Detail khulega ---
              onTap: () {
                context.push('/cp-detail', extra: cp);
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFFF6B22).withOpacity(0.1),
                child: const Icon(Icons.person, color: Color(0xFFFF6B22)),
              ),
              title: Text(cp.cpName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${cp.profession}\n${cp.contactNo}'),
              isThreeLine: true,

              // --- NAYA UI: Status aur Leads count dono ek sath dikhenge ---
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      cp.status,
                      style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Leads Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: leadCount > 0 ? const Color(0xFFFF6B22) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$leadCount Leads',
                      style: TextStyle(
                        color: leadCount > 0 ? Colors.white : Colors.grey.shade700,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      // --- ADD BUTTON YAHAN HAI ---
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: FloatingActionButton(
          onPressed: () {
            // Add button dabane pe Form open hoga
            context.push('/add-cp');
          },
          backgroundColor: const Color(0xFFFF6B22),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      // ADDED THE BOTTOM NAV BAR HERE TOO
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  // --- BOTTOM NAVIGATION BAR ---
  Widget _buildBottomNavBar(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFFF6B22), width: 1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Home Icon (Navigates back to dashboard)
          IconButton(
            icon: const Icon(Icons.home_outlined, color: Color(0xFFFF6B22), size: 30),
            onPressed: () {
              context.go('/dashboard');
            },
          ),

          // Properties Icon
          IconButton(
            icon: const Icon(Icons.location_city_outlined, color: Color(0xFFFF6B22), size: 30),
            onPressed: () { context.go('/projects');},
          ),

          // Active Person Icon (We are on the CP List)
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFFF6B22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline, color: Colors.white),
              ),
              const Text('Network',
                  style: TextStyle(
                      color: Color(0xFFFF6B22),
                      fontSize: 10,
                      fontWeight: FontWeight.bold))
            ],
          ),

           IconButton(
            icon: const Icon(Icons.bar_chart, color: Color(0xFFFF6B22), size: 30),
            onPressed: () {},
          ),

          // Flag Icon
          IconButton(
            icon: const Icon(Icons.outlined_flag, color: Color(0xFFFF6B22), size: 30),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}