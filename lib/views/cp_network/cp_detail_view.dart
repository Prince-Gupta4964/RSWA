import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/cp_model.dart';
import '../../viewmodels/lead_viewmodel.dart';
import '../../viewmodels/cp_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/project_viewmodel.dart';
import '../../utils/role_permissions.dart';

class CPDetailView extends StatefulWidget {
  final CPModel cp;
  const CPDetailView({super.key, required this.cp});

  @override
  State<CPDetailView> createState() => _CPDetailViewState();
}

class _CPDetailViewState extends State<CPDetailView> {
  final Map<String, bool> _sectionStates = {
    'Basic Info': true,
    'CP Details': false,
    'Associated Projects': false, // 🚀 NAYA
    'Associated Leads': false,
    'Admin Controls & Score': false,
  };

  void _globalToggle() {
    bool allOpen = _sectionStates.values.every((v) => v);
    setState(() {
      _sectionStates.updateAll((key, value) => !allOpen);
    });
  }

  @override
  Widget build(BuildContext context) {
    final leadVM = Provider.of<LeadViewModel>(context);
    final cpVM = Provider.of<CPViewModel>(context);
    final authVM = Provider.of<AuthViewModel>(context);
    final projectVM = Provider.of<ProjectViewModel>(context);

    final data = widget.cp.rawData;

    final cpProjects = projectVM.projects.where((project) {
      return project.builderIds.contains(widget.cp.id) || 
             widget.cp.companyNames.any((c) => c.trim().toLowerCase() == (project.propertyDetails['projectCompany'] ?? '').toString().toLowerCase());
    }).toList();

    final cpLeads = leadVM.leads.where((lead) {
      final name = widget.cp.fullName.toLowerCase();
      return (lead.rawData['referralName1'] ?? '').toString().toLowerCase() == name;
    }).toList();

    final directDownline = cpVM.cps.where((p) {
      return (p.rawData['referralName1'] ?? '').toString().toLowerCase() == widget.cp.fullName.toLowerCase();
    }).toList();

    bool isAdmin = authVM.appRole == AppRole.admin || authVM.appRole == AppRole.superAdmin;
    Color statusColor = widget.cp.status.toLowerCase().contains('active') ? Colors.green : Colors.orange;

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) context.go('/cp-list'); },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              expandedHeight: 380, pinned: true, backgroundColor: Colors.white, elevation: 0,
              leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => context.go('/cp-list')),
              actions: [
                if (isAdmin)
                  Container(
                    margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: statusColor.withOpacity(0.4))),
                    child: Center(child: Text(widget.cp.status.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10))),
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    CircleAvatar(
                      radius: 50, backgroundColor: Colors.grey.shade100, 
                      backgroundImage: data['profilePhoto'] != null && data['profilePhoto'].toString().isNotEmpty ? NetworkImage(data['profilePhoto'].toString()) : null, 
                      child: (data['profilePhoto'] == null || data['profilePhoto'].toString().isEmpty) ? Text(widget.cp.fullName.isNotEmpty ? widget.cp.fullName[0].toUpperCase() : '?', style: const TextStyle(fontSize: 32)) : null
                    ),
                    const SizedBox(height: 16),
                    Text(widget.cp.fullName.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(widget.cp.profession.toString(), style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _actionBtn(Icons.call, 'Call', Colors.blue, () => _makeCall(widget.cp.contactNo)),
                        const SizedBox(width: 12),
                        _actionBtn(Icons.chat_bubble, 'WhatsApp', Colors.green, () => _sendWhatsApp(widget.cp.contactNo)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          body: Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. BASIC INFO
                _buildCollapsible('Basic Info', Icons.badge_outlined, [
                  _detailRow('Partner ID', data['cpID']),
                  _detailRow('Company Name', widget.cp.companyNames.isNotEmpty ? widget.cp.companyNames.join(', ') : (data['companyName'] ?? 'N/A')),
                  _detailRow('Partner Type', data['partnerType']),
                  _detailRow('Location', widget.cp.location),
                  _detailRow('RERA ID', widget.cp.reraId),
                  const Divider(height: 32),
                  const Text('Referral Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  _detailRow('Referred By', data['referralName1'] ?? 'Direct Join'),
                  if (isAdmin) ...[
                    _detailRow('R2 (Grandparent)', data['referralName2'] ?? 'Not available'),
                    _detailRow('R3 (Great GP)', data['referralName3'] ?? 'Not available'),
                    const SizedBox(height: 16),
                    _visualChain(data),
                  ],
                ]),
                const SizedBox(height: 12),

                // 2. CP DETAILS
                _buildCollapsible('CP Details', Icons.info_outline, [
                  _detailRow('Nick Name', data['nickName']),
                  _detailRow('Gender', data['gender']),
                  _detailRow('Qualification', data['qualification']),
                  _detailRow('Experience', data['experience']),
                  _detailRow('Joined Date', data['joinedDate']),
                  const Divider(height: 32),
                  const Text('Documents & Downlines', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _docPreview('Aadhar Card', data['aadharCard'])),
                    const SizedBox(width: 12),
                    Expanded(child: _docPreview('Pan Card', data['panCard'])),
                  ]),
                  const SizedBox(height: 16),
                  const Text('Direct Downlines', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  if (directDownline.isEmpty)
                    const Padding(padding: EdgeInsets.only(top: 8), child: Text('No partners referred yet.', style: TextStyle(color: Colors.grey, fontSize: 13)))
                  else
                    ...directDownline.map((p) => _partnerTile(context, p)).toList(),
                ]),
                const SizedBox(height: 12),

                // 🚀 NAYA: Associated Projects Section
                _buildCollapsible('Associated Projects (${cpProjects.length})', Icons.business_rounded, 
                  cpProjects.isEmpty 
                    ? [const Text('No associated projects found.', style: TextStyle(color: Colors.grey, fontSize: 13))] 
                    : cpProjects.map((proj) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        leading: const CircleAvatar(radius: 12, backgroundColor: Color(0xFFFFF1EA), child: Icon(Icons.domain, size: 14, color: Color(0xFFFF6B22))),
                        title: Text(proj.projectName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          proj.propertyDetails['projectCompany']?.toString().isNotEmpty == true 
                            ? 'Company: ${proj.propertyDetails['projectCompany']}' 
                            : 'Type: ${proj.propertyType}', 
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 16),
                        onTap: () => context.push('/project-detail/${proj.id}', extra: proj),
                      )).toList(),
                ),
                const SizedBox(height: 12),

                // 🚀 NAYA: Associated Leads Section
                _buildCollapsible('Associated Leads (${cpLeads.length})', Icons.people_alt_outlined, 
                  cpLeads.isEmpty 
                    ? [const Text('No leads referred yet.', style: TextStyle(color: Colors.grey, fontSize: 13))] 
                    : cpLeads.map((l) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        leading: const CircleAvatar(radius: 12, backgroundColor: Color(0xFFFFF1EA), child: Icon(Icons.person, size: 14, color: Color(0xFFFF6B22))),
                        title: Text(l.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text(l.status, style: TextStyle(fontSize: 11, color: l.status.toLowerCase() == 'hot' ? Colors.red : Colors.grey)),
                        trailing: const Icon(Icons.chevron_right, size: 16),
                        onTap: () => context.push('/lead-detail/${l.id}', extra: l),
                      )).toList(),
                ),
                const SizedBox(height: 12),

                // 3. SCORE & ADMIN CONTROLS (Strictly Admin only)
                if (isAdmin) _buildCollapsible('Admin Controls & Score', Icons.admin_panel_settings_outlined, [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Account Approved', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                      Switch(
                        value: data['isApproved'] == true,
                        activeColor: const Color(0xFFFF6B22),
                        onChanged: (val) async {
                          try {
                            await FirebaseFirestore.instance.collection('cps').doc(widget.cp.id).update({'isApproved': val});
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Account ${val ? "Approved" : "Suspended"} successfully!'), backgroundColor: val ? Colors.green : Colors.orange));
                            }
                            setState(() { data['isApproved'] = val; });
                          } catch (e) {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  _detailRow('Membership Status', data['membershipStatus'] ?? 'Active'),
                  _detailRow('Membership Package', data['membershipPackage'] ?? 'N/A'),
                  _detailRow('Level', data['level'] ?? 'Scout'),
                  const Divider(height: 32),
                  _detailRow('Total Leads Added', cpLeads.length.toString()),
                  _detailRow('Total Projects Worked', cpProjects.length.toString()),
                  _detailRow('Total CP Contributed', data['totalCPContributed']?.toString() ?? '0'),
                  _detailRow('Current Network', data['currentNetwork']?.toString() ?? '0'),
                ]),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(backgroundColor: const Color(0xFFFF6B22), onPressed: () => context.push('/add-cp', extra: widget.cp), child: const Icon(Icons.edit, color: Colors.white)),
      ),
    );
  }

  Widget _buildCollapsible(String title, IconData icon, List<Widget> children) {
    bool isExpanded = _sectionStates[title] ?? false;
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _sectionStates[title] = !isExpanded),
            onDoubleTap: _globalToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, color: const Color(0xFFFF6B22), size: 20),
                  const SizedBox(width: 12),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                  const Spacer(),
                  Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, dynamic value) {
    String val = 'N/A';
    if (value != null) {
      if (value is bool) val = value ? 'Yes' : 'No';
      else if (value is int) val = value.toString();
      else if (value.toString().trim().isNotEmpty) val = value.toString();
    }
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
      Expanded(flex: 2, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
      const Text(' :  ', style: TextStyle(color: Colors.grey)),
      Expanded(flex: 3, child: Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
    ]));
  }

  Widget _visualChain(Map<String, dynamic> data) {
    List<String> chain = [];
    if (data['referralName3'] != null && data['referralName3'].toString().isNotEmpty && data['referralName3'] != 'Not available') chain.add(data['referralName3'].toString());
    if (data['referralName2'] != null && data['referralName2'].toString().isNotEmpty && data['referralName2'] != 'Not available') chain.add(data['referralName2'].toString());
    if (data['referralName1'] != null && data['referralName1'].toString().isNotEmpty) chain.add(data['referralName1'].toString());
    chain.add(widget.cp.fullName.toString());
    
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
      child: Column(children: chain.asMap().entries.map((e) {
        bool isLast = e.key == chain.length - 1;
        return Column(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: isLast ? const Color(0xFFFF6B22).withOpacity(0.1) : Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: isLast ? const Color(0xFFFF6B22) : Colors.grey.shade200)), child: Text(e.value, style: TextStyle(fontWeight: isLast ? FontWeight.bold : FontWeight.w500, fontSize: 12))),
          if (!isLast) const Icon(Icons.arrow_downward, size: 14, color: Colors.grey),
        ]);
      }).toList()),
    );
  }

  Widget _docPreview(String label, String? url) {
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(url.toString(), height: 80, width: double.infinity, fit: BoxFit.cover)),
    ]);
  }

  Widget _partnerTile(BuildContext context, CPModel p) {
    return ListTile(contentPadding: EdgeInsets.zero, visualDensity: VisualDensity.compact, onTap: () => context.push('/cp-detail/${p.id}', extra: p), leading: const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 14)), title: Text(p.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)), trailing: const Icon(Icons.chevron_right, size: 16));
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return SizedBox(height: 40, child: ElevatedButton.icon(onPressed: onTap, icon: Icon(icon, color: Colors.white, size: 16), label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0)));
  }

  Future<void> _makeCall(String n) async { final url = Uri.parse('tel:$n'); if (await canLaunchUrl(url)) await launchUrl(url); }
  Future<void> _sendWhatsApp(String n) async { String clean = n.replaceAll(RegExp(r'[^0-9]'), ''); final url = Uri.parse('https://wa.me/91$clean'); if (await canLaunchUrl(url)) await launchUrl(url); }
}
