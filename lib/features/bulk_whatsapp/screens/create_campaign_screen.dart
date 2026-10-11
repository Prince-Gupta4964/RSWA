import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../models/lead_model.dart';
import '../../../viewmodels/lead_viewmodel.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../viewmodels/campaign_viewmodel.dart';
import '../viewmodels/whatsapp_template_viewmodel.dart';
import '../models/whatsapp_template_model.dart';

class CreateCampaignScreen extends StatefulWidget {
  const CreateCampaignScreen({super.key});

  @override
  State<CreateCampaignScreen> createState() => _CreateCampaignScreenState();
}

class _CreateCampaignScreenState extends State<CreateCampaignScreen> {
  final _nameController = TextEditingController();
  final _messageController = TextEditingController();
  final _templateIdController = TextEditingController();
  
  String _messageMode = 'Write Message'; // 'Write Message' or 'Use App Template'
  String _mediaType = 'text'; // 'text', 'image', 'document'
  
  File? _selectedFile;
  String? _selectedFileName;
  
  WhatsAppTemplateModel? _selectedAppTemplate;
  
  int _delayMin = 1;
  int _delayMax = 3;

  final Set<String> _selectedLeadIds = {};
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authVM = Provider.of<AuthViewModel>(context, listen: false);
      Provider.of<LeadViewModel>(context, listen: false).fetchLeads();
      Provider.of<WhatsAppTemplateViewModel>(context, listen: false).fetchTemplates(authVM.userUid);
    });
  }

  void _toggleSelectAll(List<LeadModel> leads) {
    setState(() {
      if (_selectedLeadIds.length == leads.length) {
        _selectedLeadIds.clear();
      } else {
        _selectedLeadIds.addAll(leads.map((l) => l.id));
      }
    });
  }

  void _toggleLeadSelection(String id) {
    setState(() {
      if (_selectedLeadIds.contains(id)) {
        _selectedLeadIds.remove(id);
      } else {
        _selectedLeadIds.add(id);
      }
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
        if (ext == 'pdf') {
          _mediaType = 'document';
        } else {
          _mediaType = 'image';
        }
      });
    }
  }

  Future<String?> _uploadMediaToFirebase(String uid) async {
    if (_selectedFile == null) return null;
    try {
      final ref = FirebaseStorage.instance.ref().child('campaign_media/$uid/${DateTime.now().millisecondsSinceEpoch}_$_selectedFileName');
      final uploadTask = await ref.putFile(_selectedFile!);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading media: $e');
      return null;
    }
  }

  Future<void> _createCampaign(List<LeadModel> allLeads) async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a campaign name.')));
      return;
    }
    if (_selectedLeadIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one recipient.')));
      return;
    }

    if (_messageMode == 'Write Message' && _messageController.text.trim().isEmpty && _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please write a message or attach a file.')));
      return;
    }

    if (_messageMode == 'Use App Template' && _selectedAppTemplate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an App Template.')));
      return;
    }

    setState(() => _isUploading = true);

    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final campaignVM = Provider.of<CampaignViewModel>(context, listen: false);

    String? mediaUrl;
    if (_selectedFile != null && _messageMode == 'Write Message') {
      mediaUrl = await _uploadMediaToFirebase(authVM.userUid);
      if (mediaUrl == null) {
        setState(() => _isUploading = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to upload attachment.')));
        return;
      }
    }

    final targetLeads = allLeads.where((l) => _selectedLeadIds.contains(l.id)).toList();

    String finalType = _mediaType;
    String? msgBody = _messageController.text.trim();
    String? finalMediaUrl = mediaUrl;
    String? finalFileName = _selectedFileName;
    List<Map<String, dynamic>>? btnList;
    String? footerTxt;

    if (_messageMode == 'Use App Template' && _selectedAppTemplate != null) {
       finalType = 'buttons'; // Because app templates have buttons support natively
       msgBody = _selectedAppTemplate!.messageBody;
       finalMediaUrl = _selectedAppTemplate!.mediaUrl;
       btnList = _selectedAppTemplate!.buttons;
       footerTxt = _selectedAppTemplate!.footerText;
       
       if (finalMediaUrl != null) {
          finalType = 'buttons'; // Deropo takes "image_url" alongside type=buttons based on payload provided.
       }
    }

    // Start background campaign process (it runs async in ViewModel)
    campaignVM.startCampaign(
      name: _nameController.text.trim(),
      targets: targetLeads,
      createdByUid: authVM.userUid,
      createdByName: authVM.userName,
      messageType: finalType,
      messageBody: msgBody,
      mediaUrl: finalMediaUrl,
      fileName: finalFileName,
      buttons: btnList,
      footerText: footerTxt,
      delayMin: _delayMin,
      delayMax: _delayMax,
    );

    setState(() => _isUploading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Campaign Started Successfully!')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final leadVM = Provider.of<LeadViewModel>(context);
    final leads = leadVM.leads;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Campaign', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey.shade50,
      body: _isUploading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Basic Information
                  const Text('⚙️ Basic Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Campaign Name *',
                      hintText: 'e.g., Summer Sale Campaign',
                      border: OutlineInputBorder(),
                      filled: true, fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. Recipients
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('👥 Recipients *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () => _toggleSelectAll(leads),
                        child: Text(_selectedLeadIds.length == leads.length ? 'Deselect All' : 'Select All'),
                      )
                    ],
                  ),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                    child: leadVM.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : leads.isEmpty
                            ? const Center(child: Text('No leads found.'))
                            : ListView.builder(
                                itemCount: leads.length,
                                itemBuilder: (context, index) {
                                  final lead = leads[index];
                                  return CheckboxListTile(
                                    value: _selectedLeadIds.contains(lead.id),
                                    onChanged: (val) => _toggleLeadSelection(lead.id),
                                    title: Text(lead.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    subtitle: Text(lead.contact, style: const TextStyle(fontSize: 11)),
                                    dense: true,
                                    activeColor: const Color(0xFF7A3BFF),
                                  );
                                },
                              ),
                  ),
                  const SizedBox(height: 24),

                  // 3. Message Configuration
                  const Text('💬 Message Configuration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Radio<String>(
                        value: 'Write Message',
                        groupValue: _messageMode,
                        activeColor: const Color(0xFF7A3BFF),
                        onChanged: (val) => setState(() {
                          if (val != null) {
                            _messageMode = val;
                            _mediaType = 'text'; // reset
                          }
                        }),
                      ),
                      const Text('Write Message'),
                      const SizedBox(width: 16),
                      Radio<String>(
                        value: 'Use App Template',
                        groupValue: _messageMode,
                        activeColor: const Color(0xFF7A3BFF),
                        onChanged: (val) => setState(() {
                          if (val != null) _messageMode = val;
                        }),
                      ),
                      const Text('Use App Template'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_messageMode == 'Write Message') ...[
                    TextField(
                      controller: _messageController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Message Content *',
                        hintText: 'Type your message here... Use {{name}} for variables.',
                        border: OutlineInputBorder(),
                        filled: true, fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                      child: const Text(
                        '💡 Available Variables:\n{{name}} - Contact name\n(Tip: Spintax like {Hi|Hello} coming soon)',
                        style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Attachment (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickFile,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.cloud_upload_outlined, color: Colors.grey, size: 32),
                            const SizedBox(height: 8),
                            Text(
                              _selectedFile != null ? 'File Selected: $_selectedFileName' : 'Choose file to upload (JPG, PNG, PDF)',
                              style: TextStyle(color: _selectedFile != null ? Colors.black : Colors.grey, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    Consumer<WhatsAppTemplateViewModel>(
                      builder: (context, templateVM, child) {
                        if (templateVM.isLoading) return const LinearProgressIndicator();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<WhatsAppTemplateModel>(
                              decoration: const InputDecoration(
                                labelText: 'Select App Template *',
                                border: OutlineInputBorder(),
                                filled: true, fillColor: Colors.white,
                              ),
                              hint: const Text('Choose a template'),
                              value: _selectedAppTemplate,
                              isExpanded: true,
                              items: templateVM.templates.map((t) {
                                return DropdownMenuItem(
                                  value: t,
                                  child: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedAppTemplate = val;
                                });
                              },
                            ),
                            if (_selectedAppTemplate != null) ...[
                               const SizedBox(height: 12),
                               Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                                  child: Text('Message: ${_selectedAppTemplate!.messageBody}', style: TextStyle(color: Colors.blue.shade900, fontSize: 13)),
                               ),
                            ],
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => context.push('/template-builder'),
                              icon: const Icon(Icons.add),
                              label: const Text('Create New Template'),
                            )
                          ]
                        );
                      }
                    ),
                  ],

                  const SizedBox(height: 24),

                  // 4. Timing & Delays
                  const Text('⏱️ Timing & Delays', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _delayMin.toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Random Delay Min (sec)', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                          onChanged: (val) => _delayMin = int.tryParse(val) ?? 1,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          initialValue: _delayMax.toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Random Delay Max (sec)', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                          onChanged: (val) => _delayMax = int.tryParse(val) ?? 3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _createCampaign(leads),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7A3BFF),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Create New Campaign', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
