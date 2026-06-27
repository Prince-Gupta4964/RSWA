import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/project_viewmodel.dart';

class AddProjectView extends StatefulWidget {
  const AddProjectView({Key? key}) : super(key: key);

  @override
  State<AddProjectView> createState() => _AddProjectViewState();
}

class _AddProjectViewState extends State<AddProjectView> {
  bool _isSaving = false;

  // Basic Details
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _reraCtrl = TextEditingController();
  String selectedLegality = 'RERA Approved';
  String selectedType = 'Flat'; // Default type

  // Contact Details
  final TextEditingController _contactPersonCtrl = TextEditingController();
  final TextEditingController _contactPhoneCtrl = TextEditingController();

  // Dynamic Fields Controllers
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _areaCtrl = TextEditingController(); // Sq.ft etc
  final TextEditingController _bhkCtrl = TextEditingController(); // For Flat/Bungalow
  final TextEditingController _floorCtrl = TextEditingController(); // For Flat
  String boundaryWall = 'Yes'; // For Plot

  @override
  void dispose() {
    _nameCtrl.dispose(); _reraCtrl.dispose(); _contactPersonCtrl.dispose();
    _contactPhoneCtrl.dispose(); _priceCtrl.dispose(); _areaCtrl.dispose();
    _bhkCtrl.dispose(); _floorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => context.pop()),
        title: const Text('Add New Project', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECTION 1: BASIC DETAILS ---
            const Text('Project Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFF6B22))),
            const Divider(),
            const SizedBox(height: 12),
            _buildTextField('Project Name', _nameCtrl, isRequired: true),
            const SizedBox(height: 16),
            _buildTextField('RERA Registration ID', _reraCtrl),
            const SizedBox(height: 16),
            _buildDropdown('Legality Status', ['RERA Approved', 'Collector NA', 'Gram Panchayat', 'Pending'], selectedLegality, (val) => setState(() => selectedLegality = val!)),
            const SizedBox(height: 24),

            // --- SECTION 2: DYNAMIC INVENTORY SELECTION ---
            const Text('Property Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFF6B22))),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: ['Flat', 'Plot', 'Bungalow'].map((type) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _buildChoiceChip(type, selectedType, (val) {
                      setState(() {
                        selectedType = val; // Yahan type change hote hi UI update hoga
                        // Naya type select hote hi controllers clear kar do
                        _areaCtrl.clear(); _priceCtrl.clear(); _bhkCtrl.clear(); _floorCtrl.clear();
                      });
                    }, expanded: true),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // --- SECTION 3: DYNAMIC FIELDS RENDERER ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
              child: _buildDynamicFields(),
            ),
            const SizedBox(height: 24),

            // --- SECTION 4: CONTACT PERSON ---
            const Text('Primary Contact Person', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFF6B22))),
            const Divider(),
            const SizedBox(height: 12),
            _buildTextField('Contact Name', _contactPersonCtrl, isRequired: true),
            const SizedBox(height: 16),
            _buildTextField('Contact Phone', _contactPhoneCtrl, isRequired: true, keyboardType: TextInputType.phone),
            const SizedBox(height: 30),

            // --- SUBMIT BUTTON ---
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : () async {
                  if (_nameCtrl.text.isEmpty || _contactPersonCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill required fields')));
                    return;
                  }
                  setState(() => _isSaving = true);
                  try {
                    // Property ke hisab se dynamic data map banaya
                    Map<String, dynamic> dynamicData = {};
                    if (selectedType == 'Flat') {
                      dynamicData = {'bhk': _bhkCtrl.text, 'carpetArea': _areaCtrl.text, 'floor': _floorCtrl.text, 'price': _priceCtrl.text};
                    } else if (selectedType == 'Plot') {
                      dynamicData = {'plotArea': _areaCtrl.text, 'boundaryWall': boundaryWall, 'price': _priceCtrl.text};
                    } else if (selectedType == 'Bungalow') {
                      dynamicData = {'bhk': _bhkCtrl.text, 'builtUpArea': _areaCtrl.text, 'price': _priceCtrl.text};
                    }

                    await Provider.of<ProjectViewModel>(context, listen: false).addOrUpdateProject(
                      projectName: _nameCtrl.text,
                      reraId: _reraCtrl.text,
                      legality: selectedLegality,
                      propertyType: selectedType,
                      contactPerson: _contactPersonCtrl.text,
                      contactNumber: _contactPhoneCtrl.text,
                      propertyDetails: dynamicData,
                    );

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Project Added Successfully!')));
                    context.pop();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  } finally {
                    if (mounted) setState(() => _isSaving = false);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B22)),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('SAVE PROJECT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // --- YAHAN SE FORM CHANGE HOTA HAI ---
  Widget _buildDynamicFields() {
    if (selectedType == 'Flat') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField('Configuration (e.g. 1BHK, 2BHK)', _bhkCtrl),
          const SizedBox(height: 12),
          _buildTextField('Carpet Area (Sq.ft)', _areaCtrl, keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          _buildTextField('Available Floors', _floorCtrl),
          const SizedBox(height: 12),
          _buildTextField('Starting Price', _priceCtrl, keyboardType: TextInputType.number),
        ],
      );
    } else if (selectedType == 'Plot') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField('Plot Area (Sq.ft / Guntas)', _areaCtrl),
          const SizedBox(height: 12),
          _buildDropdown('Boundary Wall Built?', ['Yes', 'No'], boundaryWall, (val) => setState(() => boundaryWall = val!)),
          const SizedBox(height: 12),
          _buildTextField('Price per Sq.ft / Total Price', _priceCtrl),
        ],
      );
    } else if (selectedType == 'Bungalow') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField('Configuration (e.g. 3BHK Duplex)', _bhkCtrl),
          const SizedBox(height: 12),
          _buildTextField('Built-up Area (Sq.ft)', _areaCtrl, keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          _buildTextField('Total Price', _priceCtrl, keyboardType: TextInputType.number),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  // --- HELPER WIDGETS ---
  Widget _buildTextField(String label, TextEditingController controller, {bool isRequired = false, TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label + (isRequired ? ' *' : ''), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: controller, keyboardType: keyboardType,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFFF6B22))),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? selectedValue, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: selectedValue,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFFF6B22))),
          ),
          items: items.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildChoiceChip(String text, String selectedValue, Function(String) onTap, {bool expanded = false}) {
    bool isSelected = selectedValue == text;
    Widget chip = GestureDetector(
      onTap: () => onTap(text),
      child: Container(
        alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6B22) : Colors.white,
          border: Border.all(color: isSelected ? const Color(0xFFFF6B22) : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : Colors.black87)),
      ),
    );
    return expanded ? chip : IntrinsicWidth(child: chip);
  }
}