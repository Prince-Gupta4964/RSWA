import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/project_model.dart';
import '../../viewmodels/project_viewmodel.dart';

class ProjectDetailView extends StatefulWidget {
  final ProjectModel project;
  const ProjectDetailView({Key? key, required this.project}) : super(key: key);

  @override
  State<ProjectDetailView> createState() => _ProjectDetailViewState();
}

class _ProjectDetailViewState extends State<ProjectDetailView> {
  // Inventory Form Controllers
  final TextEditingController _wingCtrl = TextEditingController();
  final TextEditingController _unitNoCtrl = TextEditingController();
  final TextEditingController _areaCtrl = TextEditingController();
  String selectedStatus = 'Available';

  // --- NAYA: Sabko ek sath kholne aur band karne ke liye controllers ---
  final ExpansionTileController _ctrl1 = ExpansionTileController();
  final ExpansionTileController _ctrl2 = ExpansionTileController();
  final ExpansionTileController _ctrl3 = ExpansionTileController();

  void _expandAll() {
    if (!_ctrl1.isExpanded) _ctrl1.expand();
    if (!_ctrl2.isExpanded) _ctrl2.expand();
    if (!_ctrl3.isExpanded) _ctrl3.expand();
  }

  void _collapseAll() {
    if (_ctrl1.isExpanded) _ctrl1.collapse();
    if (_ctrl2.isExpanded) _ctrl2.collapse();
    if (_ctrl3.isExpanded) _ctrl3.collapse();
  }

  void _showAddInventoryForm() {
    _wingCtrl.clear(); _unitNoCtrl.clear(); _areaCtrl.clear(); selectedStatus = 'Available';
    String pType = widget.project.propertyType;

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
              Text('Add New $pType', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFF6B22))),
              const SizedBox(height: 16),

              if (pType == 'Flat') ...[
                TextField(controller: _wingCtrl, decoration: const InputDecoration(labelText: 'Wing/Tower Name (e.g. A, B)', border: OutlineInputBorder())),
                const SizedBox(height: 12),
              ],

              TextField(controller: _unitNoCtrl, decoration: InputDecoration(labelText: '$pType Number (e.g. 101)', border: const OutlineInputBorder())),
              const SizedBox(height: 12),

              TextField(controller: _areaCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Area (Sq.ft)', border: OutlineInputBorder())),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                items: ['Available', 'Booked', 'Sold', 'Hold'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => selectedStatus = val!,
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_unitNoCtrl.text.isEmpty) return;

                    Map<String, dynamic> invData = {
                      'unitNo': _unitNoCtrl.text,
                      'area': _areaCtrl.text,
                      'status': selectedStatus,
                      'type': pType,
                    };
                    if (pType == 'Flat') invData['wing'] = _wingCtrl.text;

                    await Provider.of<ProjectViewModel>(context, listen: false).addInventory(widget.project.id, invData);
                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$pType Added to Inventory!')));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B22)),
                  child: const Text('SAVE INVENTORY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    final details = widget.project.propertyDetails;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => context.pop()),
        title: Text(widget.project.projectName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: GestureDetector(
        onDoubleTap: _collapseAll,
        behavior: HitTestBehavior.opaque,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Center(
              child: Text('💡 Single tap on heading to expand all. Double tap background to collapse all.', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ),
            const SizedBox(height: 12),

            // --- SECTION 1: Basic Information ---
            _buildCollapsibleSection(
              controller: _ctrl1,
              title: 'Basic Project Info',
              icon: Icons.business_outlined,
              children: [
                _buildDetailRow('Project Name', widget.project.projectName),
                _buildDetailRow('Property Type', widget.project.propertyType),
                _buildDetailRow('RERA Registration', widget.project.reraId),
                _buildDetailRow('Legality', widget.project.legality),
              ],
            ),
            const SizedBox(height: 12),

            // --- SECTION 2: Dynamic Configurations ---
            _buildCollapsibleSection(
              controller: _ctrl2,
              title: 'Configurations & Details',
              icon: Icons.architecture_outlined,
              children: details.entries.map((e) => _buildDetailRow(e.key.toUpperCase(), e.value.toString())).toList(),
            ),
            const SizedBox(height: 12),

            // --- SECTION 3: Contact Person ---
            _buildCollapsibleSection(
              controller: _ctrl3,
              title: 'Primary Contact Person',
              icon: Icons.person_outline,
              children: [
                _buildDetailRow('Name', widget.project.contactPerson),
                _buildDetailRow('Phone No.', widget.project.contactNumber),
              ],
            ),
            const SizedBox(height: 24),

            // --- SECTION 4: INVENTORY HEADER & LIST ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${widget.project.propertyType} Inventory', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _showAddInventoryForm,
                  icon: const Icon(Icons.add, color: Color(0xFFFF6B22)),
                  label: const Text('Add Item', style: TextStyle(color: Color(0xFFFF6B22), fontWeight: FontWeight.bold)),
                )
              ],
            ),
            const SizedBox(height: 8),

            // Real-time Inventory List
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('projects').doc(widget.project.id).collection('inventory').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B22)));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                    child: Text('No ${widget.project.propertyType}s added to inventory yet.', style: const TextStyle(color: Colors.grey)),
                  );
                }

                var inventoryList = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true, // Isko true rakhna zaroori hai kyunki yeh ek aur ListView ke andar hai
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: inventoryList.length,
                  itemBuilder: (context, index) {
                    var item = inventoryList[index].data() as Map<String, dynamic>;

                    Color statusColor = Colors.green;
                    if (item['status'] == 'Booked' || item['status'] == 'Hold') statusColor = Colors.orange;
                    if (item['status'] == 'Sold') statusColor = Colors.red;

                    return Card(
                      color: Colors.white,
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: statusColor.withOpacity(0.1), child: Icon(Icons.vpn_key_outlined, color: statusColor)),
                        title: Text(
                          widget.project.propertyType == 'Flat' ? 'Wing ${item['wing'] ?? '-'} | No: ${item['unitNo']}' : 'No: ${item['unitNo']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Area: ${item['area']} Sq.ft'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor)),
                          child: Text(item['status'] ?? 'Available', style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---
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

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500, fontSize: 13))),
          const Text(' :   ', style: const TextStyle(color: Colors.grey)),
          Expanded(flex: 3, child: Text(value != null && value.isNotEmpty ? value : 'N/A', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13))),
        ],
      ),
    );
  }
}