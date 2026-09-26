import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/app_configuration_models.dart';
import '../../viewmodels/app_configuration_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';

class CustomFormView extends StatefulWidget {
  final String formId;

  const CustomFormView({super.key, required this.formId});

  @override
  State<CustomFormView> createState() => _CustomFormViewState();
}

class _CustomFormViewState extends State<CustomFormView> {
  final _controllers = <String, TextEditingController>{};
  bool _isSaving = false;
  bool _isEditMode = false;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configVM = context.watch<AppConfigurationViewModel>();
    final authVM = context.watch<AuthViewModel>();
    final form = configVM.customFormById(widget.formId);
    final roleKey = configVM.roleKeyForLabel(authVM.userRole ?? authVM.roleLabel);

    final isAuthorized = authVM.canConfigureForms || (form != null && form.isVisible && form.roles.contains(roleKey));

    if (form == null || !isAuthorized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Form')),
        body: const Center(child: Text('This form is not available to your role.')),
      );
    }

    final fieldsToDisplay = _isEditMode 
        ? form.fields 
        : form.fields.where((f) => f.isVisible && (f.roles.contains('all') || f.roles.contains(roleKey))).toList();

    for (final field in fieldsToDisplay) {
      _controllers.putIfAbsent(field.id, TextEditingController.new);
    }

    final fields = fieldsToDisplay..sort((a, b) => a.order.compareTo(b.order));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/dashboard');
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text(form.label),
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/dashboard'),
          ),
          actions: [
            if (authVM.canConfigureForms)
              IconButton(
                tooltip: _isEditMode ? 'View Form' : 'Customize Form',
                icon: Icon(_isEditMode ? Icons.remove_red_eye_outlined : Icons.edit_note_rounded),
                color: _isEditMode ? const Color(0xFFFF6B22) : Colors.black,
                onPressed: () => setState(() => _isEditMode = !_isEditMode),
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: fields.isEmpty
            ? const Center(child: Text('This form has no fields yet.'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_isEditMode)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Admin Mode: Tap eye icon to hide/show fields for users.',
                        style: TextStyle(color: Color(0xFFFF6B22), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ...fields.map((field) => _buildField(field, form, configVM)),
                  const SizedBox(height: 8),
                  if (!_isEditMode)
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B22),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: _isSaving ? null : () => _submit(form, fields),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Submit'),
                    ),
                  if (_isEditMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddFieldDialog(form, configVM),
                        icon: const Icon(Icons.add, color: Color(0xFFFF6B22)),
                        label: const Text('Add New Field', style: TextStyle(color: Color(0xFFFF6B22))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFF6B22)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildField(DynamicLeadField field, CustomFormConfig form, AppConfigurationViewModel configVM) {
    final controller = _controllers[field.id]!;
    final label = '${field.label}${field.isRequired ? ' *' : ''}';
    
    Widget fieldWidget;

    if (field.type == 'choice') {
      fieldWidget = DropdownButtonFormField<String>(
        value: field.options.contains(controller.text) ? controller.text : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: field.isVisible ? Colors.white : Colors.grey.shade50,
        ),
        items: field.options
            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
            .toList(),
        onChanged: _isEditMode ? null : (value) => setState(() => controller.text = value ?? ''),
      );
    } else {
      fieldWidget = TextField(
        controller: controller,
        enabled: !_isEditMode,
        keyboardType: field.type == 'number' ? TextInputType.number : TextInputType.text,
        maxLines: field.type == 'multiline' ? 4 : 1,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: field.isVisible ? Colors.white : Colors.grey.shade50,
        ),
      );
    }

    if (!_isEditMode) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: fieldWidget,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: fieldWidget),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  field.isVisible ? Icons.visibility : Icons.visibility_off,
                  color: field.isVisible ? Colors.green : Colors.grey,
                ),
                onPressed: () async {
                  final updatedFields = form.fields.map((f) {
                    if (f.id == field.id) return f.copyWith(isVisible: !f.isVisible);
                    return f;
                  }).toList();
                  await configVM.updateCustomForm(form.copyWith(fields: updatedFields));
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('Visible for:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                ...['all', 'super_admin', 'admin', 'office_staff', 'builder', 'cp'].map((rk) {
                  final isSelected = field.roles.contains(rk);
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      label: Text(rk.replaceAll('_', ' '), style: const TextStyle(fontSize: 10)),
                      selected: isSelected,
                      onSelected: (val) async {
                        final updatedRoles = List<String>.from(field.roles);
                        if (val) {
                          updatedRoles.add(rk);
                        } else {
                          updatedRoles.remove(rk);
                        }
                        final updatedFields = form.fields.map((f) {
                          if (f.id == field.id) return f.copyWith(roles: updatedRoles);
                          return f;
                        }).toList();
                        await configVM.updateCustomForm(form.copyWith(fields: updatedFields));
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }

  void _showAddFieldDialog(CustomFormConfig form, AppConfigurationViewModel configVM) {
    final labelCtrl = TextEditingController();
    String type = 'text';
    final List<String> options = [];
    bool isRequired = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return AlertDialog(
              title: const Text('Add New Field'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: labelCtrl,
                      decoration: const InputDecoration(labelText: 'Field Label (e.g. Area, BHK)'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: type,
                      items: const [
                        DropdownMenuItem(value: 'text', child: Text('Text')),
                        DropdownMenuItem(value: 'number', child: Text('Number')),
                        DropdownMenuItem(value: 'choice', child: Text('Dropdown Choice')),
                        DropdownMenuItem(value: 'multiline', child: Text('Multi-line Text')),
                      ],
                      onChanged: (val) => setSheetState(() => type = val!),
                      decoration: const InputDecoration(labelText: 'Field Type'),
                    ),
                    if (type == 'choice') ...[
                      const SizedBox(height: 16),
                      TextField(
                        decoration: const InputDecoration(labelText: 'Options (comma separated)', hintText: 'Option 1, Option 2'),
                        onChanged: (val) {
                          options.clear();
                          options.addAll(val.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('Is Required?'),
                      value: isRequired,
                      onChanged: (val) => setSheetState(() => isRequired = val!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (labelCtrl.text.isEmpty) return;
                    final newField = DynamicLeadField(
                      id: 'field_${DateTime.now().millisecondsSinceEpoch}',
                      label: labelCtrl.text.trim(),
                      type: type,
                      options: options,
                      roles: const ['all'],
                      isRequired: isRequired,
                      isVisible: true,
                      order: form.fields.length,
                    );
                    final updatedFields = [...form.fields, newField];
                    await configVM.updateCustomForm(form.copyWith(fields: updatedFields));
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B22)),
                  child: const Text('Add Field', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submit(
    CustomFormConfig form,
    List<DynamicLeadField> fields,
  ) async {
    for (final field in fields) {
      if (field.isRequired && _controllers[field.id]!.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${field.label} is required.')),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final authVM = context.read<AuthViewModel>();
      await FirebaseFirestore.instance
          .collection('custom_form_entries')
          .doc(form.id)
          .collection('entries')
          .add({
            'formId': form.id,
            'formLabel': form.label,
            'values': {
              for (final field in fields) field.id: _controllers[field.id]!.text.trim(),
            },
            'submittedBy': authVM.actorMetadata,
            'submittedAt': FieldValue.serverTimestamp(),
          });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Form submitted successfully.')),
      );
      context.go('/dashboard');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to submit the form.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
