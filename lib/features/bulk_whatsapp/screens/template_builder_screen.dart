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
      for (var b in widget.template!.buttons) {
        final text = b['text'] ?? '';
        final url = b['url'] ?? b['link'] ?? '';
        final phone = b['phone'] ?? '';
        _buttons.add({
          'type': b['type'] ?? 'reply',
          'text': text,
          'url': url,
          'phone': phone,
          'textCtrl': TextEditingController(text: text),
          'urlCtrl': TextEditingController(text: url),
          'phoneCtrl': TextEditingController(text: phone),
        });
      }
      _existingMediaUrl = widget.template!.mediaUrl;
      _mediaType = widget.template!.mediaType;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    _footerController.dispose();
    for (var b in _buttons) {
      (b['textCtrl'] as TextEditingController?)?.dispose();
      (b['urlCtrl'] as TextEditingController?)?.dispose();
      (b['phoneCtrl'] as TextEditingController?)?.dispose();
    }
    super.dispose();
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
      final defaultText = 'Button ${_buttons.length + 1}';
      _buttons.add({
        'type': 'reply',
        'text': defaultText,
        'url': '',
        'phone': '',
        'textCtrl': TextEditingController(text: defaultText),
        'urlCtrl': TextEditingController(),
        'phoneCtrl': TextEditingController(),
      });
    });
  }

  void _removeButton(int index) {
    setState(() {
      final removed = _buttons.removeAt(index);
      (removed['textCtrl'] as TextEditingController?)?.dispose();
      (removed['urlCtrl'] as TextEditingController?)?.dispose();
      (removed['phoneCtrl'] as TextEditingController?)?.dispose();
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

  Future<void> _saveTemplate() async {
    if (_nameController.text.trim().isEmpty || _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template Name and Content are required.')));
      return;
    }

    // Prepare JSON buttons for API compatibility
    List<Map<String, dynamic>> apiButtons = [];
    for (var b in _buttons) {
      final textCtrl = b['textCtrl'] as TextEditingController?;
      final urlCtrl = b['urlCtrl'] as TextEditingController?;
      final phoneCtrl = b['phoneCtrl'] as TextEditingController?;

      final text = textCtrl?.text.trim() ?? b['text'].toString().trim();
      final url = urlCtrl?.text.trim() ?? b['url'].toString().trim();
      final phone = phoneCtrl?.text.trim() ?? b['phone'].toString().trim();

      if (text.isEmpty) continue;
      
      Map<String, dynamic> btn = {"text": text};
      if (b['type'] == 'url') {
        btn["type"] = "url";
        btn["url"] = url;
        btn["link"] = url;
      } else if (b['type'] == 'call') {
        btn["type"] = "phone"; 
        btn["phone"] = phone;
      }
      apiButtons.add(btn);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚡ Template saved!')));
      Navigator.pop(context);
    }

    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final vm = Provider.of<WhatsAppTemplateViewModel>(context, listen: false);

    // Background Media Upload & Save
    _saveTemplateInBackground(authVM.userUid, authVM.userName, vm, apiButtons);
  }

  Future<void> _saveTemplateInBackground(
    String uid,
    String userName,
    WhatsAppTemplateViewModel vm,
    List<Map<String, dynamic>> apiButtons,
  ) async {
    try {
      String? finalMediaUrl = _existingMediaUrl;
      if (_selectedFile != null) {
        final ref = FirebaseStorage.instance.ref().child('template_media/$uid/${DateTime.now().millisecondsSinceEpoch}_$_selectedFileName');
        final uploadTask = await ref.putFile(_selectedFile!);
        finalMediaUrl = await uploadTask.ref.getDownloadURL();
      }

      if (widget.template != null) {
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
        createdByUid: uid,
        createdByName: userName,
        createdAt: DateTime.now(),
      );

      await vm.addTemplate(newTemplate);
    } catch (e) {
      debugPrint('Error saving template in background: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  icon: const Icon(Icons.check, color: Color(0xFF25D366)), // 🚀 NAYA: WhatsApp Green
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
                    _buildVarChip('{Hello|Hi|Hey}'),
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
                      controller: btn['textCtrl'],
                      decoration: const InputDecoration(labelText: 'Button Text', border: OutlineInputBorder(), isDense: true),
                      onChanged: (v) => setState(() => btn['text'] = v),
                    ),
                    if (btn['type'] == 'url') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: btn['urlCtrl'],
                        decoration: const InputDecoration(labelText: 'URL (https://...)', border: OutlineInputBorder(), isDense: true),
                        onChanged: (v) => setState(() => btn['url'] = v),
                      ),
                    ],
                    if (btn['type'] == 'call') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: btn['phoneCtrl'],
                        decoration: const InputDecoration(labelText: 'Phone Number (with country code)', border: OutlineInputBorder(), isDense: true),
                        onChanged: (v) => setState(() => btn['phone'] = v),
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

  Widget _buildPreview() {
    return Container(
      color: const Color(0xFFE5DDD5),
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
          
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.75 > 300 ? 300 : MediaQuery.of(context).size.width * 0.75,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedFile != null || _existingMediaUrl != null)
                    Container(
                      height: 150, width: double.infinity,
                      decoration: const BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
                      child: const Center(child: Icon(Icons.image, color: Colors.white, size: 40)),
                    ),
                  
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Text(
                      _contentController.text.isEmpty ? 'Your message text will appear here...' : _contentController.text.replaceAll('{{name}}', 'Prince'),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),

                  if (_footerController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Text(_footerController.text, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                  
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

                  if (_buttons.isNotEmpty) ...[
                    const Divider(height: 1),
                    ..._buttons.map((b) => Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      child: Text(
                        b['textCtrl']?.text.isNotEmpty == true ? b['textCtrl'].text : (b['text'] ?? 'Button'),
                        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    )),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
