import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/cp_viewmodel.dart';

class AddCPView extends StatefulWidget {
  const AddCPView({Key? key}) : super(key: key);

  @override
  State<AddCPView> createState() => _AddCPViewState();
}

class _AddCPViewState extends State<AddCPView> {
  // Saare columns ke liye controllers
  final TextEditingController _cpNameController = TextEditingController();
  final TextEditingController _professionController = TextEditingController();
  final TextEditingController _contactNoController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _officeRefController = TextEditingController();
  final TextEditingController _advisorController = TextEditingController();
  final TextEditingController _callerRefController = TextEditingController();
  final TextEditingController _reraIdController = TextEditingController(); // <-- NAYA: RERA ID ke liye

  String selectedStatus = 'Active'; // Default status
  bool _isSaving = false; // Loading animation ke liye naya variable

  @override
  void dispose() {
    _cpNameController.dispose();
    _professionController.dispose();
    _contactNoController.dispose();
    _locationController.dispose();
    _officeRefController.dispose();
    _advisorController.dispose();
    _callerRefController.dispose();
    _reraIdController.dispose(); // <-- Dispose karna zaroori hai
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => context.pop()),
        title: const Text('Add Channel Partner', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField('CP Name', _cpNameController, isRequired: true),
            const SizedBox(height: 16),
            _buildTextField('Profession', _professionController),
            const SizedBox(height: 16),
            _buildTextField('Contact No.', _contactNoController, isRequired: true),
            const SizedBox(height: 16),
            // --- NAYA: RERA ID TEXT FIELD ---
            _buildTextField('RERA Registration ID', _reraIdController),
            const SizedBox(height: 16),
            _buildTextField('Location', _locationController),
            const SizedBox(height: 16),
            _buildTextField('Office Ref.', _officeRefController),
            const SizedBox(height: 16),
            _buildTextField('Advisor Reached By', _advisorController),
            const SizedBox(height: 16),
            _buildTextField('Caller Ref.', _callerRefController),
            const SizedBox(height: 24),

            const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildChoiceChip('Active', selectedStatus, (val) => setState(() => selectedStatus = val)),
                _buildChoiceChip('Pending', selectedStatus, (val) => setState(() => selectedStatus = val)),
                _buildChoiceChip('Inactive', selectedStatus, (val) => setState(() => selectedStatus = val)),
              ],
            ),
            const SizedBox(height: 30),

            // --- UPDATED SUBMIT BUTTON ---
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                // Agar save ho raha hai toh button disable kar do
                onPressed: _isSaving ? null : () async {
                  if (_cpNameController.text.isEmpty || _contactNoController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name & Contact are required')));
                    return;
                  }

                  // UI mein loading shuru karein
                  setState(() {
                    _isSaving = true;
                  });

                  try {
                    // --- NAYA LOGIC: Yahan addOrUpdateCP call kiya aur reraId bheja ---
                    await Provider.of<CPViewModel>(context, listen: false).addOrUpdateCP(
                      cpName: _cpNameController.text,
                      profession: _professionController.text,
                      contactNo: _contactNoController.text,
                      location: _locationController.text,
                      officeRef: _officeRefController.text,
                      advisorReachedBy: _advisorController.text,
                      callerRef: _callerRefController.text,
                      status: selectedStatus,
                      reraId: _reraIdController.text, // Database me jayega
                    );

                    // Context await ke baad use karne se pehle mounted check karte hain
                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CP Added Successfully!')));

                    // Wapas list par jayein
                    context.pop();

                  } catch (e) {
                    if (!mounted) return;
                    // Agar Firebase error de, toh humein screen par dikhega
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
                  } finally {
                    // Process khatam hone ke baad loading band karein
                    if (mounted) {
                      setState(() {
                        _isSaving = false;
                      });
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B22),
                  disabledBackgroundColor: Colors.grey, // Jab button disable ho
                ),
                child: _isSaving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : const Text('SAVE CP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isRequired = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label + (isRequired ? ' *' : ''), style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter $label',
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFFF6B22))),
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceChip(String text, String selectedValue, Function(String) onTap) {
    bool isSelected = selectedValue == text;
    return GestureDetector(
      onTap: () => onTap(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6B22).withOpacity(0.1) : Colors.white,
          border: Border.all(color: isSelected ? const Color(0xFFFF6B22) : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: TextStyle(color: isSelected ? const Color(0xFFFF6B22) : Colors.black87, fontWeight: FontWeight.w500)),
      ),
    );
  }
}