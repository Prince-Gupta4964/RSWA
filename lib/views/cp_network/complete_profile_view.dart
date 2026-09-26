import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_storage_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/cp_viewmodel.dart';
import '../../utils/cp_form_config.dart';

class CompleteProfileView extends StatefulWidget {
  const CompleteProfileView({super.key});

  @override
  State<CompleteProfileView> createState() => _CompleteProfileViewState();
}

class _CompleteProfileViewState extends State<CompleteProfileView> {
  bool _isSaving = false;
  final Set<String> _expandedSections = {CPFormStrings.sectionBasicInfo};
  final Map<String, dynamic> _formData = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, LayerLink> _layerLinks = {};
  final Map<String, bool> _openDropdowns = {};
  final Map<String, int> _activeChipIndex = {};
  final Map<String, XFile?> _pickedImages = {};
  final ImagePicker _picker = ImagePicker();
  String? _currentFocusedId; // 🚀 NAYA

  static const Color primaryColor = Color(0xFFFBE64E);
  static const Color secondaryColor = Color(0xFF6B5800);

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final userData = authVM.userData ?? {};
    
    _formData['partnerType'] = userData['partnerType'] ?? 'CP';

    for (var section in CPFormStrings.formStructure) {
      for (var field in section['fields']) {
        _initializeField(field, userData);
      }
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

    if (type != 'image') {
      final node = FocusNode();
      node.addListener(() {
        if (node.hasFocus) {
          setState(() {
            _currentFocusedId = id;
          });
        }
      });
      _focusNodes[id] = node;
    }

    if (type != 'chips' && type != 'image' && type != 'switch') {
      final val = (existingData[id] ?? _formData[id] ?? '').toString();
      _controllers[id] = TextEditingController(text: val);
      _formData[id] = val;
      _layerLinks[id] = LayerLink();
    } else if (type == 'chips' || type == 'switch') {
      _formData[id] = existingData[id] ?? _formData[id];
      _activeChipIndex[id] = 0;
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) controller.dispose();
    for (var node in _focusNodes.values) node.dispose();
    super.dispose();
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

  void _toggleSection(String title) {
    setState(() {
      if (_expandedSections.contains(title)) {
        _expandedSections.remove(title);
      } else {
        _expandedSections.add(title);
      }
    });
  }

  String _generateUniqueID() {
    final String name = _controllers['cpName']?.text.trim() ?? '';
    final String surname = _controllers['surname']?.text.trim() ?? '';
    final String first3Name = name.length >= 3 ? name.substring(0, 3).toUpperCase() : name.toUpperCase();
    final String first1Surname = surname.isNotEmpty ? surname[0].toUpperCase() : '';
    final String date = DateFormat('ddMMyy').format(DateTime.now());
    return "$first3Name$first1Surname$date".trim();
  }

  List<String> _getFieldOptions(String fieldId) {
    List<String> staticOptions = [];
    for (var section in CPFormStrings.formStructure) {
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

    final cpVM = Provider.of<CPViewModel>(context, listen: false);
    final learnedData = cpVM.getUniqueValues(fieldId);

    final combined = {...staticOptions, ...learnedData};
    return combined.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        title: const Text('Partner Onboarding', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: primaryColor.withOpacity(0.1),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: secondaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Welcome! Please complete your professional profile to start adding leads.',
                    style: TextStyle(color: secondaryColor.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100, top: 16),
              children: CPFormStrings.formStructure
                .where((s) => s['title'] != CPFormStrings.sectionLoginCredentials)
                .map<Widget>((section) {
                  return _buildSection(section);
                }).toList(),
            ),
          ),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildSection(Map<String, dynamic> section) {
    final String title = section['title'];
    final bool isExpanded = _expandedSections.contains(title);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _toggleSection(title),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isExpanded ? primaryColor.withValues(alpha: 0.1) : Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: isExpanded ? secondaryColor : Colors.grey.shade600,
                    letterSpacing: 1.2,
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
    final String type = field['type'];

    if (type == 'row') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: (field['fields'] as List).map<Widget>((f) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: (field['fields'] as List).last == f ? 0 : 8,
                ),
                child: _buildFieldContent(f),
              ),
            );
          }).toList(),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _buildFieldContent(field),
    );
  }

  Widget _buildFieldContent(Map<String, dynamic> field) {
    final String id = field['id'];
    final String label = field['label'];
    final String type = field['type'];

    if (type == 'image') {
      final img = _pickedImages[id];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _pickImage(id),
            child: Container(
              height: 100, width: double.infinity,
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: img == null 
                ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.camera_alt_outlined, color: Colors.grey), const SizedBox(height: 4), Text('Upload $label', style: const TextStyle(color: Colors.grey, fontSize: 11))])
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: kIsWeb
                        ? Image.network(img.path, fit: BoxFit.cover)
                        : Image.file(File(img.path), fit: BoxFit.cover),
                  ),
            ),
          ),
        ],
      );
    }

    switch (type) {
      case 'dropdown':
      case 'autocomplete':
        return _buildSearchableField(label, id, readOnly: field['readOnly'] ?? false);
      case 'chips':
        return _buildChoiceChips(label, id, List<String>.from(field['options'] ?? []));
      case 'phone':
        return _buildSearchableField(label, id, keyboardType: TextInputType.phone);
      case 'switch':
        return _buildSwitchField(label, id);
      default:
        return _buildSearchableField(label, id, readOnly: field['readOnly'] ?? false);
    }
  }

  Widget _buildSwitchField(String label, String id) {
    bool isSwitched = _formData[id] == 'Yes';
    bool isFocused = _currentFocusedId == id;

    return Focus(
      focusNode: _focusNodes[id],
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
                });
                _focusNodes[id]?.requestFocus();
              },
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _outlinedDecoration(String label, String fieldId) {
    bool isFocused = _currentFocusedId == fieldId;
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
    final LayerLink link = _layerLinks[id]!;

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
                isListOpen = false;
                _openDropdowns[id] = false;
              });
            },
            fieldViewBuilder: (context, textCtrl, fNode, onFieldSubmitted) {
              return TextField(
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
                decoration: _outlinedDecoration(label, id).copyWith(
                  suffixIcon: finalOptions.isNotEmpty ? IconButton(
                    icon: Icon(isListOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        if (isListOpen) {
                          _openDropdowns[id] = false;
                          FocusScope.of(context).unfocus();
                        } else {
                          _openDropdowns[id] = true;
                          fNode.requestFocus();
                        }
                      });
                    },
                  ) : null,
                ),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: CompositedTransformFollower(
                  link: link,
                  showWhenUnlinked: false,
                  offset: const Offset(0, 50),
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
                            title: Text(option, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
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

  Widget _buildChoiceChips(String label, String id, List<String> options) {
    final bool isFocused = _currentFocusedId == id;
    final int activeIdx = _activeChipIndex[id] ?? 0;

    return Focus(
      focusNode: _focusNodes[id],
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

                return ChoiceChip(
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
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
      child: SizedBox(
        width: double.infinity, height: 54,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _handleSave,
          style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)), elevation: 0),
          child: _isSaving 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: secondaryColor, strokeWidth: 2))
            : const Text('SUBMIT FOR VERIFICATION', style: TextStyle(color: secondaryColor, fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    final Map<String, dynamic> updateData = {};
    _controllers.forEach((key, ctrl) {
      if (ctrl.text.trim().isNotEmpty) {
        updateData[key] = ctrl.text.trim();
      }
    });

    if (updateData['cpName'] == null || updateData['cpName'].toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    if (updateData['contactNo'] == null || updateData['contactNo'].toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact number is required')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final authVM = Provider.of<AuthViewModel>(context, listen: false);
      final cpVM = Provider.of<CPViewModel>(context, listen: false);

      // 🚀 NAYA: Upload Picked Images to Firebase
      final String cpName = '${_formData['cpName'] ?? 'cp'}_${DateTime.now().millisecondsSinceEpoch}';
      for (var entry in _pickedImages.entries) {
        if (entry.value != null) {
          final String fieldId = entry.key;
          final XFile file = entry.value!;
          
          final String path = 'profiles/$cpName/$fieldId.jpg';
          final String? url = await FirebaseStorageService.uploadFile(file, path);
          
          if (url != null && url.isNotEmpty) {
            _formData[fieldId] = url;
          }
        }
      }

      _formData.forEach((key, val) {
        if (key == 'profilePhoto' || key == 'aadharCard' || key == 'panCard' || key == 'partnerType') {
          updateData[key] = val;
        }
      });
      
      updateData['isProfileComplete'] = true;
      updateData['status'] = 'Pending Approval';
      updateData['referralCode'] = updateData['contactNo'] ?? '';
      updateData['cpID'] = _generateUniqueID();

      await cpVM.addOrUpdateCP(updateData, id: authVM.userUid, actorMetadata: authVM.actorMetadata);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile submitted! Account is now under verification.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
