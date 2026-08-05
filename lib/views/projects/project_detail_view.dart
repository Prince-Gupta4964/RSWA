import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/project_model.dart';
import '../../models/builder_model.dart';
import '../../viewmodels/project_viewmodel.dart';
import '../../viewmodels/builder_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/lead_viewmodel.dart'; // <-- NAYA: Lead list ke liye
import '../../utils/role_permissions.dart';

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

  // --- SMART KEY FORMATTER ---
  String _formatKeyLabel(String key) {
    Map<String, String> labels = {
      'bhk': 'Configuration (BHK)',
      'carpetArea': 'Carpet Area',
      'superBuiltUp': 'Super Built-up Area',
      'totalFloors': 'Total Floors',
      'parking': 'Parking Facility',
      'plotArea': 'Plot Area',
      'fsi': 'FSI Approved',
      'roadFrontage': 'Road Frontage',
      'boundaryWall': 'Boundary Wall / Fencing',
      'roadAccess': 'Internal Road Access',
      'bungalowType': 'Bungalow Type',
      'plotLandArea': 'Plot Land Area',
      'constructionArea': 'Construction Area',
      'privateGarden': 'Private Garden / Terrace',
      'condition': 'Property Condition',
      'configType': 'Configuration Type',
      'totalArea': 'Total Area',
      'usableArea': 'Usable Area',
      'builtUpArea': 'Built-Up Area',
      'oc_cc_status': 'OC / CC Status',
      'societyTitle': 'Society Title',
      'notary': 'Notary Status',
      'floorNumber': 'Floor Number',
      'ownerName': 'Owner Name',
      'referralCP': 'Referral (Channel Partner)',
    };

    if (labels.containsKey(key)) return labels[key]!;

    String formatted = key
        .replaceAllMapped(RegExp(r'[A-Z]'), (match) => ' ${match.group(0)}')
        .trim();
    if (formatted.isEmpty) return key;
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  void _showAddInventoryForm(ProjectModel project) {
    _wingCtrl.clear();
    _unitNoCtrl.clear();
    _areaCtrl.clear();
    selectedStatus = 'Available';
    String pType = project.propertyType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add New $pType Inventory',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),

              if (pType == 'Flat' || pType == 'Shop') ...[
                _buildModalTextField('Wing / Tower (e.g. A, B)', _wingCtrl),
                const SizedBox(height: 16),
              ],

              _buildModalTextField('$pType Number (e.g. 101)', _unitNoCtrl),
              const SizedBox(height: 16),

              _buildModalTextField(
                'Area / Size (Sq.ft)',
                _areaCtrl,
                isNumber: true,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFFF6B22),
                      width: 1.5,
                    ),
                  ),
                ),
                items: ['Available', 'Booked', 'Sold', 'Hold']
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(
                          e,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) => selectedStatus = val!,
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_unitNoCtrl.text.trim().isEmpty) return;

                    Map<String, dynamic> invData = {
                      'unitNo': _unitNoCtrl.text.trim(),
                      'area': _areaCtrl.text.trim(),
                      'status': selectedStatus,
                      'type': pType,
                    };
                    if (pType == 'Flat' || pType == 'Shop')
                      invData['wing'] = _wingCtrl.text.trim();

                    await Provider.of<ProjectViewModel>(
                      context,
                      listen: false,
                    ).addInventory(project.id, invData);
                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$pType successfully added!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'SAVE INVENTORY',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalTextField(
    String hint,
    TextEditingController ctrl, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF6B22), width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projectVM = Provider.of<ProjectViewModel>(context);
    final builderVM = Provider.of<BuilderViewModel>(context);
    final authVM = Provider.of<AuthViewModel>(context);
    
    final project = projectVM.projects.firstWhere(
      (item) => item.id == widget.project.id,
      orElse: () => widget.project,
    );
    final details = project.propertyDetails;

    final leadVM = Provider.of<LeadViewModel>(context);
    final associatedLeads = leadVM.leads.where((l) => l.rawData['company'] == project.projectName).toList();

    final linkedBuilders = builderVM.builders.where((b) => project.builderIds.contains(b.id)).toList();
    final builderNames = linkedBuilders.map((b) => b.name).join(', ');

    // Filtering logic to remove N/A and empty values to keep UI clean
    Map<String, dynamic> validDetails = {};
    details.forEach((key, value) {
      String valStr = value.toString().trim();
      if (valStr.isNotEmpty &&
          valStr != 'N/A' &&
          valStr != 'Sq.ft' &&
          valStr != '₹') {
        validDetails[key] = value;
      }
    });

    String location =
        validDetails['location']?.toString() ?? 'Location not specified';
    String condition = validDetails['condition']?.toString() ?? 'New';
    String startingPrice =
        validDetails['startingPrice']?.toString() ?? 'Price on Request';
    String amenitiesStr = validDetails['amenities']?.toString() ?? '';

    // Separate Config Details
    List<String> overviewKeys = [
      'location',
      'condition',
      'startingPrice',
      'amenities',
      'titleClear',
      'satbara',
      'naStatus',
      'totalUnits',
    ];
    Map<String, dynamic> configDetails = {};
    validDetails.forEach((key, value) {
      if (!overviewKeys.contains(key)) {
        configDetails[key] = value;
      }
    });

    List<String> amenitiesList = amenitiesStr.isNotEmpty
        ? amenitiesStr.split(',').map((e) => e.trim()).toList()
        : [];

    bool canManageHot = authVM.appRole == AppRole.superAdmin || 
                        authVM.appRole == AppRole.admin || 
                        authVM.appRole == AppRole.officeStaff;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          project.projectName,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          if (canManageHot)
            IconButton(
              icon: Icon(
                project.isHot ? Icons.whatshot_rounded : Icons.whatshot_outlined,
                color: project.isHot ? Colors.red : Colors.grey,
              ),
              tooltip: project.isHot ? 'Remove from Hot' : 'Mark as Hot',
              onPressed: () async {
                await projectVM.toggleHotStatus(project.id, !project.isHot);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(project.isHot ? 'Removed from Hot Projects' : 'Promoted to Hot Projects')),
                  );
                }
              },
            ),
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              color: Color(0xFFFF6B22),
              size: 22,
            ),
            onPressed: () => context.push('/add-project', extra: project),
            tooltip: 'Edit Project',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        children: [
          // --- SECTION 1: Legal & Overview ---
          _buildCardSection(
            title: 'Project Overview',
            icon: Icons.info_outline,
            children: [
              _buildDetailRow('Property Type', project.propertyType),
              _buildDetailRow('Condition', condition),
              _buildDetailRow('Location', location),
              if (validDetails.containsKey('startingPrice'))
                _buildDetailRow('Asking Price', startingPrice),
              if (builderNames.isNotEmpty)
                _buildDetailRow('Associated Builders', builderNames),

              if (condition == 'New' || project.reraId.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                if (project.reraId.isNotEmpty)
                  _buildDetailRow('RERA ID', project.reraId),
                _buildDetailRow('Legality', project.legality),
                if (validDetails.containsKey('titleClear'))
                  _buildDetailRow('Title Clear', validDetails['titleClear']),
                if (validDetails.containsKey('satbara'))
                  _buildDetailRow('7/12 (Satbara)', validDetails['satbara']),
                if (validDetails.containsKey('naStatus'))
                  _buildDetailRow('NA Status', validDetails['naStatus']),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // --- SECTION 2: Technical Configurations ---
          if (configDetails.isNotEmpty) ...[
            _buildCardSection(
              title: 'Configurations',
              icon: Icons.architecture_outlined,
              children: configDetails.entries
                  .map(
                    (e) => _buildDetailRow(
                      _formatKeyLabel(e.key),
                      e.value.toString(),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],

          // --- SECTION 3: Amenities ---
          if (amenitiesList.isNotEmpty) ...[
            _buildCardSection(
              title: 'Amenities',
              icon: Icons.pool_outlined,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: amenitiesList
                      .map(
                        (amenity) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            amenity,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // --- SECTION 4: Contact Details ---
          _buildCardSection(
            title: 'Contact Information',
            icon: Icons.support_agent_outlined,
            children: [
              _buildDetailRow('Contact Person', project.contactPerson),
              _buildDetailRow('Phone No.', project.contactNumber),
            ],
          ),
          const SizedBox(height: 16),

          // --- SECTION: ASSOCIATED LEADS ---
          _buildCardSection(
            title: 'Interested Leads (${associatedLeads.length})',
            icon: Icons.people_outline,
            initiallyExpanded: false,
            children: associatedLeads.isEmpty 
              ? [const Text('No leads associated with this project yet.', style: TextStyle(color: Colors.grey, fontSize: 13))]
              : associatedLeads.map((l) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 14)),
                  title: Text(l.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text(l.status, style: TextStyle(fontSize: 11, color: l.status == 'Hot' ? Colors.red : Colors.grey)),
                  trailing: const Icon(Icons.chevron_right, size: 16),
                  onTap: () => context.push('/lead-detail', extra: l),
                )).toList(),
          ),
          const SizedBox(height: 32),

          // --- SECTION 5: INVENTORY HEADER & LIST ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${project.propertyType} Inventory',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              InkWell(
                onTap: () => _showAddInventoryForm(project),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B22).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add, color: Color(0xFFFF6B22), size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Add Item',
                        style: TextStyle(
                          color: Color(0xFFFF6B22),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Real-time Inventory List
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('projects')
                .doc(project.id)
                .collection('inventory')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(color: Color(0xFFFF6B22)),
                  ),
                );
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(30),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 40,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Inventory is empty.',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              var inventoryList = snapshot.data!.docs;

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: inventoryList.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  var item =
                      inventoryList[index].data() as Map<String, dynamic>;

                  Color statusColor = Colors.green;
                  if (item['status'] == 'Booked' || item['status'] == 'Hold')
                    statusColor = Colors.orange;
                  if (item['status'] == 'Sold') statusColor = Colors.red;

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.vpn_key_outlined, color: statusColor),
                      ),
                      title: Text(
                        (project.propertyType == 'Flat' ||
                                    project.propertyType == 'Shop') &&
                                item['wing'] != null &&
                                item['wing'].toString().isNotEmpty
                            ? 'Wing ${item['wing']} | No: ${item['unitNo']}'
                            : 'No: ${item['unitNo']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Size: ${item['area']} Sq.ft',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: statusColor.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          item['status'] ?? 'Available',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
    );
  }

  // --- HELPER WIDGETS ---
  Widget _buildCardSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool initiallyExpanded = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B22).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFFFF6B22), size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontSize: 15,
            ),
          ),
          childrenPadding: const EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: 20,
          ),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          const Text(' :   ', style: TextStyle(color: Colors.grey)),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
