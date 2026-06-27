import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart'; // NAYA: Call & WA redirect ke liye
import '../../models/lead_model.dart';

class LeadDetailView extends StatefulWidget {
  final LeadModel lead;

  const LeadDetailView({Key? key, required this.lead}) : super(key: key);

  @override
  State<LeadDetailView> createState() => _LeadDetailViewState();
}

class _LeadDetailViewState extends State<LeadDetailView> {
  String selectedMilestone = 'First Visit';

  // --- NAYA: Sabko ek sath kholne aur band karne ke liye controllers ---
  final ExpansionTileController _ctrl1 = ExpansionTileController();
  final ExpansionTileController _ctrl2 = ExpansionTileController();
  final ExpansionTileController _ctrl3 = ExpansionTileController();
  final ExpansionTileController _ctrl4 = ExpansionTileController();

  // Temporary Dummy Follow-ups (Firebase me jodne se pehle test karne ke liye)
  final List<Map<String, String>> followUps = [
    {'date': '24 Jun 2026, 11:30 AM', 'caller': 'Manager (Admin)', 'status': 'Warm', 'remark': 'Client is asking for plot dimensions. Will visit site tomorrow.'},
  ];

  // --- NAYA: Single click pe Expand, Double click pe Collapse ---
  void _expandAll() {
    if (!_ctrl1.isExpanded) _ctrl1.expand();
    if (!_ctrl2.isExpanded) _ctrl2.expand();
    if (!_ctrl3.isExpanded) _ctrl3.expand();
    if (!_ctrl4.isExpanded) _ctrl4.expand();
  }

  void _collapseAll() {
    if (_ctrl1.isExpanded) _ctrl1.collapse();
    if (_ctrl2.isExpanded) _ctrl2.collapse();
    if (_ctrl3.isExpanded) _ctrl3.collapse();
    if (_ctrl4.isExpanded) _ctrl4.collapse();
  }

  // --- NAYA: Call and WhatsApp Functions with Auto-Tracking ---
  Future<void> _makeCall(String? number) async {
    if (number == null || number.isEmpty) return;
    final Uri url = Uri.parse('tel:$number');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
      _addNewFollowUp('System Auto-Track', 'Call Attempted', 'Initiated a call to $number');
    }
  }

  Future<void> _sendWhatsApp(String? number) async {
    if (number == null || number.isEmpty) return;
    // Remove symbols and spaces
    String cleanNumber = number.replaceAll(RegExp(r'[^0-9]'), '');
    final Uri url = Uri.parse('https://wa.me/91$cleanNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
      _addNewFollowUp('System Auto-Track', 'WhatsApp Msg', 'Redirected to WhatsApp for $number');
    }
  }

  void _addNewFollowUp(String caller, String status, String remark) {
    setState(() {
      followUps.insert(0, {
        'date': 'Just Now', // Real date hum aage layenge
        'caller': caller,
        'status': status,
        'remark': remark,
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Follow-up entry added automatically!')));
  }

  // --- NAYA: Beautiful Follow-up Form ---
  void _showFollowUpForm() {
    final TextEditingController remarkController = TextEditingController();
    String selectedStatus = 'Warm';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Follow-up', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: InputDecoration(
                  labelText: 'Lead Status',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: ['Hot', 'Warm', 'Cold', 'Book', 'Paid'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => selectedStatus = val!,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: remarkController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Discussion Remark',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (remarkController.text.isNotEmpty) {
                      _addNewFollowUp('Current User', selectedStatus, remarkController.text);
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B22)),
                  child: const Text('SAVE FOLLOW-UP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.lead.rawData;
    String primaryContact = data['whatsapp'] ?? data['contact2'] ?? '';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.lead.name,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFFFF6B22)),
            onPressed: () => context.push('/add-lead', extra: widget.lead),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMilestoneToggleBar(),

          // --- NAYA: Quick Action Bar (Call & WA) ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _makeCall(primaryContact),
                    icon: const Icon(Icons.call, color: Colors.white, size: 18),
                    label: const Text('Call', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, elevation: 0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _sendWhatsApp(primaryContact),
                    icon: const Icon(Icons.chat, color: Colors.white, size: 18),
                    label: const Text('WhatsApp', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, elevation: 0),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Double Tap se sab collapse hoga
          Expanded(
            child: GestureDetector(
              onDoubleTap: _collapseAll,
              behavior: HitTestBehavior.opaque,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  const Center(
                    child: Text('💡 Single tap on any heading to expand all. Double tap background to collapse all.', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  ),
                  const SizedBox(height: 12),

                  _buildCollapsibleSection(
                    controller: _ctrl1,
                    title: 'Basic Information',
                    icon: Icons.person_outline,
                    children: [
                      _buildDetailRow('Name', widget.lead.name),
                      _buildDetailRow('Profession', data['profession']),
                      _buildDetailRow('WhatsApp No.', data['whatsapp']),
                      _buildDetailRow('Contact 2', data['contact2']),
                      _buildDetailRow('Email', data['email']),
                      _buildDetailRow('Gender', data['gender']),
                      _buildDetailRow('Date of Birth', data['dob']),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildCollapsibleSection(
                    controller: _ctrl2,
                    title: 'Requirements & Budget',
                    icon: Icons.home_work_outlined,
                    children: [
                      _buildDetailRow('Needs BHK', data['needsBHK']),
                      _buildDetailRow('Down Payment', data['downPayment']),
                      _buildDetailRow('Final Amount', data['finalAmount'] != null ? '₹${data['finalAmount']}' : 'N/A'),
                      _buildDetailRow('Monthly Income', data['monthlyIncome']),
                      _buildDetailRow('Current Living In', data['livingIn']),
                      _buildDetailRow('Major Requirement', data['majorRequirement']),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildCollapsibleSection(
                    controller: _ctrl3,
                    title: 'Interaction & Source',
                    icon: Icons.info_outline,
                    children: [
                      _buildDetailRow('Company', data['company']),
                      _buildDetailRow('Lead Type', data['leadType']),
                      _buildDetailRow('Current Status', data['status']),
                      _buildDetailRow('Lead Source', data['source']),
                      _buildDetailRow('Demo Done', data['demoDone']),
                      _buildDetailRow('Major Problem', data['majorProblem']),
                      _buildDetailRow('Best Free Time', data['freeTime']),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildCollapsibleSection(
                    controller: _ctrl4,
                    title: 'Remarks & Documents',
                    icon: Icons.description,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Initial Remark:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(data['remark'] ?? 'No remarks added.', style: const TextStyle(fontSize: 14, color: Colors.black87)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // --- FOLLOW-UP TIMELINE ---
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Follow-up History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                      TextButton.icon(
                        onPressed: _showFollowUpForm,
                        icon: const Icon(Icons.add_circle_outline, color: Color(0xFFFF6B22)),
                        label: const Text('Add Entry', style: TextStyle(color: Color(0xFFFF6B22), fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildFollowUpTimeline(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpTimeline() {
    if (followUps.isEmpty) return const Text("No follow-ups yet.", style: TextStyle(color: Colors.grey));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: followUps.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final entry = followUps[index];
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry['date']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
                      child: Text(entry['status']!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('By: ${entry['caller']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Text(entry['remark']!, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCollapsibleSection({required ExpansionTileController controller, required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          controller: controller,
          onExpansionChanged: (expanded) {
            // Kisi ek par click karne se saare expand ho jayenge
            if (expanded) _expandAll();
          },
          leading: Icon(icon, color: const Color(0xFFFF6B22)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 15)),
          childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _buildMilestoneToggleBar() {
    List<String> milestones = ['First Visit', 'Revisit', 'Token', 'Registration', 'Possession'];
    return Container(
      height: 60, color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: milestones.length,
        itemBuilder: (context, index) {
          String milestone = milestones[index];
          bool isSelected = selectedMilestone == milestone;
          return GestureDetector(
            onTap: () => setState(() => selectedMilestone = milestone),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6), padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFF6B22) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? const Color(0xFFFF6B22) : Colors.grey.shade300),
              ),
              alignment: Alignment.center,
              child: Text(milestone, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 13)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500, fontSize: 13))),
          const Text(' :   ', style: TextStyle(color: Colors.grey)),
          Expanded(flex: 3, child: Text(value != null && value.isNotEmpty ? value : 'N/A', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13))),
        ],
      ),
    );
  }
}