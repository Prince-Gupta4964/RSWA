import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/lead_model.dart';
import '../../viewmodels/lead_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/app_configuration_viewmodel.dart';

class LeadListView extends StatefulWidget {
  final List<LeadModel>? leads;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final String emptyMessage;
  final bool isModernStyle;

  const LeadListView({
    super.key,
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

  void _toggleCategory(String category) {
    setState(() {
      if (_expandedCategories.contains(category)) {
        _expandedCategories.remove(category);
      } else {
        _expandedCategories.add(category);
      }
    });
  }

  void _collapseAll() {
    setState(() {
      _expandedCategories.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final leadVM = Provider.of<LeadViewModel>(context);
    final configVM = Provider.of<AppConfigurationViewModel>(context);

    // 🚀 Uses centralized sorting/filtering logic from ViewModel
    List<LeadModel> visibleLeads = leadVM.applyFiltersAndSort(widget.leads ?? leadVM.leads);
    final statusOrder = configVM.leadStatuses;

    if (leadVM.isLoading && widget.leads == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF6B22)),
      );
    }

    if (visibleLeads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Text(
            widget.emptyMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    final Map<String, List<LeadModel>> groupedLeads = {
      for (var status in statusOrder) status: [],
    };

    final defaultStatus = statusOrder.isNotEmpty ? statusOrder.last : 'Out';

    for (var lead in visibleLeads) {
      final s = lead.status.trim().toLowerCase();
      String category = defaultStatus;

      bool matched = false;
      for (var st in statusOrder) {
        if (st.toLowerCase() == s) {
          category = st;
          matched = true;
          break;
        }
      }

      if (!matched && (s == 'hot' || s == 'emergency')) {
        for (var st in statusOrder) {
          if (st.toLowerCase() == 'hot') {
            category = st;
            matched = true;
            break;
          }
        }
      }

      if (groupedLeads.containsKey(category)) {
        groupedLeads[category]?.add(lead);
      } else if (statusOrder.isNotEmpty) {
        groupedLeads[statusOrder.last]?.add(lead);
      }
    }

    final activeCategories = statusOrder.where((st) => (groupedLeads[st] ?? []).isNotEmpty).toList();

    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      itemCount: activeCategories.length,
      itemBuilder: (context, catIndex) {
        final category = activeCategories[catIndex];
        final categoryLeads = groupedLeads[category]!;
        final isExpanded = _expandedCategories.contains(category);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: Colors.white,
              child: InkWell(
                onTap: () => _toggleCategory(category),
                onDoubleTap: _collapseAll,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Text(
                        category.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: _getCategoryHeaderColor(category),
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getCategoryHeaderColor(category).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${categoryLeads.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getCategoryHeaderColor(category),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: _getCategoryHeaderColor(category).withValues(alpha: 0.7),
                      ),
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
                separatorBuilder: (context, index) =>
                    Divider(height: 1, color: Colors.grey.shade200, indent: 0, endIndent: 0),
                itemBuilder: (context, index) {
                  final lead = categoryLeads[index];
                  return _LeadTile(lead: lead, isModern: widget.isModernStyle, onDoubleTap: _collapseAll);
                },
              ),
          ],
        );
      },
    );
  }

  Color _getCategoryHeaderColor(String category) {
    switch (category.toLowerCase()) {
      case 'paid':
        return Colors.green.shade700;
      case 'book':
        return const Color(0xFFFF6B22);
      case 'hot':
        return Colors.red.shade700;
      case 'warm':
        return Colors.blue.shade700;
      case 'cold':
        return Colors.grey.shade700;
      case 'think':
        return Colors.purple.shade700;
      case 'hold':
        return Colors.amber.shade800;
      case 'out':
        return Colors.grey.shade600;
      default:
        return Colors.black87;
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

  final List<String> milestones = [
    'Lead QC',
    'First Visit',
    'Revisit',
    'Token',
    'Registration',
    'Possession'
  ];

  void _showStatusPopup(BuildContext context) {
    final statuses = Provider.of<AppConfigurationViewModel>(context, listen: false).leadStatuses;
    final currentStatus = _optimisticStatus ?? widget.lead.status;

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Update Status',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: statuses.map((status) {
                    bool isSelected = currentStatus.toLowerCase() == status.toLowerCase();
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _optimisticStatus = status.toLowerCase();
                        });

                        FirebaseFirestore.instance
                            .collection('leads')
                            .doc(widget.lead.id)
                            .update({'status': status.toLowerCase()});

                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF4A90E2) : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF4A90E2) : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
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
    final String firstLetter = widget.lead.name.trim().isEmpty
        ? '?'
        : widget.lead.name.trim()[0].toUpperCase();

    final displayStatus = _optimisticStatus ?? widget.lead.status;
    final tagColor = _statusColor(displayStatus);

    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final stage = widget.lead.rawData['journeyStage']?.toString() ?? 'Lead QC';

    final badgeText = displayStatus.toUpperCase();
    final badgeColor = tagColor;

    return Container(
      color: Colors.white,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/lead-detail', extra: widget.lead),
          onDoubleTap: widget.onDoubleTap,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
                child: Row(
                  children: [
                    // Avatar click now expands stepper
                    GestureDetector(
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFFF5F5F5),
                          child: Text(
                            firstLetter,
                            style: const TextStyle(color: Color(0xFF888888), fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.lead.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                          ),
                          const SizedBox(height: 2),
                          StreamBuilder<QuerySnapshot>(
                            stream: leadVM.getFollowUps(widget.lead.id),
                            builder: (context, snapshot) {
                              String remarkText = widget.lead.rawData['source']?.toString().toLowerCase() ?? '';
                              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                                final lastFollow = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                                remarkText = lastFollow['remark'] ?? remarkText;
                              }

                              if (remarkText.isEmpty) return const SizedBox.shrink();

                              return Text(
                                remarkText,
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Status Badge (Non-clickable Tag)
                    Container(
                      width: 50,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: badgeColor.withValues(alpha: 0.4), width: 1.2),
                      ),
                      child: Text(
                        badgeText,
                        maxLines: 1,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _makeCall(context, widget.lead.contact, widget.lead.id),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.phone_outlined, color: Colors.blue, size: 20),
                      ),
                    ),
                    const SizedBox(width: 4),

                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _sendWhatsApp(context, widget.lead.contact, widget.lead.id),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12, top: 4, bottom: 4, left: 4),
                        child: Image.asset(
                            'Assets/img.png',
                            height: 20,
                            errorBuilder: (c, e, s) => const Icon(Icons.chat_bubble_outline_rounded, color: Colors.green, size: 20)
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_isExpanded)
                Column(
                  children: [
                    _buildHorizontalStepper(widget.lead.rawData['journeyStage'] ?? 'Lead QC'),
                    const SizedBox(height: 16),
                    _buildActionButtons(context, leadVM, authVM),
                    const SizedBox(height: 12),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalStepper(String currentStage) {
    int currentIdx = milestones.indexOf(currentStage);
    if (currentIdx == -1) currentIdx = 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        children: [
          const Divider(height: 1),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: milestones.asMap().entries.map((entry) {
                int idx = entry.key;
                String title = entry.value;
                bool isCompleted = idx <= currentIdx;
                bool isActive = idx == currentIdx;
                bool isLast = idx == milestones.length - 1;

                Color nodeColor;
                if (idx == 0) {
                  nodeColor = const Color(0xFF0033CC);
                } else if (isCompleted) {
                  nodeColor = const Color(0xFF168A3A);
                } else {
                  nodeColor = const Color(0xFFC0C0D0);
                }

                double size = isActive ? 34.0 : 22.0;

                return Row(
                  children: [
                    Column(
                      children: [
                        Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: nodeColor,
                          ),
                          child: Icon(Icons.check, size: isActive ? 18 : 14, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            color: isActive ? const Color(0xFF168A3A) : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    if (!isLast)
                      Container(
                        width: 36,
                        height: 2,
                        margin: const EdgeInsets.only(bottom: 20),
                        color: const Color(0xFF0033CC),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 FIXED: Added Fav icon button back before the 3 action buttons
  Widget _buildActionButtons(BuildContext context, LeadViewModel leadVM, AuthViewModel authVM) {
    final isFav = widget.lead.favUids.contains(authVM.userUid);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          // Favorite Button (Wapas Laya Gaya)
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : Colors.grey.shade500, size: 28),
            onPressed: () => leadVM.toggleFavorite(widget.lead.id, authVM.userUid, widget.lead.favUids),
          ),
          const SizedBox(width: 12),

          // Action Buttons
          Expanded(
            child: OutlinedButton(
              onPressed: () => context.push('/lead-detail', extra: widget.lead),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.edit_outlined, size: 14, color: Colors.black87),
                  SizedBox(width: 4),
                  Text('Edit', style: TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _showRemarkDialog(context, widget.lead.id, leadVM, authVM),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.blue.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.event_note_outlined, size: 14, color: Colors.blue),
                  SizedBox(width: 4),
                  Text('Follow Up', style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _showStatusPopup(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B22),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.label_outline, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Status', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRemarkDialog(BuildContext context, String leadId, LeadViewModel leadVM, AuthViewModel authVM) {
    final TextEditingController ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Note / Remark', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: 'Enter your remark here...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B22)),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                leadVM.addFollowUp(leadId, {
                  'caller': authVM.userName,
                  'status': 'Note',
                  'remark': ctrl.text.trim(),
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Save Note', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _makeCall(BuildContext context, String? number, String leadId) async {
    if (number == null || number.isEmpty) return;
    final Uri url = Uri.parse('tel:$number');
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
      if (context.mounted) {
        Provider.of<LeadViewModel>(context, listen: false).addFollowUp(leadId, {
          'caller': authVM.userName,
          'status': 'Contacted',
          'remark': 'Call initiated from Dashboard.',
        });
      }
    }
  }

  Future<void> _sendWhatsApp(BuildContext context, String? number, String leadId) async {
    if (number == null || number.isEmpty) return;
    String cleanNumber = number.replaceAll(RegExp(r'[^0-9]'), '');
    final Uri url = Uri.parse('https://wa.me/91$cleanNumber');
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
      if (context.mounted) {
        Provider.of<LeadViewModel>(context, listen: false).addFollowUp(leadId, {
          'caller': authVM.userName,
          'status': 'WhatsApp',
          'remark': 'WhatsApp message initiated from Dashboard.',
        });
      }
    }
  }

  Widget _buildClassicTile(BuildContext context) {
    final String firstLetter = widget.lead.name.trim().isEmpty
        ? '?'
        : widget.lead.name.trim()[0].toUpperCase();
    final String source = widget.lead.rawData['source']?.toString().trim() ?? '';
    final String caller = widget.lead.rawData['caller']?.toString().trim() ?? '';
    final String date = widget.lead.rawData['date']?.toString().trim() ?? '';

    final metaParts = <String>[
      if (source.isNotEmpty) source,
      if (caller.isNotEmpty && caller != source) caller,
    ];

    final tagColor = _statusColor(widget.lead.status);

    return ListTile(
      onTap: () => context.push('/lead-detail', extra: widget.lead),
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: const Color(0xFFFFF1EA),
        child: Text(
          firstLetter,
          style: const TextStyle(
            color: Color(0xFFFF6B22),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(
        widget.lead.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.lead.contact,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
            if (metaParts.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                metaParts.join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: tagColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: tagColor.withValues(alpha: 0.22)),
            ),
            child: Text(
              widget.lead.status,
              style: TextStyle(
                color: tagColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (date.isNotEmpty) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: 76,
              child: Text(
                date,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    final s = status.trim().toLowerCase();
    if (s == 'paid') return Colors.green;
    switch (s) {
      case 'hot':
      case 'emergency':
        return Colors.red;
      case 'warm':
        return Colors.blue;
      case 'cold':
        return Colors.grey.shade400;
      case 'paid':
      case 'book':
        return const Color(0xFFFF6B22);
      default:
        return Colors.grey.shade400;
    }
  }
}