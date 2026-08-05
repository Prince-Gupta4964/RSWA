import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/lead_viewmodel.dart';
import '../../viewmodels/cp_viewmodel.dart';
import '../../viewmodels/project_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/app_configuration_viewmodel.dart';
import '../../models/lead_model.dart';
import '../../utils/lead_form_config.dart';

class AddLeadView extends StatefulWidget {
  final LeadModel? lead;

  const AddLeadView({super.key, this.lead});

  @override
  State<AddLeadView> createState() => _AddLeadViewState();
}

class _AddLeadViewState extends State<AddLeadView> {
  bool _isSaving = false;
  bool _showContact2 = false;
  final Set<String> _expandedSections = {"Basic Info"}; // Basic Info expanded by default

  final Map<String, dynamic> _formData = {};
  final Map<String, TextEditingController> _controllers = {};
  
  // Theme Color: Mango Yellow
  static const Color primaryColor = Color(0xFFFFC324);

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    final existingData = widget.lead?.rawData ?? {};
    
    // Default initial states
    _formData['company'] = existingData['company'] ?? '';
    _formData['subCompany'] = existingData['subCompany'] ?? '';
    _formData['leadType'] = existingData['leadType'] ?? 'Client';
    _formData['status'] = existingData['status'] ?? 'Cold';
    _formData['source'] = existingData['source'] ?? 'Walk In';
    _formData['gender'] = existingData['gender'] ?? 'Male';
    _formData['demoDone'] = existingData['demoDone'] ?? 'N';
    _formData['propertyType'] = existingData['propertyType'] ?? '1BHK';

    if (existingData['contact2'] != null && existingData['contact2'].toString().isNotEmpty) {
      _showContact2 = true;
    }

    for (var section in LeadFormStrings.formStructure) {
      _processFields(section['fields'], existingData);
    }
  }

  void _processFields(List<dynamic> fields, Map<String, dynamic> existingData) {
    for (var field in fields) {
      if (field['type'] == 'row') {
        _processFields(field['fields'], existingData);
        continue;
      }

      final String id = field['id'];
      final String type = field['type'];
      
      if (type == 'text' || type == 'phone_plus' || type == 'phone_hidden' || type == 'multiline' || 
          type == 'number' || type == 'date' || type == 'time' || type == 'autocomplete') {
        _controllers[id] = TextEditingController(text: (existingData[id] ?? '').toString());
        _formData[id] = existingData[id] ?? '';
      } else if (type == 'project_dropdown' || type == 'dropdown' || type == 'chips' || type == 'cp_dropdown') {
        _formData[id] = existingData[id] ?? _formData[id];
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.lead != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isEditing ? 'Update Details' : 'Add New Lead',
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: LeadFormStrings.formStructure.map((section) {
                return _buildSection(section);
              }).toList(),
            ),
          ),
          _buildBottomAction(isEditing),
        ],
      ),
    );
  }

  Widget _buildSection(Map<String, dynamic> section) {
    final String title = section['title'];
    final bool isExpanded = _expandedSections.contains(title);

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedSections.remove(title);
              } else {
                _expandedSections.add(title);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isExpanded ? primaryColor.withValues(alpha: 0.1) : Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isExpanded ? primaryColor : Colors.grey.shade600,
                    letterSpacing: 1.1,
                  ),
                ),
                const Spacer(),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: isExpanded ? primaryColor : Colors.grey,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: (section['fields'] as List).map((field) => _buildDynamicField(field)).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildDynamicField(Map<String, dynamic> field) {
    final String type = field['type'];

    if (type == 'row') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: (field['fields'] as List).map<Widget>((f) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: (field['fields'] as List).last == f ? 0 : 8,
                ),
                child: _buildDynamicFieldContent(f),
              ),
            );
          }).toList(),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _buildDynamicFieldContent(field),
    );
  }

  Widget _buildDynamicFieldContent(Map<String, dynamic> field) {
    final String id = field['id'];
    final String label = field['label'];
    final String type = field['type'];

    if (field.containsKey('visibleIf')) {
      final cond = field['visibleIf'].toString().split(' == ');
      if (cond.length == 2) {
        if (_formData[cond[0]] != cond[1]) return const SizedBox.shrink();
      }
    }

    switch (type) {
      case 'project_dropdown':
        return _buildProjectDropdown(label, id);
      case 'cp_dropdown':
        return _buildCPDropdown(label, id);
      case 'dropdown':
        return _buildSearchableField(label, id, options: List<String>.from(field['options'] ?? []));
      case 'chips':
        if (field['dynamicStatus'] == true) return _buildStatusChips(label, id);
        return _buildChoiceChips(label, id, List<String>.from(field['options'] ?? []));
      case 'phone_plus':
        return _buildPhoneWithPlus(label, id);
      case 'phone_hidden':
        return Visibility(
          visible: _showContact2,
          child: _buildTextField(label, id, keyboardType: TextInputType.phone)
        );
      case 'autocomplete':
        return _buildSearchableField(label, id, options: List<String>.from(field['options'] ?? []));
      case 'number':
        return _buildTextField(label, id, keyboardType: TextInputType.number);
      case 'multiline':
        return _buildTextField(label, id, maxLines: 3);
      case 'date':
        return _buildDateField(label, id);
      case 'time':
        return _buildTimeField(label, id);
      default:
        return _buildTextField(label, id);
    }
  }

  InputDecoration _roundedDecoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      floatingLabelStyle: const TextStyle(color: primaryColor, fontWeight: FontWeight.w700, fontSize: 16),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade100),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildTextField(String label, String id, {TextInputType? keyboardType, int maxLines = 1}) {
    return TextField(
      controller: _controllers[id],
      keyboardType: keyboardType,
      maxLines: maxLines,
      textInputAction: TextInputAction.next,
      onChanged: (val) => _formData[id] = val,
      decoration: _roundedDecoration(label),
    );
  }

  Widget _buildSearchableField(String label, String id, {List<String> options = const []}) {
    final leadVM = Provider.of<LeadViewModel>(context, listen: false);
    
    // Combine config options + learned data from Firebase
    final List<String> learnedData = leadVM.getUniqueValues(id);
    final Set<String> combined = {...options, ...learnedData};
    final List<String> finalOptions = combined.toList()..sort();

    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return finalOptions; // Show all if empty (like a dropdown)
        }
        return finalOptions.where((String option) {
          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
        });
      },
      onSelected: (String selection) {
        setState(() {
          _controllers[id]?.text = selection;
          _formData[id] = selection;
        });
        FocusScope.of(context).nextFocus();
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250, maxWidth: 300), // Compact List
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return ListTile(
                    title: Text(option, style: const TextStyle(fontSize: 14)),
                    onTap: () => onSelected(option),
                    dense: true,
                    hoverColor: primaryColor.withValues(alpha: 0.1),
                  );
                },
              ),
            ),
          ),
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        if (_controllers[id]?.text != controller.text && _controllers[id]?.text != null) {
          controller.text = _controllers[id]!.text;
        }
        
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.next,
          onChanged: (val) {
            _controllers[id]?.text = val;
            _formData[id] = val;
          },
          onSubmitted: (value) {
            onFieldSubmitted();
          },
          decoration: _roundedDecoration(label, suffixIcon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey)),
        );
      },
    );
  }

  Widget _buildPhoneWithPlus(String label, String id) {
    return Row(
      children: [
        Expanded(
          child: _buildTextField(label, id, keyboardType: TextInputType.phone),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {
            setState(() {
              _showContact2 = !_showContact2;
            });
          },
          icon: Icon(
            _showContact2 ? Icons.remove_circle_outline_rounded : Icons.add_circle_outline_rounded,
            color: primaryColor,
            size: 28,
          ),
        ),
      ],
    );
  }

  Widget _buildProjectDropdown(String label, String id) {
    return Consumer<ProjectViewModel>(
      builder: (context, projectVM, child) {
        final options = projectVM.projects.map((p) => p.projectName).toSet().toList();
        return _buildSearchableField(label, id, options: options);
      },
    );
  }

  Widget _buildCPDropdown(String label, String id) {
    return Consumer<CPViewModel>(
      builder: (context, cpVM, child) {
        final options = cpVM.cps.map((c) => c.cpName).toSet().toList();
        return _buildSearchableField(label, id, options: options);
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

  Widget _buildDropdown(String label, String id, List<String> options) {
    if (_formData[id] != null && _formData[id].toString().isNotEmpty && !options.contains(_formData[id])) {
      options.insert(0, _formData[id]);
    }

    return DropdownButtonFormField<String>(
      value: options.contains(_formData[id]) ? _formData[id] : null,
      decoration: _roundedDecoration(label),
      items: options.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
      onChanged: (val) => setState(() => _formData[id] = val),
    );
  }

  Widget _buildChoiceChips(String label, String id, List<String> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = _formData[id] == opt;
            return ChoiceChip(
              label: Text(opt, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal)),
              selected: isSelected,
              selectedColor: primaryColor,
              backgroundColor: const Color(0xFFF5F5F5),
              checkmarkColor: Colors.white,
              onSelected: (val) => setState(() => _formData[id] = val ? opt : null),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide.none),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDateField(String label, String id) {
    return TextField(
      controller: _controllers[id],
      readOnly: true,
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
        }
      },
      decoration: _roundedDecoration(label, suffixIcon: const Icon(Icons.calendar_month_rounded, size: 20, color: primaryColor)),
    );
  }

  Widget _buildTimeField(String label, String id) {
    return TextField(
      controller: _controllers[id],
      readOnly: true,
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
        }
      },
      decoration: _roundedDecoration(label, suffixIcon: const Icon(Icons.access_time_rounded, size: 20, color: primaryColor)),
    );
  }

  Widget _buildBottomAction(bool isEditing) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 0,
          ),
          child: _isSaving
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(
                  isEditing ? 'UPDATE CLIENT' : 'SAVE CLIENT DATA',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 16),
                ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (_controllers['name']?.text.trim().isEmpty ?? true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lead name is required')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final authVM = Provider.of<AuthViewModel>(context, listen: false);
      
      _controllers.forEach((id, ctrl) {
        _formData[id] = ctrl.text.trim();
      });

      // Maintain internal model fields
      _formData['name'] = _controllers['name']!.text.trim();
      _formData['whatsapp'] = _controllers['contact1']!.text.trim();

      await Provider.of<LeadViewModel>(context, listen: false).addOrUpdateLead(
        _formData,
        id: widget.lead?.id,
        actorMetadata: authVM.actorMetadata,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Client saved successfully!')));
      context.go('/dashboard');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
