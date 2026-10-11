import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/whatsapp_template_model.dart';
import '../viewmodels/whatsapp_template_viewmodel.dart';
import '../../../viewmodels/auth_viewmodel.dart';

class TemplateBuilderScreen extends StatefulWidget {
  final WhatsAppTemplateModel? template;

  const TemplateBuilderScreen({super.key, this.template});

  @override
  State<TemplateBuilderScreen> createState() => _TemplateBuilderScreenState();
}

class _TemplateBuilderScreenState extends State<TemplateBuilderScreen> {
  final _nameController = TextEditingController();
  final _contentController = TextEditingController();
  final _footerController = TextEditingController();

  final List<Map<String, dynamic>> _buttons = [];
  bool _isSaving = false;

  File? _selectedFile;
  String? _selectedFileName;
  String? _mediaType; // 'image' or 'document'
  String? _existingMediaUrl;

  @override
  void initState() {
    super.initState();
    if (widget.template != null) {
      _nameController.text = widget.template!.title;
      _contentController.text = widget.template!.messageBody;
      _footerController.text = widget.template!.footerText ?? '';
      _buttons.addAll(List.from(widget.template!.buttons));
      _existingMediaUrl = widget.template!.mediaUrl;
      _mediaType = widget.template!.mediaType;
    }
  }

  void _insertVariable(String variable) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    if (selection.start >= 0 && selection.end >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, variable);
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + variable.length),
      );
    } else {
      _contentController.text = text + variable;
      _contentController.selection = TextSelection.collapsed(offset: _contentController.text.length);
    }
    setState(() {}); // Update preview
  }

  void _addButton() {
    if (_buttons.length >= 5) return;
    setState(() {
      _buttons.add({
        'type': 'reply', // 'reply', 'url', 'call', 'copy'
        'text': 'Button ${_buttons.length + 1}',
        'url': '',
        'phone': ''
      });
    });
  }

  void _removeButton(int index) {
    setState(() {
      _buttons.removeAt(index);
    });
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result != null) {
      final file = File(result.files.single.path!);
      final ext = result.files.single.extension?.toLowerCase();
      setState(() {
        _selectedFile = file;
        _selectedFileName = result.files.single.name;
        _mediaType = ext == 'pdf' ? 'document' : 'image';
        _existingMediaUrl = null; // Clear existing if new picked
      });
    }
  }

  Future<String?> _uploadMediaToFirebase(String uid) async {
    if (_selectedFile == null) return _existingMediaUrl;
    try {
      final ref = FirebaseStorage.instance.ref().child('template_media/$uid/${DateTime.now().millisecondsSinceEpoch}_$_selectedFileName');
      final uploadTask = await ref.putFile(_selectedFile!);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading template media: $e');
      return null;
    }
  }

  Future<void> _saveTemplate() async {
    if (_nameController.text.trim().isEmpty || _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template Name and Content are required.')));
      return;
    }

    // Prepare JSON buttons for API compatibility
    List<Map<String, dynamic>> apiButtons = [];
    for (var b in _buttons) {
      if (b['text'].toString().trim().isEmpty) continue;
      
      Map<String, dynamic> btn = {"text": b['text']};
      if (b['type'] == 'url') {
        btn["type"] = "url";
        btn["url"] = b['url'];
      } else if (b['type'] == 'call') {
        btn["type"] = "phone"; // Adjust based on Deropo specs if needed, commonly phone/call
        btn["phone"] = b['phone'];
      }
      // 'reply' or 'copy' might just use text if specific payload isn't known, standard is just {text:""}
      apiButtons.add(btn);
    }

    setState(() => _isSaving = true);
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final vm = Provider.of<WhatsAppTemplateViewModel>(context, listen: false);

    String? finalMediaUrl = await _uploadMediaToFirebase(authVM.userUid);

    try {
      if (widget.template != null) {
        // Update existing logic could be added to ViewModel. For now just updating title/body.
        // Needs a full update method in ViewModel for rich templates. I'll delete old and create new.
        await vm.deleteTemplate(widget.template!.id);
      }

      final newTemplate = WhatsAppTemplateModel(
        id: '',
        title: _nameController.text.trim(),
        messageBody: _contentController.text.trim(),
        footerText: _footerController.text.trim(),
        buttons: apiButtons,
        mediaUrl: finalMediaUrl,
        mediaType: _mediaType,
        createdByUid: authVM.userUid,
        createdByName: authVM.userName,
        createdAt: DateTime.now(),
      );

      await vm.addTemplate(newTemplate);
      
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine layout based on screen width (for iPad/Web)
    final bool isWideScreen = MediaQuery.of(context).size.width > 800;

    Widget editorContent = _buildEditor();
    Widget previewContent = _buildPreview();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template == null ? 'Create Template' : 'Edit Template', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        actions: [
          _isSaving
              ? const Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(
                  icon: const Icon(Icons.check, color: Color(0xFF7A3BFF)),
                  onPressed: _saveTemplate,
                )
        ],
      ),
      backgroundColor: Colors.grey.shade100,
      body: isWideScreen
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: editorContent),
                Container(width: 1, color: Colors.grey.shade300),
                Expanded(flex: 2, child: previewContent),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  previewContent,
                  const Divider(),
                  editorContent,
                ],
              ),
            ),
    );
  }

  Widget _buildEditor() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Template Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(hintText: 'Welcome Message', border: OutlineInputBorder(), filled: true, fillColor: Colors.white, isDense: true),
          ),
          const SizedBox(height: 20),

          const Text('Template Content *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _contentController,
            maxLines: 6,
            onChanged: (v) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Enter your message here...', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
          ),
          
          const SizedBox(height: 12),
          // Variable Chips Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.push_pin, size: 14, color: Colors.red),
                    SizedBox(width: 4),
                    Text('Click a variable to insert it at the cursor:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    _buildVarChip('{{name}}'),
                    _buildVarChip('{{phone}}'),
                    _buildVarChip('{Hello|Hi|Hey}'), // Spintax example
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Variables use {{name}} syntax. Spintax uses {A|B|C} for random selection.', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Text('Footer (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _footerController,
            onChanged: (v) => setState(() {}),
            decoration: const InputDecoration(hintText: 'e.g. Reply STOP to unsubscribe', border: OutlineInputBorder(), filled: true, fillColor: Colors.white, isDense: true),
          ),

          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Buttons (Max 5)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              if (_buttons.length < 5)
                TextButton.icon(
                  onPressed: _addButton,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Button'),
                )
            ],
          ),
          const SizedBox(height: 8),

          // Dynamic Buttons List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _buttons.length,
            itemBuilder: (context, index) {
              final btn = _buttons[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: btn['type'],
                            decoration: const InputDecoration(labelText: 'Button Type', border: OutlineInputBorder(), isDense: true),
                            items: const [
                              DropdownMenuItem(value: 'reply', child: Text('Quick Reply (Keyword)')),
                              DropdownMenuItem(value: 'url', child: Text('CTA - URL')),
                              DropdownMenuItem(value: 'call', child: Text('CTA - Phone')),
                            ],
                            onChanged: (v) {
                              setState(() {
                                btn['type'] = v;
                              });
                            },
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removeButton(index)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Button Text', border: OutlineInputBorder(), isDense: true),
                      onChanged: (v) => setState(() => btn['text'] = v),
                      controller: TextEditingController.fromValue(TextEditingValue(text: btn['text'], selection: TextSelection.collapsed(offset: btn['text'].toString().length))),
                    ),
                    if (btn['type'] == 'url') ...[
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(labelText: 'URL (https://...)', border: OutlineInputBorder(), isDense: true),
                        onChanged: (v) => setState(() => btn['url'] = v),
                        controller: TextEditingController.fromValue(TextEditingValue(text: btn['url'], selection: TextSelection.collapsed(offset: btn['url'].toString().length))),
                      ),
                    ],
                    if (btn['type'] == 'call') ...[
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(labelText: 'Phone Number (with country code)', border: OutlineInputBorder(), isDense: true),
                        onChanged: (v) => setState(() => btn['phone'] = v),
                        controller: TextEditingController.fromValue(TextEditingValue(text: btn['phone'], selection: TextSelection.collapsed(offset: btn['phone'].toString().length))),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 20),
          const Text('Attachment (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  const Icon(Icons.cloud_upload_outlined, color: Colors.grey, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    _selectedFile != null ? 'File Selected: $_selectedFileName' : (_existingMediaUrl != null ? 'Existing Media Attached. Tap to change.' : 'Choose file to upload (JPG, PNG, PDF)'),
                    style: TextStyle(color: (_selectedFile != null || _existingMediaUrl != null) ? Colors.black : Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildVarChip(String text) {
    return InkWell(
      onTap: () => _insertVariable(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.blue.shade200), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: const TextStyle(color: Colors.blue, fontSize: 12)),
      ),
    );
  }

  // --- LIVE PREVIEW UI ---
  Widget _buildPreview() {
    return Container(
      color: const Color(0xFFE5DDD5), // WhatsApp background color
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: Colors.grey),
              const SizedBox(width: 8),
              const Text('Preview (Live)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 16),
          
          // Chat Bubble
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.75 > 300 ? 300 : MediaQuery.of(context).size.width * 0.75,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fake Attachment
                  if (_selectedFile != null || _existingMediaUrl != null)
                    Container(
                      height: 150, width: double.infinity,
                      decoration: const BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
                      child: const Center(child: Icon(Icons.image, color: Colors.white, size: 40)),
                    ),
                  
                  // Message Body
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Text(
                      _contentController.text.isEmpty ? 'Your message text will appear here...' : _contentController.text.replaceAll('{{name}}', 'Prince'),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),

                  // Footer
                  if (_footerController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Text(_footerController.text, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                  
                  // Timestamp
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 8),
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('12:00', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          const SizedBox(width: 4),
                          const Icon(Icons.done_all, size: 14, color: Colors.blue),
                        ],
                      ),
                    ),
                  ),
                  
                  // Buttons Preview
                  if (_buttons.isNotEmpty)
                    Column(
                      children: _buttons.map((b) {
                        return Container(
                          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.black12))),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (b['type'] == 'url') const Icon(Icons.link, size: 16, color: Colors.blue),
                                if (b['type'] == 'call') const Icon(Icons.phone, size: 16, color: Colors.blue),
                                if (b['type'] != 'reply') const SizedBox(width: 6),
                                Text(b['text'].isEmpty ? 'Button' : b['text'], style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
