import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactPickerSheet extends StatefulWidget {
  const ContactPickerSheet({super.key});

  @override
  State<ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<ContactPickerSheet> {
  List<Contact> _contacts = [];
  final Set<Contact> _selectedContacts = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    try {
      debugPrint("ContactPicker: Requesting permissions...");
      final status = await Permission.contacts.request();
      debugPrint("ContactPicker: Permission status = $status");

      if (status.isGranted) {
        // In 2.x, use getAll() instead of getContacts()
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
        debugPrint("ContactPicker: Permission permanently denied.");
        if (mounted) {
          setState(() {
            _error = 'Contacts access is permanently blocked. Please enable it in App Settings.';
            _isLoading = false;
          });
        }
      } else {
        debugPrint("ContactPicker: Permission denied.");
        if (mounted) {
          setState(() {
            _error = 'Permission denied. We need contact access to import your partners.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("ContactPicker: Fatal Error = $e");
      if (mounted) {
        setState(() {
          _error = 'Error fetching contacts: $e';
          _isLoading = false;
        });
      }
    }
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Import Contacts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('Select contacts to add to your network', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                if (_selectedContacts.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _selectedContacts.clear()),
                    child: const Text('Deselect All'),
                  ),
              ],
            ),
          ),

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

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(_error!, textAlign: TextAlign.center)))
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
                                  ? (contact.phones.first.number ?? 'No number') 
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
                onPressed: _selectedContacts.isEmpty ? null : () => Navigator.pop(context, _selectedContacts.toList()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B22),
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _selectedContacts.isEmpty ? 'Select Contacts' : 'Add ${_selectedContacts.length} Partners',
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
