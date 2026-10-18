import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/lead_model.dart';
import '../../viewmodels/lead_viewmodel.dart';
import '../../widgets/leads/follow_up_history_tile.dart';

class FollowUpHistoryView extends StatefulWidget {
  final LeadModel lead;

  const FollowUpHistoryView({super.key, required this.lead});

  @override
  State<FollowUpHistoryView> createState() => _FollowUpHistoryViewState();
}

class _FollowUpHistoryViewState extends State<FollowUpHistoryView> {
  String _selectedFilter = 'All'; // 'All', 'Call', 'Msg', 'Meets', 'Others'

  @override
  Widget build(BuildContext context) {
    final leadVM = Provider.of<LeadViewModel>(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/lead-detail/${widget.lead.id}', extra: widget.lead);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => context.go('/lead-detail/${widget.lead.id}', extra: widget.lead),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Follow-up History',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(
                widget.lead.name,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B22),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () => context.push('/add-task', extra: widget.lead),
                icon: const Icon(Icons.add_circle, size: 18, color: Colors.white),
                label: const Text('Add Entry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Filter Chips
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('All', Icons.all_inclusive),
                    _filterChip('Call', Icons.phone_rounded),
                    _filterChip('Msg', Icons.chat_bubble_rounded),
                    _filterChip('Meets', Icons.groups_rounded),
                    _filterChip('Others', Icons.assignment_rounded),
                  ],
                ),
              ),
            ),

            // StreamBuilder for followups
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: leadVM.getFollowUps(widget.lead.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B22)));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  final docs = snapshot.data!.docs;

                  // --- Stats Calculation ---
                  int totalCalls = 0;
                  int totalWa = 0;
                  int totalMeetings = 0;

                  for (var doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final type = (data['workType'] ?? data['status'] ?? '').toString().toLowerCase();
                    if (type.contains('call') || type.contains('contact')) totalCalls++;
                    if (type.contains('msg') || type.contains('whatsapp') || type.contains('message')) totalWa++;
                    if (type.contains('meet') || type.contains('visit') || type.contains('site')) totalMeetings++;
                  }

                  // --- Filter Logic ---
                  final filteredDocs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final type = (data['workType'] ?? data['status'] ?? '').toString().toLowerCase();
                    if (_selectedFilter == 'All') return true;
                    if (_selectedFilter == 'Call') return type.contains('call') || type.contains('contact');
                    if (_selectedFilter == 'Msg') return type.contains('msg') || type.contains('whatsapp') || type.contains('message');
                    if (_selectedFilter == 'Meets') return type.contains('meet') || type.contains('visit') || type.contains('site');
                    if (_selectedFilter == 'Others') {
                      return !type.contains('call') && !type.contains('contact') && 
                             !type.contains('msg') && !type.contains('whatsapp') && !type.contains('message') &&
                             !type.contains('meet') && !type.contains('visit') && !type.contains('site');
                    }
                    return true;
                  }).toList();

                  int totalFollowUps = docs.length;
                  int leadAge = _calculateLeadAge();

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      // Lead Age & Stats Summary Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9E6), // 🚀 NAYA: Background color from screenshot
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Left Section: Calendar icon & Lead age text
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFE2A3), // Darker yellow/brown from screenshot
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF5C4033), size: 28),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Lead age', style: TextStyle(color: Colors.black54, fontSize: 13)),
                                  Text('$leadAge days', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.black)),
                                  const Text('since lead was created', style: TextStyle(color: Colors.black54, fontSize: 11)),
                                ],
                              ),
                            ),
                            
                            // Right Section: Small Stats columns
                            _buildStatColumn(Icons.phone_rounded, totalCalls.toString(), 'Calls', Colors.blue.shade700, Colors.blue.shade50),
                            const SizedBox(width: 12),
                            _buildStatColumn(Icons.chat_rounded, totalWa.toString(), 'Msg', Colors.green.shade700, Colors.green.shade50),
                            const SizedBox(width: 12),
                            _buildStatColumn(Icons.groups_rounded, totalMeetings.toString(), 'Meets', Colors.deepPurple.shade600, Colors.deepPurple.shade50),
                            const SizedBox(width: 12),
                            _buildStatColumn(Icons.bar_chart_rounded, totalFollowUps.toString(), 'Follow-ups', Colors.orange.shade700, Colors.orange.shade50),
                          ],
                        ),
                      ),

                      if (filteredDocs.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Text('No $_selectedFilter entries found.', style: TextStyle(color: Colors.grey.shade500)),
                          ),
                        )
                      else
                        ...filteredDocs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return FollowUpHistoryTile(
                            lead: widget.lead,
                            entry: data,
                            docId: doc.id,
                          );
                        }),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, IconData icon) {
    final bool isSelected = _selectedFilter == label;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: label == 'All' ? null : Icon(icon, size: 16, color: isSelected ? Colors.black : Colors.grey.shade700),
        label: Text(label),
        selected: isSelected,
        selectedColor: const Color(0xFFFFD54F),
        backgroundColor: Colors.grey.shade200,
        labelStyle: TextStyle(
          color: isSelected ? Colors.black87 : Colors.grey.shade700,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        showCheckmark: false,
        onSelected: (_) => setState(() => _selectedFilter = label),
      ),
    );
  }

  // 🚀 NAYA: Helper for Vertical Stat Columns
  Widget _buildStatColumn(IconData icon, String count, String label, Color iconColor, Color iconBg) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(height: 6),
        Text(count, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  DateTime? _getLeadCreationDate() {
    final raw = widget.lead.rawData['createdAt'] ?? widget.lead.rawData['timestamp'] ?? widget.lead.rawData['date'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  int _calculateLeadAge() {
    final createdDt = _getLeadCreationDate();
    if (createdDt != null) {
      final diff = DateTime.now().difference(createdDt).inDays;
      return diff >= 0 ? diff + 1 : 1;
    }
    return 1;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No history found for this client.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
