import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/lead_model.dart';

class TaskDetailView extends StatelessWidget {
  final LeadModel lead;
  final String followupId;
  final Map<String, dynamic> data;

  const TaskDetailView({
    super.key,
    required this.lead,
    required this.followupId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final DateFormat formatter = DateFormat('dd MMM yyyy, hh:mm a');
    final DateTime? followUpDateTime = data['followUpDateTime'] is Timestamp 
        ? (data['followUpDateTime'] as Timestamp).toDate() 
        : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/dashboard');
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => context.go('/dashboard'),
          ),
          title: const Text('Interaction Details', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Color(0xFFFF6B22)),
              onPressed: () => context.push('/add-task', extra: {
                'lead': lead,
                'followupData': data,
                'followupId': followupId,
              }),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildInfoCard(
              title: 'Task Information',
              icon: Icons.task_alt_rounded,
              children: [
                _buildDetailRow('Client', lead.name),
                _buildDetailRow('Project', data['project'] ?? 'N/A'),
                _buildDetailRow('Work Type', data['workType'] ?? 'N/A'),
                _buildDetailRow('Priority', data['priority'] ?? 'N/A'),
                _buildDetailRow('Work Status', data['status'] == 'Contacted' ? 'Done' : (data['workStatus'] ?? 'Pending')),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              title: 'Schedule & Timeline',
              icon: Icons.access_time_rounded,
              children: [
                _buildDetailRow('Follow Up Date', followUpDateTime != null ? formatter.format(followUpDateTime) : 'N/A'),
                _buildDetailRow('Start Time', data['startTime'] ?? 'N/A'),
                _buildDetailRow('End Time', data['endTime'] ?? 'N/A'),
                _buildDetailRow('Deadline', data['deadline'] is Timestamp ? formatter.format((data['deadline'] as Timestamp).toDate()) : 'N/A'),
                _buildDetailRow('Remind Later', data['remindLater'] is Timestamp ? formatter.format((data['remindLater'] as Timestamp).toDate()) : 'N/A'),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              title: 'Assignment',
              icon: Icons.person_outline_rounded,
              children: [
                _buildDetailRow('Assigned To', data['assign'] ?? 'N/A'),
                _buildDetailRow('Accompanied By', data['accompaniedBy'] ?? 'N/A'),
                _buildDetailRow('Recorded By', data['caller'] ?? 'N/A'),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              title: 'Remarks',
              icon: Icons.notes_rounded,
              children: [
                Text(
                  data['remark']?.toString() ?? 'No remarks provided.',
                  style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'Interaction recorded on ${data['timestamp'] is Timestamp ? formatter.format((data['timestamp'] as Timestamp).toDate()) : 'N/A'}',
              textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildInfoCard({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFFFF6B22), size: 20),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          const Text(' :  ', style: TextStyle(color: Colors.grey)),
          Expanded(flex: 3, child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87))),
        ],
      ),
    );
  }

}
