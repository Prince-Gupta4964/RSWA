import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../utils/cp_form_config.dart';
import '../../utils/lead_form_config.dart';
import '../../utils/project_form_config.dart';

class FormLabelsManagerView extends StatefulWidget {
  const FormLabelsManagerView({super.key});

  @override
  State<FormLabelsManagerView> createState() => _FormLabelsManagerViewState();
}

class _FormLabelsManagerViewState extends State<FormLabelsManagerView> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, List<Map<String, dynamic>>> _formsData = {};
  late TabController _tabController;
  final List<String> _formNames = ['CP Network Form', 'Lead Form', 'Project Form'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _formNames.length, vsync: this);
    _loadFormConfigs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFormConfigs() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('app_config').doc('form_labels').get();
      final data = doc.data();

      Map<String, List<Map<String, dynamic>>> loaded = {};

      loaded['CP Network Form'] = _flattenFormStructure(CPFormStrings.formStructure);
      loaded['Lead Form'] = _flattenFormStructure(LeadFormStrings.formStructure);
      loaded['Project Form'] = _flattenFormStructure(ProjectFormStrings.formStructure);

      if (data != null && data['forms'] is Map) {
        final savedForms = data['forms'] as Map<String, dynamic>;
        savedForms.forEach((formName, fieldsList) {
          if (fieldsList is List) {
            loaded[formName] = fieldsList.map((f) {
              final map = Map<String, dynamic>.from(f as Map);
              if (map['options'] is List) {
                map['options'] = (map['options'] as List).join(', ');
              }
              return map;
            }).toList();
          }
        });
      }

      setState(() {
        _formsData = loaded;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading form labels: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _flattenFormStructure(List<Map<String, dynamic>> structure) {
    List<Map<String, dynamic>> result = [];
    for (var section in structure) {
      final fields = section['fields'] as List<dynamic>? ?? [];
      for (var field in fields) {
        if (field['type'] == 'row') {
          final subFields = field['fields'] as List<dynamic>? ?? [];
          for (var sub in subFields) {
            final opts = sub['options'] is List ? (sub['options'] as List).join(', ') : '';
            result.add({
              'id': sub['id'],
              'label': sub['label'] ?? '',
              'type': sub['type'] ?? 'text',
              'initialValue': sub['initialValue'] ?? '',
              'options': opts,
              'isVisible': sub['isVisible'] ?? true,
            });
          }
        } else {
          final opts = field['options'] is List ? (field['options'] as List).join(', ') : '';
          result.add({
            'id': field['id'],
            'label': field['label'] ?? '',
            'type': field['type'] ?? 'text',
            'initialValue': field['initialValue'] ?? '',
            'options': opts,
            'isVisible': field['isVisible'] ?? true,
          });
        }
      }
    }
    return result;
  }

  Future<void> _saveConfigs() async {
    setState(() => _isSaving = true);
    try {
      // Convert comma-separated options back to Lists before saving
      Map<String, List<Map<String, dynamic>>> preparedData = {};
      _formsData.forEach((formName, fieldsList) {
        preparedData[formName] = fieldsList.map((field) {
          final Map<String, dynamic> copy = Map.from(field);
          if (copy['options'] is String) {
            copy['options'] = (copy['options'] as String)
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
          }
          return copy;
        }).toList();
      });

      await FirebaseFirestore.instance.collection('app_config').doc('form_labels').set({
        'forms': preparedData,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Form columns & options updated successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);

    if (!authVM.isSuperAdmin) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: const Center(
          child: Text('Access Denied. Super Admin only.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('AppSheet-Style Form Manager', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFFF6B22),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFFF6B22),
          tabs: _formNames.map((name) => Tab(text: name)).toList(),
        ),
        actions: [
          IconButton(
            icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save, color: Color(0xFFFF6B22)),
            onPressed: _isSaving ? null : _saveConfigs,
            tooltip: 'Save Spreadsheet',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B22)))
          : TabBarView(
              controller: _tabController,
              children: _formNames.map((formName) {
                final fields = _formsData[formName] ?? [];

                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                      border: TableBorder.all(color: Colors.grey.shade300, width: 0.8),
                      columns: const [
                        DataColumn(label: Text('NO.', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('FIELD LABEL / NAME', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('TYPE', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('INTERNAL KEY', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('SHOW?', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('INITIAL VALUE', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('DROPDOWN OPTIONS (COMMA SEPARATED)', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: fields.asMap().entries.map((entry) {
                        int index = entry.key;
                        Map<String, dynamic> field = entry.value;

                        return DataRow(
                          cells: [
                            // 1. No.
                            DataCell(Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),

                            // 2. Field Label / Name (Editable)
                            DataCell(
                              SizedBox(
                                width: 200,
                                child: TextFormField(
                                  initialValue: field['label'],
                                  decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                                  style: const TextStyle(fontSize: 13),
                                  onChanged: (val) {
                                    _formsData[formName]![index]['label'] = val;
                                  },
                                ),
                              ),
                            ),

                            // 3. Type (Dropdown)
                            DataCell(
                              SizedBox(
                                width: 130,
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: ['text', 'phone', 'dropdown', 'number', 'switch', 'file', 'rating', 'chips', 'segmented'].contains(field['type']) ? field['type'] : 'text',
                                    isDense: true,
                                    items: ['text', 'phone', 'dropdown', 'number', 'switch', 'file', 'rating', 'chips', 'segmented']
                                        .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13))))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _formsData[formName]![index]['type'] = val;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),

                            // 4. Internal Key (Read-only)
                            DataCell(
                              Text(
                                '${field['id']}',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                              ),
                            ),

                            // 5. Show? (Checkbox / Switch)
                            DataCell(
                              Center(
                                child: Checkbox(
                                  value: field['isVisible'] != false,
                                  activeColor: const Color(0xFFFF6B22),
                                  onChanged: (val) {
                                    setState(() {
                                      _formsData[formName]![index]['isVisible'] = val ?? true;
                                    });
                                  },
                                ),
                              ),
                            ),

                            // 6. Initial Value (Editable)
                            DataCell(
                              SizedBox(
                                width: 150,
                                child: TextFormField(
                                  initialValue: field['initialValue'] ?? '',
                                  decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: '='),
                                  style: const TextStyle(fontSize: 13),
                                  onChanged: (val) {
                                    _formsData[formName]![index]['initialValue'] = val;
                                  },
                                ),
                              ),
                            ),

                            // 7. Dropdown Options (Comma separated)
                            DataCell(
                              SizedBox(
                                width: 220,
                                child: TextFormField(
                                  initialValue: field['options'] ?? '',
                                  decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: 'Opt1, Opt2, Opt3'),
                                  style: const TextStyle(fontSize: 13),
                                  onChanged: (val) {
                                    _formsData[formName]![index]['options'] = val;
                                  },
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}
