import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/project_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/project_viewmodel.dart';
import '../../viewmodels/builder_viewmodel.dart';
import '../../viewmodels/lead_viewmodel.dart';
import '../../viewmodels/cp_viewmodel.dart';
import '../../viewmodels/app_configuration_viewmodel.dart';
import '../../utils/project_form_config.dart';
import '../../utils/role_permissions.dart';
import '../../services/firebase_storage_service.dart';
import '../../services/youtube_upload_service.dart';

class AddProjectView extends StatefulWidget {
  final ProjectModel? project;
  const AddProjectView({super.key, this.project});

  @override
  State<AddProjectView> createState() => _AddProjectViewState();
}

class _AddProjectViewState extends State<AddProjectView> {
  static const Color primaryColor = Color(0xFFFBE64E);
  static const Color secondaryColor = Color(0xFF6B5800);

  final Map<String, dynamic> _formData = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, LayerLink> _layerLinks = {};
  final Map<String, bool> _openDropdowns = {};

  final Map<String, List<dynamic>> _pickedMediaLists = {}; 
  final Map<String, dynamic> _pickedFiles = {}; 
  final List<Map<String, dynamic>> _customAttachmentRows = []; // 🚀 NAYA: Dynamic "Others" Attachments

  final List<String> _expandedSections = [
    ProjectFormStrings.sectionBasicInfo,
  ];
  String _currentFocusedId = '';
  bool _isSaving = false;
  String _loadingMessage = '';

  List<String> _selectedBuilderIds = [];
  final List<String> _pendingBuilderNames = []; // 🚀 Staged new builder names
  final List<String> _flatFields = ['flatNo', 'buildingName', 'areaName', 'nearby', 'opposite', 'road'];
  final ScrollController _scrollController = ScrollController();
  final Map<String, int> _activeChipIndex = {};
  final Map<String, GlobalKey> _sectionKeys = {}; // 🚀 NAYA

  @override
  void initState() {
    super.initState();
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    if (authVM.appRole == AppRole.cp && !authVM.isApproved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your account is pending admin approval.'), backgroundColor: Colors.red),
          );
          context.go('/dashboard');
        }
      });
      return;
    }

    if (widget.project != null) {
      _formData.addAll(widget.project!.rawData);
      if (widget.project!.propertyDetails.isNotEmpty) {
        _formData.addAll(widget.project!.propertyDetails);
      }
    }

    _formData['isReraApproved'] = _formData['isReraApproved'] ?? 'No';
    _formData['isTitleClear'] = _formData['isTitleClear'] ?? 'No';
    _formData['isLegallyVerified'] = _formData['isLegallyVerified'] ?? 'No';
    
    if (widget.project == null) {
      _formData['isApproved'] = 'No';
    } else {
      _formData['isApproved'] = _formData['isApproved'] ?? 'No';
    }
    
    _formData['alreadyExists'] = _formData['alreadyExists'] ?? 'No';
    _formData['likeButton'] = _formData['likeButton'] == true;
    _formData['adminRating'] = int.tryParse(_formData['adminRating']?.toString() ?? '0') ?? 0;
    _formData['peopleRating'] = int.tryParse(_formData['peopleRating']?.toString() ?? '0') ?? 0;
    _selectedBuilderIds = List<String>.from(_formData['builderIds'] ?? []);

    // 🚀 NAYA: Initialize custom attachments
    if (_formData['otherAttachments'] is List) {
      final list = _formData['otherAttachments'] as List;
      for (var item in list) {
        if (item is Map) {
          final title = (item['title'] ?? '').toString();
          final url = (item['url'] ?? item['file'] ?? '').toString();
          _customAttachmentRows.add({
            'titleCtrl': TextEditingController(text: title),
            'file': null,
            'existingUrl': url.isNotEmpty ? url : null,
          });
        }
      }
    }
    if (_customAttachmentRows.isEmpty) {
      _customAttachmentRows.add({
        'titleCtrl': TextEditingController(),
        'file': null,
        'existingUrl': null,
      });
    }

    _initializeAllControllers(_formData);

    if (widget.project == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToField('propertyName');
      });
    }
  }

  void _initializeAllControllers(Map<String, dynamic> data) {
    for (var section in ProjectFormStrings.formStructure) {
      _initFields(section['fields'], data);
    }
  }

  void _initFields(List<dynamic> fields, Map<String, dynamic> data) {
    for (var field in fields) {
      if (field['type'] == 'row' || field['type'] == 'group') {
        _initFields(field['fields'], data);
      } else if (field.containsKey('id')) {
        _createController(field['id'], data[field['id']]);
      }
    }
  }

  void _createController(String id, dynamic value) {
    String text = '';
    if (value != null) {
      if (value is DateTime) {
        text = DateFormat('dd MMM yyyy').format(value);
      } else if (value is Timestamp) {
        text = DateFormat('dd MMM yyyy').format(value.toDate());
      } else {
        text = value.toString();
      }
    }
    _controllers[id] = TextEditingController(text: text);
    _focusNodes[id] = FocusNode();
    _layerLinks[id] = LayerLink();

    _focusNodes[id]!.addListener(() {
      if (_focusNodes[id]!.hasFocus) {
        bool needsUpdate = false;
        if (_currentFocusedId != id) {
          _currentFocusedId = id;
          needsUpdate = true;
        }
        if (_openDropdowns.containsKey(id) && _openDropdowns[id] != true) {
          _openDropdowns[id] = true;
          needsUpdate = true;
        }
        
        if (needsUpdate) {
          setState(() {});
        }

        Future.delayed(const Duration(milliseconds: 100), () {
          final context = _focusNodes[id]?.context;
          if (context != null && mounted) {
            Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 300), alignment: 0.2);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    for (var ctrl in _controllers.values) ctrl.dispose();
    for (var node in _focusNodes.values) node.dispose();
    for (var row in _customAttachmentRows) {
      if (row['titleCtrl'] is TextEditingController) {
        (row['titleCtrl'] as TextEditingController).dispose();
      }
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleSection(String title) {
    setState(() {
      if (_expandedSections.contains(title)) {
        _expandedSections.remove(title);
      } else {
        _expandedSections.add(title);
        // 🚀 NAYA: Auto-scroll to top when expanding
        Future.delayed(const Duration(milliseconds: 250), () {
          final key = _sectionKeys[title];
          if (key != null && key.currentContext != null) {
            Scrollable.ensureVisible(
              key.currentContext!,
              duration: const Duration(milliseconds: 400),
              alignment: 0.0, 
              curve: Curves.easeInOut,
            );
          }
        });
      }
    });
  }

  void _globalToggle() {
    final allTitles = ProjectFormStrings.formStructure.map((s) => s['title'] as String).toList();
    setState(() {
      if (_expandedSections.length == allTitles.length) {
        _expandedSections.clear();
      } else {
        _expandedSections.clear();
        _expandedSections.addAll(allTitles);
      }
    });
  }

  void _focusNextField({bool isDoubleClick = false}) {
    final fieldIds = _getAllFieldIds();
    
    if (_currentFocusedId.isEmpty) {
      for (var fid in fieldIds) {
        if (_isFieldVisible(fid)) {
          _navigateToField(fid);
          return;
        }
      }
      return;
    }

    final currentIndex = fieldIds.indexOf(_currentFocusedId);

    if (!isDoubleClick) {
      final fieldType = _getFieldType(_currentFocusedId);
      if (fieldType != 'chips' && fieldType != 'date' && fieldType != 'rating' && fieldType != 'switch') {
        final ctrl = _controllers[_currentFocusedId];
        if (ctrl != null && ctrl.text.isNotEmpty) {
          final query = ctrl.text.toLowerCase();
          final options = _getFieldOptions(_currentFocusedId);
          final matches = options.where((opt) => opt.toLowerCase().contains(query)).toList();
          if (matches.isNotEmpty) {
            final match = matches.first;
            if (ctrl.text != match) {
              setState(() {
                ctrl.value = TextEditingValue(
                  text: match,
                  selection: TextSelection.collapsed(offset: match.length),
                );
                _formData[_currentFocusedId] = match;
              });
              return;
            }
          }
        }
      }
    }

    if (currentIndex != -1 && currentIndex < fieldIds.length - 1) {
      for (int i = currentIndex + 1; i < fieldIds.length; i++) {
        if (_isFieldVisible(fieldIds[i])) {
          _navigateToField(fieldIds[i]);
          return;
        }
      }
    }
  }

  void _focusPrevField() {
    final fieldIds = _getAllFieldIds();
    final currentIndex = fieldIds.indexOf(_currentFocusedId);
    if (currentIndex > 0) {
      for (int i = currentIndex - 1; i >= 0; i--) {
        if (_isFieldVisible(fieldIds[i])) {
          _navigateToField(fieldIds[i]);
          return;
        }
      }
    }
  }

  void _navigateToField(String fieldId) {
    String? targetSectionTitle;
    for (var section in ProjectFormStrings.formStructure) {
      if (_isFieldInSection(section['fields'], fieldId)) {
        targetSectionTitle = section['title'];
        break;
      }
    }

    if (targetSectionTitle != null && !_expandedSections.contains(targetSectionTitle)) {
      setState(() {
        _expandedSections.add(targetSectionTitle!);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_focusNodes.containsKey(fieldId)) {
        _focusNodes[fieldId]!.requestFocus();
        final type = _getFieldType(fieldId);
        final isTextInput = type == 'text' || type == 'searchable' || type == 'dropdown' || type == 'builder_selector' || type == 'multiline' || type == 'number';
        if (isTextInput && !kIsWeb) {
          SystemChannels.textInput.invokeMethod('textInput.show');
        }
      }
    });
  }

  String? _getFieldType(String fieldId) {
    for (var section in ProjectFormStrings.formStructure) {
      final res = _findType(section['fields'], fieldId);
      if (res != null) return res;
    }
    return null;
  }

  String? _findType(List<dynamic> fields, String fieldId) {
    for (var f in fields) {
      if (f['type'] == 'row' || f['type'] == 'group') {
        final res = _findType(f['fields'], fieldId);
        if (res != null) return res;
      } else if (f['id'] == fieldId) {
        return f['type'];
      }
    }
    return null;
  }

  List<String> _getChipOptions(String fieldId) {
    for (var section in ProjectFormStrings.formStructure) {
      final res = _findOptions(section['fields'], fieldId);
      if (res != null) return res;
    }
    return [];
  }

  List<String>? _findOptions(List<dynamic> fields, String fieldId) {
    for (var f in fields) {
      if (f['type'] == 'row' || f['type'] == 'group') {
        final res = _findOptions(f['fields'], fieldId);
        if (res != null) return res;
      } else if (f['id'] == fieldId) {
        if (fieldId == 'subType') {
          final pType = _formData['propertyType']?.toString() ?? '';
          if (pType == 'Project') return ['Residential', 'Commercial', 'Bungalow', 'Redevelopment', 'Bulk'];
          if (pType == 'Flat' || pType == 'Shop' || pType == 'Bungalow') return ['New', 'Resale'];
          if (pType == 'Land') return ['NA', 'Non-NA'];
        }
        return List<String>.from(f['options'] ?? []);
      }
    }
    return null;
  }

  bool _isFieldInSection(List<dynamic> fields, String fieldId) {
    for (var f in fields) {
      if (f['type'] == 'row' || f['type'] == 'group') {
        if (_isFieldInSection(f['fields'], fieldId)) return true;
      } else if (f['id'] == fieldId) {
        return true;
      }
    }
    return false;
  }

  List<String> _getAllFieldIds() {
    final ids = <String>[];
    for (var section in ProjectFormStrings.formStructure) {
      _addFieldIds(section['fields'], ids);
    }
    return ids;
  }

  void _addFieldIds(List<dynamic> fields, List<String> ids) {
    for (var field in fields) {
      if (field['type'] == 'row' || field['type'] == 'group') {
        _addFieldIds(field['fields'], ids);
      } else if (field.containsKey('id')) {
        ids.add(field['id']);
      }
    }
  }

  bool get _isFormUnlocked {
    final bool hasPropertyType = _formData['propertyType'] != null && _formData['propertyType'].toString().isNotEmpty;
    final bool hasSubType = _formData['subType'] != null && _formData['subType'].toString().isNotEmpty;
    final String pType = (_formData['propertyType'] ?? '').toString();
    final dynamic configVal = _formData['configuration'];
    final bool hasConfiguration = configVal != null && (configVal is List ? configVal.isNotEmpty : configVal.toString().trim().isNotEmpty);

    if (!hasPropertyType || !hasSubType) return false;

    // Land or Shop: unlocked when subType is selected
    if (pType == 'Land' || pType == 'Shop') {
      return true;
    }

    // Project, Bungalow, or Flat: unlocked when configuration is selected
    if (pType == 'Project' || pType == 'Bungalow' || pType == 'Flat') {
      return hasConfiguration;
    }

    return true;
  }

  bool _isFieldVisible(String fieldId) {
    final bool hasPropertyType = _formData['propertyType'] != null && _formData['propertyType'].toString().isNotEmpty;
    final bool hasSubType = _formData['subType'] != null && _formData['subType'].toString().isNotEmpty;
    final String pType = (_formData['propertyType'] ?? '').toString();

    // Stage 1: Photos/Media and Property Type are ALWAYS visible by default from the start
    if (fieldId == 'coverImage' ||
        fieldId == 'images' ||
        fieldId == 'highlightsImages' ||
        fieldId == 'outdoorsImages' ||
        fieldId == 'projectVideo' ||
        fieldId == 'propertyType') {
      return true;
    }

    // Stage 2: Sub Type is visible only if Property Type is selected
    if (fieldId == 'subType') {
      return hasPropertyType;
    }

    // Stage 3: Configuration is visible if Property Type is Project, Flat, or Bungalow AND Sub Type is selected
    if (fieldId == 'configuration') {
      return (pType == 'Project' || pType == 'Flat' || pType == 'Bungalow') && hasSubType;
    }

    // Stage 4: All other fields inside Basic Info & other sections appear ONLY WHEN form is unlocked
    if (!_isFormUnlocked) {
      return false;
    }

    Map<String, dynamic>? config;
    for (var section in ProjectFormStrings.formStructure) {
      config = _findFieldConfig(section['fields'], fieldId);
      if (config != null) break;
    }

    if (config == null) return true;

    if (config.containsKey('visibleIf')) {
      final String visibleIf = config['visibleIf'];
      if (visibleIf.contains(' != ')) {
        final parts = visibleIf.split(' != ');
        final String val = (_formData[parts[0]] ?? '').toString();
        if (val == parts[1]) return false;
      } else if (visibleIf.contains(' == ')) {
        final parts = visibleIf.split(' == ');
        final String val = (_formData[parts[0]] ?? '').toString();
        if (val != parts[1]) return false;
      } else if (visibleIf.contains(' && ')) {
        final parts = visibleIf.split(' && ');
        for (var p in parts) {
          if (p.contains(' != ')) {
            final subParts = p.split(' != ');
            if ((_formData[subParts[0]] ?? '').toString() == subParts[1]) return false;
          } else if (p.contains(' == ')) {
            final subParts = p.split(' == ');
            if ((_formData[subParts[0]] ?? '').toString() != subParts[1]) return false;
          }
        }
      } else if (visibleIf.contains(' || ')) {
        final parts = visibleIf.split(' || ');
        bool matched = false;
        for (var p in parts) {
          if (p.contains(' == ')) {
            final subParts = p.split(' == ');
            if ((_formData[subParts[0]] ?? '').toString() == subParts[1]) matched = true;
          }
        }
        if (!matched) return false;
      }
    }
    return true;
  }

  Map<String, dynamic>? _findFieldConfig(List<dynamic> fields, String fieldId) {
    for (var f in fields) {
      if (f['type'] == 'row' || f['type'] == 'group') {
        final res = _findFieldConfig(f['fields'], fieldId);
        if (res != null) return res;
      } else if (f['id'] == fieldId) {
        return f;
      }
    }
    return null;
  }

  void _updateFullAddress() {
    final flat = _controllers['flatNo']?.text ?? '';
    final bldg = _controllers['buildingName']?.text ?? '';
    final area = _controllers['areaName']?.text ?? '';
    final nearby = _controllers['nearby']?.text ?? '';
    final opp = _controllers['opposite']?.text ?? '';
    final road = _controllers['road']?.text ?? '';

    String full = '';
    if (flat.isNotEmpty) full += '$flat, ';
    if (bldg.isNotEmpty) full += '$bldg, ';
    if (area.isNotEmpty) full += '$area, ';
    if (nearby.isNotEmpty) full += 'Nearby $nearby, ';
    if (opp.isNotEmpty) full += 'Opposite $opp, ';
    if (road.isNotEmpty) full += road;

    if (full.endsWith(', ')) full = full.substring(0, full.length - 2);
    _controllers['address']?.text = full;
    _formData['address'] = full;
  }

  List<String> _getFieldOptions(String id) {
    final projectVM = Provider.of<ProjectViewModel>(context, listen: false);
    final learnedData = <String>{};
    for (var p in projectVM.projects) {
      if (id == 'propertyName' && p.projectName.isNotEmpty) {
        learnedData.add(p.projectName);
      } else {
        final val = p.propertyDetails[id];
        if (val != null && val.toString().isNotEmpty) {
          learnedData.add(val.toString());
        }
      }
    }
    if (id == 'projectCompany') {
      final builderVM = Provider.of<BuilderViewModel>(context, listen: false);
      for (var b in builderVM.builders) {
        if (b.companyNames.isNotEmpty) {
          learnedData.addAll(b.companyNames);
        }
      }
    }

    if (id == 'subType') {
      final pType = _formData['propertyType']?.toString() ?? '';
      if (pType == 'Land') {
        return ['NA', 'Non - NA'];
      } else {
        return ['New', 'UC', 'Resale', 'Rent', 'RTM'];
      }
    }

    if (id == 'isHot') {
      final Set<String> takenPriorities = {};
      final String currentProjectId = widget.project?.id ?? '';

      for (var p in projectVM.projects) {
        if (p.id == currentProjectId) continue;
        final prio = p.priorityNumber;
        if (prio >= 1 && prio <= 30) {
          takenPriorities.add(prio.toString());
        }
      }

      List<String> available = ['None'];
      for (int i = 1; i <= 30; i++) {
        final str = i.toString();
        if (!takenPriorities.contains(str)) {
          available.add(str);
        }
      }
      return available;
    }

    return learnedData.toList()..sort();
  }

  List<String> _getReferralNames() {
    final leadVM = Provider.of<LeadViewModel>(context, listen: false);
    final cpVM = Provider.of<CPViewModel>(context, listen: false);
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    
    final names = <String>{};
    
    // 1. Current User
    if (authVM.userName.isNotEmpty) names.add(authVM.userName);
    
    // 2. From Channel Partners
    for (var cp in cpVM.cps) {
      if (cp.fullName.isNotEmpty) names.add(cp.fullName);
    }
    
    // 3. From Leads (Potential referrals)
    for (var l in leadVM.leads) {
      if (l.fullName.isNotEmpty) names.add(l.fullName);
    }
    
    return names.toList()..sort();
  }

  void _navigateBackOnCancelOrSave({String? targetDocId}) {
    if (widget.project != null || targetDocId != null) {
      final docId = targetDocId ?? widget.project!.id;
      final projectVM = Provider.of<ProjectViewModel>(context, listen: false);
      final updatedProject = projectVM.projects.where((p) => p.id == docId).firstOrNull ?? widget.project;
      
      context.go('/project-detail/$docId', extra: updatedProject);
    } else {
      context.go('/projects');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.project != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _navigateBackOnCancelOrSave();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(onPressed: _navigateBackOnCancelOrSave, icon: const Icon(Icons.arrow_back, color: Colors.black)),
          title: Text(isEditing ? 'Edit Project' : 'New Project Form', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 20),
                children: ProjectFormStrings.formStructure.map<Widget>((section) => _buildSection(section)).toList(),
              ),
            ),
            _buildStickyNavigation(isEditing),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(Map<String, dynamic> section) {
    final String title = section['title'];
    final bool hasPropertyType = _formData['propertyType'] != null && _formData['propertyType'].toString().isNotEmpty;
    final bool hasSubType = _formData['subType'] != null && _formData['subType'].toString().isNotEmpty;

    // 🚀 NAYA: Hide other sections until form is unlocked
    if (title != ProjectFormStrings.sectionBasicInfo && !_isFormUnlocked) {
      return const SizedBox.shrink();
    }

    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    if (section.containsKey('roles')) {
      final List<String> allowedRoles = List<String>.from(section['roles']);
      final String currentRoleKey = appRoleKey(authVM.appRole);
      if (!allowedRoles.contains(currentRoleKey) && !allowedRoles.contains('all')) {
        return const SizedBox.shrink();
      }
    }

    if (section.containsKey('visibleIf')) {
      final String visibleIf = section['visibleIf'];
      if (visibleIf.contains(' || ')) {
        final parts = visibleIf.split(' || ');
        bool matched = false;
        for (var p in parts) {
          if (p.contains(' == ')) {
            final subParts = p.split(' == ');
            if ((_formData[subParts[0]] ?? '').toString() == subParts[1]) matched = true;
          }
        }
        if (!matched) return const SizedBox.shrink();
      } else if (visibleIf.contains(' == ')) {
        final parts = visibleIf.split(' == ');
        if ((_formData[parts[0]] ?? '').toString() != parts[1]) return const SizedBox.shrink();
      }
    }

    final bool isExpanded = _expandedSections.contains(title);
    final key = _sectionKeys.putIfAbsent(title, () => GlobalKey()); // 🚀 NAYA

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _toggleSection(title),
          onDoubleTap: _globalToggle,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isExpanded ? primaryColor.withValues(alpha: 0.1) : primaryColor.withValues(alpha: 0.05),
              border: Border(
                bottom: BorderSide(color: isExpanded ? primaryColor.withValues(alpha: 0.3) : Colors.grey.shade200),
                left: const BorderSide(color: primaryColor, width: 4),
              ),
            ),
            child: Row(
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const Spacer(),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: isExpanded ? secondaryColor : secondaryColor.withValues(alpha: 0.6),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 15, 8, 5),
            child: Column(
              children: (section['fields'] as List).map<Widget>((field) => _buildDynamicField(field)).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildDynamicField(Map<String, dynamic> field) {
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    if (field.containsKey('roles')) {
      final List<String> allowedRoles = List<String>.from(field['roles']);
      final String currentRoleKey = appRoleKey(authVM.appRole);
      if (!allowedRoles.contains(currentRoleKey) && !allowedRoles.contains('all')) {
        return const SizedBox.shrink();
      }
    }

    if (field.containsKey('id') && field['id'] != null) {
      final String id = field['id'];
      if (!_isFieldVisible(id)) return const SizedBox.shrink();

      // 🚀 NAYA: 2x2 Grid + Video Container for Media Categories
      if (id == 'coverImage') {
        return _buildImageMediaGrid();
      }
      if (id == 'images' || id == 'highlightsImages' || id == 'outdoorsImages' || id == 'projectVideo') {
        return const SizedBox.shrink(); // Rendered together in media grid
      }
    }

    final String type = field['type'];
    if (type == 'row') {
      bool anyVisible = false;
      for (var f in field['fields']) {
        if (_isFieldVisible(f['id'])) anyVisible = true;
      }
      if (!anyVisible) return const SizedBox.shrink();

      return Padding(
        key: ValueKey('row_${field.hashCode}'),
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: (field['fields'] as List).map<Widget>((f) {
            if (!_isFieldVisible(f['id'])) return const SizedBox.shrink();
            return Expanded(
              key: ValueKey('exp_${f['id']}'),
              child: Padding(
                padding: EdgeInsets.only(right: (field['fields'] as List).last == f ? 0 : 12),
                child: _buildFieldContent(f),
              ),
            );
          }).toList(),
        ),
      );
    } else if (type == 'group') {
      return Column(
        key: ValueKey('grp_${field.hashCode}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (field.containsKey('title')) ...[
            Text(field['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: secondaryColor)),
            const SizedBox(height: 12),
          ],
          ...(field['fields'] as List).map<Widget>((f) => _buildDynamicField(f)),
        ],
      );
    }
    return Padding(
      key: ValueKey('pad_${field['id']}'),
      padding: const EdgeInsets.only(bottom: 16), 
      child: _buildFieldContent(field)
    );
  }

  Widget _buildFieldContent(Map<String, dynamic> field) {
    final String id = field['id'];
    final String label = field['label'];
    final String type = field['type'];
    final configVM = Provider.of<AppConfigurationViewModel>(context, listen: false);

    if (id == 'subType') {
      final pType = _formData['propertyType']?.toString() ?? '';
      if (pType.isEmpty) return const SizedBox.shrink();

      List<String> dynamicOptions = [];
      if (pType == 'Land') {
        dynamicOptions = ['NA', 'Non - NA'];
      } else {
        dynamicOptions = ['New', 'UC', 'Resale', 'Rent', 'RTM'];
      }
      return _buildChoiceChips(label, id, dynamicOptions);
    }

    if (id == 'source') {
      final List<String> defaultOpts = List<String>.from(field['options'] ?? []);
      final currentOpts = configVM.getOptionsForField('Project Form', id, defaultOpts);
      return _buildSourceSelector(label, id, currentOpts);
    }

    if (id == 'referral') {
      return _buildReferralNameSelector(label, id);
    }

    switch (type) {
      case 'custom_attachment_list': return _buildCustomAttachmentList(label, id);
      case 'media_list': return _buildMediaList(label, id);
      case 'chips': return _buildChoiceChips(label, id, configVM.getOptionsForField('Project Form', id, List<String>.from(field['options'] ?? [])));
      case 'addable_chips': return _buildAddableChips(label, id, configVM.getOptionsForField('Project Form', id, List<String>.from(field['options'] ?? [])));
      case 'dropdown': 
      case 'searchable': return _buildSearchableField(label, id, readOnly: field['readOnly'] ?? false);
      case 'builder_selector': return _buildBuilderSelector(label, id);
      case 'switch': return _buildSwitchField(label, id);
      case 'file': return _buildFilePicker(label, id);
      case 'image': return _buildImagePicker(label, id);
      case 'date': return _buildDateField(label, id);
      case 'rating': return _buildRatingField(label, id);
      case 'like': return _buildLikeField(label, id);
      default: return _buildSearchableField(label, id, readOnly: field['readOnly'] ?? false);
    }
  }

  Widget _buildCustomAttachmentList(String label, String id) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.black87)),
        const SizedBox(height: 10),
        ..._customAttachmentRows.asMap().entries.map((entry) {
          final int index = entry.key;
          final row = entry.value;
          final TextEditingController titleCtrl = row['titleCtrl'] as TextEditingController;
          final dynamic pickedFile = row['file'];
          final String? existingUrl = row['existingUrl'];

          String fileName = 'No file selected';
          if (pickedFile != null) {
            fileName = (pickedFile is XFile) ? pickedFile.name : (pickedFile is PlatformFile ? pickedFile.name : 'Selected File');
          } else if (existingUrl != null && existingUrl.isNotEmpty) {
            fileName = 'Uploaded File (${index + 1})';
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Attachment #${index + 1}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                    ),
                    const Spacer(),
                    if (_customAttachmentRows.length > 1)
                      InkWell(
                        onTap: () {
                          setState(() {
                            titleCtrl.dispose();
                            _customAttachmentRows.removeAt(index);
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(2.0),
                          child: Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left 50%: Document Title Input
                    Expanded(
                      child: TextField(
                        controller: titleCtrl,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'e.g. Tax Receipt, Draft',
                          labelText: 'Document Title',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Right 50%: Image/File Picker
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final FilePickerResult? result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
                          );
                          if (result != null && result.files.isNotEmpty) {
                            setState(() {
                              row['file'] = result.files.first;
                            });
                          }
                        },
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: (pickedFile != null || existingUrl != null) ? const Color(0xFFFF6B22) : Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                (pickedFile != null || existingUrl != null) ? Icons.check_circle_rounded : Icons.file_upload_outlined,
                                color: (pickedFile != null || existingUrl != null) ? const Color(0xFFFF6B22) : Colors.grey.shade600,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  fileName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: (pickedFile != null || existingUrl != null) ? FontWeight.bold : FontWeight.normal,
                                    color: (pickedFile != null || existingUrl != null) ? Colors.black87 : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),

        // + Add More Attachment Button
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _customAttachmentRows.add({
                'titleCtrl': TextEditingController(),
                'file': null,
                'existingUrl': null,
              });
            });
          },
          icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFFFF6B22)),
          label: const Text('Add More Attachment', style: TextStyle(color: Color(0xFFFF6B22), fontWeight: FontWeight.bold, fontSize: 12.5)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFFF6B22), width: 1.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildImageMediaGrid() {
    final Map<String, String> mediaFields = {
      'coverImage': 'Cover Image',
      'images': 'Images Max 10',
      'highlightsImages': 'Highlights Max 10',
      'outdoorsImages': 'Outdoors Max 10',
    };

    final List<MapEntry<String, String>> entries = mediaFields.entries.toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Project Photos & Media', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.black87)),
          const SizedBox(height: 6),
          // 1. 2x2 Grid for All 4 Image Categories
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 4,
              mainAxisExtent: 115,
            ),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final fieldId = entries[index].key;
              final fieldLabel = entries[index].value;
              return _buildGridImageCard(fieldId, fieldLabel);
            },
          ),
          const SizedBox(height: 8),
          // 2. Project Video Container at the bottom
          _buildVideoContainerCard('projectVideo', 'Project Video (File / Link)'),
        ],
      ),
    );
  }

  Widget _buildVideoContainerCard(String id, String label) {
    dynamic pickedVideo = _pickedFiles[id];
    String? existingUrl = _formData[id] is String && _formData[id].toString().isNotEmpty ? _formData[id] as String : null;

    bool hasVideo = pickedVideo != null || existingUrl != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.black87)),
            const Spacer(),
            if (hasVideo)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: const Text('Video Added', style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 3),
        if (hasVideo)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.video_collection_rounded, color: Colors.blue.shade700, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    existingUrl ?? (pickedVideo is PlatformFile ? pickedVideo.name : (pickedVideo is XFile ? pickedVideo.name : 'Selected Video File')),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.redAccent, size: 16),
                  onPressed: () => setState(() {
                    _pickedFiles.remove(id);
                    _formData.remove(id);
                  }),
                ),
              ],
            ),
          )
        else
          InkWell(
            onTap: () async {
              final FilePickerResult? result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['mp4', 'mov', 'avi', 'mkv', 'pdf'],
              );
              if (result != null && result.files.isNotEmpty) {
                final file = result.files.first;
                setState(() => _pickedFiles[id] = file);
              }
            },
            child: Container(
              height: 52,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300, width: 1, style: BorderStyle.solid),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_call_outlined, color: Colors.blue.shade600, size: 22),
                  const SizedBox(width: 6),
                  Text('Upload Project Video File', style: TextStyle(color: Colors.blue.shade700, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGridImageCard(String id, String label) {
    bool isSingle = id == 'coverImage';
    
    dynamic singlePicked = _pickedFiles[id];
    String? singleExisting = _formData[id] is String && _formData[id].toString().startsWith('http') ? _formData[id] as String : null;

    List<dynamic> multiPicked = _pickedMediaLists[id] ?? [];
    List<dynamic> multiExisting = (_formData[id] is List) ? _formData[id] as List<dynamic> : [];

    int totalCount = isSingle 
        ? (singlePicked != null || singleExisting != null ? 1 : 0)
        : (multiPicked.length + multiExisting.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87),
              ),
            ),
            if (totalCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: const Color(0xFFFF6B22).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text('$totalCount', style: const TextStyle(color: Color(0xFFFF6B22), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Center(
          child: isSingle
              ? _buildSingleImageGridTile(id, singlePicked, singleExisting)
              : _buildMultiImageGridTile(id, multiPicked, multiExisting),
        ),
      ],
    );
  }

  Widget _buildSingleImageGridTile(String id, dynamic picked, String? existingUrl) {
    if (picked != null || existingUrl != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: existingUrl != null
                ? Image.network(existingUrl, width: 75, height: 75, fit: BoxFit.cover)
                : (kIsWeb
                    ? Image.network((picked as XFile).path, width: 75, height: 75, fit: BoxFit.cover)
                    : Image.file(File((picked as XFile).path), width: 75, height: 75, fit: BoxFit.cover)),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: InkWell(
              onTap: () => setState(() {
                _pickedFiles.remove(id);
                _formData.remove(id);
              }),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: () async {
        final ImagePicker picker = ImagePicker();
        final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1280, maxHeight: 1280);
        if (pickedFile != null) setState(() => _pickedFiles[id] = pickedFile);
      },
      child: Container(
        width: 75,
        height: 75,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300, width: 1, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, color: Colors.grey.shade400, size: 22),
            const SizedBox(height: 2),
            Text('Add Photo', style: TextStyle(color: Colors.grey.shade500, fontSize: 9.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiImageGridTile(String id, List<dynamic> multiPicked, List<dynamic> multiExisting) {
    final allItems = [
      ...multiExisting.map((url) => _buildThumbnail(url, () {
        setState(() {
          final updatedList = List<dynamic>.from(multiExisting);
          updatedList.remove(url);
          _formData[id] = updatedList;
        });
      }, isUrl: true)),
      ...multiPicked.map((file) => _buildThumbnail(file, () => setState(() => multiPicked.remove(file)))),
    ];

    if (allItems.isNotEmpty) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...allItems,
            if (allItems.length < 10)
              InkWell(
                onTap: () async {
                  final ImagePicker picker = ImagePicker();
                  final picked = await picker.pickMultiImage(imageQuality: 70, maxWidth: 1280, maxHeight: 1280);
                  if (picked.isNotEmpty) setState(() => _pickedMediaLists.putIfAbsent(id, () => []).addAll(picked));
                },
                child: Container(
                  width: 75,
                  height: 75,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, color: Colors.grey.shade400, size: 22),
                      const SizedBox(height: 2),
                      Text('Add', style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () async {
        final ImagePicker picker = ImagePicker();
        final picked = await picker.pickMultiImage(imageQuality: 70, maxWidth: 1280, maxHeight: 1280);
        if (picked.isNotEmpty) setState(() => _pickedMediaLists.putIfAbsent(id, () => []).addAll(picked));
      },
      child: Container(
        width: 75,
        height: 75,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300, width: 1, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, color: Colors.grey.shade400, size: 22),
            const SizedBox(height: 2),
            Text('Add Photo', style: TextStyle(color: Colors.grey.shade500, fontSize: 9.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaList(String label, String id) {
    final list = _pickedMediaLists[id] ?? [];
    final existing = (_formData[id] is List) ? _formData[id] as List<dynamic> : [];
    
    final allItems = [
      ...existing.map((url) => _buildThumbnail(url, () {
        setState(() {
          final updatedList = List<dynamic>.from(existing);
          updatedList.remove(url);
          _formData[id] = updatedList;
        });
      }, isUrl: true)),
      ...list.map((file) => _buildThumbnail(file, () => setState(() => list.remove(file)))),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 12),
        Center(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              ...allItems,
              if (allItems.length < 10)
                InkWell(
                  onTap: () async {
                    final ImagePicker picker = ImagePicker();
                    final picked = await picker.pickMultiImage(imageQuality: 70, maxWidth: 1280, maxHeight: 1280);
                    if (picked.isNotEmpty) setState(() => _pickedMediaLists.putIfAbsent(id, () => []).addAll(picked));
                  },
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50, 
                      borderRadius: BorderRadius.circular(12), 
                      border: Border.all(color: Colors.grey.shade300, width: 1.5, style: BorderStyle.solid)
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, color: Colors.grey.shade400, size: 42),
                        const SizedBox(height: 6),
                        Text('Add Photo', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnail(dynamic file, VoidCallback onRemove, {bool isUrl = false}) {
    return Container(
      width: 75,
      height: 75,
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: isUrl 
              ? Image.network(file, fit: BoxFit.cover, width: 75, height: 75)
              : (kIsWeb ? Image.network(file.path, fit: BoxFit.cover, width: 75, height: 75) : Image.file(File(file.path), fit: BoxFit.cover, width: 75, height: 75)),
          ),
          Positioned(
            top: 2, 
            right: 2, 
            child: GestureDetector(
              onTap: onRemove, 
              child: Container(
                padding: const EdgeInsets.all(3), 
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), 
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _autoSelectBuildersForCompany(String rawCompany) {
    final builderVM = Provider.of<BuilderViewModel>(context, listen: false);
    final cleanCompany = rawCompany.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (cleanCompany.isEmpty) {
      setState(() {
        _selectedBuilderIds.clear();
        _formData['builderIds'] = _selectedBuilderIds;
        for (var entry in _controllers.entries) {
          if (entry.key.toLowerCase().contains('builder') || entry.key == 'builderIds') {
            entry.value.text = '';
          }
        }
      });
      return;
    }
    final matchingBuilderIds = builderVM.builders
        .where((b) => b.companyNames.any((c) => c.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ') == cleanCompany))
        .map((b) => b.id)
        .toList();

    final matchingNames = builderVM.builders
        .where((b) => matchingBuilderIds.contains(b.id))
        .map((b) => b.name)
        .join(', ');

    setState(() {
      _selectedBuilderIds = matchingBuilderIds;
      _formData['builderIds'] = _selectedBuilderIds;
      for (var entry in _controllers.entries) {
        if (entry.key.toLowerCase().contains('builder') || entry.key == 'builderIds') {
          entry.value.text = matchingNames;
        }
      }
    });
  }

  void _handleAddNewBuilder(String queryText, String id) {
    final cleanName = queryText.trim();
    if (cleanName.isEmpty) return;

    setState(() {
      if (!_pendingBuilderNames.contains(cleanName)) {
        _pendingBuilderNames.add(cleanName);
      }
      _controllers[id]?.clear();
    });
    _focusNodes[id]?.requestFocus();
  }

  Widget _buildBuilderSelector(String label, String id) {
    final builderVM = Provider.of<BuilderViewModel>(context);
    final allBuilders = builderVM.builders;
    final optionsNames = allBuilders.map((b) => b.name).toList();

    final TextEditingController builderCtrl = _controllers.putIfAbsent(id, () {
      return TextEditingController();
    });

    final FocusNode fNode = _focusNodes[id]!;
    final LayerLink link = _layerLinks[id] ??= LayerLink();

    final selectedBuilders = allBuilders.where((b) => _selectedBuilderIds.contains(b.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        CompositedTransformTarget(
          link: link,
          child: RawAutocomplete<String>(
            focusNode: fNode,
            textEditingController: builderCtrl,
            optionsBuilder: (TextEditingValue textEditingValue) {
              final query = textEditingValue.text.trim().toLowerCase();
              if (query.isEmpty) return const Iterable<String>.empty();
              final matches = optionsNames.where((opt) => opt.toLowerCase().contains(query)).toList();
              final bool exactMatch = matches.any((m) => m.toLowerCase() == query);
              if (!exactMatch) {
                return [textEditingValue.text, ...matches];
              }
              return matches;
            },
            onSelected: (String selection) async {
              final existing = allBuilders.where((b) => b.name.toLowerCase() == selection.toLowerCase()).toList();
              if (existing.isNotEmpty) {
                final match = existing.first;
                setState(() {
                  if (!_selectedBuilderIds.contains(match.id)) {
                    _selectedBuilderIds.add(match.id);
                    _formData['builderIds'] = _selectedBuilderIds;
                  }
                  builderCtrl.clear();
                });
                final comp = _formData['projectCompany']?.toString().trim() ?? '';
                if (comp.isNotEmpty) {
                  try {
                    await FirebaseFirestore.instance.collection(match.sourceCollection).doc(match.id).set({
                      'companyNames': FieldValue.arrayUnion([comp]),
                      'companyName': comp,
                    }, SetOptions(merge: true));
                  } catch (_) {}
                }
                fNode.requestFocus();
              } else {
                // 🚀 NAYA: Handle "Add New" from Enter key
                _handleAddNewBuilder(selection, id);
              }
            },
            fieldViewBuilder: (context, textCtrl, textFocusNode, onFieldSubmitted) {
              return Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    // 🚀 NAYA: Explicit Enter handling to ensure it triggers onSelected
                    if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                      if (textCtrl.text.trim().isNotEmpty) {
                        onFieldSubmitted(); 
                        return KeyEventResult.handled;
                      }
                    }

                    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                      if (textCtrl.selection.baseOffset == textCtrl.text.length) {
                        final query = textCtrl.text.toLowerCase();
                        if (query.isNotEmpty) {
                          final matches = optionsNames.where((opt) => opt.toLowerCase().contains(query)).toList();
                          if (matches.isNotEmpty) {
                            final matchName = matches.first;
                            setState(() {
                              builderCtrl.value = TextEditingValue(
                                text: matchName,
                                selection: TextSelection.collapsed(offset: matchName.length),
                              );
                            });
                            // Stay in field for multi-select
                            return KeyEventResult.handled;
                          }
                        }
                        // Only move forward if empty
                        if (textCtrl.text.isEmpty) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _focusNextField(isDoubleClick: true);
                          });
                        }
                        return KeyEventResult.handled;
                      }
                    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                      if (textCtrl.selection.baseOffset == 0) {
                        _focusPrevField();
                        return KeyEventResult.handled;
                      }
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  controller: textCtrl,
                  focusNode: textFocusNode,
                  style: const TextStyle(fontSize: 15),
                  textInputAction: TextInputAction.next,
                  decoration: _outlinedDecoration(label, id).copyWith(
                    hintText: 'Search or add builder name...',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_drop_down),
                      onPressed: () {
                        if (textFocusNode.hasFocus) {
                          textFocusNode.unfocus();
                        } else {
                          textFocusNode.requestFocus();
                        }
                      },
                    ),
                  ),
                  onChanged: (val) {
                    _formData['builderIds'] = _selectedBuilderIds;
                  },
                  onSubmitted: (val) {
                    if (val.trim().isEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _focusNextField(isDoubleClick: true);
                      });
                    } else {
                      // Already handled by onKeyEvent or RawAutocomplete internal selection
                    }
                  },
                ),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              final projectVM = Provider.of<ProjectViewModel>(context, listen: false);
              final queryText = builderCtrl.text.trim();
              final bool exactMatchExists = allBuilders.any((b) => b.name.toLowerCase() == queryText.toLowerCase());
              
              final int highlightIndex = AutocompleteHighlightedOption.of(context);
              final bool showAddRow = queryText.isNotEmpty && !exactMatchExists;
              final realOptionsStartIdx = showAddRow ? 1 : 0;
              final realOptions = options.skip(realOptionsStartIdx).toList();

              return Align(
                alignment: Alignment.topLeft,
                child: CompositedTransformFollower(
                  link: link,
                  showWhenUnlinked: false,
                  offset: const Offset(0, 52),
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 350),
                      width: 380,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showAddRow)
                            ListTile(
                              dense: true,
                              tileColor: (highlightIndex == 0 || highlightIndex == -1) ? primaryColor.withValues(alpha: 0.3) : null,
                              leading: const Icon(Icons.add_circle, color: secondaryColor, size: 18),
                              title: Text('Add "$queryText"', style: const TextStyle(fontWeight: FontWeight.bold, color: secondaryColor, fontSize: 13)),
                              onTap: () => onSelected(queryText), // 🚀 Consistency
                            ),
                          if (showAddRow && realOptions.isNotEmpty) const Divider(height: 1),
                          if (realOptions.isNotEmpty)
                            Flexible(
                              child: ListView.separated(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: realOptions.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final optionName = realOptions[index];
                                  final builderObj = allBuilders.firstWhere((b) => b.name.toLowerCase() == optionName.toLowerCase(), orElse: () => allBuilders.first);
                                  
                                  final associatedProjects = projectVM.projects
                                      .where((p) => p.builderIds.contains(builderObj.id))
                                      .map((p) => p.projectName)
                                      .toList();

                                  final bool isHighlighted = highlightIndex == (index + realOptionsStartIdx);

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    tileColor: isHighlighted ? primaryColor.withValues(alpha: 0.3) : null,
                                    title: _highlightText(builderObj.name, queryText),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (builderObj.companyNames.isNotEmpty)
                                          Text('Companies: ${builderObj.companyNames.join(', ')}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        if (associatedProjects.isNotEmpty)
                                        Text('Associated Projects: ${associatedProjects.join(', ')}', style: const TextStyle(fontSize: 11, color: secondaryColor, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                    onTap: () => onSelected(optionName),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (selectedBuilders.isNotEmpty || _pendingBuilderNames.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Associated Partners / Builders:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: secondaryColor)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...selectedBuilders.map((b) {
                      final companiesText = b.companyNames.isNotEmpty ? ' (${b.companyNames.join(', ')})' : '';
                      return Chip(
                        label: Text('${b.name}$companiesText', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        backgroundColor: primaryColor.withValues(alpha: 0.3),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _selectedBuilderIds.remove(b.id);
                            _formData['builderIds'] = _selectedBuilderIds;
                          });
                        },
                      );
                    }),
                    ..._pendingBuilderNames.map((name) {
                      return Chip(
                        avatar: const Icon(Icons.add_circle, size: 16, color: secondaryColor),
                        label: Text('$name (New Partner)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: secondaryColor)),
                        backgroundColor: const Color(0xFFFFF1EA),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _pendingBuilderNames.remove(name);
                          });
                        },
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFilePicker(String label, String id) {
    final picked = _pickedFiles[id];
    final existingUrl = _formData[id] is String && _formData[id].toString().startsWith('http') ? _formData[id] as String : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx']);
            if (result != null) setState(() => _pickedFiles[id] = result.files.first);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: Row(
              children: [
                Icon(Icons.description_outlined, color: (picked == null && existingUrl == null) ? Colors.grey : secondaryColor),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  picked != null ? (kIsWeb ? (picked as PlatformFile).name : (picked as PlatformFile).path!.split('/').last) 
                  : (existingUrl != null ? 'File Attached (Click to Change)' : 'Upload $label'), 
                  style: TextStyle(color: (picked == null && existingUrl == null) ? Colors.grey : Colors.black87, fontSize: 13)
                )),
                if (picked != null || existingUrl != null) IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() { _pickedFiles.remove(id); _formData[id] = null; })),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker(String label, String id) {
    final picked = _pickedFiles[id];
    final existingUrl = _formData[id] is String && _formData[id].toString().startsWith('http') ? _formData[id] as String : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final ImagePicker picker = ImagePicker();
            final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1280, maxHeight: 1280);
            if (pickedFile != null) setState(() => _pickedFiles[id] = pickedFile);
          },
          child: Container(
            height: 120, width: double.infinity,
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: (picked == null && existingUrl == null) 
              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.camera_alt_outlined, color: Colors.grey), const SizedBox(height: 4), Text('Upload $label', style: const TextStyle(color: Colors.grey, fontSize: 11))])
              : ClipRRect(borderRadius: BorderRadius.circular(12), child: existingUrl != null ? Image.network(existingUrl, fit: BoxFit.cover) : (kIsWeb ? Image.network((picked as XFile).path, fit: BoxFit.cover) : Image.file(File((picked as XFile).path), fit: BoxFit.cover))),
          ),
        ),
      ],
    );
  }

  Widget _buildReferralNameSelector(String label, String id) {
    final options = _getReferralNames();
    final controller = _controllers[id]!;
    final focusNode = _focusNodes[id]!;
    final link = _layerLinks[id]!;

    return CompositedTransformTarget(
      link: link,
      child: RawAutocomplete<String>(
        focusNode: focusNode,
        textEditingController: controller,
        optionsBuilder: (val) {
          final query = val.text.trim().toLowerCase();
          if (query.isEmpty) return const Iterable<String>.empty();
          final matches = options.where((o) => o.toLowerCase().contains(query)).toList();
          if (!matches.any((m) => m.toLowerCase() == query)) {
            return [val.text, ...matches];
          }
          return matches;
        },
        onSelected: (val) async {
          if (!options.contains(val)) {
            // New name! Show selection dialog
            _showLeadOrCPDialog(val, id);
          } else {
            setState(() {
              controller.text = val;
              _formData[id] = val;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _focusNextField(isDoubleClick: true);
            });
          }
        },
        fieldViewBuilder: (ctx, ctrl, node, onSub) {
          return TextField(
            controller: ctrl,
            focusNode: node,
            style: const TextStyle(fontSize: 15),
            textInputAction: TextInputAction.next,
            onSubmitted: (_) {
              onSub();
            },
            decoration: _outlinedDecoration(label, id),
          );
        },
        optionsViewBuilder: (ctx, onSel, opts) {
          final queryText = controller.text.trim();
          final bool showAddRow = queryText.isNotEmpty && !options.any((o) => o.toLowerCase() == queryText.toLowerCase());
          final int highlightIndex = AutocompleteHighlightedOption.of(ctx);

          return Align(
            alignment: Alignment.topLeft,
            child: CompositedTransformFollower(
              link: link,
              offset: const Offset(0, 52),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 250),
                  width: 380,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showAddRow)
                        ListTile(
                          dense: true,
                          tileColor: (highlightIndex == 0 || highlightIndex == -1) ? primaryColor.withValues(alpha: 0.3) : null,
                          leading: const Icon(Icons.add_circle, color: secondaryColor, size: 18),
                          title: Text('Add "$queryText"', style: const TextStyle(fontWeight: FontWeight.bold, color: secondaryColor, fontSize: 13)),
                          onTap: () => onSel(queryText),
                        ),
                      if (showAddRow && opts.length > 1) const Divider(height: 1),
                      Flexible(
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: showAddRow ? opts.length - 1 : opts.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final option = opts.elementAt(showAddRow ? index + 1 : index);
                            final bool isHighlighted = highlightIndex == (showAddRow ? index + 1 : index);
                            return ListTile(
                              dense: true,
                              tileColor: isHighlighted ? primaryColor.withValues(alpha: 0.3) : null,
                              title: _highlightText(option, queryText),
                              onTap: () => onSel(option),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showLeadOrCPDialog(String name, String fieldId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Save New Contact'),
        content: Text('How would you like to save "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            onPressed: () async {
              // 🚀 Save as LEAD
              final authVM = Provider.of<AuthViewModel>(context, listen: false);
              final leadVM = Provider.of<LeadViewModel>(context, listen: false);
              await leadVM.addOrUpdateLead({
                'name': name,
                'status': 'Cold',
                'source': 'Referral',
                'timestamp': FieldValue.serverTimestamp(),
                'createdBy': authVM.actorMetadata,
              });
              if (mounted) {
                setState(() {
                  _controllers[fieldId]?.text = name;
                  _formData[fieldId] = name;
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _focusNextField(isDoubleClick: true);
              }
            },
            child: const Text('LEAD', style: TextStyle(color: secondaryColor, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: secondaryColor),
            onPressed: () async {
              // 🚀 Save as PARTNER (CP)
              final authVM = Provider.of<AuthViewModel>(context, listen: false);
              final cpVM = Provider.of<CPViewModel>(context, listen: false);
              await cpVM.addOrUpdateCP({
                'cpName': name,
                'status': 'Pending',
                'partnerType': 'CP',
                'timestamp': FieldValue.serverTimestamp(),
                'createdBy': authVM.actorMetadata,
              });
              if (mounted) {
                setState(() {
                  _controllers[fieldId]?.text = name;
                  _formData[fieldId] = name;
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _focusNextField(isDoubleClick: true);
              }
            },
            child: const Text('PARTNER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceSelector(String label, String id, List<String> options) {
    final controller = _controllers[id]!;
    final focusNode = _focusNodes[id]!;
    final link = _layerLinks[id]!;
    final configVM = Provider.of<AppConfigurationViewModel>(context, listen: false);

    return CompositedTransformTarget(
      link: link,
      child: RawAutocomplete<String>(
        focusNode: focusNode,
        textEditingController: controller,
        optionsBuilder: (val) {
          final query = val.text.trim().toLowerCase();
          final matches = options.where((o) => o.toLowerCase().contains(query)).toList();
          if (query.isNotEmpty && !matches.any((m) => m.toLowerCase() == query)) {
            return [val.text, ...matches];
          }
          return matches;
        },
        onSelected: (val) async {
          if (!options.contains(val)) {
            // Add new source to config
            final updated = List<String>.from(options)..add(val);
            final Map<String, Map<String, List<String>>> currentAll = Map.from(configVM.fieldOptions);
            if (!currentAll.containsKey('Project Form')) currentAll['Project Form'] = {};
            currentAll['Project Form']!['source'] = updated;
            await configVM.saveFieldOptions(currentAll);
          }
          setState(() {
            controller.text = val;
            _formData[id] = val;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _focusNextField(isDoubleClick: true);
          });
        },
        fieldViewBuilder: (ctx, ctrl, node, onSub) {
          return TextField(
            controller: ctrl,
            focusNode: node,
            style: const TextStyle(fontSize: 15),
            textInputAction: TextInputAction.next,
            onSubmitted: (_) {
              onSub();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _focusNextField(isDoubleClick: true);
              });
            },
            decoration: _outlinedDecoration(label, id).copyWith(
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_drop_down),
                onPressed: () {
                  if (node.hasFocus) {
                    node.unfocus();
                  } else {
                    node.requestFocus();
                    final current = ctrl.text;
                    ctrl.text = '$current ';
                    ctrl.text = current;
                  }
                },
              ),
            ),
          );
        },
        optionsViewBuilder: (ctx, onSel, opts) {
          final queryText = controller.text.trim();
          final bool showAddRow = queryText.isNotEmpty && !options.any((o) => o.toLowerCase() == queryText.toLowerCase());
          final int highlightIndex = AutocompleteHighlightedOption.of(ctx);

          return Align(
            alignment: Alignment.topLeft,
            child: CompositedTransformFollower(
              link: link,
              offset: const Offset(0, 52),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 250),
                  width: 380,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showAddRow)
                        ListTile(
                          dense: true,
                          tileColor: (highlightIndex == 0 || highlightIndex == -1) ? primaryColor.withValues(alpha: 0.3) : null,
                          leading: const Icon(Icons.add_circle, color: secondaryColor, size: 18),
                          title: Text('Add "$queryText"', style: const TextStyle(fontWeight: FontWeight.bold, color: secondaryColor, fontSize: 13)),
                          onTap: () => onSel(queryText),
                        ),
                      if (showAddRow && opts.length > 1) const Divider(height: 1),
                      Flexible(
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: showAddRow ? opts.length - 1 : opts.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final option = opts.elementAt(showAddRow ? index + 1 : index);
                            final bool isHighlighted = highlightIndex == (showAddRow ? index + 1 : index);
                            return ListTile(
                              dense: true,
                              tileColor: isHighlighted ? primaryColor.withValues(alpha: 0.3) : null,
                              title: _highlightText(option, queryText),
                              onTap: () => onSel(option),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }


  Widget _buildSearchableField(String label, String id, {TextInputType? keyboardType, int maxLines = 1, bool readOnly = false}) {
    final options = _getFieldOptions(id);
    final controller = _controllers[id]!;
    final focusNode = _focusNodes[id]!;
    final link = _layerLinks[id]!;
    bool isOpen = _openDropdowns[id] ?? false;

    return LayoutBuilder(
      key: ValueKey('lbl_$id'),
      builder: (context, constraints) {
        return CompositedTransformTarget(
          link: link,
          child: RawAutocomplete<String>(
            key: ValueKey('auto_$id'),
            focusNode: focusNode,
            textEditingController: controller,
            optionsBuilder: (val) {
              if (isOpen || val.text.isNotEmpty) {
                return options.where((o) => o.toLowerCase().contains(val.text.toLowerCase()));
              }
              return const Iterable<String>.empty();
            },
            onSelected: (val) {
              setState(() { 
                controller.text = val; 
                _formData[id] = val; 
                _openDropdowns[id] = false; 
                if (id == 'projectCompany') {
                  _autoSelectBuildersForCompany(val);
                }
                if (['flatNo', 'buildingName', 'areaName', 'nearby', 'opposite', 'road'].contains(id)) {
                  _updateFullAddress();
                }
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _focusNextField(isDoubleClick: true);
              });
            },
            fieldViewBuilder: (ctx, ctrl, node, onSub) => Focus(
              onKeyEvent: (fnode, event) {
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                    if (ctrl.selection.baseOffset == ctrl.text.length) {
                      final query = ctrl.text.toLowerCase();
                      if (query.isNotEmpty) {
                        final opts = _getFieldOptions(id);
                        final matches = opts.where((opt) => opt.toLowerCase().contains(query)).toList();
                        if (matches.isNotEmpty) {
                          final match = matches.first;
                          if (ctrl.text != match) {
                            setState(() {
                              ctrl.value = TextEditingValue(
                                text: match,
                                selection: TextSelection.collapsed(offset: match.length),
                              );
                              _formData[id] = match;
                            });
                            return KeyEventResult.handled;
                          }
                        }
                      }
                      _focusNextField();
                      return KeyEventResult.handled;
                    }
                  } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                    if (ctrl.selection.baseOffset == 0) {
                      _focusPrevField();
                      return KeyEventResult.handled;
                    }
                  }
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: ctrl,
                focusNode: node,
                readOnly: readOnly,
                style: const TextStyle(fontSize: 15),
                keyboardType: keyboardType,
                textInputAction: TextInputAction.next,
                maxLines: maxLines,
                onTap: () {
                  if (ctrl.text.isEmpty) {
                    setState(() => _openDropdowns[id] = true);
                    ctrl.text = ' ';
                    ctrl.text = '';
                  }
                },
                decoration: _outlinedDecoration(label, id).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down), 
                    onPressed: () {
                      setState(() {
                        _openDropdowns[id] = !isOpen;
                      });
                      if (!isOpen) {
                        node.requestFocus();
                        final currentText = ctrl.text;
                        ctrl.text = '$currentText ';
                        ctrl.text = currentText;
                      }
                    }
                  ),
                ),
                onChanged: (v) {
                  _formData[id] = v;
                  if (isOpen) setState(() => _openDropdowns[id] = false);
                  if (id == 'projectCompany') {
                    _autoSelectBuildersForCompany(v);
                  }
                  if (['flatNo', 'buildingName', 'areaName', 'nearby', 'opposite', 'road'].contains(id)) {
                    _updateFullAddress();
                  }
                },
                onSubmitted: (v) { 
                  setState(() => _openDropdowns[id] = false);
                  onSub(); 
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _focusNextField(isDoubleClick: true);
                  });
                },
              ),
            ),
            optionsViewBuilder: (ctx, onSel, opts) => Align(
              alignment: Alignment.topLeft,
              child: CompositedTransformFollower(
                link: link,
                offset: const Offset(0, 52),
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 250),
                    width: 380,
                    child: ListView.separated(
                      padding: EdgeInsets.zero, 
                      shrinkWrap: true, 
                      itemCount: opts.length, 
                      separatorBuilder: (context, index) => const Divider(height: 1, indent: 12, endIndent: 12),
                      itemBuilder: (ctx, idx) {
                        final String option = opts.elementAt(idx);
                        final String query = controller.text.trim();
                        final bool isHighlighted = AutocompleteHighlightedOption.of(ctx) == idx || (AutocompleteHighlightedOption.of(ctx) == -1 && idx == 0);
                        return ListTile(
                          tileColor: isHighlighted ? primaryColor.withValues(alpha: 0.3) : null,
                          title: _highlightText(option, query), 
                          onTap: () => onSel(option)
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildChoiceChips(String label, String id, List<String> options) {
    final bool isFocused = _currentFocusedId == id;
    final int activeIdx = _activeChipIndex[id] ?? 0;

    return Focus(
      focusNode: _focusNodes[id],
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            final int currentIndex = _activeChipIndex[id] ?? 0;
            if (currentIndex < options.length - 1) {
              setState(() {
                _activeChipIndex[id] = currentIndex + 1;
              });
            } else {
              _focusNextField();
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            final int currentIndex = _activeChipIndex[id] ?? 0;
            if (currentIndex > 0) {
              setState(() {
                _activeChipIndex[id] = currentIndex - 1;
              });
            } else {
              _focusPrevField();
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
            final int currentIndex = _activeChipIndex[id] ?? 0;
            if (currentIndex < options.length) {
              final opt = options[currentIndex];
              final bool isSelecting = _formData[id] != opt;
              setState(() {
                _formData[id] = isSelecting ? opt : null;
                if (id == 'propertyType' && !isSelecting) {
                  _formData['subType'] = null;
                }
              });
              if (isSelecting) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _focusNextField(isDoubleClick: true);
                });
              }
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: options.asMap().entries.map((entry) {
                  int idx = entry.key;
                  String o = entry.value;
                  final bool isSelected = _formData[id] == o;
                  final bool isHighlighted = isFocused && activeIdx == idx;

                  return GestureDetector(
                    onDoubleTap: () {
                      setState(() {
                        _formData[id] = o;
                        _activeChipIndex[id] = idx;
                        _currentFocusedId = id;
                      });
                      _focusNextField();
                    },
                    child: ChoiceChip(
                      label: Text(o, style: TextStyle(color: isSelected ? Colors.black : Colors.black87, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      selected: isSelected,
                      selectedColor: primaryColor,
                      backgroundColor: const Color(0xFFF5F5F5),
                      checkmarkColor: Colors.black,
                      onSelected: (v) {
                        setState(() {
                          _formData[id] = v ? o : null;
                          _activeChipIndex[id] = idx;
                          if (id == 'propertyType' && !v) {
                            _formData['subType'] = null;
                          }
                        });
                        if (v) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _focusNextField(isDoubleClick: true);
                          });
                        } else {
                          _focusNodes[id]!.requestFocus();
                        }
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: isHighlighted 
                          ? const BorderSide(color: Colors.blue, width: 2.0) 
                          : BorderSide.none
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddableChips(String label, String id, List<String> defaultOptions) {
    List<String> selected;
    if (_formData[id] is List) {
      selected = List<String>.from((_formData[id] as List).map((e) => e.toString()));
      _formData[id] = selected;
    } else {
      selected = <String>[];
      _formData[id] = selected;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
            ...defaultOptions.map((o) {
              final isSel = selected.contains(o);
              return FilterChip(
                label: Text(o, style: TextStyle(fontSize: 12, color: isSel ? Colors.white : Colors.black87)),
                selected: isSel,
                selectedColor: secondaryColor,
                checkmarkColor: Colors.white,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      if (!selected.contains(o)) selected.add(o);
                    } else {
                      selected.remove(o);
                    }
                  });
                },
              );
            }),
            ...selected.where((s) => !defaultOptions.contains(s)).map((o) => Chip(
              label: Text(o, style: const TextStyle(fontSize: 12, color: Colors.white)),
              backgroundColor: secondaryColor,
              deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white),
              onDeleted: () => setState(() => selected.remove(o)),
            )),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16, color: secondaryColor),
              label: const Text('Add Custom', style: TextStyle(fontSize: 12, color: secondaryColor, fontWeight: FontWeight.bold)),
              onPressed: () => _showAddOptionDialog(label, (val) {
                setState(() {
                  if (!selected.contains(val)) selected.add(val);
                });
              }),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      ],
    );
  }

  void _showAddOptionDialog(String label, Function(String) onAdd) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('Add $label'),
      content: TextField(controller: ctrl, style: const TextStyle(fontSize: 15), decoration: const InputDecoration(hintText: 'Type here...')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () { if (ctrl.text.isNotEmpty) onAdd(ctrl.text.trim()); Navigator.pop(ctx); }, style: ElevatedButton.styleFrom(backgroundColor: secondaryColor), child: const Text('Add', style: TextStyle(color: Colors.white))),
      ],
    ));
  }

  Widget _buildSwitchField(String label, String id) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFCCCCCC))),
      child: SwitchListTile.adaptive(
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), 
        value: _formData[id] == 'Yes' || _formData[id] == true, 
        activeColor: secondaryColor, 
        onChanged: (v) => setState(() => _formData[id] = v ? 'Yes' : 'No')
      ),
    );
  }

  Widget _buildDateField(String label, String id) {
    return TextField(
      controller: _controllers[id],
      readOnly: true,
      style: const TextStyle(fontSize: 15),
      onTap: () async {
        final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (d != null) setState(() { _controllers[id]!.text = DateFormat('dd MMM yyyy').format(d); _formData[id] = d; });
      },
      decoration: _outlinedDecoration(label, id).copyWith(suffixIcon: const Icon(Icons.calendar_today, size: 18)),
    );
  }

  Widget _buildRatingField(String label, String id) {
    int rating = _formData[id] ?? 0;
    return Row(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const Spacer(),
        ...List.generate(5, (i) => IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(i < rating ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber), 
          onPressed: () => setState(() => _formData[id] = i + 1)
        )),
      ],
    );
  }

  Widget _buildLikeField(String label, String id) {
    bool liked = _formData[id] == true;
    return Row(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const Spacer(),
        IconButton(icon: Icon(liked ? Icons.favorite : Icons.favorite_border, color: Colors.red), onPressed: () => setState(() => _formData[id] = !liked)),
      ],
    );
  }

  Widget _highlightText(String text, String query) {
    if (query.isEmpty) return Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87));
    final List<TextSpan> spans = [];
    final String lowerText = text.toLowerCase();
    final String lowerQuery = query.toLowerCase();
    int start = 0;
    int indexOfMatch;

    while ((indexOfMatch = lowerText.indexOf(lowerQuery, start)) != -1) {
      if (indexOfMatch > start) {
        spans.add(TextSpan(text: text.substring(start, indexOfMatch), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 14)));
      }
      spans.add(TextSpan(text: text.substring(indexOfMatch, indexOfMatch + query.length), style: const TextStyle(color: secondaryColor, fontWeight: FontWeight.w900, fontSize: 14)));
      start = indexOfMatch + query.length;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 14)));
    }
    return RichText(text: TextSpan(children: spans));
  }

  InputDecoration _outlinedDecoration(String label, String id) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(fontSize: 15, color: Color(0xFF555555), fontWeight: FontWeight.w400),
      floatingLabelStyle: const TextStyle(color: secondaryColor, fontWeight: FontWeight.bold, fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      isDense: true,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCCCCCC), width: 1.0)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: secondaryColor, width: 1.5)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
    );
  }

  Widget _buildStickyNavigation(bool isEditing) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(flex: 1, child: InkWell(onTap: _focusPrevField, borderRadius: BorderRadius.circular(25), child: Container(height: 50, decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(25)), child: const Icon(Icons.arrow_back_rounded, color: secondaryColor)))),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: ElevatedButton(
              onPressed: _isSaving ? null : _handleSave, 
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12)), 
              child: _isSaving 
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: secondaryColor, strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Flexible(child: Text(_loadingMessage, style: TextStyle(color: secondaryColor, fontSize: 11), overflow: TextOverflow.ellipsis)),
                    ],
                  )
                : Text(isEditing ? 'Update Project' : 'Save Project', style: const TextStyle(color: secondaryColor, fontWeight: FontWeight.bold, fontSize: 13))
            )),
            const SizedBox(width: 8),
            Expanded(
              flex: 1, 
              child: GestureDetector(
                onDoubleTap: () {
                  if (_currentFocusedId.isNotEmpty && _getFieldType(_currentFocusedId) == 'chips') {
                    final options = _getChipOptions(_currentFocusedId);
                    if (options.isNotEmpty) {
                      setState(() {
                        _formData[_currentFocusedId] = options.first;
                      });
                    }
                  }
                  _focusNextField(isDoubleClick: true);
                },
                child: InkWell(onTap: _focusNextField, borderRadius: BorderRadius.circular(25), child: Container(height: 50, decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(25)), child: const Icon(Icons.arrow_forward_rounded, color: secondaryColor))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _toTitleCase(String input) {
    if (input.trim().isEmpty) return input;
    return input.trim().split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Future<void> _handleSave() async {
    final titleCaseFields = [
      'propertyName',
      'projectCompany',
      'buildingName',
      'areaName',
      'buildersOwnerName',
      'location',
    ];

    // 🚀 Only collect text values for text-based inputs and auto-apply Title Case formatting
    _controllers.forEach((id, ctrl) {
      final type = _getFieldType(id);
      final textTypes = ['text', 'searchable', 'dropdown', 'multiline', 'number'];
      if (textTypes.contains(type) || type == null) {
        var val = ctrl.text.trim();
        if (titleCaseFields.contains(id) && val.isNotEmpty) {
          val = _toTitleCase(val);
          ctrl.text = val;
        }
        _formData[id] = val;
      }
    });

    if ((_formData['propertyName']?.toString() ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Property Name is required')));
      return;
    }

    // 🚀 NAYA: Auto-update "Last Updated On" timestamp
    final String nowStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    _formData['lastUpdatedOn'] = nowStr;
    _controllers['lastUpdatedOn']?.text = nowStr;

    setState(() { _isSaving = true; _loadingMessage = 'Uploading Files...'; });
    try {
      final authVM = Provider.of<AuthViewModel>(context, listen: false);
      final String folderName = '${_formData['propertyName'] ?? 'project'}_${DateTime.now().millisecondsSinceEpoch}';
      
      for (var entry in _pickedMediaLists.entries) {
        final String fieldId = entry.key;
        if (entry.value.isEmpty) continue;
        List<String> urls = List<String>.from(_formData[fieldId] is List ? _formData[fieldId] : []);
        for (int i = 0; i < entry.value.length; i++) {
          final file = entry.value[i];
          setState(() {
            _loadingMessage = 'Uploading $fieldId ${i + 1}/${entry.value.length}...';
          });
          final String ext = file.name.split('.').last;
          final String path = 'projects/$folderName/${fieldId}_$i.$ext';
          final url = await FirebaseStorageService.uploadFile(file, path);
          if (url != null) urls.add(url);
        }
        _formData[fieldId] = urls;
      }

      for (var entry in _pickedFiles.entries) {
        if (entry.value == null) continue;
        final String fieldId = entry.key;
        setState(() {
          _loadingMessage = 'Uploading $fieldId...';
        });

        if (fieldId == 'projectVideo') {
          Uint8List? videoBytes;
          if (entry.value is XFile) {
            videoBytes = await (entry.value as XFile).readAsBytes();
          } else if (entry.value is PlatformFile) {
            videoBytes = (entry.value as PlatformFile).bytes;
          }

          if (videoBytes != null) {
            setState(() {
              _loadingMessage = 'Uploading video to YouTube...';
            });
            final youtubeUrl = await YouTubeUploadService.uploadVideoBytes(
              videoBytes: videoBytes,
              title: _formData['propertyName']?.toString() ?? 'Project Video',
              description: 'Project Video uploaded via Property+ App',
              googleUser: authVM.lastGoogleUser,
            );
            if (youtubeUrl != null) {
              _formData[fieldId] = youtubeUrl;
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Video successfully published to YouTube!'), backgroundColor: Colors.green),
                );
              }
              continue;
            } else {
              throw 'YouTube video upload failed. Please check YouTube API quota or credentials.';
            }
          }
          continue;
        }

        String fileName = (entry.value is XFile) ? (entry.value as XFile).name : (entry.value as PlatformFile).name;
        final String ext = fileName.split('.').last;
        final String path = 'projects/$folderName/$fieldId.$ext';
        final url = await FirebaseStorageService.uploadFile(entry.value, path);
        if (url != null) _formData[fieldId] = url;
      }

      // 🚀 NAYA: Save any pending newly added builders to Firestore now
      if (_pendingBuilderNames.isNotEmpty) {
        final rawComp = _formData['projectCompany']?.toString().trim() ?? '';
        final comp = _toTitleCase(rawComp);
        _formData['projectCompany'] = comp;

        for (var rawName in List<String>.from(_pendingBuilderNames)) {
          final name = _toTitleCase(rawName);
          final cpData = {
            'cpName': name,
            'name': name,
            'partnerType': 'Builder',
            'profession': 'Builder',
            'companyNames': comp.isNotEmpty ? [comp] : [],
            'companyName': comp,
            'status': 'Active Partner',
            'isApproved': true,
            'timestamp': FieldValue.serverTimestamp(),
            'createdBy': authVM.actorMetadata,
            'parentUid': authVM.userUid,
            'addedBy': authVM.userName,
          };
          try {
            final docRef = await FirebaseFirestore.instance.collection('cps').add(cpData);
            if (!_selectedBuilderIds.contains(docRef.id)) {
              _selectedBuilderIds.add(docRef.id);
            }
          } catch (e) {
            debugPrint('Error saving pending builder $name: $e');
          }
        }
        _pendingBuilderNames.clear();
      }

      _formData['builderIds'] = _selectedBuilderIds;

      // 🚀 NAYA: Save initial existing custom attachments
      final List<Map<String, String>> initialCustomAttachments = [];
      for (var row in _customAttachmentRows) {
        final String title = (row['titleCtrl'] as TextEditingController).text.trim();
        final String? existingUrl = row['existingUrl'];
        if (title.isNotEmpty && existingUrl != null && existingUrl.isNotEmpty && row['file'] == null) {
          initialCustomAttachments.add({'title': title, 'url': existingUrl});
        }
      }
      _formData['otherAttachments'] = initialCustomAttachments;

      final String projName = _formData['propertyName'] ?? 'New Project';
      final projectVM = Provider.of<ProjectViewModel>(context, listen: false);

      // Save Project Document to Firestore first (instant!)
      await projectVM.addOrUpdateProject(
        id: widget.project?.id,
        projectName: projName,
        propertyType: _formData['propertyType'] ?? 'Project',
        legality: _formData['isReraApproved'] == 'Yes' ? 'RERA Approved' : 'N/A',
        reraId: _formData['reraNumber'] ?? 'N/A',
        contactPerson: _formData['buildersOwnerName'] ?? '',
        contactNumber: '',
        propertyDetails: _formData,
        builderIds: _selectedBuilderIds,
        actorUid: authVM.userUid,
        actorEmail: authVM.userEmail,
        actorName: authVM.userName,
        actorRole: authVM.roleLabel,
      );

      final String hasMediaToUpload = (_pickedMediaLists.values.any((l) => l.isNotEmpty) || _pickedFiles.values.any((f) => f != null) || _customAttachmentRows.any((r) => r['file'] != null))
          ? ' Files uploading in background...'
          : '';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚡ Project saved!$hasMediaToUpload'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        _navigateBackOnCancelOrSave(targetDocId: widget.project?.id ?? _toTitleCase(projName));
      }

      // Background Async Upload
      _uploadProjectMediaInBackground(projName, Map.from(_pickedMediaLists), Map.from(_pickedFiles), List.from(_customAttachmentRows), folderName);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  static Future<void> _uploadProjectMediaInBackground(
    String projectName,
    Map<String, List<dynamic>> pickedMediaLists,
    Map<String, dynamic> pickedFiles,
    List<Map<String, dynamic>> customAttachmentRows,
    String folderName,
  ) async {
    final db = FirebaseFirestore.instance;
    final sanitizeId = projectName.trim().replaceAll('/', '-').replaceAll('\\', '-').replaceAll(RegExp(r'\s+'), ' ');

    try {
      for (var entry in pickedMediaLists.entries) {
        final String fieldId = entry.key;
        if (entry.value.isEmpty) continue;
        for (int i = 0; i < entry.value.length; i++) {
          final file = entry.value[i];
          final String ext = file.name.split('.').last;
          final String path = 'projects/$folderName/${fieldId}_${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
          final url = await FirebaseStorageService.uploadFile(file, path);
          if (url != null) {
            final docSnap = await db.collection('projects').doc(sanitizeId).get();
            if (docSnap.exists) {
              final data = docSnap.data() ?? {};
              final details = Map<String, dynamic>.from(data['propertyDetails'] ?? {});
              List<String> currentUrls = List<String>.from(details[fieldId] is List ? details[fieldId] : []);
              if (!currentUrls.contains(url)) {
                currentUrls.add(url);
                details[fieldId] = currentUrls;
                await db.collection('projects').doc(sanitizeId).update({
                  'propertyDetails': details,
                  fieldId: currentUrls,
                });
              }
            }
          }
        }
      }

      for (var entry in pickedFiles.entries) {
        if (entry.value == null) continue;
        final String fieldId = entry.key;
        String fileName = (entry.value is XFile) ? (entry.value as XFile).name : (entry.value as PlatformFile).name;
        final String ext = fileName.split('.').last;
        final String path = 'projects/$folderName/${fieldId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final url = await FirebaseStorageService.uploadFile(entry.value, path);
        if (url != null) {
          final docSnap = await db.collection('projects').doc(sanitizeId).get();
          if (docSnap.exists) {
            final data = docSnap.data() ?? {};
            final details = Map<String, dynamic>.from(data['propertyDetails'] ?? {});
            details[fieldId] = url;
            await db.collection('projects').doc(sanitizeId).update({
              'propertyDetails': details,
              fieldId: url,
            });
          }
        }
      }

      // 🚀 Upload Custom Attachments ("Others")
      for (int i = 0; i < customAttachmentRows.length; i++) {
        final row = customAttachmentRows[i];
        final String title = (row['titleCtrl'] as TextEditingController).text.trim();
        final dynamic file = row['file'];

        if (file != null) {
          String fileName = (file is XFile) ? file.name : (file as PlatformFile).name;
          final String ext = fileName.split('.').last;
          final String path = 'projects/$folderName/others_${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
          final String? url = await FirebaseStorageService.uploadFile(file, path);
          if (url != null) {
            final docSnap = await db.collection('projects').doc(sanitizeId).get();
            if (docSnap.exists) {
              final data = docSnap.data() ?? {};
              final details = Map<String, dynamic>.from(data['propertyDetails'] ?? {});
              List<dynamic> currentAttachments = List<dynamic>.from(details['otherAttachments'] is List ? details['otherAttachments'] : []);
              currentAttachments.add({'title': title.isNotEmpty ? title : 'Attachment ${i + 1}', 'url': url});
              details['otherAttachments'] = currentAttachments;
              await db.collection('projects').doc(sanitizeId).update({
                'propertyDetails': details,
                'otherAttachments': currentAttachments,
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Background project media upload error: $e");
    }
  }
}
