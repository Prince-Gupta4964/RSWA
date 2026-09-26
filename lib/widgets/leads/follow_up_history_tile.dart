import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../models/lead_model.dart';

class FollowUpHistoryTile extends StatefulWidget {
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
  State<FollowUpHistoryTile> createState() => _FollowUpHistoryTileState();
}

class _FollowUpHistoryTileState extends State<FollowUpHistoryTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final timestamp = widget.entry['timestamp'] as Timestamp?;
    final String dateStr = timestamp != null
        ? DateFormat('dd/MM/yyyy').format(timestamp.toDate())
        : "Recently";
    
    final String workType = (widget.entry['workType'] ?? widget.entry['status'] ?? 'Work').toString();
    final String firstLetter = workType.isNotEmpty ? workType[0].toUpperCase() : 'W';
    final String status = (widget.entry['status']?.toString() ?? 'WARM').toUpperCase();
    
    const Color primaryColor = Color(0xFFFBE64E); 
    const Color secondaryColor = Color(0xFF6B5800);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.grey.shade200, width: 1.0),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20.0,
                    backgroundColor: primaryColor,
                    child: Text(firstLetter, style: const TextStyle(color: secondaryColor, fontWeight: FontWeight.bold, fontSize: 16.0)),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0, color: Colors.black87)),
                        const SizedBox(height: 2.0),
                        Text(
                          (widget.entry['remark'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12.0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Container(
                    width: 70.0,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20.0),
                      border: Border.all(color: primaryColor, width: 1.2),
                    ),
                    child: Text(status, style: const TextStyle(color: secondaryColor, fontSize: 9.0, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1.0),
                  const SizedBox(height: 8.0),
                  _detailItem('Recorded By', (widget.entry['caller'] ?? 'Unknown').toString()),
                  _detailItem('Assignee', (widget.entry['assign'] ?? 'N/A').toString()),
                  _detailItem('Time', '${(widget.entry['startTime'] ?? '--').toString()} to ${(widget.entry['endTime'] ?? '--').toString()}'),
                  const SizedBox(height: 8.0),
                  const Text('Remark:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.0, color: Colors.black54)),
                  const SizedBox(height: 4.0),
                  Text((widget.entry['remark'] ?? 'No remark.').toString(), style: const TextStyle(fontSize: 13.0, color: Colors.black87, height: 1.4)),
                  const SizedBox(height: 16.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _circleBtn(Icons.edit_outlined, Colors.blue, () {
                        context.push('/add-task', extra: {'lead': widget.lead, 'followupData': widget.entry, 'followupId': widget.docId});
                      }),
                      const SizedBox(width: 12.0),
                      _circleBtn(Icons.info_outline, const Color(0xFFFF6B22), () {
                        context.push('/task-detail', extra: {'lead': widget.lead, 'followupId': widget.docId, 'data': widget.entry});
                      }),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _detailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(children: [
        Text('$label: ', style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold, color: Colors.black54)),
        Text(value, style: const TextStyle(fontSize: 12.0, color: Colors.black87)),
      ]),
    );
  }

  Widget _circleBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: Colors.grey.shade200, width: 1.0)),
        child: Icon(icon, color: color, size: 20.0),
      ),
    );
  }
}
