import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/lead_model.dart';
import '../../viewmodels/lead_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/app_configuration_viewmodel.dart';
import '../../widgets/leads/follow_up_history_tile.dart';

class LeadListView extends StatefulWidget {
  final String tabId;
  final List<LeadModel>? leads;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final String emptyMessage;
  final bool isModernStyle;

  const LeadListView({
    super.key,
    required this.tabId,
    this.leads,
    this.shrinkWrap = false,
    this.physics,
    this.emptyMessage = 'No clients found. Add a new lead!',
    this.isModernStyle = false,
  });

  @override
  State<LeadListView> createState() => _LeadListViewState();
}

class _LeadListViewState extends State<LeadListView> {
  final Set<String> _expandedCategories = {};
  bool _isDefaultHotExpanded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isDefaultHotExpanded) {
      final configVM = Provider.of<AppConfigurationViewModel>(context, listen: false);
      for (var status in configVM.leadStatuses) {
        final s = status.toLowerCase();
        if (s == 'hot' || s == 'book') {
          _expandedCategories.add(status);
        }
      }
      _isDefaultHotExpanded = true;
    }
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_expandedCategories.contains(category)) {
        _expandedCategories.remove(category);
      } else {
        _expandedCategories.add(category);
      }
    });
  }

  void _globalToggle(List<String> activeCategories) {
    setState(() {
      bool allOpen = true;
      for (var cat in activeCategories) {
        if (!_expandedCategories.contains(cat)) {
          allOpen = false;
          break;
        }
      }

      if (allOpen) {
        _expandedCategories.clear();
      } else {
        _expandedCategories.addAll(activeCategories);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final leadVM = Provider.of<LeadViewModel>(context);
    final configVM = Provider.of<AppConfigurationViewModel>(context);

    List<LeadModel> visibleLeads = leadVM.applyFiltersAndSort(widget.leads ?? leadVM.leads, widget.tabId);

    if (leadVM.isLoading && widget.leads == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B22)));
    }

    if (visibleLeads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Text(widget.emptyMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w500)),
        ),
      );
    }

    final Map<String, List<LeadModel>> groupedLeads = {};
    final String currentGroupBy = leadVM.getGroupBy(widget.tabId);

    for (var lead in visibleLeads) {
      String key = _getGroupKey(lead, currentGroupBy, configVM);
      if (!groupedLeads.containsKey(key)) groupedLeads[key] = [];
      groupedLeads[key]!.add(lead);
    }

    final List<String> sortedCategories = groupedLeads.keys.toList();
    if (currentGroupBy == 'Status') {
      final statusOrder = configVM.leadStatuses;
      sortedCategories.sort((a, b) {
        int idxA = statusOrder.indexOf(a);
        int idxB = statusOrder.indexOf(b);
        if (idxA == -1) idxA = 999;
        if (idxB == -1) idxB = 999;
        return idxA.compareTo(idxB);
      });
    } else {
      sortedCategories.sort();
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      itemCount: sortedCategories.length,
      itemBuilder: (context, catIndex) {
        final category = sortedCategories[catIndex];
        final categoryLeads = groupedLeads[category]!;
        final isExpanded = _expandedCategories.contains(category);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: Colors.white,
              child: InkWell(
                onTap: () => _toggleCategory(category),
                onDoubleTap: () => _globalToggle(sortedCategories),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Text(category.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _getCategoryHeaderColor(category, currentGroupBy), letterSpacing: 1.0)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: _getCategoryHeaderColor(category, currentGroupBy).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                        child: Text('${categoryLeads.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _getCategoryHeaderColor(category, currentGroupBy))),
                      ),
                      const Spacer(),
                      Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 22, color: _getCategoryHeaderColor(category, currentGroupBy).withValues(alpha: 0.7)),
                    ],
                  ),
                ),
              ),
            ),
            if (isExpanded)
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: categoryLeads.length,
                separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                itemBuilder: (context, index) {
                  final lead = categoryLeads[index];
                  return _LeadTile(lead: lead, isModern: widget.isModernStyle, onDoubleTap: () => _globalToggle(sortedCategories));
                },
              ),
          ],
        );
      },
    );
  }

  String _getGroupKey(LeadModel lead, String groupBy, AppConfigurationViewModel configVM) {
    switch (groupBy) {
      case 'Company': return lead.rawData['company']?.toString().trim() ?? 'No Company';
      case 'Project': return lead.rawData['project']?.toString().trim() ?? 'No Project';
      case 'Source': return lead.rawData['source']?.toString().trim() ?? 'No Source';
      case 'Referral': return lead.rawData['referralName1']?.toString().trim() ?? 'No Referral';
      case 'Nearest Station': return lead.rawData['nearestStation']?.toString().trim() ?? 'No Station';
      case 'Advisor': return lead.rawData['advisor']?.toString().trim() ?? 'No Advisor';
      case 'Caller': return lead.rawData['caller']?.toString().trim() ?? 'No Caller';
      case 'Created Month':
        final ts = lead.rawData['timestamp'];
        if (ts is Timestamp) return DateFormat('MMMM yyyy').format(ts.toDate());
        return 'Unknown Month';
      case 'Configuration': return lead.rawData['propertyType']?.toString().trim() ?? 'No Configuration';
      case 'Gender': return lead.rawData['gender']?.toString().trim() ?? 'No Gender';
      case 'Demo Done': return lead.rawData['demoDone']?.toString().trim() ?? 'No Demo Status';
      case 'Reached By': return lead.rawData['reachedBy']?.toString().trim() ?? 'No Staff';
      case 'Status':
      default:
        final s = lead.status.trim();
        for (var st in configVM.leadStatuses) {
          if (st.toLowerCase() == s.toLowerCase()) return st;
        }
        return 'Out';
    }
  }

  Color _getCategoryHeaderColor(String category, String groupBy) {
    if (groupBy != 'Status') return Colors.blueGrey.shade800;
    switch (category.toLowerCase()) {
      case 'paid': return Colors.green.shade700;
      case 'book': return const Color(0xFFFF6B22);
      case 'hot': return Colors.red.shade700;
      case 'warm': return Colors.blue.shade700;
      case 'cold': return Colors.grey.shade700;
      case 'think': return Colors.purple.shade700;
      case 'hold': return Colors.amber.shade800;
      case 'out': return Colors.grey.shade600;
      default: return Colors.black87;
    }
  }
}

class _LeadTile extends StatefulWidget {
  final LeadModel lead;
  final bool isModern;
  final VoidCallback? onDoubleTap;

  const _LeadTile({required this.lead, this.isModern = false, this.onDoubleTap});

  @override
  State<_LeadTile> createState() => _LeadTileState();
}

class _LeadTileState extends State<_LeadTile> {
  bool _isExpanded = false;
  String? _optimisticStatus;

  final List<String> milestones = ['Lead QC', 'First Visit', 'Revisit', 'Token', 'Registration', 'Possession'];

  void _showStatusPopup(BuildContext context) {
    final statuses = Provider.of<AppConfigurationViewModel>(context, listen: false).leadStatuses;
    final currentStatus = _optimisticStatus ?? widget.lead.status;

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return Align(
          alignment: const Alignment(0, 0.35),
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Update Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10, runSpacing: 10, alignment: WrapAlignment.center,
                    children: statuses.map((status) {
                      bool isSelected = currentStatus.toLowerCase() == status.toLowerCase();
                      return GestureDetector(
                        onTap: () {
                          setState(() => _optimisticStatus = status.toLowerCase());
                          FirebaseFirestore.instance.collection('leads').doc(widget.lead.id).update({'status': status.toLowerCase()});
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(color: isSelected ? const Color(0xFF4A90E2) : Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: isSelected ? const Color(0xFF4A90E2) : Colors.grey.shade300)),
                          child: Text(status, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isModern) return _buildModernTile(context);
    return _buildClassicTile(context);
  }

  Widget _buildModernTile(BuildContext context) {
    final leadVM = Provider.of<LeadViewModel>(context, listen: false);
    final String firstLetter = widget.lead.fullName.trim().isEmpty ? '?' : widget.lead.fullName.trim()[0].toUpperCase();
    final displayStatus = _optimisticStatus ?? widget.lead.status;
    final tagColor = _statusColor(displayStatus);
    final authVM = Provider.of<AuthViewModel>(context, listen: false);

    return Container(
      color: Colors.white,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/lead-detail/${widget.lead.id}', extra: widget.lead),
          onDoubleTap: widget.onDoubleTap,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: CircleAvatar(radius: 20, backgroundColor: const Color(0xFFF5F5F5), child: Text(firstLetter, style: const TextStyle(color: Color(0xFF888888), fontSize: 16, fontWeight: FontWeight.w500))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.lead.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                          const SizedBox(height: 2),
                          StreamBuilder<QuerySnapshot>(
                            stream: leadVM.getFollowUps(widget.lead.id),
                            builder: (context, snapshot) {
                              String remarkText = widget.lead.rawData['source']?.toString().toLowerCase() ?? '';
                              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                                final lastFollow = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                                remarkText = lastFollow['remark'] ?? remarkText;
                              }
                              return remarkText.isEmpty ? const SizedBox.shrink() : Text(remarkText, style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis);
                            },
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      child: Container(
                        width: 50, alignment: Alignment.center, padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(20), border: Border.all(color: tagColor.withValues(alpha: 0.4), width: 1.2)),
                        child: Text(displayStatus.toUpperCase(), maxLines: 1, style: TextStyle(color: tagColor, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => _makeCall(context, widget.lead.contact, widget.lead.id), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.phone_outlined, color: Colors.blue, size: 20))),
                    const SizedBox(width: 4),
                    GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => _sendWhatsApp(context, widget.lead.contact, widget.lead.id), child: Padding(padding: const EdgeInsets.only(right: 12, top: 4, bottom: 4, left: 4), child: Image.asset('Assets/img.png', height: 20, errorBuilder: (c, e, s) => const Icon(Icons.chat_bubble_outline_rounded, color: Colors.green, size: 20)))),
                  ],
                ),
              ),
              if (_isExpanded)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Source: ${widget.lead.rawData['source'] ?? 'Direct'}${widget.lead.rawData['referralName1'] != null ? " | Referrer: ${widget.lead.rawData['referralName1']}" : ""}', style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w600))),
                    _buildHorizontalStepper(widget.lead.rawData['journeyStage'] ?? 'Lead QC'),
                    const SizedBox(height: 16),
                    _buildCircularActionButtonRow(context, leadVM, authVM),
                    const SizedBox(height: 12),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircularActionButtonRow(BuildContext context, LeadViewModel leadVM, AuthViewModel authVM) {
    final isFav = widget.lead.favUids.contains(authVM.userUid);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCircleIconBtn(icon: isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : Colors.grey, onTap: () => leadVM.toggleFavorite(widget.lead.id, authVM.userUid, widget.lead.favUids)),
          _buildCircleIconBtn(icon: Icons.edit_outlined, color: Colors.blue, onTap: () => context.push('/add-lead/${widget.lead.id}', extra: widget.lead)),
          _buildCircleIconBtn(icon: Icons.calendar_today_outlined, color: const Color(0xFFFF6B22), onTap: () => context.push('/add-task', extra: widget.lead)),
          _buildCircleIconBtn(icon: Icons.history_outlined, color: Colors.purple, onTap: () => _showHistoryBottomSheet(context, leadVM)),
          _buildCircleIconBtn(icon: Icons.label_outline, color: Colors.orange, onTap: () => _showStatusPopup(context)),
        ],
      ),
    );
  }

  Widget _buildCircleIconBtn({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(24), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]), child: Icon(icon, color: color, size: 22)));
  }

  Widget _buildHorizontalStepper(String currentStage) {
    int currentIdx = milestones.indexOf(currentStage);
    if (currentIdx == -1) currentIdx = 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: milestones.asMap().entries.map((entry) {
            int idx = entry.key;
            String title = entry.value;
            bool isCompleted = idx <= currentIdx;
            bool isActive = idx == currentIdx;
            bool isLast = idx == milestones.length - 1;
            Color nodeColor = idx == 0 ? const Color(0xFF0033CC) : (isCompleted ? const Color(0xFF168A3A) : const Color(0xFFC0C0D0));
            double size = isActive ? 34.0 : 22.0;
            return Row(
              children: [
                Column(children: [Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: nodeColor), child: Icon(Icons.check, size: isActive ? 18 : 14, color: Colors.white)), const SizedBox(height: 8), Text(title, style: TextStyle(fontSize: 10, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? const Color(0xFF168A3A) : Colors.grey))]),
                if (!isLast) Container(width: 36, height: 2, margin: const EdgeInsets.only(bottom: 20), color: idx < currentIdx ? const Color(0xFF0033CC) : Colors.grey.shade300),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showHistoryBottomSheet(BuildContext context, LeadViewModel leadVM) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7, maxChildSize: 0.9, minChildSize: 0.5, expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Follow-up History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text(widget.lead.name, style: TextStyle(color: Colors.grey.shade600, fontSize: 12))]), ElevatedButton.icon(onPressed: () { Navigator.pop(context); context.push('/add-task', extra: widget.lead); }, icon: const Icon(Icons.add_circle_outline, size: 18), label: const Text('Add Entry', style: TextStyle(fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B22), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0))])),
            const SizedBox(height: 12), const Divider(height: 1),
            Expanded(child: StreamBuilder<QuerySnapshot>(stream: leadVM.getFollowUps(widget.lead.id), builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B22)));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No history found."));
              final docs = snapshot.data!.docs;
              return ListView.builder(controller: scrollController, padding: const EdgeInsets.all(12), itemCount: docs.length, itemBuilder: (context, index) => FollowUpHistoryTile(lead: widget.lead, entry: docs[index].data() as Map<String, dynamic>, docId: docs[index].id));
            })),
          ],
        ),
      ),
    );
  }

  Future<void> _makeCall(BuildContext context, String? number, String leadId) async {
    if (number == null || number.isEmpty) return;
    final Uri url = Uri.parse('tel:$number');
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
      if (context.mounted) Provider.of<LeadViewModel>(context, listen: false).addFollowUp(leadId, {'caller': authVM.userName, 'status': 'Contacted', 'remark': 'Call initiated from Dashboard.'});
    }
  }

  Future<void> _sendWhatsApp(BuildContext context, String? number, String leadId) async {
    if (number == null || number.isEmpty) return;
    String cleanNumber = number.replaceAll(RegExp(r'[^0-9]'), '');
    final Uri url = Uri.parse('https://wa.me/91$cleanNumber');
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
      if (context.mounted) Provider.of<LeadViewModel>(context, listen: false).addFollowUp(leadId, {'caller': authVM.userName, 'status': 'WhatsApp', 'remark': 'WhatsApp message initiated from Dashboard.'});
    }
  }

  Widget _buildClassicTile(BuildContext context) {
    final String firstLetter = widget.lead.fullName.trim().isEmpty ? '?' : widget.lead.fullName.trim()[0].toUpperCase();
    final String source = widget.lead.rawData['source']?.toString().trim() ?? '';
    final String caller = widget.lead.rawData['caller']?.toString().trim() ?? '';
    final String date = widget.lead.rawData['date']?.toString().trim() ?? '';
    final metaParts = <String>[if (source.isNotEmpty) source, if (caller.isNotEmpty && caller != source) caller];
    final tagColor = _statusColor(widget.lead.status);

    return ListTile(
      onTap: () => context.push('/lead-detail', extra: widget.lead),
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      leading: CircleAvatar(radius: 24, backgroundColor: const Color(0xFFFFF1EA), child: Text(firstLetter, style: const TextStyle(color: Color(0xFFFF6B22), fontWeight: FontWeight.w700))),
      title: Text(widget.lead.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.lead.contact, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black87)),
            if (metaParts.isNotEmpty) ...[const SizedBox(height: 2), Text(metaParts.join(' • '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey.shade600))],
          ],
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: tagColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(999), border: Border.all(color: tagColor.withValues(alpha: 0.22))), child: Text(widget.lead.status, style: TextStyle(color: tagColor, fontSize: 10, fontWeight: FontWeight.w700))),
          if (date.isNotEmpty) ...[const SizedBox(height: 6), SizedBox(width: 76, child: Text(date, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)))],
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    final s = status.trim().toLowerCase();
    if (s == 'paid') return Colors.green;
    switch (s) {
      case 'hot':
      case 'emergency': return Colors.red;
      case 'warm': return Colors.blue;
      case 'cold': return Colors.grey.shade400;
      case 'paid':
      case 'book': return const Color(0xFFFF6B22);
      default: return Colors.grey.shade400;
    }
  }
}
