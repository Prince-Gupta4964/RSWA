import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../viewmodels/cp_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';

class ContactPickerSheet extends StatefulWidget {
  final CPViewModel cpVM;
  final AuthViewModel authVM;
  const ContactPickerSheet({super.key, required this.cpVM, required this.authVM});

  @override
  State<ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<ContactPickerSheet> {
  List<Contact> _contacts = [];
  final Set<Contact> _selectedContacts = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String? _error;
  bool _isManualMode = false;
  final TextEditingController _manualInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  @override
  void dispose() {
    _manualInputController.dispose();
    super.dispose();
  }

  Future<void> _fetchContacts() async {
    try {
      debugPrint("ContactPicker: Requesting permissions...");
      final status = await Permission.contacts.request();
      debugPrint("ContactPicker: Permission status = $status");

      if (status.isGranted) {
        final contacts = await FlutterContacts.getAll(
          properties: {ContactProperty.phone, ContactProperty.email},
        );
        debugPrint("ContactPicker: Successfully fetched ${contacts.length} contacts.");
        if (mounted) {
          setState(() {
            _contacts = contacts;
            _isLoading = false;
          });
        }
      } else if (status.isPermanentlyDenied) {
        if (mounted) {
          setState(() {
            _error = 'Contacts access is permanently blocked. Please enable it in App Settings.';
            _isLoading = false;
            _isManualMode = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Permission denied. We need contact access to import your partners.';
            _isLoading = false;
            _isManualMode = true;
          });
        }
      }
    } catch (e) {
      debugPrint("ContactPicker: Fatal Error = $e");
      if (mounted) {
        setState(() {
          _error = 'Error fetching contacts: $e';
          _isLoading = false;
          _isManualMode = true;
        });
      }
    }
  }

  void _returnSelected() {
    List<Map<String, String>> contactsToAdd = [];

    if (_isManualMode) {
      final text = _manualInputController.text.trim();
      final lines = text.split('\n');
      for (var line in lines) {
        final parts = line.split(',');
        if (parts.isNotEmpty) {
          final name = parts[0].trim();
          final phone = parts.length > 1 ? parts[1].trim() : '';
          if (name.isNotEmpty) {
            contactsToAdd.add({'name': name, 'tel': phone, 'email': ''});
          }
        }
      }
    } else {
      contactsToAdd = _selectedContacts.map((c) => {
        'name': c.displayName ?? 'Unknown',
        'tel': c.phones.isNotEmpty ? c.phones.first.number : '',
        'email': c.emails.isNotEmpty ? c.emails.first.address : '',
      }).toList();
    }

    Navigator.pop(context, contactsToAdd);
  }

  @override
  Widget build(BuildContext context) {
    final String q = _searchQuery.toLowerCase();
    
    final filteredContacts = _contacts.where((c) {
      final String name = (c.displayName ?? '').toLowerCase();
      if (q.isEmpty) return true;
      return name.contains(q);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Import Contacts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(_isManualMode ? 'Paste contacts manually (Name, Phone)' : 'Select contacts to add to your network', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _isManualMode = !_isManualMode),
                  icon: Icon(_isManualMode ? Icons.contacts_rounded : Icons.edit_note_rounded, size: 16, color: const Color(0xFFFF6B22)),
                  label: Text(_isManualMode ? 'Device Contacts' : 'Manual Paste', style: const TextStyle(color: Color(0xFFFF6B22))),
                ),
              ],
            ),
          ),

          if (!_isManualMode) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search contacts...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
          ],

          Expanded(
            child: _isManualMode
                ? Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Enter or paste contacts below (One per line in format: Name, Phone):\nExample:\nRajesh Sharma, 9876543210\nAmit Kumar, 9123456789',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: TextField(
                            controller: _manualInputController,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            decoration: InputDecoration(
                              hintText: 'Name, Phone\nName, Phone',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B22)))
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B22), foregroundColor: Colors.white),
                                    onPressed: () => setState(() => _isManualMode = true),
                                    child: const Text('Switch to Manual Paste'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : filteredContacts.isEmpty
                            ? const Center(child: Text('No contacts found'))
                            : ListView.builder(
                                itemCount: filteredContacts.length,
                                itemBuilder: (context, index) {
                                  final contact = filteredContacts[index];
                                  final isSelected = _selectedContacts.contains(contact);
                                  
                                  final String displayName = contact.displayName ?? 'No Name';
                                  final String firstChar = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
                                  
                                  final String phoneNum = contact.phones.isNotEmpty 
                                      ? contact.phones.first.number 
                                      : 'No number';

                                  return CheckboxListTile(
                                    value: isSelected,
                                    activeColor: const Color(0xFFFF6B22),
                                    title: Text(displayName),
                                    subtitle: Text(phoneNum),
                                    secondary: CircleAvatar(
                                      backgroundColor: const Color(0xFFFFF1EA),
                                      child: Text(firstChar, style: const TextStyle(color: Color(0xFFFF6B22))),
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedContacts.add(contact);
                                        } else {
                                          _selectedContacts.remove(contact);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isManualMode
                    ? _returnSelected
                    : (_selectedContacts.isEmpty ? null : _returnSelected),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B22),
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _isManualMode
                      ? 'Import Entered Contacts'
                      : (_selectedContacts.isEmpty ? 'Select Contacts' : 'Add ${_selectedContacts.length} Partners'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
