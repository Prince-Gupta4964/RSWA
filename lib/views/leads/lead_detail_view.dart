import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/lead_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/lead_viewmodel.dart';
import '../../utils/role_permissions.dart';

class LeadDetailView extends StatefulWidget {
  final LeadModel lead;

  const LeadDetailView({Key? key, required this.lead}) : super(key: key);

  @override
  State<LeadDetailView> createState() => _LeadDetailViewState();
}

class _LeadDetailViewState extends State<LeadDetailView> {
  String selectedMilestone = 'Visit';
  bool _isUpdating = false;

  final ExpansionTileController _ctrl1 = ExpansionTileController();
  final ExpansionTileController _ctrl2 = ExpansionTileController();
  final ExpansionTileController _ctrl3 = ExpansionTileController();
  final ExpansionTileController _ctrl4 = ExpansionTileController();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  Future<void> _makeCall(String? number, AuthViewModel authVM) async {
    if (number == null || number.isEmpty) return;
    final Uri url = Uri.parse('tel:$number');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
      _addNewFollowUp(widget.lead.id, authVM.userName, 'System Auto-Track', 'Initiated a call to $number');
    }
  }

  Future<void> _sendWhatsApp(String? number, AuthViewModel authVM) async {
    if (number == null || number.isEmpty) return;
    String cleanNumber = number.replaceAll(RegExp(r'[^0-9]'), '');
    final Uri url = Uri.parse('https://wa.me/91$cleanNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
      _addNewFollowUp(widget.lead.id, authVM.userName, 'System Auto-Track', 'Redirected to WhatsApp for $number');
    }
  }

  void _addNewFollowUp(String leadId, String caller, String status, String remark, {bool updateStatus = true}) {
    Provider.of<LeadViewModel>(context, listen: false).addFollowUp(leadId, {
      'caller': caller,
      'status': status,
      'remark': remark,
    }, updateLeadStatus: updateStatus);
  }

  void _showFollowUpForm(AuthViewModel authVM) {
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
                      _addNewFollowUp(widget.lead.id, authVM.userName, selectedStatus, remarkController.text, updateStatus: true);
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
    final leadVM = context.watch<LeadViewModel>();
    final authVM = context.watch<AuthViewModel>();
    
    final currentLead = leadVM.leads.firstWhere((l) => l.id == widget.lead.id, orElse: () => widget.lead);
    final data = currentLead.rawData;
    
    String primaryContact = data['whatsapp'] ?? data['contact2'] ?? '';
    selectedMilestone = data['journeyStage'] ?? 'Visit';

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
          currentLead.name,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isUpdating)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFFFF6B22)),
            onPressed: () => context.push('/add-lead', extra: currentLead),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _makeCall(primaryContact, authVM),
                    icon: const Icon(Icons.call, color: Colors.white, size: 18),
                    label: const Text('Call', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, elevation: 0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _sendWhatsApp(primaryContact, authVM),
                    icon: const Icon(Icons.chat, color: Colors.white, size: 18),
                    label: const Text('WhatsApp', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, elevation: 0),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: GestureDetector(
              onDoubleTap: _collapseAll,
              behavior: HitTestBehavior.opaque,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildCollapsibleSection(
                    controller: _ctrl1,
                    title: 'Basic Information',
                    icon: Icons.person_outline_rounded,
                    children: [
                      _buildDetailRow('Name', currentLead.name),
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
                    icon: Icons.info_outline_rounded,
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
                    title: 'Remarks',
                    icon: Icons.description_outlined,
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

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Follow-up History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                      TextButton.icon(
                        onPressed: () => _showFollowUpForm(authVM),
                        icon: const Icon(Icons.add_circle_outline, color: Color(0xFFFF6B22)),
                        label: const Text('Add Entry', style: TextStyle(color: Color(0xFFFF6B22), fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildFollowUpTimeline(currentLead, leadVM),
                  const SizedBox(height: 10),

                  // 🚀 NEW: Expandable Journey Stepper (Per User Request)
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                    child: ExpansionTile(
                      leading: const Icon(Icons.linear_scale, color: Color(0xFFFF6B22)),
                      title: const Text('Track Journey Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      children: [
                        _buildLeadJourneyStepper(currentLead, leadVM, authVM),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpTimeline(LeadModel lead, LeadViewModel leadVM) {
    return StreamBuilder<QuerySnapshot>(
      stream: leadVM.getFollowUps(lead.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Text("No follow-ups yet.", style: TextStyle(color: Colors.grey));

        final docs = snapshot.data!.docs;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = docs[index].data() as Map<String, dynamic>;
              final timestamp = entry['timestamp'] as Timestamp?;
              final dateStr = timestamp != null ? "${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}" : "Recently";

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
                          child: Text(entry['status']?.toString().toUpperCase() ?? 'WARM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('By: ${entry['caller'] ?? 'Unknown'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Text(entry['remark']?.toString() ?? '', style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)),
                  ],
                ),
              );
            },
          ),
        );
      },
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

  Widget _buildLeadJourneyStepper(LeadModel lead, LeadViewModel leadVM, AuthViewModel authVM) {
    List<String> milestones = [ 'Visit', 'Revisit', 'Token', 'Loan process', 'Downpayment', 'Registration', 'Disbursement', 'Possession' ];
    bool canEdit = authVM.appRole == AppRole.superAdmin || authVM.appRole == AppRole.admin || authVM.appRole == AppRole.officeStaff;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration( color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)], ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ const Text('Lead Lifecycle Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), if (!canEdit) const Icon(Icons.lock_outline, size: 16, color: Colors.grey), ], ),
          const SizedBox(height: 16),
          ...milestones.asMap().entries.map((entry) {
            int idx = entry.key;
            String m = entry.value;
            bool isCompleted = _isStageCompleted(m, selectedMilestone, milestones);
            return _buildStepperItem(
              title: m,
              isCompleted: isCompleted,
              isLast: idx == milestones.length - 1,
              canEdit: canEdit,
              onToggle: (val) {
                if (val) _updateJourneyStage(lead, m, leadVM, authVM);
                else { String prevStage = idx > 0 ? milestones[idx - 1] : milestones[0]; _updateJourneyStage(lead, prevStage, leadVM, authVM); }
              },
              lead: lead,
              leadVM: leadVM,
              authVM: authVM,
            );
          }).toList(),
        ],
      ),
    );
  }

  bool _isStageCompleted(String stage, String current, List<String> all) {
    int stageIdx = all.indexOf(stage);
    int currentIdx = all.indexOf(current);
    return stageIdx <= currentIdx;
  }

  Widget _buildStepperItem({
    required String title,
    required bool isCompleted,
    required bool isLast,
    required bool canEdit,
    required Function(bool) onToggle,
    required LeadModel lead,
    required LeadViewModel leadVM,
    required AuthViewModel authVM,
  }) {
    Color activeColor = const Color(0xFFFF6B22);
    bool needsToken = title == 'Token' && isCompleted;
    bool needsDownpayment = title == 'Downpayment' && isCompleted;

    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration( shape: BoxShape.circle, color: isCompleted ? activeColor : Colors.grey.shade200, border: Border.all(color: isCompleted ? activeColor : Colors.grey.shade300, width: 2), ),
                child: isCompleted ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
              if (!isLast) Expanded( child: Container( width: 2, color: isCompleted ? activeColor : Colors.grey.shade200, ), ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: TextStyle(fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal, color: isCompleted ? Colors.black87 : Colors.grey, fontSize: 14)),
                          if (needsToken) _buildInlineInput('Enter Token:', lead.rawData['tokenAmount']?.toString() ?? '', (val) => _updateField(lead, 'tokenAmount', val, leadVM, authVM)),
                          if (needsDownpayment) _buildInlineInput('Enter Downpayment:', lead.rawData['downPayment']?.toString() ?? '', (val) => _updateField(lead, 'downPayment', val, leadVM, authVM)),
                        ],
                      ),
                    ),
                    if (canEdit) Switch( value: isCompleted, onChanged: onToggle, activeColor: activeColor, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineInput(String label, String initialValue, Function(String) onSave) {
     final controller = TextEditingController(text: initialValue);
     return Padding(
       padding: const EdgeInsets.only(top: 8.0),
       child: Row(
         children: [
           Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFFF6B22))),
           const SizedBox(width: 8),
           SizedBox(
             width: 100, height: 30,
             child: TextField(
               controller: controller,
               keyboardType: TextInputType.number,
               style: const TextStyle(fontSize: 12),
               decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0), border: OutlineInputBorder()),
               onSubmitted: onSave,
             ),
           ),
           IconButton(onPressed: () => onSave(controller.text), icon: const Icon(Icons.save, size: 16, color: Colors.green)),
         ],
       ),
     );
  }

  Future<void> _updateField(LeadModel lead, String key, String value, LeadViewModel leadVM, AuthViewModel authVM) async {
    setState(() => _isUpdating = true);
    try {
      await _db.collection('leads').doc(lead.id).update({
         key: value,
         'updatedAt': FieldValue.serverTimestamp(),
         'updatedBy': authVM.actorMetadata,
      });
      _addNewFollowUp(lead.id, authVM.userName, 'Data Update', 'Updated $key to $value.', updateStatus: false);
    } finally { setState(() => _isUpdating = false); }
  }

  Future<void> _updateJourneyStage(LeadModel lead, String stage, LeadViewModel leadVM, AuthViewModel authVM) async {
    if (selectedMilestone == stage) return;
    setState(() => _isUpdating = true);
    try {
      await leadVM.updateLeadJourney(lead.id, stage, authVM.actorMetadata);
      _addNewFollowUp(lead.id, authVM.userName, 'Journey Update', 'Moved to $stage stage.', updateStatus: false);
    } finally { setState(() => _isUpdating = false); }
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
