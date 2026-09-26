import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/lead_model.dart';
import '../../viewmodels/lead_viewmodel.dart';
import '../../viewmodels/cp_viewmodel.dart';
import '../../viewmodels/project_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';

class TodayTaskFormView extends StatefulWidget {
  final LeadModel? lead;
  final Map<String, dynamic>? followupData;
  final String? followupId;
  const TodayTaskFormView({super.key, this.lead, this.followupData, this.followupId});

  @override
  State<TodayTaskFormView> createState() => _TodayTaskFormViewState();
}

class _TodayTaskFormViewState extends State<TodayTaskFormView> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  final Map<String, bool> _openDropdowns = {}; // 🚀 NAYA

  late DateTime _followUpDate;
  late TimeOfDay _followUpTime;
  
  String? _selectedWorkType = 'Work';
  final TextEditingController _workDetailsController = TextEditingController();
  String _selectedPriority = 'Today';
  DateTime? _remindLaterDate;
  
  TimeOfDay _startTime = const TimeOfDay(hour: 11, minute: 55);
  TimeOfDay _endTime = const TimeOfDay(hour: 12, minute: 25);
  
  String? _selectedAssign;
  String? _selectedAccompaniedBy;
  DateTime? _deadlineDate;
  String _workStatus = 'Pending';
  String? _selectedProject;
  final TextEditingController _remarkController = TextEditingController();

  static const Color primaryColor = Color(0xFFFBE64E);
  static const Color secondaryColor = Color(0xFF6B5800);

  @override
  void initState() {
    super.initState();
    _followUpDate = DateTime.now();
    _followUpTime = TimeOfDay.now();
    
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    
    if (widget.followupData != null) {
      // 🚀 EDIT MODE Initialization
      final data = widget.followupData!;
      
      if (data['followUpDateTime'] is Timestamp) {
        final dt = (data['followUpDateTime'] as Timestamp).toDate();
        _followUpDate = dt;
        _followUpTime = TimeOfDay.fromDateTime(dt);
      }
      
      _selectedWorkType = data['workType'] ?? 'Work';
      _workDetailsController.text = data['workDetails'] ?? '';
      _selectedPriority = data['priority'] ?? 'Today';
      
      if (data['remindLater'] is Timestamp) {
        _remindLaterDate = (data['remindLater'] as Timestamp).toDate();
      }
      
      if (data['startTime'] != null) {
        final parts = data['startTime'].toString().split(':');
        if (parts.length == 2) _startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      if (data['endTime'] != null) {
        final parts = data['endTime'].toString().split(':');
        if (parts.length == 2) _endTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      
      _selectedAssign = data['assign'];
      _selectedAccompaniedBy = data['accompaniedBy'];
      
      if (data['deadline'] is Timestamp) {
        _deadlineDate = (data['deadline'] as Timestamp).toDate();
      }
      
      _workStatus = data['status'] == 'Contacted' ? 'Done' : (data['workStatus'] ?? 'Pending');
      _selectedProject = data['project'];
      _remarkController.text = data['remark'] ?? '';
      
    } else {
      // 🚀 NEW TASK Mode
      _selectedAssign = authVM.userName;
      _selectedAccompaniedBy = authVM.userName;
      
      if (widget.lead != null) {
        _selectedProject = widget.lead!.rawData['project'];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cpVM = Provider.of<CPViewModel>(context);
    final projectVM = Provider.of<ProjectViewModel>(context);

    bool isTimeError = _isTimeInvalid();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/dashboard');
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => context.go('/dashboard'),
          ),
          title: const Text('Today Task Only Form', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            _buildLabel('Follow Up Date & Time *'),
            _buildDateTimePicker(),
            const SizedBox(height: 20),

            _buildLabel('Ref Client *'),
            _buildSearchableDropdown(
              id: 'refClient',
              value: widget.lead?.name ?? 'Personal (Personal) {}',
              items: widget.lead != null ? [widget.lead!.name] : ['Personal (Personal) {}'],
              onChanged: null, // Readonly if lead passed
              isReadOnly: widget.lead != null,
            ),
            const SizedBox(height: 20),

            _buildLabel('Work Type *'),
            _buildDropdown(
              id: 'workType',
              value: _selectedWorkType,
              items: ['Work', 'Call', 'Meeting', 'Site Visit', 'Payment Collection', 'Other'],
              onChanged: (val) => setState(() => _selectedWorkType = val),
            ),
            const SizedBox(height: 20),

            _buildLabel('Work Details *'),
            _buildTextField(_workDetailsController, 'Enter specific details...', maxLines: 2),
            const SizedBox(height: 20),

            _buildLabel('Priority Level'),
            _buildPriorityChips(),
            const SizedBox(height: 20),

            _buildLabel('Remind Later'),
            _buildDateField(
              value: _remindLaterDate,
              onTap: () async {
                final date = await _pickDate(_remindLaterDate ?? DateTime.now());
                if (date != null) setState(() => _remindLaterDate = date);
              },
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Start Time'),
                      _buildTimeField(
                        value: _startTime,
                        onTap: () async {
                          final time = await _pickTime(_startTime);
                          if (time != null) setState(() => _startTime = time);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('End Time'),
                      _buildTimeField(
                        value: _endTime,
                        onTap: () async {
                          final time = await _pickTime(_endTime);
                          if (time != null) setState(() => _endTime = time);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isTimeError)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Warning! End Time cannot be less than Start Time!',
                  style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            const SizedBox(height: 20),

            _buildLabel('Assign *'),
            _buildDropdown(
              id: 'assign',
              value: _selectedAssign,
              items: cpVM.cps.map((c) => c.cpName).toList(),
              onChanged: (val) => setState(() => _selectedAssign = val),
            ),
            const SizedBox(height: 20),

            _buildLabel('Accompanied By'),
            _buildDropdown(
              id: 'accompaniedBy',
              value: _selectedAccompaniedBy,
              items: cpVM.cps.map((c) => c.cpName).toList(),
              onChanged: (val) => setState(() => _selectedAccompaniedBy = val),
            ),
            const SizedBox(height: 20),

            _buildLabel('Deadline'),
            _buildDateField(
              value: _deadlineDate,
              onTap: () async {
                final date = await _pickDate(_deadlineDate ?? DateTime.now());
                if (date != null) setState(() => _deadlineDate = date);
              },
            ),
            const SizedBox(height: 20),

            _buildLabel('Work Status'),
            _buildWorkStatusChips(),
            const SizedBox(height: 20),

            _buildLabel('Ref Projects'),
            _buildDropdown(
              id: 'refProject',
              value: _selectedProject,
              items: projectVM.projects.map((p) => p.projectName).toList(),
              onChanged: widget.lead != null ? null : (val) => setState(() => _selectedProject = val),
            ),
            const SizedBox(height: 20),

            _buildLabel('Remark'),
            _buildTextField(_remarkController, 'Final thoughts or follow-up notes...'),
            const SizedBox(height: 40),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                      elevation: 0,
                    ),
                    child: _isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: secondaryColor, strokeWidth: 2))
                      : const Text('Save Task', style: TextStyle(color: secondaryColor, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    ));
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475467))),
    );
  }

  Widget _buildDateTimePicker() {
    final dateStr = DateFormat('dd/MM/yyyy').format(_followUpDate);
    final timeStr = _followUpTime.format(context);
    return InkWell(
      onTap: () async {
        final date = await _pickDate(_followUpDate);
        if (date != null) {
          final time = await _pickTime(_followUpTime);
          if (time != null) {
            setState(() {
              _followUpDate = date;
              _followUpTime = time;
            });
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$dateStr, $timeStr', style: const TextStyle(fontSize: 15)),
            const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField({DateTime? value, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(value == null ? 'Select Date' : DateFormat('dd/MM/yyyy').format(value), style: const TextStyle(fontSize: 15)),
            const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeField({required TimeOfDay value, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(value.format(context), style: const TextStyle(fontSize: 15)),
            const Icon(Icons.access_time, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({String? value, required List<String> items, required Function(String?)? onChanged, String? id}) {
    bool isOpen = id != null && (_openDropdowns[id] ?? false);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: isOpen ? secondaryColor : const Color(0xFFCCCCCC), width: isOpen ? 1.5 : 1.0), 
        borderRadius: BorderRadius.circular(8)
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: items.contains(value) ? value : null,
          icon: Icon(isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down, color: Colors.grey),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (val) {
             if (id != null) setState(() => _openDropdowns[id] = false);
             if (onChanged != null) onChanged(val);
          },
          onTap: () {
             if (id != null) setState(() => _openDropdowns[id] = true);
          },
        ),
      ),
    );
  }

  Widget _buildSearchableDropdown({required String value, required List<String> items, required Function(String?)? onChanged, bool isReadOnly = false, String? id}) {
    bool isOpen = id != null && (_openDropdowns[id] ?? false);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isReadOnly ? Colors.grey.shade50 : Colors.white,
        border: Border.all(color: isOpen ? secondaryColor : const Color(0xFFCCCCCC), width: isOpen ? 1.5 : 1.0), 
        borderRadius: BorderRadius.circular(8)
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          icon: Icon(isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down, color: Colors.grey),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: isReadOnly ? null : (val) {
             if (id != null) setState(() => _openDropdowns[id] = false);
             if (onChanged != null) onChanged(val);
          },
          onTap: isReadOnly ? null : () {
             if (id != null) setState(() => _openDropdowns[id] = true);
          },
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(fontSize: 15, color: Color(0xFF555555), fontWeight: FontWeight.w400),
        floatingLabelStyle: const TextStyle(color: secondaryColor, fontWeight: FontWeight.bold, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCCCCCC))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCCCCCC))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: secondaryColor, width: 1.5)),
      ),
    );
  }

  Widget _buildPriorityChips() {
    final priorities = ['Urgent', 'IMP', 'Today', 'Tomorrow', 'Day Later', 'Later', 'Process', 'Hold', 'Free'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: priorities.map((p) {
        bool isSelected = _selectedPriority == p;
        return ChoiceChip(
          label: Text(p, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 12)),
          selected: isSelected,
          selectedColor: const Color(0xFF0088CC),
          backgroundColor: Colors.grey.shade100,
          onSelected: (val) { if (val) setState(() => _selectedPriority = p); },
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        );
      }).toList(),
    );
  }

  Widget _buildWorkStatusChips() {
    return Row(
      children: [
        _buildStatusBtn('Pending'),
        _buildStatusBtn('Done'),
      ],
    );
  }

  Widget _buildStatusBtn(String status) {
    bool isSelected = _workStatus == status;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _workStatus = status),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0088CC) : Colors.white,
            border: Border.all(color: isSelected ? const Color(0xFF0088CC) : Colors.grey.shade300),
            borderRadius: BorderRadius.horizontal(
              left: status == 'Pending' ? const Radius.circular(8) : Radius.zero,
              right: status == 'Done' ? const Radius.circular(8) : Radius.zero,
            ),
          ),
          child: Center(
            child: Text(status, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Future<DateTime?> _pickDate(DateTime initial) async {
    return showDatePicker(context: context, initialDate: initial, firstDate: DateTime(1900), lastDate: DateTime(2100));
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay initial) async {
    return showTimePicker(context: context, initialTime: initial);
  }

  bool _isTimeInvalid() {
    int startMin = _startTime.hour * 60 + _startTime.minute;
    int endMin = _endTime.hour * 60 + _endTime.minute;
    return endMin < startMin;
  }

  Future<void> _handleSave() async {
    if (_workDetailsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill work details.')));
      return;
    }
    
    setState(() => _isSaving = true);
    try {
      final leadVM = Provider.of<LeadViewModel>(context, listen: false);
      
      final taskData = {
        'followUpDateTime': DateTime(_followUpDate.year, _followUpDate.month, _followUpDate.day, _followUpTime.hour, _followUpTime.minute),
        'workType': _selectedWorkType,
        'workDetails': _workDetailsController.text.trim(),
        'priority': _selectedPriority,
        'remindLater': _remindLaterDate,
        'startTime': '${_startTime.hour}:${_startTime.minute}',
        'endTime': '${_endTime.hour}:${_endTime.minute}',
        'assign': _selectedAssign,
        'accompaniedBy': _selectedAccompaniedBy,
        'deadline': _deadlineDate,
        'status': _workStatus,
        'project': _selectedProject,
        'remark': _remarkController.text.trim(),
        // Only set this if it's not already in followupData
        if (widget.followupData?['timestamp'] == null) 'timestamp': FieldValue.serverTimestamp(),
      };

      if (widget.lead != null) {
        if (widget.followupId != null) {
          // UPDATE Existing
          await leadVM.updateFollowUp(widget.lead!.id, widget.followupId!, {
            'caller': _selectedAssign ?? 'Unknown',
            'status': _workStatus == 'Done' ? 'Contacted' : 'Pending Task',
            'remark': 'Task: ${_selectedWorkType} - ${_workDetailsController.text.trim()}',
            ...taskData,
          });
        } else {
          // CREATE New
          await leadVM.addFollowUp(widget.lead!.id, {
            'caller': _selectedAssign ?? 'Unknown',
            'status': _workStatus == 'Done' ? 'Contacted' : 'Pending Task',
            'remark': 'Task: ${_selectedWorkType} - ${_workDetailsController.text.trim()}',
            ...taskData,
          });
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task saved successfully!')));
      context.go('/dashboard');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
