import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_storage_service.dart';
import '../../services/contact_picker_service.dart';
import '../../viewmodels/lead_viewmodel.dart';
import '../../viewmodels/cp_viewmodel.dart';
import '../../viewmodels/project_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/app_configuration_viewmodel.dart';
import '../../models/lead_model.dart';
import '../../utils/lead_form_config.dart';
import '../../utils/role_permissions.dart';

class AddLeadView extends StatefulWidget {
  final LeadModel? lead;

  const AddLeadView({super.key, this.lead});

  @override
  State<AddLeadView> createState() => _AddLeadViewState();
}

class _AddLeadViewState extends State<AddLeadView> {
  bool _isSaving = false;
  final Set<String> _expandedSections = {LeadFormStrings.sectionBasicInfo};

  final Map<String, dynamic> _formData = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, LayerLink> _layerLinks = {};
  final Map<String, bool> _openDropdowns = {}; 
  final List<String> _flatFields = [];
  String? _currentFocusedId;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {}; 

  final Map<String, int> _activeChipIndex = {};
  final Map<String, XFile?> _pickedImages = {};
  final ImagePicker _picker = ImagePicker();

  static const Color primaryColor = Color(0xFFFBE64E);
  static const Color secondaryColor = Color(0xFF6B5800);

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
    _initializeData();
  }

  void _initializeData() {
    final existingData = widget.lead?.rawData ?? {};
    final authVM = Provider.of<AuthViewModel>(context, listen: false);

    _formData['leadType'] = existingData['leadType'] ?? 'Client';
    _formData['status'] = existingData['status'] ?? 'Cold';
    _formData['source'] = existingData['source'] ?? 'Walk In';
    _formData['gender'] = existingData['gender'] ?? 'Male';
    _formData['demoDone'] = existingData['demoDone'] ?? 'No';
    _formData['propertyType'] = existingData['propertyType'] ?? '1BHK';
    _formData['coupon'] = existingData['coupon'] ?? 'No';
    _formData['sendProjectDetails'] = existingData['sendProjectDetails'] ?? 'No';

    if (widget.lead == null && authVM.appRole == AppRole.cp) {
      _formData['referralName1'] = authVM.userName;
      _formData['source'] = 'Referral';
    }

    for (var section in LeadFormStrings.formStructure) {
      for (var field in section['fields']) {
        _initializeField(field, existingData);
      }
    }

    if (widget.lead == null) {
      final now = DateTime.now();
      final formatter = DateFormat('dd MMM yyyy, hh:mm a');
      _controllers['timestamp']?.text = formatter.format(now);
      _formData['timestamp'] = now;
    } else {
      if (existingData['timestamp'] is Timestamp) {
        final date = (existingData['timestamp'] as Timestamp).toDate();
        _controllers['timestamp']?.text = DateFormat('dd MMM yyyy, hh:mm a').format(date);
      }
    }

    if (_flatFields.isNotEmpty && widget.lead == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNodes['company']?.requestFocus();
      });
    }
  }

  void _initializeField(Map<String, dynamic> field, Map<String, dynamic> existingData) {
    if (field['type'] == 'row') {
      for (var subField in field['fields']) {
        _initializeField(subField, existingData);
      }
      return;
    }

    final String id = field['id'];
    final String type = field['type'];

    if (!_flatFields.contains(id) && type != 'image') {
      _flatFields.add(id);
      _layerLinks[id] = LayerLink();
      final node = FocusNode();
      node.addListener(() {
        if (node.hasFocus) {
          setState(() {
            _currentFocusedId = id;
          });
          Future.delayed(const Duration(milliseconds: 100), () {
            final context = node.context;
            if (context != null && mounted) {
              Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 300), alignment: 0.2);
            }
          });
        }
      });
      _focusNodes[id] = node;
    }

    if (type != 'chips' && type != 'image' && type != 'switch') {
      _controllers[id] = TextEditingController(text: (existingData[id] ?? _formData[id] ?? '').toString());
      _formData[id] = existingData[id] ?? _formData[id] ?? '';
    } else if (type == 'chips' || type == 'switch') {
      var val = existingData[id] ?? _formData[id];
      if (type == 'switch' && val is int) {
        val = val == 1 ? 'Yes' : 'No';
      }
      _formData[id] = val;
      _activeChipIndex[id] = 0;
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    for (var node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _toggleSection(String title) {
    setState(() {
      if (_expandedSections.contains(title)) {
        _expandedSections.remove(title);
      } else {
        _expandedSections.add(title);
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
    final allTitles = LeadFormStrings.formStructure.map((s) => s['title'] as String).toList();
    setState(() {
      if (_expandedSections.length == allTitles.length) {
        _expandedSections.clear();
      } else {
        _expandedSections.clear();
        _expandedSections.addAll(allTitles);
      }
    });
  }

  List<String> _getFieldOptions(String fieldId) {
    List<String> staticOptions = [];
    for (var section in LeadFormStrings.formStructure) {
      for (var field in section['fields']) {
        if (field['type'] == 'row') {
          for (var sub in field['fields']) {
            if (sub['id'] == fieldId) {
              staticOptions = List<String>.from(sub['options'] ?? []);
            }
          }
        } else if (field['id'] == fieldId) {
          staticOptions = List<String>.from(field['options'] ?? []);
        }
      }
    }

    final leadVM = Provider.of<LeadViewModel>(context, listen: false);
    final learnedData = leadVM.getUniqueValues(fieldId);

    final fieldType = _getFieldType(fieldId);
    if (fieldType == 'project_dropdown') {
      final projectVM = Provider.of<ProjectViewModel>(context, listen: false);
      staticOptions = projectVM.projects.map((p) => p.projectName).where((s) => s.isNotEmpty).toList();
      for (var l in leadVM.leads) {
        final proj = l.rawData['project']?.toString().trim() ?? '';
        if (proj.isNotEmpty && !staticOptions.contains(proj)) staticOptions.add(proj);
      }
    } else if (fieldType == 'cp_dropdown') {
      final cpVM = Provider.of<CPViewModel>(context, listen: false);
      staticOptions = cpVM.cps.map((c) => c.cpName).where((s) => s.isNotEmpty).toList();
      for (var l in leadVM.leads) {
        final src = l.rawData['source']?.toString().trim() ?? '';
        if (src.isNotEmpty && !staticOptions.contains(src)) staticOptions.add(src);
        final adv = l.rawData['advisor']?.toString().trim() ?? '';
        if (adv.isNotEmpty && !staticOptions.contains(adv)) staticOptions.add(adv);
        final ref = l.rawData['referralName1']?.toString().trim() ?? '';
        if (ref.isNotEmpty && !staticOptions.contains(ref)) staticOptions.add(ref);
      }
    }

    if (fieldId == 'status') {
      final configVM = Provider.of<AppConfigurationViewModel>(context, listen: false);
      staticOptions = configVM.leadStatuses;
    } else if (staticOptions.isEmpty) {
      final configVM = Provider.of<AppConfigurationViewModel>(context, listen: false);
      staticOptions = configVM.getOptionsForField('Lead Form', fieldId, staticOptions);
    }

    final combined = {...staticOptions, ...learnedData};
    return combined.toList()..sort();
  }

  void _focusNextField({bool isDoubleClick = false}) {
    if (_currentFocusedId == null && _flatFields.isNotEmpty) {
      _navigateToField(_flatFields.first);
      return;
    }

    final String currentId = _currentFocusedId!;
    final fieldType = _getFieldType(currentId);

    if (!isDoubleClick && fieldType != 'chips' && fieldType != 'date' && fieldType != 'time' && fieldType != 'switch') {
      final ctrl = _controllers[currentId];
      if (ctrl != null && ctrl.text.isNotEmpty) {
        final query = ctrl.text.toLowerCase();
        final options = _getFieldOptions(currentId);
        final matches = options.where((opt) => opt.toLowerCase().contains(query)).toList();
        if (matches.isNotEmpty) {
          final match = matches.first;
          if (ctrl.text != match) {
            setState(() {
              ctrl.value = TextEditingValue(
                text: match,
                selection: TextSelection.collapsed(offset: match.length),
              );
              _formData[currentId] = match;
            });
            return;
          }
        }
      }
    }

    if (fieldType == 'chips' && !isDoubleClick) {
      final options = _getChipOptions(currentId);
      int currentIndex = _activeChipIndex[currentId] ?? 0;
      if (currentIndex < options.length - 1) {
        setState(() {
          _activeChipIndex[currentId] = currentIndex + 1;
          _formData[currentId] = options[currentIndex + 1];
        });
        return;
      }
    }

    final currentIndex = _flatFields.indexOf(currentId);
    if (currentIndex != -1) {
      for (int i = currentIndex + 1; i < _flatFields.length; i++) {
        if (_isFieldVisible(_flatFields[i])) {
          _navigateToField(_flatFields[i]);
          return;
        }
      }
    }
  }

  void _focusPrevField() {
    if (_currentFocusedId == null) return;

    final String currentId = _currentFocusedId!;
    final fieldType = _getFieldType(currentId);

    if (fieldType == 'chips') {
      final options = _getChipOptions(currentId);
      int currentIndex = _activeChipIndex[currentId] ?? 0;
      if (currentIndex > 0) {
        setState(() {
          _activeChipIndex[currentId] = currentIndex - 1;
          _formData[currentId] = options[currentIndex - 1];
        });
        return;
      }
    }

    final currentIndex = _flatFields.indexOf(currentId);
    if (currentIndex > 0) {
      for (int i = currentIndex - 1; i >= 0; i--) {
        if (_isFieldVisible(_flatFields[i])) {
          _navigateToField(_flatFields[i]);
          return;
        }
      }
    }
  }

  String? _getFieldType(String fieldId) {
    for (var section in LeadFormStrings.formStructure) {
      for (var field in section['fields']) {
        if (field['type'] == 'row') {
          for (var sub in field['fields']) {
            if (sub['id'] == fieldId) return sub['type'];
          }
        } else if (field['id'] == fieldId) {
          return field['type'];
        }
      }
    }
    return null;
  }

  List<String> _getChipOptions(String fieldId) {
    final configVM = Provider.of<AppConfigurationViewModel>(context, listen: false);
    for (var section in LeadFormStrings.formStructure) {
      for (var field in section['fields']) {
        if (field['id'] == fieldId) {
          if (field['dynamicStatus'] == true) {
            return configVM.leadStatuses;
          }
          final defaultOpts = List<String>.from(field['options'] ?? []);
          return configVM.getOptionsForField('Lead Form', fieldId, defaultOpts);
        }
      }
    }
    return [];
  }

  bool _isFieldVisible(String fieldId) {
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    
    Map<String, dynamic>? config;
    for (var section in LeadFormStrings.formStructure) {
      for (var field in section['fields']) {
        if (field['type'] == 'row') {
          for (var sub in field['fields']) {
            if (sub['id'] == fieldId) config = sub;
          }
        } else if (field['id'] == fieldId) {
          config = field;
        }
      }
    }

    if (config == null) return true;

    if (config.containsKey('hideIf')) {
      final String hideIf = config['hideIf'];
      if (hideIf == 'role != super_admin' && authVM.appRole != AppRole.superAdmin) return false;
      if (hideIf == 'role == cp' && authVM.appRole == AppRole.cp) return false;
    }

    if (config.containsKey('visibleIf')) {
      final String visibleIf = config['visibleIf'];
      if (visibleIf.contains(' == ')) {
        final parts = visibleIf.split(' == ');
        if (_formData[parts[0]] != parts[1]) return false;
      } else if (visibleIf.contains(' != ')) {
        final parts = visibleIf.split(' != ');
        if (_formData[parts[0]] == parts[1]) return false;
      }
    }

    return true;
  }

  void _navigateToField(String fieldId) {
    String? targetSectionTitle;
    for (var section in LeadFormStrings.formStructure) {
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
        final textTypes = ['text', 'autocomplete', 'dropdown', 'multiline', 'number', 'phone', 'project_dropdown', 'cp_dropdown'];
        if (textTypes.contains(type) && !kIsWeb) {
          SystemChannels.textInput.invokeMethod('textInput.show');
        }
      }
    });
  }

  bool _isFieldInSection(List<dynamic> fields, String fieldId) {
    for (var f in fields) {
      if (f['type'] == 'row') {
        if (_isFieldInSection(f['fields'], fieldId)) return true;
      } else if (f['id'] == fieldId) {
        return true;
      }
    }
    return false;
  }

  Future<void> _pickImage(String fieldId) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1280, maxHeight: 1280);
    if (image != null) {
      setState(() {
        _pickedImages[fieldId] = image;
        _formData[fieldId] = image.path;
      });
    }
  }

  Future<void> _pickNumberFromContacts(String fieldId) async {
    try {
      final results = await ContactPickerService.pickContacts(
        context: context,
        multiple: false,
      );

      if (results.isNotEmpty && mounted) {
        final selectedNumber = results.first['tel'];
        if (selectedNumber != null) {
          setState(() {
            final clean = selectedNumber.replaceAll(RegExp(r'\s+'), '');
            _controllers[fieldId]?.text = clean;
            _formData[fieldId] = clean;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  String _generateUniqueID() {
    final String name = _controllers['name']?.text.trim() ?? '';
    final String surname = _controllers['surname']?.text.trim() ?? '';
    final String first3Name = name.length >= 3 ? name.substring(0, 3).toUpperCase() : name.toUpperCase();
    final String first1Surname = surname.isNotEmpty ? surname[0].toUpperCase() : '';
    final String date = DateFormat('ddMMyy').format(DateTime.now());
    return "$first3Name$first1Surname$date".trim();
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.lead != null;

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/dashboard');
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: primaryColor,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => context.go('/dashboard'),
          ),
          title: const Text(
            'Client Form',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 20),
              children: LeadFormStrings.formStructure.map<Widget>((section) {
                return _buildSection(section);
              }).toList(),
            ),
          ),
          _buildStickyNavigation(isEditing),
        ],
      ),
    ));
  }

  Widget _buildSection(Map<String, dynamic> section) {
    final String title = section['title'];
    final bool isExpanded = _expandedSections.contains(title);
    final key = _sectionKeys.putIfAbsent(title, () => GlobalKey());

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
              color: isExpanded ? primaryColor.withValues(alpha: 0.1) : Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: isExpanded ? secondaryColor : Colors.grey,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
            child: Column(
              children: (section['fields'] as List).map<Widget>((field) {
                return _buildDynamicField(field);
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildDynamicField(Map<String, dynamic> field) {
    final String id = field['id'] ?? '';
    if (id.isNotEmpty && !_isFieldVisible(id)) return const SizedBox.shrink();

    final String type = field['type'];

    if (type == 'row') {
      bool anyVisible = false;
      for (var f in field['fields']) {
        if (_isFieldVisible(f['id'])) anyVisible = true;
      }
      if (!anyVisible) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: (field['fields'] as List).map<Widget>((f) {
            if (!_isFieldVisible(f['id'])) return const SizedBox.shrink();
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: (field['fields'] as List).last == f ? 0 : 12,
                ),
                child: _buildFieldContent(f),
              ),
            );
          }).toList(),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _buildFieldContent(field),
    );
  }

  Widget _buildFieldContent(Map<String, dynamic> field) {
    final String id = field['id'] ?? '';
    final String label = field['label'];
    final String type = field['type'];
    final authVM = Provider.of<AuthViewModel>(context, listen: false);

    bool isLockedCPField = id == 'referralName1' && authVM.appRole == AppRole.cp;

    switch (type) {
      case 'project_dropdown':
      case 'cp_dropdown':
      case 'dropdown':
      case 'autocomplete':
        return _buildSearchableField(label, id, readOnly: isLockedCPField || (field['readOnly'] ?? false));
      case 'chips':
        if (field['dynamicStatus'] == true) return _buildStatusChips(label, id);
        return _buildChoiceChips(label, id, List<String>.from(field['options'] ?? []));
      case 'phone':
        return _buildSearchableField(label, id, keyboardType: TextInputType.phone);
      case 'number':
        return _buildSearchableField(label, id, keyboardType: TextInputType.number);
      case 'multiline':
        return _buildSearchableField(label, id, maxLines: 3);
      case 'date':
        return _buildDateField(label, id);
      case 'time':
        return _buildTimeField(label, id);
      case 'image':
        return _buildImagePicker(label, id);
      case 'switch':
        return _buildSwitchField(label, id);
      default:
        return _buildSearchableField(label, id, readOnly: field['readOnly'] ?? false);
    }
  }

  Widget _buildSwitchField(String label, String id) {
    bool isSwitched = _formData[id] == 'Yes';
    bool isFocused = _currentFocusedId == id;
    final authVM = Provider.of<AuthViewModel>(context, listen: false);

    return Focus(
      focusNode: _focusNodes[id],
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.space)) {
          setState(() {
            _formData[id] = isSwitched ? 'No' : 'Yes';
            if (id == 'demoDone' && _formData[id] == 'Yes') {
               _formData['demoBy'] = authVM.userName;
               _controllers['demoBy']?.text = authVM.userName;
            }
          });
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isFocused ? secondaryColor : const Color(0xFFCCCCCC),
            width: isFocused ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
            Switch(
              value: isSwitched,
              activeColor: secondaryColor,
              activeTrackColor: primaryColor.withValues(alpha: 0.5),
              onChanged: (value) {
                setState(() {
                  _formData[id] = value ? 'Yes' : 'No';
                  _currentFocusedId = id;
                  if (id == 'demoDone' && value) {
                     _formData['demoBy'] = authVM.userName;
                     _controllers['demoBy']?.text = authVM.userName;
                  }
                });
                _focusNodes[id]?.requestFocus();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker(String label, String id) {
    final image = _pickedImages[id];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _pickImage(id),
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: image == null
                ? const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt_outlined, color: Colors.grey, size: 32),
                SizedBox(height: 8),
                Text('Tap to select image', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            )
                : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: kIsWeb
                  ? Image.network(image.path, fit: BoxFit.cover)
                  : Image.file(File(image.path), fit: BoxFit.cover),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _outlinedDecoration(String label, String fieldId) {
    return InputDecoration(
      labelText: label,
      alignLabelWithHint: true,
      labelStyle: const TextStyle(fontSize: 15, color: Color(0xFF555555), fontWeight: FontWeight.w400),
      floatingLabelStyle: const TextStyle(color: secondaryColor, fontWeight: FontWeight.bold, fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFCCCCCC), width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: secondaryColor, width: 1.5),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
    );
  }

  Widget _buildSearchableField(String label, String id, {TextInputType? keyboardType, int maxLines = 1, bool readOnly = false}) {
    final List<String> finalOptions = _getFieldOptions(id);
    final TextEditingController controller = _controllers[id]!;
    final FocusNode focusNode = _focusNodes[id]!;
    final LayerLink link = _layerLinks[id] ??= LayerLink();

    bool optionSelected = false;
    bool isListOpen = _openDropdowns[id] ?? false; 

    return LayoutBuilder(
      builder: (context, constraints) {
        return CompositedTransformTarget(
          link: link,
          child: RawAutocomplete<String>(
            focusNode: focusNode,
            textEditingController: controller,
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty && !isListOpen) return const Iterable<String>.empty();
              if (textEditingValue.text.isEmpty) return finalOptions;
              return finalOptions.where((String option) =>
                  option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
            },
            onSelected: (String selection) {
              setState(() {
                controller.text = selection;
                _formData[id] = selection;
                _openDropdowns[id] = false; 
              });
              optionSelected = true;
              _focusNextField();
            },
            fieldViewBuilder: (context, textCtrl, fNode, onFieldSubmitted) {
              return Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowRight) {
                    if (textCtrl.selection.baseOffset == textCtrl.text.length) {
                      final query = textCtrl.text.toLowerCase();
                      if (query.isNotEmpty) {
                        final matches = finalOptions.where((opt) => opt.toLowerCase().contains(query)).toList();
                        if (matches.isNotEmpty) {
                          final match = matches.first;
                          if (textCtrl.text != match) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setState(() {
                                controller.value = TextEditingValue(
                                  text: match,
                                  selection: TextSelection.collapsed(offset: match.length),
                                );
                                _formData[id] = match;
                              });
                            });
                            return KeyEventResult.handled;
                          }
                        }
                      }
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  controller: textCtrl,
                  focusNode: fNode,
                  readOnly: readOnly,
                  keyboardType: keyboardType,
                  maxLines: maxLines,
                  style: const TextStyle(fontSize: 15),
                  textInputAction: TextInputAction.next,
                  onChanged: (val) {
                    _formData[id] = val;
                  },
                  onTap: () {
                    if (textCtrl.text.isEmpty) {
                      textCtrl.text = ' ';
                      textCtrl.text = '';
                    }
                  },
                  onSubmitted: (_) {
                    optionSelected = false;
                    onFieldSubmitted();
                    Future.delayed(const Duration(milliseconds: 50), () {
                      if (!optionSelected) {
                        _focusNextField();
                      }
                    });
                  },
                  decoration: _outlinedDecoration(label, id).copyWith(
                    suffixIcon: (id == 'whatsapp' || id == 'contact2') 
                      ? IconButton(
                          icon: const Icon(Icons.contact_phone_outlined, color: Color(0xFFFF6B22)),
                          onPressed: () => _pickNumberFromContacts(id),
                        )
                      : (finalOptions.isNotEmpty ? IconButton(
                          icon: Icon(isListOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down, color: Colors.grey),
                          onPressed: () {
                            setState(() {
                              if (isListOpen) {
                                _openDropdowns[id] = false;
                                FocusScope.of(context).unfocus();
                              } else {
                                _openDropdowns[id] = true;
                                fNode.requestFocus();
                                final currentText = textCtrl.text;
                                textCtrl.text = '$currentText ';
                                textCtrl.text = currentText;
                              }
                            });
                          },
                        ) : null),
                  ),
                ),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              final String query = controller.text.trim().toLowerCase();
              return Align(
                alignment: Alignment.topLeft,
                child: CompositedTransformFollower(
                  link: link,
                  showWhenUnlinked: false,
                  offset: const Offset(0, 52),
                  child: Material(
                    elevation: 16,
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                    child: Container(
                      width: constraints.maxWidth,
                      constraints: const BoxConstraints(maxHeight: 280),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300, width: 1.5),
                      ),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                        itemBuilder: (context, index) {
                          final String option = options.elementAt(index);
                          final int highlightIndex = AutocompleteHighlightedOption.of(context);
                          final bool isHighlighted = highlightIndex == index || (highlightIndex == -1 && index == 0); 

                          return ListTile(
                            dense: true,
                            tileColor: isHighlighted ? primaryColor.withValues(alpha: 0.3) : null,
                            title: _highlightText(option, query),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStatusChips(String label, String id) {
    return Consumer<AppConfigurationViewModel>(
      builder: (context, configVM, child) {
        return _buildChoiceChips(label, id, configVM.leadStatuses);
      },
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
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() {
                  _activeChipIndex[id] = currentIndex + 1;
                  _formData[id] = options[currentIndex + 1];
                });
              });
            } else {
              WidgetsBinding.instance.addPostFrameCallback((_) => _focusNextField());
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            final int currentIndex = _activeChipIndex[id] ?? 0;
            if (currentIndex > 0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() {
                  _activeChipIndex[id] = currentIndex - 1;
                  _formData[id] = options[currentIndex - 1];
                });
              });
            } else {
              WidgetsBinding.instance.addPostFrameCallback((_) => _focusPrevField());
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
            final int currentIndex = _activeChipIndex[id] ?? 0;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _formData[id] = options[currentIndex];
              });
              _focusNextField();
            });
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
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.asMap().entries.map((entry) {
                int idx = entry.key;
                String opt = entry.value;
                final bool isSelected = _formData[id] == opt;
                final bool isHighlighted = isFocused && activeIdx == idx;

                return GestureDetector(
                  onDoubleTap: () {
                    setState(() {
                      _formData[id] = opt;
                      _activeChipIndex[id] = idx;
                      _currentFocusedId = id;
                    });
                    _focusNextField();
                  },
                  child: ChoiceChip(
                    label: Text(opt, style: TextStyle(fontSize: 12, color: isSelected || isHighlighted ? Colors.black : Colors.black87, fontWeight: isSelected || isHighlighted ? FontWeight.bold : FontWeight.normal)),
                    selected: isSelected || isHighlighted,
                    selectedColor: isHighlighted ? primaryColor : primaryColor.withValues(alpha: 0.6),
                    backgroundColor: const Color(0xFFF5F5F5),
                    checkmarkColor: Colors.black,
                    onSelected: (val) {
                      setState(() {
                        _formData[id] = val ? opt : null;
                        _activeChipIndex[id] = idx;
                        _currentFocusedId = id;
                      });
                      _focusNodes[id]!.requestFocus();
                    },
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: isHighlighted ? const BorderSide(color: secondaryColor, width: 1.5) : BorderSide.none
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField(String label, String id) {
    return TextField(
      controller: _controllers[id],
      focusNode: _focusNodes[id],
      readOnly: true,
      style: const TextStyle(fontSize: 15),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
        );
        if (date != null) {
          final formatted = "${date.day}/${date.month}/${date.year}";
          setState(() {
            _controllers[id]!.text = formatted;
            _formData[id] = formatted;
          });
          _focusNextField();
        }
      },
      decoration: _outlinedDecoration(label, id).copyWith(suffixIcon: const Icon(Icons.calendar_today, size: 18)),
    );
  }

  Widget _buildTimeField(String label, String id) {
    return TextField(
      controller: _controllers[id],
      focusNode: _focusNodes[id],
      readOnly: true,
      style: const TextStyle(fontSize: 15),
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );
        if (time != null) {
          if (!mounted) return;
          final formatted = time.format(context);
          setState(() {
            _controllers[id]!.text = formatted;
            _formData[id] = formatted;
          });
          _focusNextField();
        }
      },
      decoration: _outlinedDecoration(label, id).copyWith(suffixIcon: const Icon(Icons.access_time, size: 18)),
    );
  }

  Widget _highlightText(String text, String query) {
    if (query.isEmpty) return Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87));
    final List<TextSpan> spans = [];
    final String lowerText = text.toLowerCase();
    final String lowerQuery = query.toLowerCase();
    int start = 0;
    int indexOfMatch;

    while ((indexOfMatch = lowerText.indexOf(lowerQuery, start)) != -1) {
      if (indexOfMatch > start) {
        spans.add(TextSpan(text: text.substring(start, indexOfMatch), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13)));
      }
      spans.add(TextSpan(text: text.substring(indexOfMatch, indexOfMatch + query.length), style: const TextStyle(color: secondaryColor, fontWeight: FontWeight.w900, fontSize: 13)));
      start = indexOfMatch + query.length;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13)));
    }
    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildStickyNavigation(bool isEditing) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: _buildNavButton(Icons.arrow_back_rounded, _focusPrevField),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: GestureDetector(
                onDoubleTap: () => _focusNextField(isDoubleClick: true),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: secondaryColor))
                      : Text(
                      isEditing ? 'Update Client' : 'Save Client',
                      style: const TextStyle(color: secondaryColor, fontWeight: FontWeight.bold, fontSize: 13)
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: GestureDetector(
                onDoubleTap: () {
                  _focusNextField(isDoubleClick: true);
                },
                child: _buildNavButton(Icons.arrow_forward_rounded, _focusNextField),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Icon(icon, color: secondaryColor, size: 22),
      ),
    );
  }

  Future<void> _handleSave() async {
    _controllers.forEach((id, ctrl) {
      final type = _getFieldType(id);
      final textTypes = ['text', 'autocomplete', 'dropdown', 'multiline', 'number', 'phone', 'project_dropdown', 'cp_dropdown'];
      if (textTypes.contains(type) || type == null) {
        _formData[id] = ctrl.text.trim();
      }
    });

    if (_formData['name'] == null || _formData['name'].toString().trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }

    // 🚀 NAYA: Robust multi-field Phone and Email duplicate checking
    String digitsOnly(String p) => p.replaceAll(RegExp(r'[^0-9]'), '');
    bool isSamePhone(String p1, String p2) {
      final d1 = digitsOnly(p1);
      final d2 = digitsOnly(p2);
      if (d1.length < 7 || d2.length < 7) return false;
      final sub1 = d1.length >= 10 ? d1.substring(d1.length - 10) : d1;
      final sub2 = d2.length >= 10 ? d2.substring(d2.length - 10) : d2;
      return sub1 == sub2;
    }

    List<String> getPhoneNumbers(Map<String, dynamic> raw) {
      List<String> list = [];
      for (var k in ['whatsapp', 'phone', 'contactNo', 'contact2', 'mobile', 'clientPhone']) {
        final v = (raw[k] ?? '').toString().trim();
        if (v.isNotEmpty) list.add(v);
      }
      return list;
    }

    List<String> getEmails(Map<String, dynamic> raw) {
      List<String> list = [];
      for (var k in ['email', 'emailAddress', 'email_login']) {
        final v = (raw[k] ?? '').toString().trim().toLowerCase();
        if (v.isNotEmpty) list.add(v);
      }
      return list;
    }

    final leadVM = Provider.of<LeadViewModel>(context, listen: false);
    final currentPhones = getPhoneNumbers(_formData);
    final currentEmails = getEmails(_formData);
    final String? currentLeadId = widget.lead?.id;

    for (var existingLead in leadVM.leads) {
      if (currentLeadId != null && existingLead.id == currentLeadId) continue;
      final exPhones = getPhoneNumbers(existingLead.rawData);
      final exEmails = getEmails(existingLead.rawData);

      for (var cp in currentPhones) {
        for (var ep in exPhones) {
          if (isSamePhone(cp, ep)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ This phone number ($cp) already exists for lead "${existingLead.name}"!'),
                backgroundColor: Colors.red.shade800,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
            return;
          }
        }
      }

      for (var ce in currentEmails) {
        for (var ee in exEmails) {
          if (ce == ee) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ This email address ($ce) already exists for lead "${existingLead.name}"!'),
                backgroundColor: Colors.red.shade800,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
            return;
          }
        }
      }
    }

    setState(() => _isSaving = true);
    try {
      final authVM = Provider.of<AuthViewModel>(context, listen: false);
      final String leadName = '${_formData['leadName'] ?? 'lead'}_${DateTime.now().millisecondsSinceEpoch}';

      final String targetLeadId = widget.lead?.id ?? _generateUniqueID();
      _formData['leadID'] = targetLeadId;

      final leadVM = Provider.of<LeadViewModel>(context, listen: false);

      // Save Lead Document to Firestore first (instant!)
      await leadVM.addOrUpdateLead(
        _formData,
        id: widget.lead?.id,
        actorMetadata: authVM.actorMetadata,
      );

      final String hasMediaToUpload = _pickedImages.values.any((f) => f != null)
          ? ' Photos uploading in background...'
          : '';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚡ Client saved!$hasMediaToUpload'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        context.go('/dashboard');
      }

      // Non-blocking background uploads
      _uploadLeadMediaInBackground(targetLeadId, Map.from(_pickedImages), leadName);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  static Future<void> _uploadLeadMediaInBackground(
    String leadDocId,
    Map<String, XFile?> pickedImages,
    String leadName,
  ) async {
    final db = FirebaseFirestore.instance;
    try {
      for (var entry in pickedImages.entries) {
        if (entry.value != null) {
          final String fieldId = entry.key;
          final XFile file = entry.value!;
          final String path = 'leads/$leadName/${fieldId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final String? url = await FirebaseStorageService.uploadFile(file, path);
          if (url != null && url.isNotEmpty) {
            await db.collection('leads').doc(leadDocId).update({
              fieldId: url,
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Background lead media upload error: $e");
    }
  }
}
