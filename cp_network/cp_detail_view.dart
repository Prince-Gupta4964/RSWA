import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/cp_model.dart';
import '../../viewmodels/lead_viewmodel.dart';

class CPDetailView extends StatelessWidget {
  final CPModel cp;

  const CPDetailView({Key? key, required this.cp}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Lead ViewModel se connect kiya taaki is CP ke leads real-time track ho sakein
    final leadVM = Provider.of<LeadViewModel>(context);

    // Filter logic: Jo bhi lead ka source ya caller name is CP ke naam se match karega
    final cpLeads = leadVM.leads.where((lead) {
      final source = lead.rawData['source']?.toString().toLowerCase() ?? '';
      final caller = lead.rawData['caller']?.toString().toLowerCase() ?? '';
      final cpNameStr = cp.cpName.toLowerCase();
      return source == cpNameStr || caller == cpNameStr;
    }).toList();

    // Status Badge Color
    Color statusColor = cp.status == 'Active' ? Colors.green : Colors.orange;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Partner Profile',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- SECTION 1: CP PROFILE HEADER CARD ---
          Card(
            color: Colors.white,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFFFF6B22).withOpacity(0.1),
                        child: const Icon(Icons.handshake_outlined, color: Color(0xFFFF6B22), size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cp.cpName,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              cp.profession.isNotEmpty ? cp.profession : 'Channel Partner',
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          cp.status,
                          style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Divider(),
                  ),

                  // Saari information rows me divide ki hai (Bifurcation)
                  _buildProfileRow(Icons.phone_outlined, 'Contact No.', cp.contactNo),
                  _buildProfileRow(Icons.verified_user_outlined, 'RERA ID', cp.reraId),
                  _buildProfileRow(Icons.location_on_outlined, 'Location', cp.location),
                  _buildProfileRow(Icons.business_center_outlined, 'Office Reference', cp.officeRef),
                  _buildProfileRow(Icons.assignment_ind_outlined, 'Advisor Reached By', cp.advisorReachedBy),
                  _buildProfileRow(Icons.call_made_outlined, 'Caller Reference', cp.callerRef),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // --- SECTION 2: LEADS HEADER ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Leads Performance (${cpLeads.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              if (cpLeads.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${cpLeads.length} Success',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // --- SECTION 3: REAL-TIME LEADS LIST BIFURCATION ---
          cpLeads.isEmpty
              ? Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Column(
              children: [
                Icon(Icons.person_search_outlined, color: Colors.grey, size: 40),
                SizedBox(height: 8),
                Text(
                  'No clients registered through this partner yet.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                  textAlign: TextAlign.center, // <--- ERROR YAHAN FIX KIYA HAI
                ),
              ],
            ),
          )
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cpLeads.length,
            itemBuilder: (context, index) {
              final lead = cpLeads[index];

              // Lead status colors mapping
              Color leadTagColor = Colors.grey;
              if (lead.status == 'Hot' || lead.status == 'Book' || lead.status == 'Paid') {
                leadTagColor = const Color(0xFFFF6B22);
              } else if (lead.status == 'Warm') {
                leadTagColor = Colors.blue;
              }

              return Card(
                color: Colors.white,
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  onTap: () {
                    // Lead details screen par redirect karega click karne par
                    context.push('/lead-detail', extra: lead);
                  },
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey.shade100,
                    radius: 18,
                    child: const Icon(Icons.person_outline, color: Colors.grey, size: 18),
                  ),
                  title: Text(lead.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(lead.contact, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: leadTagColor),
                        ),
                        child: Text(
                          lead.status,
                          style: TextStyle(color: leadTagColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // Helper Custom Widget to render fields cleanly
  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
          const Text(' :   ', style: TextStyle(color: Colors.grey)),
          Expanded(
            flex: 3,
            child: Text(
              value.isNotEmpty ? value : 'N/A',
              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}