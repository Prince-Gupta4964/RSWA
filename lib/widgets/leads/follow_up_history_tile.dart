import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../models/lead_model.dart';

class FollowUpHistoryTile extends StatelessWidget {
  final LeadModel lead;
  final Map<String, dynamic> entry;
  final String docId;

  const FollowUpHistoryTile({
    super.key,
    required this.lead,
    required this.entry,
    required this.docId,
  });

  @override
  Widget build(BuildContext context) {
    final timestamp = entry['timestamp'] as Timestamp?;
    final String dateStr = timestamp != null
        ? DateFormat('EEE, dd MMM').format(timestamp.toDate())
        : "Recently";
    final String timeStr = timestamp != null
        ? DateFormat('hh:mm a').format(timestamp.toDate())
        : "--:--";

    final String workType = (entry['workType'] ?? entry['status'] ?? 'Work').toString();
    final lowerType = workType.toLowerCase();
    
    // Icon & Color mapping
    IconData iconData = Icons.history_rounded;
    Color iconColor = Colors.orange;
    Color bgColor = Colors.orange.shade50;

    if (lowerType.contains('call') || lowerType.contains('contact')) {
      iconData = Icons.phone_rounded;
      iconColor = Colors.orange.shade800;
      bgColor = Colors.orange.shade50;
    } else if (lowerType.contains('msg') || lowerType.contains('whatsapp') || lowerType.contains('message')) {
      iconData = Icons.chat_bubble_rounded;
      iconColor = Colors.green.shade700;
      bgColor = Colors.green.shade50;
    } else if (lowerType.contains('meet') || lowerType.contains('visit') || lowerType.contains('site')) {
      iconData = Icons.groups_rounded;
      iconColor = Colors.indigo.shade600;
      bgColor = Colors.indigo.shade50;
    } else if (lowerType.contains('journey') || lowerType.contains('stage')) {
      iconData = Icons.assignment_rounded;
      iconColor = Colors.amber.shade900;
      bgColor = Colors.amber.shade50;
    } else if (lowerType.contains('created') || lowerType.contains('lead')) {
      iconData = Icons.add_rounded;
      iconColor = Colors.pink.shade600;
      bgColor = Colors.pink.shade50;
    }

    final int dayCount = _calculateFollowUpDay(timestamp);
    final String remark = (entry['remark'] ?? entry['notes'] ?? '').toString();
    final String title = _formatTitle(workType);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch, // 🚀 Fixed Render Error
        children: [
          // Left Timeline Avatar & Line
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: iconColor, size: 20),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  color: Colors.grey.shade300,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Right Content Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Action Pill, Date, Day Pill, Time, 3-dots
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          title,
                          style: TextStyle(color: iconColor, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('·', style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                      const SizedBox(width: 6),
                      Text('·', style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD54F).withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Day $dayCount',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.brown),
                        ),
                      ),
                      const Spacer(),
                      Text(timeStr, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey.shade400),
                        onSelected: (val) {
                          if (val == 'edit') {
                            context.push('/add-task', extra: {'lead': lead, 'followupData': entry, 'followupId': docId});
                          } else if (val == 'info') {
                            context.push('/task-detail', extra: {'lead': lead, 'followupId': docId, 'data': entry});
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit Entry')),
                          const PopupMenuItem(value: 'info', child: Text('View Details')),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Description / Remark
                  if (remark.isNotEmpty)
                    Text(
                      remark,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.3),
                    ),

                  // Special Stage Changed Card if present
                  if (entry['journeyStage'] != null || entry['stage'] != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFAED),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Stage changed to ${entry['journeyStage'] ?? entry['stage']}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.brown),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _getLeadCreationDate() {
    final raw = lead.rawData['createdAt'] ?? lead.rawData['timestamp'] ?? lead.rawData['date'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  int _calculateFollowUpDay(Timestamp? entryTimestamp) {
    final createdDt = _getLeadCreationDate();
    final entryDt = entryTimestamp?.toDate();
    if (createdDt != null && entryDt != null) {
      final diff = DateTime(entryDt.year, entryDt.month, entryDt.day)
          .difference(DateTime(createdDt.year, createdDt.month, createdDt.day))
          .inDays;
      return diff >= 0 ? diff + 1 : 1;
    }
    return 1;
  }

  String _formatTitle(String raw) {
    final l = raw.toLowerCase();
    if (l.contains('call') || l.contains('contact')) return 'Call';
    if (l.contains('msg') || l.contains('whatsapp') || l.contains('message')) return 'Msg';
    if (l.contains('meet') || l.contains('visit') || l.contains('site')) return 'Meet';
    if (l.contains('journey') || l.contains('stage')) return 'Journey update';
    if (l.contains('created') || l.contains('lead')) return 'Lead Created';
    return raw[0].toUpperCase() + raw.substring(1);
  }
}
