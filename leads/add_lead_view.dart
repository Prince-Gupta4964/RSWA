import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/lead_viewmodel.dart';
import '../../viewmodels/cp_viewmodel.dart'; // <-- NAYA: CP Viewmodel Import kiya taaki live list mil sake
import '../../models/lead_model.dart';

class AddLeadView extends StatefulWidget {
  final LeadModel? lead;

  const AddLeadView({Key? key, this.lead}) : super(key: key);

  @override
  State<AddLeadView> createState() => _AddLeadViewState();
}

class _AddLeadViewState extends State<AddLeadView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSaving = false;

  late TextEditingController _dateController;
  late TextEditingController _nameController;
  late TextEditingController _professionController;
  late TextEditingController _whatsappController;
  late TextEditingController _contact2Controller;
  late TextEditingController _remarkController;
  late TextEditingController _emailController;
  late TextEditingController _finalAmountController;
  late TextEditingController _monthlyIncomeController;
  late TextEditingController _bookingDateController;
  late TextEditingController _freeTimeController;
  late TextEditingController _cameWithController;
  late TextEditingController _dobController;

  String? selectedCompany;
  String? selectedSubCompany;
  String? selectedAddress;
  String? selectedSource;
  String? selectedCP; // <-- NAYA: Reference ke time CP select karne ke liye
  late String selectedLeadType;
  late String selectedLeadStatus;
  late String selectedGender;
  late String selectedDemoDone;
  String? selectedLivingIn;
  late String selectedNeedsBHK;
  late String selectedDownPayment;
  String? selectedMajorProblem;
  String? selectedMajorRequirement;
  late String selectedReligion;
  String? selectedAdvisor;
  String? selectedReachedBy;
  String? selectedCaller;

  @override
  void initState() {
    super.initState();
    final data = widget.lead?.rawData;

    _dateController = TextEditingController(text: data?['date'] ?? '22/06/2026, 12:58 PM');
    _nameController = TextEditingController(text: data?['name'] ?? '');
    _professionController = TextEditingController(text: data?['profession'] ?? '');
    _whatsappController = TextEditingController(text: data?['whatsapp'] ?? '');
    _contact2Controller = TextEditingController(text: data?['contact2'] ?? '');
    _remarkController = TextEditingController(text: data?['remark'] ?? '');
    _emailController = TextEditingController(text: data?['email'] ?? '');
    _finalAmountController = TextEditingController(text: data?['finalAmount'] ?? '0');
    _monthlyIncomeController = TextEditingController(text: data?['monthlyIncome'] ?? '');
    _bookingDateController = TextEditingController(text: data?['bookingDate'] ?? '');
    _freeTimeController = TextEditingController(text: data?['freeTime'] ?? '');
    _cameWithController = TextEditingController(text: data?['cameWith'] ?? '');
    _dobController = TextEditingController(text: data?['dob'] ?? '');

    selectedCompany = data?['company'] ?? 'Atech IT Solution';
    selectedSubCompany = data?['subCompany'];
    selectedAddress = data?['address'];
    selectedSource = data?['source'];
    selectedLeadType = data?['leadType'] ?? 'Client';
    selectedLeadStatus = data?['status'] ?? 'Cold';
    selectedGender = data?['gender'] ?? 'Male';
    selectedDemoDone = data?['demoDone'] ?? 'N';
    selectedLivingIn = data?['livingIn'];
    selectedNeedsBHK = data?['needsBHK'] ?? '1BHK';
    selectedDownPayment = data?['downPayment'] ?? '3L';
    selectedMajorProblem = data?['majorProblem'];
    selectedMajorRequirement = data?['majorRequirement'];
    selectedReligion = data?['religion'] ?? 'Hindu';
    selectedAdvisor = data?['advisor'] ?? 'A Tech';
    selectedReachedBy = data?['reachedBy'] ?? 'A Tech';
    selectedCaller = data?['caller'] ?? 'A Tech';

    // Agar purana source reference tha, toh CP ka naam pre-fill karein
    if (selectedSource == 'Reference') {
      selectedCP = data?['caller'];
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _dateController.dispose();
    _nameController.dispose();
    _professionController.dispose();
    _whatsappController.dispose();
    _contact2Controller.dispose();
    _remarkController.dispose();
    _emailController.dispose();
    _finalAmountController.dispose();
    _monthlyIncomeController.dispose();
    _bookingDateController.dispose();
    _freeTimeController.dispose();
    _cameWithController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lead Name is required')));
      return;
    }
    // Agar Reference select kiya hai par CP select nahi kiya
    if (selectedSource == 'Reference' && (selectedCP == null || selectedCP!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Channel Partner')));
      return;
    }
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _previousPage() {
    _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.lead != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              if (_currentPage == 1) {
                _previousPage();
              } else {
                context.pop();
              }
            }
        ),
        title: Text(
            isEditing ? 'Edit Client (Step ${_currentPage + 1}/2)' : 'Add Client (Step ${_currentPage + 1}/2)',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (int page) => setState(() => _currentPage = page),
        children: [ _buildPage1(), _buildPage2(isEditing) ],
      ),
    );
  }

  Widget _buildPage1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField('Date & Time', _dateController, suffixIcon: Icons.calendar_today, isRequired: true),
          const SizedBox(height: 16),
          _buildDropdown('Company', ['Atech IT Solution', 'Other'], selectedCompany, (val) => setState(() => selectedCompany = val), isRequired: true),
          const SizedBox(height: 16),
          _buildDropdown('Sub Company', ['Sub 1', 'Sub 2'], selectedSubCompany, (val) => setState(() => selectedSubCompany = val), isRequired: true),
          const SizedBox(height: 16),
          _buildTextField('Lead Name', _nameController, isRequired: true),
          const SizedBox(height: 16),
          _buildTextField('Lead Profession', _professionController),
          const SizedBox(height: 16),
          _buildTextField('Lead Whatsapp No.', _whatsappController),
          const SizedBox(height: 16),
          _buildTextField('Lead Contact 2', _contact2Controller),
          const SizedBox(height: 16),
          _buildDropdown('Lead Address', ['Location 1', 'Location 2'], selectedAddress, (val) => setState(() => selectedAddress = val)),
          const SizedBox(height: 24),

          const Text('Lead Type *', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: ['Client', 'RP', 'CP', 'Broker', 'Investor', 'Influencer'].map((e) => _buildChoiceChip(e, selectedLeadType, (val) => setState(() => selectedLeadType = val))).toList(),
          ),
          const SizedBox(height: 24),

          const Text('Lead Status *', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: ['Paid', 'Book', 'Hot', 'Warm', 'Cold', 'Think', 'Hold', 'Out'].map((e) => _buildChoiceChip(e, selectedLeadStatus, (val) => setState(() => selectedLeadStatus = val))).toList(),
          ),
          const SizedBox(height: 24),

          // --- LEAD SOURCE DROPDOWN ---
          _buildDropdown('Lead Source *', ['Facebook', 'Google', 'Reference'], selectedSource, (val) {
            setState(() {
              selectedSource = val;
              if (val != 'Reference') {
                selectedCP = null; // Reset CP if source is changed
              }
            });
          }),
          const SizedBox(height: 16),

          // --- NAYA LOGIC: Agar Reference select kiya toh CP ki list dikhegi ---
          if (selectedSource == 'Reference') ...[
            Consumer<CPViewModel>(
              builder: (context, cpVM, child) {
                // Firebase se live CP Names extract kiye
                List<String> cpOptions = cpVM.cps.map((e) => e.cpName).toList();

                // Add New CP ka option end me jod diya
                cpOptions.add('➕ Add New CP');

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Channel Partner *', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black87, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: (selectedCP != null && cpOptions.contains(selectedCP)) ? selectedCP : null,
                      icon: const Icon(Icons.arrow_drop_down),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFFF6B22))),
                      ),
                      items: cpOptions.map((String value) {
                        return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                                value,
                                style: TextStyle(
                                    fontSize: 14,
                                    // "Add New CP" ko orange aur bold dikhane ke liye
                                    color: value == '➕ Add New CP' ? const Color(0xFFFF6B22) : Colors.black87,
                                    fontWeight: value == '➕ Add New CP' ? FontWeight.bold : FontWeight.normal
                                )
                            )
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val == '➕ Add New CP') {
                          // Direct Add CP Page pe bhejo
                          context.push('/add-cp');
                        } else {
                          setState(() {
                            selectedCP = val;
                            selectedCaller = val!; // Isko Caller me save kar lenge taaki CP detail me match ho jaye
                          });
                        }
                      },
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
          ],

          _buildTextField('Lead Remark', _remarkController, maxLines: 3),
          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B22)),
              child: const Text('NEXT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildPage2(bool isEditing) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField('Lead Email', _emailController),
          const SizedBox(height: 16),
          const Text('Gender', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: ['Male', 'Female', 'Others'].map((e) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _buildChoiceChip(e, selectedGender, (val) => setState(() => selectedGender = val), expanded: true)))).toList()),
          const SizedBox(height: 16),
          const Text('Demo Done', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: ['N', 'Y'].map((e) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _buildChoiceChip(e, selectedDemoDone, (val) => setState(() => selectedDemoDone = val), expanded: true)))).toList()),
          const SizedBox(height: 16),

          _buildDropdown('Now Living In', ['City 1', 'City 2'], selectedLivingIn, (val) => setState(() => selectedLivingIn = val)),
          const SizedBox(height: 16),
          const Text('Needs BHK', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: ['1RK', '1BHK', '2BHK', '3BHK', 'Bungalow', 'Land'].map((e) => _buildChoiceChip(e, selectedNeedsBHK, (val) => setState(() => selectedNeedsBHK = val))).toList()),
          const SizedBox(height: 16),

          const Text('Down Payment', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: ['3L', '5L', '10L', '15L', '20L', '25L', '30L', '40L', '50L'].map((e) => _buildChoiceChip(e, selectedDownPayment, (val) => setState(() => selectedDownPayment = val))).toList()),
          const SizedBox(height: 16),

          _buildTextField('Final Amount', _finalAmountController),
          const SizedBox(height: 16),
          _buildTextField('Monthly Income', _monthlyIncomeController),
          const SizedBox(height: 16),
          _buildDropdown('Major Problem', ['Problem A', 'Problem B'], selectedMajorProblem, (val) => setState(() => selectedMajorProblem = val)),
          const SizedBox(height: 16),
          _buildDropdown('Major Requirement', ['Req A', 'Req B'], selectedMajorRequirement, (val) => setState(() => selectedMajorRequirement = val)),
          const SizedBox(height: 16),
          _buildTextField('Booking Date', _bookingDateController),
          const SizedBox(height: 16),
          _buildTextField('Free Time', _freeTimeController),
          const SizedBox(height: 16),
          _buildTextField('Came With', _cameWithController),
          const SizedBox(height: 16),
          _buildTextField('Date of Birth', _dobController, suffixIcon: Icons.calendar_today, hintText: 'dd/mm/yyyy'),
          const SizedBox(height: 16),

          const Text('Religion', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: ['Hindu', 'Others'].map((e) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _buildChoiceChip(e, selectedReligion, (val) => setState(() => selectedReligion = val), expanded: true)))).toList()),
          const SizedBox(height: 16),

          _buildDropdown('Advisor *', ['A Tech', 'Other'], selectedAdvisor, (val) => setState(() => selectedAdvisor = val)),
          const SizedBox(height: 16),
          _buildDropdown('Reached By', ['A Tech', 'Other'], selectedReachedBy, (val) => setState(() => selectedReachedBy = val)),
          const SizedBox(height: 16),

          // Caller ab dynamically Update ho chuka hai (Agar CP select hua tha)
          _buildDropdown('Caller', ['A Tech', 'Other'], selectedCaller, (val) => setState(() => selectedCaller = val)),
          const SizedBox(height: 24),

          const Text('Visiting Card Front', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(height: 100, width: double.infinity, decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.camera_alt, color: Colors.grey, size: 40)),
          const SizedBox(height: 30),

          Row(
            children: [
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _previousPage,
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFFF6B22))),
                    child: const Text('PREVIOUS', style: TextStyle(color: Color(0xFFFF6B22), fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : () async {
                      setState(() => _isSaving = true);
                      try {
                        await Provider.of<LeadViewModel>(context, listen: false).addOrUpdateLead(
                          id: widget.lead?.id,
                          date: _dateController.text,
                          company: selectedCompany ?? '',
                          subCompany: selectedSubCompany ?? '',
                          name: _nameController.text,
                          profession: _professionController.text,
                          whatsapp: _whatsappController.text,
                          contact2: _contact2Controller.text,
                          address: selectedAddress ?? '',
                          leadType: selectedLeadType,
                          status: selectedLeadStatus,
                          source: selectedSource ?? '',
                          remark: _remarkController.text,
                          email: _emailController.text,
                          gender: selectedGender,
                          demoDone: selectedDemoDone,
                          livingIn: selectedLivingIn ?? '',
                          needsBHK: selectedNeedsBHK,
                          downPayment: selectedDownPayment,
                          finalAmount: _finalAmountController.text,
                          monthlyIncome: _monthlyIncomeController.text,
                          majorProblem: selectedMajorProblem ?? '',
                          majorRequirement: selectedMajorRequirement ?? '',
                          bookingDate: _bookingDateController.text,
                          freeTime: _freeTimeController.text,
                          cameWith: _cameWithController.text,
                          dob: _dobController.text,
                          religion: selectedReligion,
                          advisor: selectedAdvisor ?? '',
                          reachedBy: selectedReachedBy ?? '',
                          caller: selectedCaller ?? '', // <-- Yahan CP ka naam automatically save ho jayega DB me
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEditing ? 'Updated Successfully!' : 'Saved Successfully!')));
                        context.go('/dashboard');
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                      } finally {
                        if (mounted) setState(() => _isSaving = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B22)),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(isEditing ? 'UPDATE' : 'SUBMIT', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isRequired = false, IconData? suffixIcon, String? hintText, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label + (isRequired ? ' *' : ''), style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: controller, maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText ?? 'Enter $label',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: Colors.grey) : null,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFFF6B22))),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? selectedValue, Function(String?) onChanged, {bool isRequired = false}) {
    if (selectedValue != null && !items.contains(selectedValue)) items.add(selectedValue);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label + (isRequired ? ' *' : ''), style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87, fontSize: 13)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: selectedValue, icon: const Icon(Icons.arrow_drop_down),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFFF6B22))),
          ),
          items: items.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(fontSize: 14)))).toList(),
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
          color: isSelected ? const Color(0xFF4A90E2) : Colors.white,
          border: Border.all(color: isSelected ? const Color(0xFF4A90E2) : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text, style: TextStyle(fontSize: 13, color: isSelected ? Colors.white : Colors.black87)),
      ),
    );
    return expanded ? chip : IntrinsicWidth(child: chip);
  }
}