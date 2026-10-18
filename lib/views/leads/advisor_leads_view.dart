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
  Widget build(BuildContext context) {
    final leadVM = Provider.of<LeadViewModel>(context);

    // Filter leads specifically for this advisor
    final List<LeadModel> advisorLeads = leadVM.leads.where((lead) {
      final advisor = lead.rawData['advisor']?.toString().trim() ?? '';
      return advisor.toLowerCase() == widget.advisorName.toLowerCase();
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
              widget.advisorName,
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const Text(
              'Advisor Leads',
              style: TextStyle(color: Colors.grey, fontSize: 12),
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