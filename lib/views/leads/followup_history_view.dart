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
                  children: ['All', 'Call', 'Msg', 'Meets', 'Others'].map((filter) {
                    final bool isSelected = _selectedFilter == filter;
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter),
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
                        onSelected: (_) => setState(() => _selectedFilter = filter),
                      ),
                    );
                  }).toList(),
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
                      // Lead Age & Followups Summary Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amber.shade200, width: 1),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade300,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.calendar_today_rounded, color: Colors.brown, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Lead age', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                const SizedBox(height: 2),
                                Text('$leadAge days', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const Text('since lead was created', style: TextStyle(color: Colors.grey, fontSize: 10)),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              height: 36,
                              width: 1,
                              color: Colors.amber.shade300,
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade300,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.bar_chart_rounded, color: Colors.brown, size: 22),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('$totalFollowUps', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const Text('Follow-ups', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                  ],
                                ),
                              ],
                            ),
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

  int _calculateLeadAge() {
    final createdAt = widget.lead.rawData['createdAt'];
    if (createdAt is Timestamp) {
      final diff = DateTime.now().difference(createdAt.toDate()).inDays;
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
