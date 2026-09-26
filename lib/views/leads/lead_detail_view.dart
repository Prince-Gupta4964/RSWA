import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/lead_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/lead_viewmodel.dart';
import '../../utils/role_permissions.dart';
import '../../widgets/leads/follow_up_history_tile.dart';

class LeadDetailView extends StatefulWidget {
  final LeadModel lead;
  final String? initiallyExpandedSection;

  const LeadDetailView({super.key, required this.lead, this.initiallyExpandedSection});

  @override
  State<LeadDetailView> createState() => _LeadDetailViewState();
}

class _LeadDetailViewState extends State<LeadDetailView> {
  final Map<String, bool> _sectionStates = {
    'Basic Information': true,
    'Client Details': false,
    'Track Journey Progress': false,
    'Follow-up History': false,
    'Performance & Scores': false,
  };

  String selectedMilestone = 'Visit';

  @override
  void initState() {
    super.initState();
    if (widget.initiallyExpandedSection == 'followup') {
      _sectionStates['Follow-up History'] = true;
    }
  }

  void _globalToggle() {
    bool allOpen = _sectionStates.values.every((v) => v);
    setState(() {
      _sectionStates.updateAll((key, value) => !allOpen);
    });
  }

  @override
  Widget build(BuildContext context) {
    final leadVM = context.watch<LeadViewModel>();
    final authVM = context.watch<AuthViewModel>();
    
    final currentLead = leadVM.leads.firstWhere((l) => l.id == widget.lead.id, orElse: () => widget.lead);
    final data = currentLead.rawData;
    
    final String primaryContact = (data['whatsapp'] ?? data['contact2'] ?? '').toString();
    selectedMilestone = (data['journeyStage'] ?? 'Visit').toString();

    final Color statusColor = _statusColor(currentLead.status.toString());
    final String? profilePhoto = data['profilePhoto']?.toString();

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (context.mounted) context.go('/dashboard');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              expandedHeight: 440.0, pinned: true, backgroundColor: Colors.white, elevation: 0.0,
              leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => context.go('/dashboard')),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 16.0, top: 12.0, bottom: 12.0),
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 2.0),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1), 
                    borderRadius: BorderRadius.circular(20.0), 
                    border: Border.all(color: statusColor.withOpacity(0.4), width: 1.2)
                  ),
                  child: Center(child: Text(currentLead.status.toString().toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10.0))),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20.0, 80.0, 20.0, 10.0),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 55.0, backgroundColor: Colors.grey.shade50,
                        backgroundImage: (profilePhoto != null && profilePhoto.isNotEmpty) ? NetworkImage(profilePhoto) : null,
                        child: (profilePhoto == null || profilePhoto.isEmpty) ? Text(currentLead.name.isNotEmpty ? currentLead.name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 36.0)) : null,
                      ),
                      const SizedBox(height: 16.0),
                      Text(currentLead.name.toString(), style: const TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8.0),
                      Text('${(data['profession'] ?? 'Profession').toString()} | ${(data['nearestStation'] ?? 'Location').toString()}', style: const TextStyle(color: Colors.grey, fontSize: 15.0)),
                      const SizedBox(height: 24.0),
                      Row(
                        children: [
                          Expanded(child: _actionBtn(Icons.call, 'Call', Colors.blue, () => _makeCall(primaryContact, authVM))),
                          const SizedBox(width: 12.0),
                          Expanded(child: _actionBtn(Icons.chat_bubble, 'WhatsApp', Colors.green, () => _sendWhatsApp(primaryContact, authVM))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          body: Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32.0))),
            child: ListView(
              key: const PageStorageKey('lead_detail_scroll'),
              padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 80.0),
              children: [
                _buildSourceBanner(data),
                
                _buildSection('Basic Information', Icons.badge_outlined, [
                  _detailRow('Lead ID', data['leadID']),
                  _detailRow('Company', data['company']),
                  _detailRow('Project', data['project']),
                  _detailRow('Surname', data['surname']),
                  _detailRow('WhatsApp', data['whatsapp']),
                  _detailRow('Contact 2', data['contact2']),
                  _detailRow('Source', data['source']),
                  if (authVM.appRole == AppRole.superAdmin) _detailRow('Ref 2', data['referralName2']),
                  if (authVM.appRole == AppRole.superAdmin) _detailRow('Ref 3', data['referralName3']),
                ]),
                const SizedBox(height: 12.0),
                
                _buildSection('Client Details', Icons.person_search_outlined, [
                  _detailRow('Gender', data['gender']),
                  _detailRow('Email', data['email']),
                  _detailRow('Address', data['address']),
                  _detailRow('Now Living In', data['livingIn']),
                  _detailRow('Configuration', data['propertyType']),
                  _detailRow('Budget', data['budget']),
                  _detailRow('Final Amount', data['finalAmount']),
                ]),
                const SizedBox(height: 12.0),
                
                _buildSection('Track Journey Progress', Icons.linear_scale, [
                  _buildJourneyStepper(currentLead, leadVM, authVM),
                ]),
                const SizedBox(height: 12.0),
                
                _buildSection('Follow-up History', Icons.history_edu_outlined, [
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton.icon(
                      onPressed: () => context.push('/add-task', extra: currentLead), 
                      icon: const Icon(Icons.add_circle, size: 18.0, color: Color(0xFFFF6B22)), 
                      label: const Text('Add Entry', style: TextStyle(color: Color(0xFFFF6B22), fontWeight: FontWeight.bold))
                    )
                  ]),
                  _buildFollowUpList(currentLead, leadVM),
                ]),
                const SizedBox(height: 12.0),
                
                _buildSection('Performance & Scores', Icons.analytics_outlined, [
                   _detailRow('Lead Score', data['leadScore']),
                   _detailRow('Referral Score', data['referralScore']),
                   _detailRow('Advisor Score', data['advisorScore']),
                ]),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFFFF6B22), 
          onPressed: () => context.push('/add-lead/${currentLead.id}', extra: currentLead), 
          child: const Icon(Icons.edit, color: Colors.white)
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    bool isExpanded = _sectionStates[title] ?? false;
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.0), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _sectionStates[title] = !isExpanded),
            onDoubleTap: _globalToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              child: Row(
                children: [
                  Icon(icon, color: const Color(0xFFFF6B22), size: 20.0),
                  const SizedBox(width: 12.0),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0, color: Colors.black87)),
                  const Spacer(),
                  Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSourceBanner(Map<String, dynamic> data) {
    if ((data['source'] ?? '').toString().isEmpty && (data['referralName1'] ?? '').toString().isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1EA),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: const Color(0xFFFF6B22).withOpacity(0.2), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.person_pin_circle_outlined, color: Color(0xFFFF6B22), size: 20.0),
            SizedBox(width: 8.0),
            Text('Brought Through (Source)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0, color: Color(0xFFFF6B22))),
          ]),
          const SizedBox(height: 10.0),
          _detailRow('Source Type', data['source']),
          if ((data['referralName1'] ?? '').toString().isNotEmpty)
            _detailRow('Referring CP', data['referralName1']),
          if ((data['advisor'] ?? '').toString().isNotEmpty)
            _detailRow('Advisor', data['advisor']),
        ],
      ),
    );
  }

  Widget _detailRow(String label, dynamic value) {
    String val = 'N/A';
    if (value != null) {
      if (value is bool) val = value ? 'Yes' : 'No';
      else if (value is int) val = value.toString();
      else val = value.toString().trim().isEmpty ? 'N/A' : value.toString();
    }
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6.0), child: Row(children: [
      Expanded(flex: 2, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13.0))),
      const Text(' :  ', style: TextStyle(color: Colors.grey)),
      Expanded(flex: 3, child: Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0))),
    ]));
  }

  Widget _buildJourneyStepper(LeadModel lead, LeadViewModel leadVM, AuthViewModel authVM) {
    final List<String> stages = ['Visit', 'Revisit', 'Token', 'Loan process', 'Downpayment', 'Registration', 'Disbursement', 'Possession'];
    bool canEdit = authVM.appRole != AppRole.cp;
    int currentIdx = stages.indexOf(selectedMilestone);

    return Column(children: stages.asMap().entries.map((e) {
      int idx = e.key; String name = e.value;
      bool isDone = idx <= currentIdx;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(children: [
          Column(children: [
            Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked, color: isDone ? Colors.orange : Colors.grey, size: 20.0),
            if (idx < stages.length - 1) Container(width: 2.0, height: 16.0, color: isDone ? Colors.orange : Colors.grey.shade200),
          ]),
          const SizedBox(width: 12.0),
          Expanded(child: Text(name, style: TextStyle(fontWeight: isDone ? FontWeight.bold : FontWeight.normal, fontSize: 14.0))),
          if (canEdit) SizedBox(
            height: 30.0,
            child: Switch(
              value: isDone,
              onChanged: (v) {
                if (v) _updateJourneyStage(lead, name, leadVM, authVM);
                else _updateJourneyStage(lead, idx > 0 ? stages[idx - 1] : stages[0], leadVM, authVM);
              },
              activeColor: Colors.orange,
            ),
          ),
        ]),
      );
    }).toList());
  }

  Widget _buildFollowUpList(LeadModel lead, LeadViewModel leadVM) {
    return StreamBuilder<QuerySnapshot>(
      stream: leadVM.getFollowUps(lead.id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const SizedBox(height: 60.0, child: Center(child: CircularProgressIndicator()));
        if (!snap.hasData || snap.data!.docs.isEmpty) return const Padding(padding: EdgeInsets.all(16.0), child: Text('No history found.'));
        final docs = snap.data!.docs;
        return ListView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length > 5 ? 5 : docs.length,
          itemBuilder: (context, i) {
            final entry = docs[i].data() as Map<String, dynamic>;
            return FollowUpHistoryTile(lead: lead, entry: entry, docId: docs[i].id);
          },
        );
      },
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(onPressed: onTap, icon: Icon(icon, color: Colors.white, size: 16.0), label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)), elevation: 0.0));
  }

  Future<void> _makeCall(String n, AuthViewModel authVM) async { final url = Uri.parse('tel:$n'); if (await canLaunchUrl(url)) await launchUrl(url); }
  Future<void> _sendWhatsApp(String n, AuthViewModel authVM) async { String clean = n.replaceAll(RegExp(r'[^0-9]'), ''); final url = Uri.parse('https://wa.me/91$clean'); if (await canLaunchUrl(url)) await launchUrl(url); }

  void _addNewFollowUp(String id, String user, String status, String remark) {
    Provider.of<LeadViewModel>(context, listen: false).addFollowUp(id, {'caller': user, 'status': status, 'remark': remark});
  }

  Future<void> _updateJourneyStage(LeadModel lead, String stage, LeadViewModel leadVM, AuthViewModel authVM) async {
    await leadVM.updateLeadJourney(lead.id, stage, authVM.actorMetadata);
    _addNewFollowUp(lead.id, authVM.userName, 'Journey Update', 'Moved to $stage');
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'hot': return Colors.red;
      case 'warm': return Colors.blue;
      case 'paid': return Colors.green;
      default: return Colors.grey;
    }
  }
}
