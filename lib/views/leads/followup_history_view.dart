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
  final Set<String> _expandedDates = {};
  bool _isInitialized = false;

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
          backgroundColor: const Color(0xFFFF6B22),
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.go('/lead-detail/${widget.lead.id}', extra: widget.lead),
          ),
          title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Follow-up History',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              widget.lead.name,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: leadVM.getFollowUps(widget.lead.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B22)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final docs = snapshot.data!.docs;
          
          // --- Grouping and Stats Logic ---
          final Map<String, List<QueryDocumentSnapshot>> grouped = {};
          int totalCalls = 0;
          int totalWhatsApp = 0;
          int totalMeetings = 0;

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp?;
            final dateKey = _getFormattedDate(timestamp);
            
            if (!grouped.containsKey(dateKey)) {
              grouped[dateKey] = [];
            }
            grouped[dateKey]!.add(doc);

            // Stats
            final type = data['workType']?.toString().toLowerCase() ?? '';
            final status = data['status']?.toString().toLowerCase() ?? '';
            if (type == 'call' || status == 'contacted' || status == 'call') totalCalls++;
            if (type == 'whatsapp' || status == 'whatsapp') totalWhatsApp++;
            if (type == 'meeting' || type == 'site visit') totalMeetings++;
          }

          final sortedDates = grouped.keys.toList();
          if (!_isInitialized) {
            if (sortedDates.isNotEmpty) _expandedDates.add(sortedDates.first);
            _isInitialized = true;
          }

          return Column(
            children: [
              _buildStatsHeader(totalCalls, totalWhatsApp, totalMeetings),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: sortedDates.length,
                  itemBuilder: (context, index) {
                    final date = sortedDates[index];
                    final entries = grouped[date]!;
                    final isExpanded = _expandedDates.contains(date);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDateHeader(date, entries.length, sortedDates),
                        if (isExpanded)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: entries.length,
                              itemBuilder: (context, eIdx) {
                                final doc = entries[eIdx];
                                return FollowUpHistoryTile(
                                  lead: widget.lead,
                                  entry: doc.data() as Map<String, dynamic>,
                                  docId: doc.id,
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    ));
  }

  Widget _buildStatsHeader(int calls, int wa, int meetings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B22).withValues(alpha: 0.05),
        border: const Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.call_outlined, 'Calls', calls, Colors.blue),
          _buildStatItem(Icons.chat_bubble_outline_rounded, 'WhatsApp', wa, Colors.green),
          _buildStatItem(Icons.groups_outlined, 'Meetings', meetings, Colors.purple),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          '$count',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildDateHeader(String date, int count, List<String> allDates) {
    final bool isExpanded = _expandedDates.contains(date);
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () {
          setState(() {
            if (isExpanded) _expandedDates.remove(date);
            else _expandedDates.add(date);
          });
        },
        onDoubleTap: () {
          setState(() {
            if (_expandedDates.length == allDates.length) {
              _expandedDates.clear();
            } else {
              _expandedDates.addAll(allDates);
            }
          });
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
          ),
          child: Row(
            children: [
              Text(
                date.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFF6B22),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B22).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF6B22),
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                size: 22,
                color: const Color(0xFFFF6B22).withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getFormattedDate(Timestamp? timestamp) {
    if (timestamp == null) return "Unknown Date";
    final dt = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(dt.year, dt.month, dt.day);

    if (checkDate == today) return "Today";
    if (checkDate == yesterday) return "Yesterday";
    return DateFormat('dd MMM yyyy').format(dt);
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
