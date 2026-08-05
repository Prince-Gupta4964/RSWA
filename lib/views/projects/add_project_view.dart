import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../models/project_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/project_viewmodel.dart';
import '../../viewmodels/builder_viewmodel.dart';
import '../../viewmodels/cp_viewmodel.dart';
import '../../models/cp_model.dart';

class AddProjectView extends StatefulWidget {
  final ProjectModel? project;
  const AddProjectView({Key? key, this.project}) : super(key: key);

  @override
  State<AddProjectView> createState() => _AddProjectViewState();
}

class _AddProjectViewState extends State<AddProjectView> {
  int _currentStep = 0;
  bool _isSaving = false;
  bool _isLoadingOptions = true;
  String _loadingMessage = '';

  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];
  List<String> _existingImageUrls = [];

  Map<String, List<String>> dropdownOptions = {
    'legality': ['RERA Approved', 'Collector NA', 'Gram Panchayat', 'Under Approval'],
    'titleClear': ['Yes (Title Clear)', 'In Process', 'Leasehold Land'],
    'satbara': ['7/12 Available', 'Separate Satbara on Registry', 'NA Order Passed'],
    'naOrder': ['Collector NA', 'Town Planning (TP) Approved', 'NA Applied'],
    'parking': ['Covered Stilt Parking', 'Open Car Parking', 'Two-Wheeler Only', 'No Dedicated Parking'],
    'boundaryWall': ['Yes (Individual Fenced)', 'Common Boundary Wall', 'Pillars Demarcated', 'Open Land'],
    'roadAccess': ['30 ft Damar (Tar) Road', '20 ft Concrete Road', '40 ft Main Highway Touch', 'Paver Block Road'],
    'bungalowType': ['Independent Duplex', 'Twin Bungalow', 'Row House', 'Luxuriant Villa'],
    'privateGarden': ['Yes (Private Garden + Terrace)', 'Only Open Terrace', 'Front Porch Only', 'No'],
    'configType': ['1 BHK', '2 BHK', '3 BHK', 'Shop', 'Office Space'],
    'floorNumber': ['Ground Floor', '1st Floor', '2nd Floor', '3rd Floor', '4th Floor', '5th Floor'],
    'cpList': ['Direct / Walk-in'],
  };

  List<String> amenitiesOptions = ['Club House', 'Gymnasium', 'Swimming Pool', '24x7 Water Supply', 'Solar Power Backup', 'CCTV & Security'];
  List<String> selectedAmenities = [];
  List<String> selectedBuilderIds = [];
  String? selectedReferralCP = 'Direct / Walk-in';

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _reraCtrl = TextEditingController();
  final TextEditingController _locationCtrl = TextEditingController();
  String? selectedLegality = 'RERA Approved';
  String? titleClearStatus = 'Yes (Title Clear)';
  String? satbaraStatus = '7/12 Available';
  String? naOrder = 'Collector NA';
  String selectedType = 'Flat';
  String selectedCondition = 'New';
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _totalUnitsCtrl = TextEditingController();
  final TextEditingController _carpetAreaCtrl = TextEditingController();
  final TextEditingController _superBuiltUpCtrl = TextEditingController();
  final TextEditingController _bhkCtrl = TextEditingController();
  final TextEditingController _totalFloorsCtrl = TextEditingController();
  String? parkingType = 'Covered Stilt Parking';
  final TextEditingController _plotAreaCtrl = TextEditingController();
  final TextEditingController _fsiCtrl = TextEditingController();
  final TextEditingController _frontageCtrl = TextEditingController();
  String? boundaryWall = 'Yes (Individual Fenced)';
  String? roadAccess = '30 ft Damar (Tar) Road';
  final TextEditingController _landAreaCtrl = TextEditingController();
  final TextEditingController _constructionAreaCtrl = TextEditingController();
  String? bungalowType = 'Independent Duplex';
  String? privateGarden = 'Yes (Private Garden + Terrace)';
  String? configType;
  String? floorNumber;
  final TextEditingController _totalAreaCtrl = TextEditingController();
  final TextEditingController _usableAreaCtrl = TextEditingController();
  final TextEditingController _societyTitleCtrl = TextEditingController();
  final TextEditingController _ownerNameCtrl = TextEditingController();
  String? notaryStatus = 'Yes';
  List<String> selectedOcCc = [];
  final TextEditingController _contactPersonCtrl = TextEditingController();
  final TextEditingController _contactPhoneCtrl = TextEditingController();
  final TextEditingController _siteOfficeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedAmenities = ['Club House', '24x7 Water Supply', 'CCTV & Security'];
    _initializeData();
    _prePopulateEditData();
  }

  void _prePopulateEditData() {
    if (widget.project != null) {
      final project = widget.project!;
      final details = project.propertyDetails;
      _nameCtrl.text = project.projectName;
      _reraCtrl.text = project.reraId;
      _locationCtrl.text = details['location']?.toString() ?? '';
      selectedLegality = project.legality;
      selectedType = project.propertyType;
      _contactPersonCtrl.text = project.contactPerson;
      _contactPhoneCtrl.text = project.contactNumber;
      selectedBuilderIds = List<String>.from(project.builderIds);
      selectedCondition = details['condition']?.toString() ?? 'New';
      if (details['images'] != null) _existingImageUrls = List<String>.from(details['images']);
      String amenitiesStr = details['amenities']?.toString() ?? '';
      if (amenitiesStr.isNotEmpty) selectedAmenities = amenitiesStr.split(',').map((e) => e.trim()).toList();
      String priceStr = details['startingPrice']?.toString() ?? '';
      _priceCtrl.text = priceStr.replaceAll('₹', '').replaceAll('On Request', '').trim();
      titleClearStatus = details['titleClear']?.toString();
      satbaraStatus = details['satbara']?.toString();
      naOrder = details['naStatus']?.toString();
      _totalUnitsCtrl.text = details['totalUnits']?.toString() ?? '';
      configType = details['configType']?.toString();
      floorNumber = details['floorNumber']?.toString();
      _totalAreaCtrl.text = details['totalArea']?.toString().replaceAll('Sq.ft', '').trim() ?? '';
      _usableAreaCtrl.text = details['usableArea']?.toString().replaceAll('Sq.ft', '').trim() ?? '';
      _societyTitleCtrl.text = details['societyTitle']?.toString() ?? '';
      _ownerNameCtrl.text = details['ownerName']?.toString() ?? '';
      notaryStatus = details['notary']?.toString();
      selectedReferralCP = details['referralCP']?.toString();
      _bhkCtrl.text = details['bhk']?.toString() ?? '';
      _carpetAreaCtrl.text = details['carpetArea']?.toString().replaceAll('Sq.ft', '').trim() ?? '';
      _superBuiltUpCtrl.text = details['superBuiltUp']?.toString().replaceAll('Sq.ft', '').trim() ?? '';
      _totalFloorsCtrl.text = details['totalFloors']?.toString() ?? '';
      parkingType = details['parking']?.toString();
      _plotAreaCtrl.text = details['plotArea']?.toString().replaceAll('Sq.ft', '').trim() ?? '';
      _fsiCtrl.text = details['fsi']?.toString() ?? '';
      _frontageCtrl.text = details['roadFrontage']?.toString().replaceAll('Ft Road', '').trim() ?? '';
      boundaryWall = details['boundaryWall']?.toString();
      roadAccess = details['roadAccess']?.toString();
      _landAreaCtrl.text = details['plotLandArea']?.toString().replaceAll('Sq.ft', '').trim() ?? '';
      _constructionAreaCtrl.text = details['constructionArea']?.toString().replaceAll('Sq.ft', '').trim() ?? '';
      bungalowType = details['bungalowType']?.toString();
      privateGarden = details['privateGarden']?.toString();
    }
  }

  Future<void> _initializeData() async {
    await _fetchFormOptions();
    await _fetchCPList();
    if (mounted) setState(() => _isLoadingOptions = false);
  }

  Future<void> _fetchCPList() async {
    try {
      var snap = await FirebaseFirestore.instance.collection('cps').get();
      if (snap.docs.isNotEmpty) {
        setState(() {
          for (var doc in snap.docs) {
            var data = doc.data();
            String cpName = data['cpName']?.toString() ?? '';
            if (cpName.trim().isNotEmpty && !dropdownOptions['cpList']!.contains(cpName.trim())) dropdownOptions['cpList']!.add(cpName.trim());
          }
        });
      }
    } catch (e) { debugPrint("Error fetching CPs: $e"); }
  }

  Future<void> _fetchFormOptions() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('app_settings').doc('project_form').get();
      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        if (data['dropdowns'] != null) {
          Map<String, dynamic> dbDropdowns = data['dropdowns'];
          dbDropdowns.forEach((key, value) {
            if (dropdownOptions.containsKey(key)) {
              if (key == 'cpList') return;
              dropdownOptions[key] = List<String>.from(value).toSet().toList();
            }
          });
        }
        if (data['amenities'] != null) amenitiesOptions = List<String>.from(data['amenities']).toSet().toList();
      }
    } catch (e) { debugPrint("Error loading options: $e"); }
  }

  Future<void> _pickImages() async {
    try {
      final pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isNotEmpty) setState(() => _selectedImages.addAll(pickedFiles));
    } catch (e) { debugPrint("Error picking images: $e"); }
  }

  Future<void> _saveNewDropdownOption(String fieldKey, String newValue) async {
    setState(() { if (!dropdownOptions[fieldKey]!.contains(newValue)) dropdownOptions[fieldKey]!.add(newValue); });
    if (fieldKey == 'cpList') return;
    await FirebaseFirestore.instance.collection('app_settings').doc('project_form').set({ 'dropdowns': { fieldKey: FieldValue.arrayUnion([newValue]), }, }, SetOptions(merge: true));
  }

  Future<void> _saveNewAmenity(String newValue) async {
    setState(() {
      if (!amenitiesOptions.contains(newValue)) amenitiesOptions.add(newValue);
      if (!selectedAmenities.contains(newValue)) selectedAmenities.add(newValue);
    });
    await FirebaseFirestore.instance.collection('app_settings').doc('project_form').set({ 'amenities': FieldValue.arrayUnion([newValue]), }, SetOptions(merge: true));
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _reraCtrl.dispose(); _locationCtrl.dispose(); _priceCtrl.dispose(); _totalUnitsCtrl.dispose(); _carpetAreaCtrl.dispose(); _superBuiltUpCtrl.dispose(); _bhkCtrl.dispose(); _totalFloorsCtrl.dispose(); _plotAreaCtrl.dispose(); _fsiCtrl.dispose(); _frontageCtrl.dispose(); _landAreaCtrl.dispose(); _constructionAreaCtrl.dispose(); _contactPersonCtrl.dispose(); _contactPhoneCtrl.dispose(); _siteOfficeCtrl.dispose(); _totalAreaCtrl.dispose(); _usableAreaCtrl.dispose(); _societyTitleCtrl.dispose(); _ownerNameCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0 && _nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Project Name')));
      return;
    }
    if (_currentStep < 2) setState(() => _currentStep++);
    else _saveProject();
  }

  void _prevStep() { if (_currentStep > 0) setState(() => _currentStep--); else context.pop(); }

  Future<void> _saveProject() async {
    if (_contactPersonCtrl.text.isEmpty || _contactPhoneCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Contact Person details')));
      return;
    }
    setState(() { _isSaving = true; _loadingMessage = 'Saving...'; });
    try {
      final authVM = Provider.of<AuthViewModel>(context, listen: false);
      List<String> finalImageUrls = List.from(_existingImageUrls);
      const String gasUrl = 'https://script.google.com/macros/s/AKfycbwRwtSdKzqAVcq_Myu7q2P22B10Lh6FWzcFpmTURfUOoWaAd_uvGd0459hgaRG_jAnpXg/exec';
      for (int i = 0; i < _selectedImages.length; i++) {
        List<int> imageBytes = await _selectedImages[i].readAsBytes();
        String base64Image = base64Encode(imageBytes);
        String fileName = '${DateTime.now().millisecondsSinceEpoch}_${_selectedImages[i].name}';
        var response = await http.post(Uri.parse(gasUrl), body: { "name": fileName, "mimeType": "image/jpeg", "image": base64Image });
        if (response.statusCode == 200 || response.statusCode == 302) {
          var responseData = jsonDecode(response.body);
          String uploadedUrl = responseData['url'] ?? responseData['link'] ?? '';
          if (uploadedUrl.isNotEmpty) finalImageUrls.add(uploadedUrl);
        }
      }
      Map<String, dynamic> dynamicData = { 'condition': selectedCondition, 'location': _locationCtrl.text, 'amenities': selectedAmenities.join(', '), 'images': finalImageUrls };
      if (selectedCondition == 'Resale' && selectedType != 'Plot') {
        dynamicData.addAll({ 'startingPrice': _priceCtrl.text.isEmpty ? 'On Request' : '₹${_priceCtrl.text}', 'configType': configType ?? 'N/A', 'totalArea': '${_totalAreaCtrl.text} Sq.ft', 'usableArea': '${_usableAreaCtrl.text} Sq.ft', 'builtUpArea': '${_superBuiltUpCtrl.text} Sq.ft', 'carpetArea': '${_carpetAreaCtrl.text} Sq.ft', 'oc_cc_status': selectedOcCc.join(', '), 'societyTitle': _societyTitleCtrl.text, 'notary': notaryStatus ?? 'N/A', 'floorNumber': floorNumber ?? 'N/A', 'ownerName': _ownerNameCtrl.text, 'referralCP': selectedReferralCP ?? 'N/A' });
      } else {
        dynamicData.addAll({ 'totalUnits': _totalUnitsCtrl.text.isEmpty ? 'N/A' : _totalUnitsCtrl.text, 'startingPrice': _priceCtrl.text.isEmpty ? 'On Request' : '₹${_priceCtrl.text}', 'titleClear': titleClearStatus ?? 'N/A', 'satbara': satbaraStatus ?? 'N/A', 'naStatus': naOrder ?? 'N/A' });
        if (selectedType == 'Flat' || selectedType == 'Shop') {
          dynamicData.addAll({ 'bhk': _bhkCtrl.text, 'carpetArea': '${_carpetAreaCtrl.text} Sq.ft', 'superBuiltUp': '${_superBuiltUpCtrl.text} Sq.ft', 'totalFloors': _totalFloorsCtrl.text, 'parking': parkingType ?? 'N/A' });
        } else if (selectedType == 'Plot') {
          dynamicData.addAll({ 'plotArea': '${_plotAreaCtrl.text} Sq.ft', 'fsi': _fsiCtrl.text.isEmpty ? '1.4 Standard' : _fsiCtrl.text, 'roadFrontage': '${_frontageCtrl.text} Ft Road', 'boundaryWall': boundaryWall ?? 'N/A', 'roadAccess': roadAccess ?? 'N/A' });
        } else if (selectedType == 'Bungalow') {
          dynamicData.addAll({ 'bungalowType': bungalowType ?? 'N/A', 'plotLandArea': '${_landAreaCtrl.text} Sq.ft', 'constructionArea': '${_constructionAreaCtrl.text} Sq.ft', 'privateGarden': privateGarden ?? 'N/A', 'bhk': _bhkCtrl.text });
        }
      }
      await Provider.of<ProjectViewModel>(context, listen: false).addOrUpdateProject( id: widget.project?.id, projectName: _nameCtrl.text, reraId: _reraCtrl.text.isEmpty ? 'Applied / N/A' : _reraCtrl.text, legality: selectedLegality ?? 'N/A', propertyType: selectedType, contactPerson: _contactPersonCtrl.text, contactNumber: _contactPhoneCtrl.text, propertyDetails: dynamicData, builderIds: selectedBuilderIds, actorUid: authVM.userUid, actorEmail: authVM.userEmail, actorName: authVM.userName, actorRole: authVM.roleLabel );
      if (!mounted) return;
      context.pop(true);
    } catch (e) { debugPrint("Error: $e"); } finally { if (mounted) setState(() => _isSaving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar( backgroundColor: Colors.white, elevation: 0, leading: IconButton( icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20), onPressed: _prevStep ), title: Text( widget.project != null ? 'Edit Property' : 'Add Property', style: const TextStyle( color: Colors.black, fontWeight: FontWeight.w900, fontSize: 20 ) ), centerTitle: true ),
      body: Stack( children: [ _isLoadingOptions ? const Center( child: CircularProgressIndicator(color: Color(0xFFFF6B22)) ) : Column( children: [ _buildCustomStepperHeader(), Expanded( child: SingleChildScrollView( padding: const EdgeInsets.symmetric( horizontal: 16.0, vertical: 12.0 ), child: _buildStepContent() ) ), _buildBottomNavButtons() ] ), if (_isSaving) Container( color: Colors.black54, child: Center( child: Container( padding: const EdgeInsets.all(24), decoration: BoxDecoration( color: Colors.white, borderRadius: BorderRadius.circular(16) ), child: Column( mainAxisSize: MainAxisSize.min, children: [ const CircularProgressIndicator(color: Color(0xFFFF6B22)), const SizedBox(height: 16), Text( _loadingMessage, style: const TextStyle(fontWeight: FontWeight.bold) ) ] ) ) ) ) ] )
    );
  }

  Widget _buildCustomStepperHeader() {
    return Container( padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24), decoration: BoxDecoration( color: Colors.white, boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2) ) ] ), child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ _stepIndicator(0, 'Overview', Icons.info_outline), _stepLine(0), _stepIndicator(1, 'Details', Icons.architecture), _stepLine(1), _stepIndicator(2, 'Contact', Icons.support_agent) ] ) );
  }

  Widget _stepIndicator(int stepIndex, String title, IconData icon) {
    bool isActive = _currentStep == stepIndex, isDone = _currentStep > stepIndex;
    Color color = isActive || isDone ? const Color(0xFFFF6B22) : Colors.grey.shade400;
    return Column( children: [ CircleAvatar( radius: 18, backgroundColor: isActive ? const Color(0xFFFF6B22) : (isDone ? const Color(0xFFFF6B22).withOpacity(0.1) : Colors.grey.shade100), child: isDone ? const Icon(Icons.check, color: Color(0xFFFF6B22), size: 18) : Icon( icon, color: isActive ? Colors.white : Colors.grey.shade400, size: 18 ) ), const SizedBox(height: 8), Text( title, style: TextStyle( fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.w600, color: color ) ) ] );
  }

  Widget _stepLine(int stepIndex) { return Expanded( child: Container( height: 2, margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 15), color: _currentStep > stepIndex ? const Color(0xFFFF6B22) : Colors.grey.shade200 ) ); }

  Widget _buildBottomNavButtons() {
    return Container( padding: const EdgeInsets.all(16), decoration: BoxDecoration( color: Colors.white, boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5) ) ] ), child: Row( children: [ Expanded( flex: 1, child: SizedBox( height: 50, child: OutlinedButton( onPressed: _prevStep, style: OutlinedButton.styleFrom( side: const BorderSide(color: Color(0xFFFF6B22)), shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(12) ) ), child: Text( _currentStep == 0 ? 'CANCEL' : 'BACK', style: const TextStyle( color: Color(0xFFFF6B22), fontWeight: FontWeight.bold ) ) ) ) ), const SizedBox(width: 16), Expanded( flex: 2, child: SizedBox( height: 50, child: ElevatedButton( onPressed: _isSaving ? null : _nextStep, style: ElevatedButton.styleFrom( backgroundColor: const Color(0xFFFF6B22), shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(12) ), elevation: 0 ), child: Text( _currentStep == 2 ? 'SUBMIT' : 'SAVE & NEXT', style: const TextStyle( color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16 ) ) ) ) ) ] ) );
  }

  Widget _buildStepContent() {
    if (_currentStep == 0) {
      return Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildCardSection( title: '1. Property Type', child: SingleChildScrollView( scrollDirection: Axis.horizontal, child: Row( children: ['Flat', 'Plot', 'Bungalow', 'Shop'].map((type) => Padding( padding: const EdgeInsets.only(right: 8), child: _buildModernChip(type, selectedType, (val) { setState(() { selectedType = val; if (val == 'Plot') selectedCondition = 'New'; }); })), ).toList() ) ) ),
        if (selectedType != 'Plot') _buildCardSection( title: '2. Property Condition', child: Row( children: ['New', 'Resale'].map((cond) => Expanded( child: Padding( padding: const EdgeInsets.symmetric(horizontal: 4), child: _buildModernChip( cond, selectedCondition, (val) => setState(() => selectedCondition = val), expanded: true ) ) ), ).toList() ) ),
        _buildCardSection( title: '3. Basic Information', child: Column( children: [ _buildModernTextField( 'Project/Property Name', _nameCtrl, isRequired: true, icon: Icons.business ), const SizedBox(height: 16), _buildModernTextField( 'Site Location / City Area', _locationCtrl, icon: Icons.location_on_outlined ), const SizedBox(height: 16), _buildBuilderSelection() ] ) ),
        _buildCardSection( title: '4. Property Images', child: _buildImagePickerUI() ),
        if (selectedCondition == 'New') _buildCardSection( title: '5. Legal & Trust Parameters', child: Column( children: [ _buildModernTextField( 'RERA Registration ID', _reraCtrl, hintText: 'Leave empty if applied', icon: Icons.verified_user_outlined ), const SizedBox(height: 16), _buildModernDropdown( 'Legality Status', 'legality', selectedLegality, (val) => setState(() => selectedLegality = val) ), const SizedBox(height: 16), _buildModernDropdown( 'Title Clear Status', 'titleClear', titleClearStatus, (val) => setState(() => titleClearStatus = val) ), const SizedBox(height: 16), _buildModernDropdown( '7/12 (Satbara) Status', 'satbara', satbaraStatus, (val) => setState(() => satbaraStatus = val) ), const SizedBox(height: 16), _buildModernDropdown( 'NA (Non-Agricultural)', 'naOrder', naOrder, (val) => setState(() => naOrder = val) ) ] ) )
      ]);
    } else if (_currentStep == 1) {
      return _buildCardSection( title: 'Configuration: ${selectedType.toUpperCase()} ${selectedCondition == 'Resale' ? '(RESALE)' : '(NEW)'}', child: Column( children: [
        if (selectedCondition == 'Resale' && selectedType != 'Plot') _buildResaleConfig() else ...[ Row( children: [ Expanded( child: _buildModernTextField( 'Total Units', _totalUnitsCtrl, keyboardType: TextInputType.number ) ), const SizedBox(width: 12), Expanded( child: _buildModernTextField('Price (₹)', _priceCtrl) ) ] ), const SizedBox(height: 20), if (selectedType == 'Flat' || selectedType == 'Shop') _buildFlatConfig(), if (selectedType == 'Plot') _buildPlotConfig(), if (selectedType == 'Bungalow') _buildBungalowConfig() ]
      ]));
    } else {
      return Column( children: [
        _buildCardSection( title: '1. Amenities & Facilities', child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text( 'Select amenities to highlight for the client.', style: TextStyle(color: Colors.grey.shade500, fontSize: 12) ), const SizedBox(height: 12), _buildDynamicAmenities() ] ) ),
        _buildCardSection( title: '2. Contact Details', child: Column( children: [
          Consumer<CPViewModel>( builder: (context, cpVM, child) { return _buildSearchableCPSelector(cpVM); } ),
          const SizedBox(height: 16),
          _buildModernTextField( 'Contact Mobile Number', _contactPhoneCtrl, isRequired: true, keyboardType: TextInputType.phone, icon: Icons.phone_outlined ),
          const SizedBox(height: 16),
          _buildModernTextField( 'Office Address (Optional)', _siteOfficeCtrl, icon: Icons.store_outlined )
        ]))
      ]);
    }
  }

  Widget _buildImagePickerUI() {
    return Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell( onTap: _pickImages, child: Container( width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 20), decoration: BoxDecoration( color: Colors.grey.shade50, border: Border.all( color: const Color(0xFFFF6B22).withOpacity(0.5), style: BorderStyle.solid ), borderRadius: BorderRadius.circular(12) ), child: Column( children: [ const Icon( Icons.add_a_photo_outlined, color: Color(0xFFFF6B22), size: 32 ), const SizedBox(height: 8), Text( 'Tap to select multiple photos', style: TextStyle( color: Colors.grey.shade700, fontWeight: FontWeight.bold ) ) ] ) ) ),
      if (_existingImageUrls.isNotEmpty || _selectedImages.isNotEmpty) ...[ const SizedBox(height: 16), SizedBox( height: 90, child: ListView( scrollDirection: Axis.horizontal, children: [ ..._existingImageUrls.asMap().entries.map((entry) { int idx = entry.key; String url = entry.value; return _buildImageThumbnail( imageWidget: Image.network(url, fit: BoxFit.cover), onRemove: () => setState(() => _existingImageUrls.removeAt(idx)) ); }).toList(), ..._selectedImages.asMap().entries.map((entry) { int idx = entry.key; XFile file = entry.value; return _buildImageThumbnail( imageWidget: kIsWeb ? Image.network(file.path, fit: BoxFit.cover) : Image.file(File(file.path), fit: BoxFit.cover), onRemove: () => setState(() => _selectedImages.removeAt(idx)) ); }).toList() ] ) ) ]
    ]);
  }

  Widget _buildImageThumbnail({ required Widget imageWidget, required VoidCallback onRemove }) {
    return Container( margin: const EdgeInsets.only(right: 12), width: 90, height: 90, child: Stack( children: [ ClipRRect( borderRadius: BorderRadius.circular(8), child: SizedBox(width: 90, height: 90, child: imageWidget) ), Positioned( top: 4, right: 4, child: GestureDetector( onTap: onRemove, child: Container( padding: const EdgeInsets.all(4), decoration: const BoxDecoration( color: Colors.black54, shape: BoxShape.circle ), child: const Icon(Icons.close, color: Colors.white, size: 14) ) ) ) ] ) );
  }

  Widget _buildResaleConfig() {
    return Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildModernDropdown( 'Configuration Type', 'configType', configType, (val) => setState(() => configType = val) ), const SizedBox(height: 16),
      Row( children: [ Expanded( child: _buildModernTextField('Total Area', _totalAreaCtrl) ), const SizedBox(width: 12), Expanded( child: _buildModernTextField('Usable Area', _usableAreaCtrl) ) ] ), const SizedBox(height: 16),
      Row( children: [ Expanded( child: _buildModernTextField('Build Up Area', _superBuiltUpCtrl) ), const SizedBox(width: 12), Expanded( child: _buildModernTextField('Carpet Area', _carpetAreaCtrl) ) ] ), const SizedBox(height: 16),
      const Text( 'OC / CC Status', style: TextStyle( fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87 ) ), const SizedBox(height: 8),
      Wrap( spacing: 10, children: ['OC', 'CC'].map((status) { bool isSelected = selectedOcCc.contains(status); return FilterChip( label: Text( status, style: TextStyle( color: isSelected ? Colors.white : Colors.black87 ) ), selected: isSelected, selectedColor: const Color(0xFFFF6B22), checkmarkColor: Colors.transparent, backgroundColor: Colors.grey.shade50, shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(12), side: BorderSide( color: isSelected ? const Color(0xFFFF6B22) : Colors.grey.shade300 ) ), onSelected: (val) => setState(() { val ? selectedOcCc.add(status) : selectedOcCc.remove(status); }) ); }).toList() ), const SizedBox(height: 16),
      _buildModernTextField('Society Title', _societyTitleCtrl), const SizedBox(height: 16),
      const Text( 'Notary Done?', style: TextStyle( fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87 ) ), const SizedBox(height: 8),
      DropdownButtonFormField<String>( value: notaryStatus, icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey), decoration: InputDecoration( contentPadding: const EdgeInsets.symmetric( horizontal: 16, vertical: 14 ), filled: true, fillColor: Colors.grey.shade50, enabledBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200) ), focusedBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12), borderSide: const BorderSide( color: Color(0xFFFF6B22), width: 1.5 ) ) ), items: ['Yes', 'No', 'In Process'].map((e) => DropdownMenuItem( value: e, child: Text(e, style: const TextStyle(fontSize: 14)) )).toList(), onChanged: (val) => setState(() => notaryStatus = val) ), const SizedBox(height: 16),
      _buildModernDropdown( 'Floor Number', 'floorNumber', floorNumber, (val) => setState(() => floorNumber = val) ), const SizedBox(height: 16),
      _buildModernTextField('Owner Name', _ownerNameCtrl, icon: Icons.person), const SizedBox(height: 16),
      _buildModernDropdown( 'Referral Name (CP)', 'cpList', selectedReferralCP, (val) => setState(() => selectedReferralCP = val) ), const SizedBox(height: 16),
      _buildModernTextField( 'Resale Price (₹)', _priceCtrl, isRequired: true, icon: Icons.currency_rupee )
    ]);
  }

  Widget _buildFlatConfig() { return Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ _buildModernTextField('Configurations Available', _bhkCtrl), const SizedBox(height: 16), Row( children: [ Expanded( child: _buildModernTextField('Carpet Area', _carpetAreaCtrl) ), const SizedBox(width: 12), Expanded( child: _buildModernTextField('Super Built-up', _superBuiltUpCtrl) ) ] ), const SizedBox(height: 16), _buildModernTextField('Total Floors', _totalFloorsCtrl), const SizedBox(height: 16), _buildModernDropdown( 'Parking Facility', 'parking', parkingType, (val) => setState(() => parkingType = val) ) ]); }
  Widget _buildPlotConfig() { return Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ _buildModernTextField('Plot Sizes Available', _plotAreaCtrl), const SizedBox(height: 16), Row( children: [ Expanded(child: _buildModernTextField('FSI', _fsiCtrl)), const SizedBox(width: 12), Expanded( child: _buildModernTextField('Road Frontage', _frontageCtrl) ) ] ), const SizedBox(height: 16), _buildModernDropdown( 'Boundary Wall', 'boundaryWall', boundaryWall, (val) => setState(() => boundaryWall = val) ), const SizedBox(height: 16), _buildModernDropdown( 'Road Access', 'roadAccess', roadAccess, (val) => setState(() => roadAccess = val) ) ]); }
  Widget _buildBungalowConfig() { return Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ _buildModernDropdown( 'Bungalow Type', 'bungalowType', bungalowType, (val) => setState(() => bungalowType = val) ), const SizedBox(height: 16), _buildModernTextField('BHK Layout', _bhkCtrl), const SizedBox(height: 16), Row( children: [ Expanded( child: _buildModernTextField('Plot Land Area', _landAreaCtrl) ), const SizedBox(width: 12), Expanded( child: _buildModernTextField( 'Construction Area', _constructionAreaCtrl ) ) ] ), const SizedBox(height: 16), _buildModernDropdown( 'Private Garden', 'privateGarden', privateGarden, (val) => setState(() => privateGarden = val) ) ]); }

  Widget _buildCardSection({required String title, required Widget child}) { return Container( margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(20), decoration: BoxDecoration( color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4) ) ] ), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text( title, style: const TextStyle( fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87 ) ), const SizedBox(height: 16), child ] ) ); }
  Widget _buildModernTextField( String label, TextEditingController controller, { bool isRequired = false, String? hintText, TextInputType keyboardType = TextInputType.text, IconData? icon }) { return Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text( label + (isRequired ? ' *' : ''), style: const TextStyle( fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87 ) ), const SizedBox(height: 8), TextField( controller: controller, keyboardType: keyboardType, style: const TextStyle(fontSize: 14), decoration: InputDecoration( hintText: hintText, prefixIcon: icon != null ? Icon(icon, color: Colors.grey.shade400, size: 20) : null, contentPadding: const EdgeInsets.symmetric( horizontal: 16, vertical: 14 ), filled: true, fillColor: Colors.grey.shade50, enabledBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200) ), focusedBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12), borderSide: const BorderSide( color: Color(0xFFFF6B22), width: 1.5 ) ) ) ) ] ); }
  Widget _buildModernChip( String text, String selectedValue, Function(String) onTap, { bool expanded = false }) { bool isSelected = selectedValue == text; Widget chip = GestureDetector( onTap: () => onTap(text), child: AnimatedContainer( duration: const Duration(milliseconds: 200), alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), decoration: BoxDecoration( color: isSelected ? const Color(0xFFFF6B22) : Colors.grey.shade50, border: Border.all( color: isSelected ? const Color(0xFFFF6B22) : Colors.grey.shade200 ), borderRadius: BorderRadius.circular(12) ), child: Text( text, style: TextStyle( fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: isSelected ? Colors.white : Colors.black87 ) ) ) ); return expanded ? chip : IntrinsicWidth(child: chip); }
  Widget _buildModernDropdown( String label, String fieldKey, String? selectedValue, Function(String) onChanged ) { List<String> options = List.from(dropdownOptions[fieldKey] ?? []); if (selectedValue != null && !options.contains(selectedValue) && selectedValue != '➕ Add New') options.add(selectedValue); options = options.toSet().toList(); options.add('➕ Add New'); return Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text( label, style: const TextStyle( fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87 ) ), const SizedBox(height: 8), DropdownButtonFormField<String>( value: selectedValue != null && options.contains(selectedValue) ? selectedValue : null, icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey), decoration: InputDecoration( contentPadding: const EdgeInsets.symmetric( horizontal: 16, vertical: 14 ), filled: true, fillColor: Colors.grey.shade50, enabledBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200) ), focusedBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(12), borderSide: const BorderSide( color: Color(0xFFFF6B22), width: 1.5 ) ) ), items: options .map( (String value) => DropdownMenuItem<String>( value: value, child: Text( value, style: TextStyle( fontSize: 14, color: value == '➕ Add New' ? const Color(0xFFFF6B22) : Colors.black87, fontWeight: value == '➕ Add New' ? FontWeight.bold : FontWeight.normal ), maxLines: 1, overflow: TextOverflow.ellipsis ) ) ) .toList(), onChanged: (val) { if (val == '➕ Add New') { _showAddNewOptionDialog(label, fieldKey, onChanged); } else if (val != null) { onChanged(val); } } ) ] ); }
  void _showAddNewOptionDialog( String label, String fieldKey, Function(String) onSelected ) { TextEditingController newOptionCtrl = TextEditingController(); showDialog( context: context, builder: (context) { return AlertDialog( shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(16) ), title: Text( 'Add New $label', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold) ), content: TextField( controller: newOptionCtrl, decoration: InputDecoration( hintText: 'Type new option here...', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder( borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none ) ) ), actions: [ TextButton( onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey)) ), ElevatedButton( onPressed: () async { if (newOptionCtrl.text.trim().isNotEmpty) { String newVal = newOptionCtrl.text.trim(); await _saveNewDropdownOption(fieldKey, newVal); onSelected(newVal); if (context.mounted) Navigator.pop(context); } }, style: ElevatedButton.styleFrom( backgroundColor: const Color(0xFFFF6B22), shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(8) ) ), child: const Text( 'Save & Select', style: TextStyle(color: Colors.white) ) ) ] ); } ); }
  Widget _buildDynamicAmenities() { return Wrap( spacing: 8, runSpacing: 8, children: [ ...amenitiesOptions.map((amenity) { bool isSelected = selectedAmenities.contains(amenity); return FilterChip( label: Text( amenity, style: TextStyle( fontSize: 12, color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500 ) ), selected: isSelected, selectedColor: const Color(0xFFFF6B22), checkmarkColor: Colors.transparent, backgroundColor: Colors.grey.shade50, shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(12), side: BorderSide( color: isSelected ? const Color(0xFFFF6B22) : Colors.grey.shade200 ) ), onSelected: (bool selected) { setState(() { selected ? selectedAmenities.add(amenity) : selectedAmenities.remove(amenity); }); } ); }).toList(), ActionChip( label: const Text( '➕ Add New', style: TextStyle( fontSize: 12, color: Color(0xFFFF6B22), fontWeight: FontWeight.bold ) ), backgroundColor: Colors.white, shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFFF6B22)) ), onPressed: _showAddAmenityDialog ) ] ); }
  void _showAddAmenityDialog() { TextEditingController newAmenityCtrl = TextEditingController(); showDialog( context: context, builder: (context) { return AlertDialog( shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(16) ), title: const Text( 'Add New Amenity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold) ), content: TextField( controller: newAmenityCtrl, decoration: InputDecoration( hintText: 'e.g. Indoor Games / Jacuzzi', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder( borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none ) ) ), actions: [ TextButton( onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey)) ), ElevatedButton( onPressed: () async { if (newAmenityCtrl.text.isNotEmpty) { await _saveNewAmenity(newAmenityCtrl.text.trim()); if (context.mounted) Navigator.pop(context); } }, style: ElevatedButton.styleFrom( backgroundColor: const Color(0xFFFF6B22), shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(8) ) ), child: const Text( 'Save & Select', style: TextStyle(color: Colors.white) ) ) ] ); } ); }
  Widget _buildBuilderSelection() { final builderVM = Provider.of<BuilderViewModel>(context); final selectedBuilders = builderVM.builders.where((b) => selectedBuilderIds.contains(b.id)).toList(); return Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ const Text( 'Associated Builders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87) ), IconButton( onPressed: () => context.push('/add-builder'), icon: const Icon(Icons.add_circle_outline, color: Color(0xFFFF6B22), size: 20), tooltip: 'Add New Builder', constraints: const BoxConstraints(), padding: EdgeInsets.zero ) ] ), const SizedBox(height: 8), InkWell( onTap: () => _showBuilderSelectionSheet(builderVM), child: Container( padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration( color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200) ), child: Row( children: [ Expanded( child: Text( selectedBuilders.isEmpty ? 'Select Builders' : '${selectedBuilders.length} Builders Selected (${selectedBuilders.map((b) => b.name).join(', ')})', style: TextStyle( color: selectedBuilders.isEmpty ? Colors.grey.shade500 : Colors.black87, fontSize: 14 ), maxLines: 1, overflow: TextOverflow.ellipsis ) ), const Icon(Icons.arrow_drop_down, color: Colors.grey) ] ) ) ) ] ); }
  void _showBuilderSelectionSheet(BuilderViewModel builderVM) { showModalBottomSheet( context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) { return StatefulBuilder( builder: (context, setSheetState) { return Padding( padding: const EdgeInsets.all(20), child: Column( mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [ Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ const Text('Select Builders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), TextButton.icon( onPressed: () => context.push('/add-builder'), icon: const Icon(Icons.add, size: 18, color: Color(0xFFFF6B22)), label: const Text('New Builder', style: TextStyle(color: Color(0xFFFF6B22), fontWeight: FontWeight.bold)) ) ] ), const SizedBox(height: 16), if (builderVM.builders.isEmpty) const Padding( padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Text('No builders found.')) ) else Flexible( child: ListView.builder( shrinkWrap: true, itemCount: builderVM.builders.length, itemBuilder: (context, index) { final builder = builderVM.builders[index]; final isSelected = selectedBuilderIds.contains(builder.id); return CheckboxListTile( title: Text(builder.name), subtitle: Text(builder.companyName), activeColor: const Color(0xFFFF6B22), value: isSelected, onChanged: (val) { setSheetState(() { if (val == true) selectedBuilderIds.add(builder.id); else selectedBuilderIds.remove(builder.id); }); setState(() {}); } ); } ) ), const SizedBox(height: 16), SizedBox( width: double.infinity, height: 50, child: ElevatedButton( onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B22)), child: const Text('DONE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) ) ) ] ) ); } ); } ); }

  Widget _buildSearchableCPSelector(CPViewModel cpVM) { return Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ const Text( 'Contact Person (CP) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87) ), const SizedBox(height: 8), InkWell( onTap: () => _showCPSearchDialog(cpVM), child: Container( padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration( color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200) ), child: Row( children: [ Expanded( child: Text( _contactPersonCtrl.text.isEmpty ? 'Tap to select CP...' : _contactPersonCtrl.text, style: TextStyle(color: _contactPersonCtrl.text.isEmpty ? Colors.grey.shade500 : Colors.black87, fontSize: 14) ) ), const Icon(Icons.search, color: Colors.grey) ] ) ) ) ] ); }
  void _showCPSearchDialog(CPViewModel cpVM) { TextEditingController searchCtrl = TextEditingController(); List<CPModel> filteredCPs = List.from(cpVM.cps); showDialog( context: context, builder: (context) { return StatefulBuilder( builder: (context, setDialogState) { return AlertDialog( title: const Text('Select Contact Person'), content: Column( mainAxisSize: MainAxisSize.min, children: [ TextField( controller: searchCtrl, decoration: const InputDecoration(hintText: 'Search CP by name...', prefixIcon: Icon(Icons.search)), onChanged: (val) => setDialogState(() => filteredCPs = cpVM.cps.where((cp) => cp.cpName.toLowerCase().contains(val.toLowerCase())).toList()) ), const SizedBox(height: 12), SizedBox( height: 250, width: double.maxFinite, child: filteredCPs.isEmpty ? const Center(child: Text('No CPs found.')) : ListView.builder( itemCount: filteredCPs.length, itemBuilder: (context, index) { final cp = filteredCPs[index]; return ListTile( title: Text(cp.cpName), subtitle: Text(cp.contactNo), onTap: () { setState(() { _contactPersonCtrl.text = cp.cpName; _contactPhoneCtrl.text = cp.contactNo; }); Navigator.pop(context); } ); } ) ) ] ), actions: [ TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')) ] ); } ); } ); }
}
