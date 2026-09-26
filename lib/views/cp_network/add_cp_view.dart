import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_storage_service.dart';
import '../../services/contact_picker_service.dart';
import '../../viewmodels/cp_viewmodel.dart';
import '../../viewmodels/lead_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/app_configuration_viewmodel.dart';
import '../../models/cp_model.dart';
import '../../utils/cp_form_config.dart';
import '../../utils/role_permissions.dart';

class AddCPView extends StatefulWidget {
  final CPModel? cp;
  const AddCPView({super.key, this.cp});

  @override
  State<AddCPView> createState() => _AddCPViewState();
}

class _AddCPViewState extends State<AddCPView> {
  bool _isSaving = false;
  final Set<String> _expandedSections = {'Basic Info'};

  final Map<String, dynamic> _formData = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, LayerLink> _layerLinks = {};
  final Map<String, bool> _openDropdowns = {}; 
  final List<String> _flatFields = [];
  String? _currentFocusedId;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {}; 

  final Map<String, int> _activeChipIndex = {};
  final Map<String, XFile?> _pickedImages = {};
  final ImagePicker _picker = ImagePicker();

  static const Color primaryColor = Color(0xFFFBE64E);
  static const Color secondaryColor = Color(0xFF6B5800);

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    final existingData = widget.cp?.rawData ?? {};
    _formData['partnerType'] = existingData['partnerType'] ?? ''; 
    _formData['source'] = existingData['source'] ?? 'Walk In';
    _formData['status'] = existingData['status'] ?? 'Active Partner';
    _formData['gender'] = existingData['gender'] ?? 'Male';
    _formData['membershipStatus'] = existingData['membershipStatus'] ?? 'Active';
    _formData['level'] = existingData['level'] ?? 'Scout (1%)';

    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    if (widget.cp == null) {
      _formData['advisor'] = authVM.userName;
      _formData['caller'] = authVM.userName;
      _formData['reachedBy'] = authVM.userName;
      _formData['createdByLabel'] = authVM.userName;
      _formData['lastEditedBy'] = authVM.userName;
    } else {
      _formData['lastEditedBy'] = authVM.userName;
    }

    _initializeFieldsLocal(existingData);

    if (widget.cp == null) {
      final now = DateTime.now();
      _formData['timestamp'] = now;
      _controllers['timestamp']?.text = DateFormat('dd MMM yyyy, hh:mm a').format(now);
      _formData['cpID'] = _generateUniqueIDLocal();
      _controllers['cpID']?.text = _formData['cpID'];
      _formData['joinedDate'] = now;
      _controllers['joinedDate']?.text = DateFormat('dd MMM yyyy').format(now);
      _formData['yearsCompleted'] = '0 years';
      _controllers['yearsCompleted']?.text = '0 years';
    } else {
      final joined = existingData['joinedDate'];
      if (joined != null) {
        DateTime? joinedDt;
        if (joined is Timestamp) joinedDt = joined.toDate();
        else if (joined is DateTime) joinedDt = joined;
        if (joinedDt != null) {
          final diff = DateTime.now().difference(joinedDt).inDays / 365;
          _controllers['yearsCompleted']?.text = '${diff.floor()} years';
        }
      }
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) { 
      // 🚀 NAYA: Handle Referral Link (?ref=Name)
      final state = GoRouterState.of(context);
      final String? refFromLink = state.uri.queryParameters['ref'];
      if (refFromLink != null && refFromLink.isNotEmpty && widget.cp == null) {
        setState(() {
          _formData['source'] = 'Referral';
          _formData['referralName1'] = refFromLink;
          _controllers['referralName1']?.text = refFromLink;
          _updateMultiLevelReferrals(refFromLink);
        });
      }
      _navigateToField('partnerType'); 
    });
  }

  void _initializeFieldsLocal(Map<String, dynamic> existingData) {
    for (var section in _customFormStructure) {
      for (var field in section['fields']) { _initFieldRecursive(field, existingData); }
    }
  }

  void _initFieldRecursive(Map<String, dynamic> field, Map<String, dynamic> existingData) {
    if (field['type'] == 'row') {
      for (var sub in field['fields']) _initFieldRecursive(sub, existingData);
      return;
    }
    final String id = field['id'];
    final String type = field['type'];
    if (!_flatFields.contains(id) && type != 'image') {
      _flatFields.add(id);
      _layerLinks[id] = LayerLink();
      final node = FocusNode();
      node.addListener(() {
        if (node.hasFocus) {
          setState(() => _currentFocusedId = id);
          Future.delayed(const Duration(milliseconds: 100), () {
            if (node.context != null && mounted) Scrollable.ensureVisible(node.context!, duration: const Duration(milliseconds: 300), alignment: 0.2);
          });
        }
      });
      _focusNodes[id] = node;
    }
    if (type != 'chips' && type != 'image' && type != 'switch') {
      var val = existingData[id] ?? _formData[id] ?? '';
      if (val is Timestamp) val = DateFormat('dd MMM yyyy, hh:mm a').format(val.toDate());
      _controllers[id] = TextEditingController(text: val.toString());
      _formData[id] = val.toString();
    } else if (type == 'chips' || type == 'switch') {
      _formData[id] = existingData[id] ?? _formData[id];
    }
  }

  final List<Map<String, dynamic>> _customFormStructure = [
    {
      'title': 'Basic Info',
      'fields': [
        {'type': 'row', 'fields': [
          {'id': 'cpID', 'label': 'ID (Auto)', 'type': 'text', 'readOnly': true},
          {'id': 'timestamp', 'label': 'Date Time (Auto)', 'type': 'text', 'readOnly': true},
        ]},
        {'id': 'partnerType', 'label': 'Type', 'type': 'chips', 'options': ['RP', 'CP', 'Pro CP', 'Investor', 'Builder', 'Land Owner']},
        {'type': 'row', 'fields': [
          {'id': 'cpName', 'label': 'Name', 'type': 'text'},
          {'id': 'surname', 'label': 'Surname', 'type': 'text'},
        ]},
        {'id': 'companyName', 'label': 'Company Name', 'type': 'autocomplete'},
        {'type': 'row', 'fields': [
          {'id': 'contactNo', 'label': 'WhatsApp No.', 'type': 'phone'},
          {'id': 'contact2', 'label': 'Contact 2', 'type': 'phone'},
        ]},
        {'id': 'email', 'label': 'Email', 'type': 'text'},
        {'id': 'source', 'label': 'Source', 'type': 'dropdown', 'options': ['Walk In', 'Referral', 'Event', 'Digital Marketing', 'Banner Marketing', 'Poster Marketing', 'Pamphlet Marketing', 'Seminar', 'Facebook', 'Instagram', 'Youtube', 'Justdial', 'Website', 'IVR', 'Others']},
        {'id': 'referralName1', 'label': 'Referral Name 1', 'type': 'autocomplete', 'visibleIf': 'source == Referral'},
        {'id': 'referralName2', 'label': 'Referral Name 2', 'type': 'text', 'readOnly': true, 'visibleIf': 'source == Referral'},
        {'id': 'referralName3', 'label': 'Referral Name 3', 'type': 'text', 'readOnly': true, 'visibleIf': 'source == Referral'},
        {'id': 'nearestStation', 'label': 'Nearest Station', 'type': 'text'},
        {'id': 'sendReferralLink', 'label': 'Send Referral Link (Toggle)', 'type': 'switch'},
      ]
    },
    {
      'title': 'CP Details',
      'fields': [
        {'id': 'status', 'label': 'Status (Auto or SuperAdmin)', 'type': 'chips', 'options': ['Active Partner', 'Pending', 'Inactive'], 'roles': ['admin', 'super_admin']},
        {'id': 'tag', 'label': 'Tag', 'type': 'text', 'roles': ['admin', 'super_admin']},
        {'id': 'nickName', 'label': 'Nick Name (Unique)', 'type': 'text'},
        {'id': 'gender', 'label': 'Gender', 'type': 'chips', 'options': ['Male', 'Female', 'Other']},
        {'id': 'address', 'label': 'Address', 'type': 'multiline'},
        {'id': 'workLocation', 'label': 'Work Location', 'type': 'text'},
        {'id': 'qualification', 'label': 'Qualification', 'type': 'text'},
        {'id': 'reraId', 'label': 'Rera Number', 'type': 'text'},
        {'id': 'experience', 'label': 'Total Experience', 'type': 'text'},
        {'type': 'row', 'fields': [
          {'id': 'joinedDate', 'label': 'Joined A Tech on (Auto)', 'type': 'text', 'readOnly': true},
          {'id': 'yearsCompleted', 'label': 'Years Completed', 'type': 'text', 'readOnly': true},
        ]},
        {'id': 'profilePhoto', 'label': 'Photo', 'type': 'image'},
        {'id': 'visitingCard', 'label': 'Visiting Card', 'type': 'image'},
        {'id': 'aadharCard', 'label': 'Aadhar Card', 'type': 'image'},
        {'id': 'panCard', 'label': 'Pan Card', 'type': 'image'},
        {'id': 'advisor', 'label': 'Advisor', 'type': 'text'},
        {'id': 'caller', 'label': 'Caller', 'type': 'text'},
        {'id': 'reachedBy', 'label': 'Reached By (Staff)', 'type': 'text'},
      ]
    },
    {
      'title': 'Score',
      'roles': ['admin', 'super_admin'],
      'fields': [
        {'id': 'approveMembership', 'label': 'Approve Membership', 'type': 'switch'},
        {'id': 'membershipStatus', 'label': 'Membership Status (Active)', 'type': 'text', 'readOnly': true},
        {'id': 'membershipPackage', 'label': 'Membership Package', 'type': 'autocomplete', 'options': ['Basic 30k', 'Silver 50k', 'Gold 1L', 'Diamond 2.3L', 'Platinum 3L']},
        {'id': 'level', 'label': 'Level', 'type': 'chips', 'options': ['Scout (1%)', 'Referral Partner', 'Verified Referral', 'Registered Referral (2%)', 'Active Partner (3%)', 'Channel Partner', 'Elite CP', 'Strategic CP', 'Brand Advocate', 'Franchise Partner (5%)']},
        {'id': 'totalCPContributed', 'label': 'Total CP Contributed', 'type': 'number', 'readOnly': true},
        {'id': 'contributedCPWorth', 'label': 'Contributed CP Worth', 'type': 'text'},
        {'id': 'clientsAdded', 'label': 'Clients Added', 'type': 'number', 'readOnly': true},
        {'id': 'clientsVisits', 'label': 'Clients Visits', 'type': 'number'},
        {'id': 'clientsToken', 'label': 'Clients Token', 'type': 'number'},
        {'id': 'clientsRegistrationDone', 'label': 'Clients Registration Done', 'type': 'number'},
        {'id': 'projectsWorkedOn', 'label': 'Projects Worked On', 'type': 'number'},
        {'id': 'investorsWorkedOn', 'label': 'Investors Worked On', 'type': 'number'},
        {'id': 'investorsConverted', 'label': 'Investors Converted', 'type': 'number'},
        {'id': 'currentNetwork', 'label': 'Current Network', 'type': 'text'},
        {'id': 'reviewByClients', 'label': 'Review By Clients', 'type': 'multiline'},
        {'id': 'reviewByColleagues', 'label': 'Review by Collegues', 'type': 'multiline'},
        {'id': 'reviewByStaff', 'label': 'Review By Staff', 'type': 'multiline'},
        {'id': 'createdByLabel', 'label': 'Created By', 'type': 'text', 'readOnly': true},
        {'id': 'lastEditedBy', 'label': 'Last Edited By', 'type': 'text', 'readOnly': true},
      ]
    },
    {
      'title': 'Login Credentials',
      'fields': [
        {'id': 'email_login', 'label': 'Login Email', 'type': 'text'},
        {'id': 'password', 'label': 'Login Password', 'type': 'text'},
      ]
    }
  ];

  @override
  void dispose() {
    for (var c in _controllers.values) c.dispose();
    for (var n in _focusNodes.values) n.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleSection(String title) {
    setState(() {
      if (_expandedSections.contains(title)) _expandedSections.remove(title);
      else {
        _expandedSections.add(title);
        Future.delayed(const Duration(milliseconds: 250), () {
          final key = _sectionKeys[title];
          if (key?.currentContext != null) Scrollable.ensureVisible(key!.currentContext!, duration: const Duration(milliseconds: 400), alignment: 0.0, curve: Curves.easeInOut);
        });
      }
    });
  }

  void _globalToggle() {
    final all = _customFormStructure.map((s) => s['title'] as String).toList();
    setState(() {
      if (_expandedSections.length == all.length) _expandedSections.clear();
      else { _expandedSections.clear(); _expandedSections.addAll(all); }
    });
  }

  void _navigateToField(String id) {
    String? sec;
    for (var s in _customFormStructure) { if (_isFieldIn(s['fields'], id)) { sec = s['title']; break; } }
    if (sec != null && !_expandedSections.contains(sec)) setState(() => _expandedSections.add(sec!));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_focusNodes.containsKey(id)) {
        _focusNodes[id]!.requestFocus();
        final type = _getFieldTypeLocal(id);
        final textTypes = ['text', 'autocomplete', 'dropdown', 'multiline', 'number', 'phone'];
        if (textTypes.contains(type) && !kIsWeb) SystemChannels.textInput.invokeMethod('textInput.show');
      }
    });
  }

  bool _isFieldIn(List<dynamic> fields, String id) {
    for (var f in fields) { if (f['type'] == 'row') { if (_isFieldIn(f['fields'], id)) return true; } else if (f['id'] == id) return true; }
    return false;
  }

  String? _getFieldTypeLocal(String id) {
    for (var s in _customFormStructure) { for (var f in s['fields']) { if (f['type'] == 'row') { for (var sub in f['fields']) if (sub['id'] == id) return sub['type']; } else if (f['id'] == id) return f['type']; } }
    return null;
  }

  void _focusNextField({bool isDoubleClick = false}) {
    if (_currentFocusedId == null) { _navigateToField(_flatFields.first); return; }
    final int idx = _flatFields.indexOf(_currentFocusedId!);
    if (idx != -1 && idx < _flatFields.length - 1) {
      for (int i = idx + 1; i < _flatFields.length; i++) {
        if (_isFieldVisibleLocal(_flatFields[i])) { _navigateToField(_flatFields[i]); return; }
      }
    }
  }

  void _focusPrevField() {
    if (_currentFocusedId == null) return;
    final int idx = _flatFields.indexOf(_currentFocusedId!);
    if (idx > 0) {
      for (int i = idx - 1; i >= 0; i--) {
        if (_isFieldVisibleLocal(_flatFields[i])) { _navigateToField(_flatFields[i]); return; }
      }
    }
  }

  bool _isFieldVisibleLocal(String id) {
    final bool hasType = _formData['partnerType'] != null && _formData['partnerType'].toString().isNotEmpty;
    if (id == 'cpID' || id == 'timestamp' || id == 'partnerType') return true;
    
    // 🚀 NAYA: Gatekeeper logic - hide everything else until Type is selected
    if (!hasType) return false;

    // 🚀 NAYA: Referral 2 & 3 are Admin-only
    if (id == 'referralName2' || id == 'referralName3') {
      final authVM = Provider.of<AuthViewModel>(context, listen: false);
      if (authVM.appRole != AppRole.admin && authVM.appRole != AppRole.superAdmin) return false;
    }

    if (id.startsWith('referralName')) return _formData['source'] == 'Referral';
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.cp != null;
    final String roleKey = appRoleKey(context.watch<AuthViewModel>().appRole);
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) { if (!didPop) context.go('/cp-list'); },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: primaryColor, elevation: 0, centerTitle: true, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => context.go('/cp-list')), title: Text(isEditing ? 'Update Partner' : 'Add Partner', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18))),
        body: Column(
          children: [
            Expanded(child: ListView(controller: _scrollController, padding: const EdgeInsets.fromLTRB(16, 16, 16, 20), children: _customFormStructure.map((s) => _buildSectionLocal(s, roleKey)).toList())),
            _buildStickyNav(isEditing),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLocal(Map<String, dynamic> s, String roleKey) {
    final String title = s['title'];
    final bool isExp = _expandedSections.contains(title);
    final key = _sectionKeys.putIfAbsent(title, () => GlobalKey());
    final bool hasType = _formData['partnerType'] != null && _formData['partnerType'].toString().isNotEmpty;

    if (title != 'Basic Info' && !hasType) return const SizedBox.shrink();
    if (s.containsKey('roles') && !(s['roles'] as List).contains(roleKey)) return const SizedBox.shrink();

    return Column(
      key: key, crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _toggleSection(title), onDoubleTap: _globalToggle,
          child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration(color: isExp ? primaryColor.withValues(alpha: 0.1) : Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade100))), child: Row(children: [Text(title.toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)), const Spacer(), Icon(isExp ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: isExp ? secondaryColor : Colors.grey, size: 20)])),
        ),
        if (isExp) Padding(padding: const EdgeInsets.fromLTRB(8, 12, 8, 4), child: Column(children: (s['fields'] as List).map((f) => _buildDynamicFieldLocal(f, roleKey)).toList())),
      ],
    );
  }

  Widget _buildDynamicFieldLocal(Map<String, dynamic> f, String roleKey) {
    if (f['type'] == 'row') {
      final vis = (f['fields'] as List).where((sub) => _isFieldVisibleLocal(sub['id'])).toList();
      if (vis.isEmpty) return const SizedBox.shrink();
      return Padding(padding: const EdgeInsets.only(bottom: 16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: vis.map((sub) => Expanded(child: Padding(padding: EdgeInsets.only(right: vis.last == sub ? 0 : 12), child: _buildFieldContentLocal(sub, roleKey)))).toList()));
    }
    if (!_isFieldVisibleLocal(f['id'])) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: _buildFieldContentLocal(f, roleKey));
  }

  Widget _buildFieldContentLocal(Map<String, dynamic> f, String roleKey) {
    final id = f['id']; final label = f['label']; final type = f['type'];
    if (f.containsKey('roles') && !(f['roles'] as List).contains(roleKey)) return const SizedBox.shrink();
    final bool readOnly = f['readOnly'] == true;
    switch (type) {
      case 'dropdown': return _buildSearchableLocal(label, id, readOnly: readOnly);
      case 'autocomplete': return _buildSearchableLocal(label, id, readOnly: readOnly);
      case 'chips': return _buildChoiceChipsLocal(label, id, List<String>.from(f['options'] ?? []));
      case 'phone': return _buildSearchableLocal(label, id, kType: TextInputType.phone);
      case 'number': return _buildSearchableLocal(label, id, kType: TextInputType.number);
      case 'image': return _buildImagePickerLocal(label, id);
      case 'switch': return _buildSwitchLocal(label, id);
      default: return _buildSearchableLocal(label, id, readOnly: readOnly);
    }
  }

  Widget _buildSearchableLocal(String label, String id, {TextInputType? kType, bool readOnly = false}) {
    final opts = _getOptsLocal(id); final ctrl = _controllers[id]!; final node = _focusNodes[id]!; final link = _layerLinks[id]!;
    bool isOpen = _openDropdowns[id] ?? false;
    return CompositedTransformTarget(
      link: link,
      child: RawAutocomplete<String>(
        focusNode: node, textEditingController: ctrl,
        optionsBuilder: (val) {
          if (val.text.isEmpty && !isOpen) return const Iterable<String>.empty();
          if (val.text.isEmpty) return opts;
          return opts.where((o) => o.toLowerCase().contains(val.text.toLowerCase()));
        },
        onSelected: (val) { 
          setState(() { 
            ctrl.text = val; _formData[id] = val; _openDropdowns[id] = false; 
            // 🚀 NAYA: Trigger chain reaction for Referrals
            if (id == 'referralName1') _updateMultiLevelReferrals(val);
          }); 
          _focusNextField(); 
        },
        fieldViewBuilder: (ctx, tCtrl, fNode, onSub) => Focus(
          onKeyEvent: (n, e) {
            if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.arrowRight && tCtrl.selection.baseOffset == tCtrl.text.length) {
              final query = tCtrl.text.toLowerCase();
              if (query.isNotEmpty) {
                final matches = opts.where((o) => o.toLowerCase().contains(query)).toList();
                if (matches.isNotEmpty && tCtrl.text != matches.first) {
                   WidgetsBinding.instance.addPostFrameCallback((_) { setState(() { ctrl.value = TextEditingValue(text: matches.first, selection: TextSelection.collapsed(offset: matches.first.length)); _formData[id] = matches.first; }); });
                   return KeyEventResult.handled;
                }
              }
            }
            return KeyEventResult.ignored;
          },
          child: TextField(
            controller: tCtrl, focusNode: fNode, readOnly: readOnly, keyboardType: kType, textInputAction: TextInputAction.next, style: const TextStyle(fontSize: 15),
            onChanged: (v) => _formData[id] = v,
            onTap: () { if (tCtrl.text.isEmpty) { setState(() => _openDropdowns[id] = true); tCtrl.text = ' '; tCtrl.text = ''; } },
            onSubmitted: (_) { onSub(); Future.delayed(const Duration(milliseconds: 50), () => _focusNextField()); },
            decoration: _outlinedDecoration(label, id).copyWith(
              suffixIcon: (id == 'contactNo' || id == 'contact2') ? IconButton(icon: const Icon(Icons.contact_phone_outlined, color: Color(0xFFFF6B22)), onPressed: () => _pickNumberFromContactsLocal(id)) : (opts.isNotEmpty ? IconButton(icon: Icon(isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down, color: Colors.grey), onPressed: () { setState(() { if (isOpen) { _openDropdowns[id] = false; FocusScope.of(context).unfocus(); } else { _openDropdowns[id] = true; fNode.requestFocus(); final curr = tCtrl.text; tCtrl.text = '$curr '; tCtrl.text = curr; } }); }) : null)
            ),
          ),
        ),
        optionsViewBuilder: (ctx, onSel, options) => Align(alignment: Alignment.topLeft, child: CompositedTransformFollower(link: link, showWhenUnlinked: false, offset: const Offset(0, 52), child: Material(elevation: 16, borderRadius: BorderRadius.circular(12), color: Colors.white, child: Container(width: 380, constraints: const BoxConstraints(maxHeight: 280), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300, width: 1.5)), child: ListView.separated(padding: EdgeInsets.zero, shrinkWrap: true, itemCount: options.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (ctx, idx) { final o = options.elementAt(idx); final hIdx = AutocompleteHighlightedOption.of(ctx); final isH = hIdx == idx || (hIdx == -1 && idx == 0); return ListTile(dense: true, tileColor: isH ? primaryColor.withValues(alpha: 0.3) : null, title: _highlightTextLocal(o, ctrl.text), onTap: () => onSel(o)); }))))),
      ),
    );
  }

  Widget _buildChoiceChipsLocal(String label, String id, List<String> opts) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)), const SizedBox(height: 8), Wrap(spacing: 8, runSpacing: 8, children: opts.map((o) { final isS = _formData[id] == o; return ChoiceChip(label: Text(o, style: TextStyle(fontSize: 12, color: isS ? Colors.black : Colors.black87, fontWeight: isS ? FontWeight.bold : FontWeight.normal)), selected: isS, selectedColor: primaryColor, backgroundColor: const Color(0xFFF5F5F5), checkmarkColor: Colors.black, onSelected: (v) { setState(() { _formData[id] = v ? o : null; if (id == 'partnerType' && !v) { _formData['partnerType'] = ''; } }); _focusNextField(isDoubleClick: true); }, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))); }).toList())]));
  }

  Widget _buildSwitchLocal(String label, String id) {
    bool isS = _formData[id] == 'Yes';
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFCCCCCC))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)), Switch(value: isS, activeColor: secondaryColor, activeTrackColor: primaryColor.withValues(alpha: 0.5), onChanged: (v) { setState(() { _formData[id] = v ? 'Yes' : 'No'; }); })]));
  }

  Widget _buildImagePickerLocal(String label, String id) {
    final img = _pickedImages[id];
    final existingUrl = _formData[id] is String && _formData[id].toString().startsWith('http') ? _formData[id] as String : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)), const SizedBox(height: 8), InkWell(onTap: () => _pickImageLocal(id), child: Container(height: 120, width: double.infinity, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)), child: (img == null && existingUrl == null) ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt_outlined, color: Colors.grey, size: 32), SizedBox(height: 8), Text('Tap to select image', style: TextStyle(color: Colors.grey, fontSize: 12))]) : ClipRRect(borderRadius: BorderRadius.circular(8), child: existingUrl != null ? Image.network(existingUrl, fit: BoxFit.cover) : (kIsWeb ? Image.network(img!.path, fit: BoxFit.cover) : Image.file(File(img!.path), fit: BoxFit.cover)))) )]);
  }

  InputDecoration _outlinedDecoration(String label, String id) { return InputDecoration(labelText: label, alignLabelWithHint: true, labelStyle: const TextStyle(fontSize: 15, color: Color(0xFF555555)), floatingLabelStyle: const TextStyle(color: secondaryColor, fontWeight: FontWeight.bold, fontSize: 12), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), filled: true, fillColor: Colors.white, isDense: true, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCCCCCC))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: secondaryColor, width: 1.5)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(6))); }

  Widget _highlightTextLocal(String text, String query) {
    if (query.trim().isEmpty) return Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87));
    final List<TextSpan> spans = []; final String lt = text.toLowerCase(); final String lq = query.trim().toLowerCase(); int start = 0; int idx;
    while ((idx = lt.indexOf(lq, start)) != -1) { if (idx > start) spans.add(TextSpan(text: text.substring(start, idx), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13))); spans.add(TextSpan(text: text.substring(idx, idx + lq.length), style: const TextStyle(color: secondaryColor, fontWeight: FontWeight.w900, fontSize: 13))); start = idx + lq.length; }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13)));
    return RichText(text: TextSpan(children: spans));
  }

  List<String> _getOptsLocal(String id) {
    final cpVM = Provider.of<CPViewModel>(context, listen: false); 
    
    // 🚀 NAYA: Fetch CP names for Referral 1
    if (id == 'referralName1') {
      final String myFullName = widget.cp?.fullName ?? '${_formData['cpName'] ?? ''} ${_formData['surname'] ?? ''}'.trim();
      return cpVM.cps
          .map((c) => c.fullName)
          .where((s) => s.isNotEmpty && s.toLowerCase() != myFullName.toLowerCase())
          .toSet()
          .toList()
          ..sort();
    }

    final learned = cpVM.getUniqueValues(id);
    final configVM = Provider.of<AppConfigurationViewModel>(context, listen: false);
    List<String> static = [];
    for (var s in _customFormStructure) { for (var f in s['fields']) { if (f['type'] == 'row') { for (var sub in f['fields']) if (sub['id'] == id) static = List<String>.from(sub['options'] ?? []); } else if (f['id'] == id) static = List<String>.from(f['options'] ?? []); } }
    static = configVM.getOptionsForField('CP Network Form', id, static);
    return {...static, ...learned}.toList()..sort();
  }

  Widget _buildStickyNav(bool isEditing) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: const BoxDecoration(color: Colors.transparent), child: SafeArea(top: false, child: Row(children: [
      Expanded(flex: 1, child: _buildNavBtn(Icons.arrow_back_rounded, _focusPrevField)), const SizedBox(width: 8),
      Expanded(flex: 4, child: GestureDetector(onDoubleTap: () => _focusNextField(isDoubleClick: true), child: ElevatedButton(onPressed: _isSaving ? null : _handleSave, style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0, padding: const EdgeInsets.symmetric(vertical: 10)), child: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: secondaryColor)) : Text(isEditing ? 'Update Partner' : 'Save Partner', style: const TextStyle(color: secondaryColor, fontWeight: FontWeight.bold, fontSize: 13)) ))),
      const SizedBox(width: 8),
      Expanded(flex: 1, child: _buildNavBtn(Icons.arrow_forward_rounded, _focusNextField)),
    ])));
  }

  Widget _buildNavBtn(IconData icon, VoidCallback onTap) { return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(25), child: Container(height: 50, decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(25)), child: Icon(icon, color: secondaryColor, size: 22))); }

  Future<void> _pickImageLocal(String fieldId) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1280, maxHeight: 1280);
    if (image != null) setState(() { _pickedImages[fieldId] = image; _formData[fieldId] = image.path; });
  }

  Future<void> _pickNumberFromContactsLocal(String fieldId) async {
    try {
      final results = await ContactPickerService.pickContacts(context: context, multiple: false);
      if (results.isNotEmpty && mounted) {
        final selectedNumber = results.first['tel'];
        if (selectedNumber != null) setState(() { final clean = selectedNumber.replaceAll(RegExp(r'\s+'), ''); _controllers[fieldId]?.text = clean; _formData[fieldId] = clean; });
      }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent)); }
  }

  String _generateUniqueIDLocal() {
    final String name = _controllers['cpName']?.text.trim() ?? '';
    final String surname = _controllers['surname']?.text.trim() ?? '';
    final String first3Name = name.length >= 3 ? name.substring(0, 3).toUpperCase() : name.toUpperCase();
    final String first1Surname = surname.isNotEmpty ? surname[0].toUpperCase() : '';
    final String date = DateFormat('ddMMyy').format(DateTime.now());
    return "$first3Name$first1Surname$date".trim();
  }

  void _updateMultiLevelReferrals(String ref1Name) {
    final cpVM = Provider.of<CPViewModel>(context, listen: false);
    final String currentCPName = '${_formData['cpName'] ?? ''} ${_formData['surname'] ?? ''}'.trim();
    
    // 1. Find CP 1 (Parent)
    final cp1 = cpVM.cps.firstWhere(
      (c) => c.fullName.toLowerCase() == ref1Name.toLowerCase(),
      orElse: () => CPModel.fromMap({}, ''),
    );

    if (cp1.id.isNotEmpty) {
      // 🚀 NAYA: Circular Reference Prevention
      final String cp1Referrer = (cp1.rawData['referralName1'] ?? '').toString();
      final String cp1GrandReferrer = (cp1.rawData['referralName2'] ?? '').toString();
      
      if (currentCPName.isNotEmpty && 
          (cp1.fullName.toLowerCase() == currentCPName.toLowerCase() || 
           cp1Referrer.toLowerCase() == currentCPName.toLowerCase() || 
           cp1GrandReferrer.toLowerCase() == currentCPName.toLowerCase())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Circular referral detected! This person cannot refer you.'), backgroundColor: Colors.redAccent),
        );
        setState(() {
          _formData['referralName1'] = '';
          _controllers['referralName1']?.text = '';
          _formData['referralName2'] = 'Not available';
          _controllers['referralName2']?.text = 'Not available';
          _formData['referralName3'] = 'Not available';
          _controllers['referralName3']?.text = 'Not available';
        });
        return;
      }

      // Logic: My R2 is Parent's R1, My R3 is Parent's R2
      final String ref2 = (cp1.rawData['referralName1'] ?? '').toString();
      final String ref3 = (cp1.rawData['referralName2'] ?? '').toString();

      setState(() {
        _formData['referralName2'] = ref2.isEmpty ? 'Not available' : ref2;
        _controllers['referralName2']?.text = _formData['referralName2'];

        _formData['referralName3'] = ref3.isEmpty ? 'Not available' : ref3;
        _controllers['referralName3']?.text = _formData['referralName3'];
      });
    } else {
      setState(() {
        _formData['referralName2'] = 'Not available'; _controllers['referralName2']?.text = 'Not available';
        _formData['referralName3'] = 'Not available'; _controllers['referralName3']?.text = 'Not available';
      });
    }
  }

  String _toTitleCase(String input) {
    if (input.trim().isEmpty) return input;
    return input.trim().split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Future<void> _handleSave() async {
    final titleCaseFields = ['cpName', 'surname', 'companyName', 'nickName', 'profession', 'location'];
    _controllers.forEach((id, ctrl) {
      final type = _getFieldTypeLocal(id);
      final textTypes = ['text', 'autocomplete', 'dropdown', 'multiline', 'number', 'phone'];
      if (textTypes.contains(type) || type == null) {
        var val = ctrl.text.trim();
        if (titleCaseFields.contains(id) && val.isNotEmpty) {
          val = _toTitleCase(val);
          ctrl.text = val;
        }
        _formData[id] = val;
      }
    });

    if (_formData['companyName'] != null && _formData['companyName'].toString().trim().isNotEmpty) {
      final compStr = _formData['companyName'].toString().trim();
      _formData['companyNames'] = [compStr];
    }

    if (_formData['cpName'] == null || _formData['cpName'].toString().trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required'))); return; }

    // 🚀 NAYA: Robust multi-field Phone and Email duplicate checking
    String digitsOnly(String p) => p.replaceAll(RegExp(r'[^0-9]'), '');
    bool isSamePhone(String p1, String p2) {
      final d1 = digitsOnly(p1);
      final d2 = digitsOnly(p2);
      if (d1.length < 7 || d2.length < 7) return false;
      final sub1 = d1.length >= 10 ? d1.substring(d1.length - 10) : d1;
      final sub2 = d2.length >= 10 ? d2.substring(d2.length - 10) : d2;
      return sub1 == sub2;
    }

    List<String> getPhoneNumbers(Map<String, dynamic> raw) {
      List<String> list = [];
      for (var k in ['contactNo', 'phone', 'contact2', 'mobile', 'whatsapp']) {
        final v = (raw[k] ?? '').toString().trim();
        if (v.isNotEmpty) list.add(v);
      }
      return list;
    }

    List<String> getEmails(Map<String, dynamic> raw) {
      List<String> list = [];
      for (var k in ['email', 'emailAddress', 'email_login']) {
        final v = (raw[k] ?? '').toString().trim().toLowerCase();
        if (v.isNotEmpty) list.add(v);
      }
      return list;
    }

    final cpVM = Provider.of<CPViewModel>(context, listen: false);
    final currentPhones = getPhoneNumbers(_formData);
    final currentEmails = getEmails(_formData);
    final String? currentCPId = widget.cp?.id;

    for (var existingCP in cpVM.cps) {
      if (currentCPId != null && existingCP.id == currentCPId) continue;
      final exPhones = getPhoneNumbers(existingCP.rawData);
      final exEmails = getEmails(existingCP.rawData);

      for (var cp in currentPhones) {
        for (var ep in exPhones) {
          if (isSamePhone(cp, ep)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ This phone number ($cp) already exists for partner "${existingCP.fullName}"!'),
                backgroundColor: Colors.red.shade800,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
            return;
          }
        }
      }

      for (var ce in currentEmails) {
        for (var ee in exEmails) {
          if (ce == ee) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ This email address ($ce) already exists for partner "${existingCP.fullName}"!'),
                backgroundColor: Colors.red.shade800,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
            return;
          }
        }
      }
    }

    setState(() => _isSaving = true);
    try {
      final authVM = Provider.of<AuthViewModel>(context, listen: false);
      final String folderName = '${_formData['cpName'] ?? 'cp'}_${DateTime.now().millisecondsSinceEpoch}';

      _formData['cpID'] = widget.cp?.rawData['cpID'] ?? _generateUniqueIDLocal();
      if (widget.cp == null) {
        _formData['isApproved'] = true;
        _formData['timestamp'] = FieldValue.serverTimestamp();
        _formData['createdBy'] = authVM.userName;
      } else {
        _formData['lastEditedBy'] = authVM.userName;
      }

      final cpVM = Provider.of<CPViewModel>(context, listen: false);

      // Save CP Document to Firestore first (instant!)
      await cpVM.addOrUpdateCP(
        _formData,
        id: widget.cp?.id,
        actorMetadata: authVM.actorMetadata,
      );

      final String hasMediaToUpload = _pickedImages.values.any((f) => f != null)
          ? ' Photos uploading in background...'
          : '';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚡ Partner saved!$hasMediaToUpload'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        context.go('/cp-list');
      }

      // Non-blocking background uploads
      if (widget.cp?.id != null || cpVM.cps.isNotEmpty) {
        final targetDocId = widget.cp?.id ?? cpVM.cps.first.id;
        _uploadCPMediaInBackground(targetDocId, Map.from(_pickedImages), folderName);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  static Future<void> _uploadCPMediaInBackground(
    String cpDocId,
    Map<String, XFile?> pickedImages,
    String folderName,
  ) async {
    final db = FirebaseFirestore.instance;
    try {
      for (var entry in pickedImages.entries) {
        if (entry.value != null) {
          final String fieldId = entry.key;
          final XFile file = entry.value!;
          final String path = 'profiles/$folderName/${fieldId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final String? url = await FirebaseStorageService.uploadFile(file, path);
          if (url != null && url.isNotEmpty) {
            await db.collection('cps').doc(cpDocId).update({
              fieldId: url,
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Background CP media upload error: $e");
    }
  }
}
