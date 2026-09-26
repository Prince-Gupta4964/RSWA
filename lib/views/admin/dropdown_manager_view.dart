import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../utils/lead_form_config.dart';
import '../../utils/project_form_config.dart';
import '../../utils/cp_form_config.dart';
import '../../utils/role_permissions.dart';
import '../../viewmodels/app_configuration_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/app_drawer.dart';

class DropdownManagerView extends StatefulWidget {
  const DropdownManagerView({super.key});

  @override
  State<DropdownManagerView> createState() => _DropdownManagerState();
}

class _DropdownManagerState extends State<DropdownManagerView> {
  final Set<String> _expandedSections = {
    'Lead Form Dropdowns',
    'Project Form Dropdowns',
    'CP Network Form Dropdowns',
  };

  static const Color primaryOrange = Color(0xFFFF6B22);

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    final configVM = context.watch<AppConfigurationViewModel>();

    if (!authVM.canManageUsers) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(child: Text('Admin access is required.')),
      );
    }

    final formSections = [
      {
        'title': 'Lead Form Dropdowns',
        'formKey': 'Lead Form',
        'fields': _extractDropdownFieldsFromStructure('Lead Form', LeadFormStrings.formStructure),
      },
      {
        'title': 'Project Form Dropdowns',
        'formKey': 'Project Form',
        'fields': _extractDropdownFieldsFromStructure('Project Form', ProjectFormStrings.formStructure),
      },
      {
        'title': 'CP Network Form Dropdowns',
        'formKey': 'CP Network Form',
        'fields': _extractDropdownFieldsFromStructure('CP Network Form', CPFormStrings.formStructure),
      },
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.canPop(context)) {
          context.pop();
        } else {
          StatefulNavigationShell.of(context).goBranch(0);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: Builder(
            builder: (context) => IconButton(
              icon: Icon(
                Navigator.canPop(context) ? Icons.arrow_back : Icons.menu,
                color: Colors.black,
              ),
              onPressed: () {
                if (Navigator.canPop(context)) {
                  context.pop();
                } else {
                  Scaffold.of(context).openDrawer();
                }
              },
            ),
          ),
          title: const Text(
            'Form Dropdowns Manager',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 18),
          ),
        ),
        drawer: const AppDrawer(),
        body: configVM.isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryOrange))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: formSections.map((section) {
                  final String title = section['title'] as String;
                  final String formKey = section['formKey'] as String;
                  final fields = section['fields'] as List<Map<String, dynamic>>;
                  final isExpanded = _expandedSections.contains(title);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
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
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                const Icon(Icons.list_alt_rounded, color: primaryOrange, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: primaryOrange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${fields.length} Dropdowns',
                                    style: const TextStyle(
                                      color: primaryOrange,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  isExpanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isExpanded) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: fields.map((field) {
                                final String fieldId = field['id'];
                                final String fieldLabel = field['label'];
                                final List<String> defaultOpts = List<String>.from(field['options'] ?? []);

                                final currentOpts = configVM.getOptionsForField(formKey, fieldId, defaultOpts);

                                return _buildFieldOptionCard(
                                  context,
                                  configVM,
                                  formKey: formKey,
                                  fieldId: fieldId,
                                  fieldLabel: fieldLabel,
                                  currentOptions: currentOpts,
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }

  Widget _buildFieldOptionCard(
    BuildContext context,
    AppConfigurationViewModel configVM, {
    required String formKey,
    required String fieldId,
    required String fieldLabel,
    required List<String> currentOptions,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  fieldLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: Colors.black87,
                  ),
                ),
              ),
              ActionChip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.add, size: 14, color: primaryOrange),
                label: const Text('Add Option', style: TextStyle(fontSize: 11, color: primaryOrange, fontWeight: FontWeight.bold)),
                backgroundColor: primaryOrange.withValues(alpha: 0.1),
                side: BorderSide.none,
                onPressed: () => _showAddOptionDialog(context, configVM, formKey, fieldId, fieldLabel, currentOptions),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (currentOptions.isEmpty)
            const Text('No options defined.', style: TextStyle(color: Colors.grey, fontSize: 12))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: currentOptions.map((opt) {
                return InputChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(opt, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey.shade300),
                  deleteIcon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                  onPressed: () => _showEditOptionDialog(context, configVM, formKey, fieldId, fieldLabel, currentOptions, opt),
                  onDeleted: () async {
                    final updated = List<String>.from(currentOptions)..remove(opt);
                    await _updateOptionsInVM(configVM, formKey, fieldId, updated);
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Future<void> _updateOptionsInVM(
    AppConfigurationViewModel configVM,
    String formKey,
    String fieldId,
    List<String> newOptions,
  ) async {
    final Map<String, Map<String, List<String>>> currentAll = Map.from(configVM.fieldOptions);
    if (!currentAll.containsKey(formKey)) {
      currentAll[formKey] = {};
    }
    currentAll[formKey]![fieldId] = newOptions;
    await configVM.saveFieldOptions(currentAll);
  }

  String _toTitleCase(String input) {
    if (input.trim().isEmpty) return input;
    return input.trim().split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  void _showAddOptionDialog(
    BuildContext context,
    AppConfigurationViewModel configVM,
    String formKey,
    String fieldId,
    String fieldLabel,
    List<String> currentOptions,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Option to $fieldLabel', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Enter new option name...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryOrange),
            onPressed: () async {
              final rawVal = controller.text.trim();
              if (rawVal.isNotEmpty) {
                final formattedVal = _toTitleCase(rawVal);
                final updated = List<String>.from(currentOptions);
                if (!updated.contains(formattedVal)) {
                  updated.add(formattedVal);
                  await _updateOptionsInVM(configVM, formKey, fieldId, updated);
                }
              }
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
            },
            child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditOptionDialog(
    BuildContext context,
    AppConfigurationViewModel configVM,
    String formKey,
    String fieldId,
    String fieldLabel,
    List<String> currentOptions,
    String oldOption,
  ) {
    final controller = TextEditingController(text: oldOption);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit $oldOption', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Enter updated option name...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryOrange),
            onPressed: () async {
              final rawVal = controller.text.trim();
              if (rawVal.isNotEmpty) {
                final formattedVal = _toTitleCase(rawVal);
                final updated = List<String>.from(currentOptions);
                final idx = updated.indexOf(oldOption);
                if (idx != -1) {
                  updated[idx] = formattedVal;
                } else {
                  updated.add(formattedVal);
                }
                await _updateOptionsInVM(configVM, formKey, fieldId, updated);
              }
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _extractDropdownFieldsFromStructure(
    String formName,
    List<Map<String, dynamic>> formStructure,
  ) {
    final List<Map<String, dynamic>> dropdownFields = [];

    void inspectFields(List<dynamic> fields) {
      for (var f in fields) {
        if (f is! Map) continue;
        final map = Map<String, dynamic>.from(f);
        if (map['type'] == 'row') {
          inspectFields(map['fields'] ?? []);
        } else if (['dropdown', 'chips', 'autocomplete', 'addable_chips', 'choice'].contains(map['type'])) {
          dropdownFields.add({
            'id': map['id'] ?? '',
            'label': map['label'] ?? map['id'] ?? '',
            'options': map['options'] ?? [],
            'type': map['type'],
          });
        }
      }
    }

    for (var section in formStructure) {
      final fields = section['fields'] as List<dynamic>? ?? [];
      inspectFields(fields);
    }

    return dropdownFields;
  }
}
