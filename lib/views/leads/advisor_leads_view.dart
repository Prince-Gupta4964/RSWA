import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../viewmodels/lead_viewmodel.dart';
import '../../models/lead_model.dart';
import 'lead_list_view.dart';

class AdvisorLeadsView extends StatefulWidget {
  final String advisorName;

  const AdvisorLeadsView({super.key, required this.advisorName});

  @override
  State<AdvisorLeadsView> createState() => _AdvisorLeadsViewState();
}

class _AdvisorLeadsViewState extends State<AdvisorLeadsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final leadVM = Provider.of<LeadViewModel>(context, listen: false);
      leadVM.setGroupBy('advisor_details', 'Status'); // 🚀 NAYA: Force group by Status for drill-down view
    });
  }

  @override
  Widget build(BuildContext context) {
    final leadVM = Provider.of<LeadViewModel>(context);

    // 🚀 NAYA: Decode both name and email from the unique string key
    final parts = widget.advisorName.split('|');
    final String targetName = parts[0].toLowerCase();
    final String targetEmail = parts.length > 1 ? parts[1].toLowerCase() : '';

    // Filter leads specifically for this exact advisor
    final List<LeadModel> advisorLeads = leadVM.leads.where((lead) {
      final advisorName = lead.rawData['advisor']?.toString().trim().toLowerCase() ?? '';
      final advisorEmail = lead.rawData['advisorEmail']?.toString().trim().toLowerCase() ?? '';
      
      // If we have an email target, strictly match the email. Otherwise fallback to name match.
      if (targetEmail.isNotEmpty) {
        return advisorEmail == targetEmail;
      }
      return advisorName == targetName;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              parts[0], // Display original formatted name
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              targetEmail.isNotEmpty ? 'Advisor: $targetEmail' : 'Advisor Leads',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 12),
          LeadListView(
            tabId: 'advisor_details', // Use a unique tab ID to maintain independent filter/group state
            leads: advisorLeads,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            emptyMessage: 'No leads found for this advisor.',
            isModernStyle: true,
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}