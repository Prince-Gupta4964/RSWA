import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/lead_viewmodel.dart';
import '../../models/lead_model.dart';

class LeadListView extends StatelessWidget {
  const LeadListView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ViewModel se data yahan aayega
    final leadVM = Provider.of<LeadViewModel>(context);

    if (leadVM.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B22)));
    }

    if (leadVM.leads.isEmpty) {
      return const Center(child: Text("No clients found. Add a new lead!"));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: leadVM.leads.length,
      itemBuilder: (context, index) {
        final lead = leadVM.leads[index];

        Color tagColor = Colors.grey;
        if (lead.status == 'Hot' || lead.status == 'Emergency') {
          tagColor = Colors.red;
        } else if (lead.status == 'Warm' || lead.status == 'Paid' || lead.status == 'Book') {
          tagColor = Colors.blue;
        } else if (lead.status == 'Cold' || lead.status == 'Think') {
          tagColor = Colors.grey;
        }

        return _clientTile(context, lead, tagColor);
      },
    );
  }

  Widget _clientTile(BuildContext context, LeadModel lead, Color tagColor) {
    return InkWell(
      onTap: () {
        context.push('/lead-detail', extra: lead);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey.shade100,
              radius: 20,
              child: const Icon(Icons.person_outline, color: Colors.grey),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lead.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(lead.contact, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tagColor),
              ),
              child: Text(lead.status, style: TextStyle(color: tagColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Icon(Icons.call_outlined, color: Colors.blue.shade400, size: 18),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.green.shade200),
              ),
              child: const Icon(Icons.chat_bubble_outline, color: Colors.green, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}