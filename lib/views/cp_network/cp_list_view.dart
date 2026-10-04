import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../models/cp_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/cp_viewmodel.dart';
import '../../viewmodels/lead_viewmodel.dart';
import '../../viewmodels/app_configuration_viewmodel.dart';
import '../../utils/role_permissions.dart';
import '../../services/contact_picker_service.dart';
import '../../widgets/app_drawer.dart';

class CPListView extends StatefulWidget {
  const CPListView({super.key});

  @override
  State<CPListView> createState() => _CPListViewState();
}

class _CPListViewState extends State<CPListView> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isSearching = false;
  String _searchQuery = '';
  int? _lastSearchTriggerCount;
  final FocusNode _searchFocusNode = FocusNode();
  final Set<String> _selectedCPIds = <String>{}; // 🚀 NAYA

  bool get _isSelectionMode => _selectedCPIds.isNotEmpty;
  
  final Set<String> _expandedCategories = {'Active'}; // Default expand Active

  List<Map<String, String>> _getCategoryTabs(AuthViewModel authVM) {
    final bool isAdmin = authVM.appRole == AppRole.admin || authVM.appRole == AppRole.superAdmin;
    return [
      {'id': 'my_cp', 'label': 'My CP'},
      if (isAdmin) {'id': 'all_cp', 'label': 'All CP'},
      if (isAdmin) {'id': 'customers', 'label': 'Customers'},
      {'id': 'fav_cp', 'label': 'Fav CP'},
      {'id': 'builders', 'label': 'Builders'},
      {'id': 'investors', 'label': 'Investors'},
      {'id': 'pending', 'label': 'Pending Approval'},
    ];
  }

  @override
  void initState() {
    super.initState();
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final tabs = _getCategoryTabs(authVM);
    _tabController = TabController(length: tabs.length, vsync: this);

    final currentMonth = DateFormat('MMMM yyyy').format(DateTime.now());
    _expandedCategories.add(currentMonth);

    // 🚀 NAYA: Auto-close search when focus is lost
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && _isSearching && _searchQuery.isEmpty) {
        setState(() {
          _isSearching = false;
        });
      }
    });
  }

  String? _selectedPartnerTypeFilter;

  List<CPModel> _filterCPsForTab(String tabId, List<CPModel> allCPs, AuthViewModel authVM) {
    final bool isAdmin = authVM.appRole == AppRole.admin || authVM.appRole == AppRole.superAdmin;
    final String myUid = authVM.userUid.trim().toLowerCase();
    final String myName = authVM.userName.trim().toLowerCase();

    return allCPs.where((cp) {
      final String parentUid = (cp.parentUid ?? cp.rawData['parentUid'] ?? '').toString().trim().toLowerCase();
      final String addedBy = (cp.addedBy ?? cp.rawData['addedBy'] ?? '').toString().trim().toLowerCase();
      final dynamic rawCreatedBy = cp.rawData['createdBy'];
      final String createdByUid = rawCreatedBy is Map
          ? (rawCreatedBy['uid'] ?? '').toString().trim().toLowerCase()
          : (rawCreatedBy?.toString().trim().toLowerCase() ?? '');
      final String createdByName = rawCreatedBy is Map
          ? (rawCreatedBy['name'] ?? '').toString().trim().toLowerCase()
          : '';
      final String partnerType = (cp.rawData['partnerType'] ?? cp.profession).toString().trim().toLowerCase();

      if (_selectedPartnerTypeFilter != null) {
        if (partnerType != _selectedPartnerTypeFilter!.trim().toLowerCase()) return false;
      }

      final bool isOwn = (parentUid.isNotEmpty && parentUid == myUid) ||
                         (addedBy.isNotEmpty && (addedBy == myName || addedBy == myUid)) ||
                         (createdByUid.isNotEmpty && createdByUid == myUid) ||
                         (createdByName.isNotEmpty && createdByName == myName) ||
                         cp.id.trim().toLowerCase() == myUid;

      final bool isPending = !cp.isApproved ||
                             cp.status.toLowerCase().contains('pending') ||
                             cp.status.toLowerCase().contains('unapproved');

      switch (tabId) {
        case 'my_cp':
          return isOwn;

        case 'all_cp':
          return isAdmin; // Admin sees all CPs

        case 'fav_cp':
          final favUids = List<dynamic>.from(cp.rawData['favUids'] ?? []);
          return favUids.contains(authVM.userUid);

        case 'builders':
          if (partnerType != 'builder') return false;
          return isAdmin || isOwn;

        case 'investors':
          if (partnerType != 'investor') return false;
          return isAdmin || isOwn;

        case 'pending':
          final bool isCustomerRole = cp.rawData['role']?.toString().toLowerCase() == 'viewer' ||
              cp.profession.toLowerCase() == 'viewer' ||
              cp.rawData['collection'] == 'customers';
          if (!isPending && !isCustomerRole) return false;
          return isAdmin || isOwn;

        case 'customers':
          return (cp.rawData['collection'] == 'customers') ||
                 (cp.rawData['role']?.toString().toLowerCase() == 'viewer') ||
                 (cp.rawData['profession']?.toString().toLowerCase() == 'viewer') ||
                 (cp.profession.toLowerCase() == 'viewer');

        default:
          return true;
      }
    }).toList();
  }

  void _toggleCPSelection(String cpId) {
    setState(() {
      if (_selectedCPIds.contains(cpId)) {
        _selectedCPIds.remove(cpId);
      } else {
        _selectedCPIds.add(cpId);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedCPIds.clear());
  }

  void _selectAllFiltered(List<CPModel> list) {
    setState(() {
      final allIds = list.map((c) => c.id).toSet();
      if (_selectedCPIds.length == allIds.length && _selectedCPIds.containsAll(allIds)) {
        _selectedCPIds.clear();
      } else {
        _selectedCPIds..clear()..addAll(allIds);
      }
    });
  }

  Future<void> _deleteSelectedCPs(CPViewModel cpVM) async {
    if (_selectedCPIds.isEmpty) return;

    final count = _selectedCPIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Move $count partners to Recycle Bin?'),
        content: const Text('They can be restored later from the Recycle Bin in the sidebar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B22)),
            child: const Text('Move to Bin', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await cpVM.softDeleteMultipleCPs(_selectedCPIds.toList());
      if (!mounted) return;
      _clearSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count partners moved to Recycle Bin'),
          backgroundColor: Colors.orange.shade800,
          action: SnackBarAction(label: 'VIEW BIN', textColor: Colors.white, onPressed: () => context.push('/recycle-bin')),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_expandedCategories.contains(category)) {
        _expandedCategories.remove(category);
      } else {
        _expandedCategories.add(category);
      }
    });
  }


  Future<void> _importContacts(CPViewModel cpVM, AuthViewModel authVM) async {
    List<Map<String, String>> selectedData = [];

    try {
      selectedData = await ContactPickerService.pickContacts(
        context: context,
        multiple: true,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
      return;
    }

    if (selectedData.isEmpty) return;

    if (!mounted) return;
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    int count = 0;
    int skipped = 0;
    
    final existingNumbers = cpVM.cps.map((c) => c.contactNo.replaceAll(RegExp(r'[^0-9]'), '')).toSet();

    for (var contact in selectedData) {
      final name = contact['name'] ?? 'Unknown';
      final rawPhone = contact['tel'] ?? '';
      final cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
      
      if (cleanPhone.isEmpty) {
        skipped++;
        continue;
      }

      // Skip if already in network
      if (existingNumbers.contains(cleanPhone)) {
        skipped++;
        continue;
      }

      final email = contact['email'] ?? '';

      final cpData = {
        'cpName': name,
        'contactNo': rawPhone,
        'email': email,
        'status': 'Active',
        'location': '',
        'parentUid': authVM.userUid,
        'addedBy': authVM.userName,
        'isApproved': false,
        'isProfileComplete': false,
        'referralCode': '',
      };

      try {
        await cpVM.addOrUpdateCP(cpData, actorMetadata: authVM.actorMetadata);
        count++;
        existingNumbers.add(cleanPhone); // Prevent adding same number twice in this loop
      } catch (e) {
        debugPrint('Error adding contact $name: $e');
      }
    }

    if (mounted) {
      Navigator.pop(context); // Remove loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count partners added! ${skipped > 0 ? "($skipped skipped - existing or no number)" : ""}'),
          backgroundColor: count > 0 ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  void _showCPFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        String? tempPartnerType = _selectedPartnerTypeFilter;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Filter Channel Partners', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedPartnerTypeFilter = null;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Clear All', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Partner Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['All', 'CP', 'Pro CP', 'Builder', 'Investor', 'Land Owner'].map((type) {
                      final isSelected = (type == 'All' && tempPartnerType == null) || tempPartnerType == type;
                      return ChoiceChip(
                        label: Text(type),
                        selected: isSelected,
                        selectedColor: const Color(0xFFFBE64E),
                        backgroundColor: Colors.grey.shade100,
                        labelStyle: TextStyle(color: isSelected ? const Color(0xFF6B5800) : Colors.black87, fontSize: 12, fontWeight: FontWeight.bold),
                        onSelected: (val) {
                          setSheetState(() {
                            tempPartnerType = type == 'All' ? null : type;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedPartnerTypeFilter = tempPartnerType;
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFBE64E),
                        foregroundColor: const Color(0xFF6B5800),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 0,
                      ),
                      child: const Text('APPLY FILTERS', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);
    final cpVM = Provider.of<CPViewModel>(context);
    final leadVM = Provider.of<LeadViewModel>(context);
    final configVM = Provider.of<AppConfigurationViewModel>(context); // 🚀 NAYA

    // 🚀 NAYA: Handle Double-Tap Search Trigger
    if (_lastSearchTriggerCount == null) {
      _lastSearchTriggerCount = configVM.searchTriggerCount;
    } else if (configVM.searchTriggerCount > _lastSearchTriggerCount! && configVM.activeSearchTab == 'cp') {
      _lastSearchTriggerCount = configVM.searchTriggerCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _isSearching = true);
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) _searchFocusNode.requestFocus();
          });
        }
      });
    }

    // No access fallback UI
    if (!authVM.permissions.dashboardTabs.contains('cp')) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Channel Partners',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => context.go('/dashboard'),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 52, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text(
                  'Channel Partner access is not enabled for your role.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your available dashboard sections are still accessible.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // List calculations
    final tabs = _getCategoryTabs(authVM);
    if (_tabController.length != tabs.length) {
      _tabController.dispose();
      _tabController = TabController(length: tabs.length, vsync: this);
    }

    final filteredCPs = cpVM.cps.where((cp) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return cp.fullName.toLowerCase().contains(q) ||
             cp.contactNo.contains(q) ||
             cp.location.toLowerCase().contains(q);
    }).toList();

    _sortCPsByNewest(filteredCPs);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isSelectionMode) {
          _clearSelection();
        } else if (_isSearching) {
          _searchFocusNode.unfocus();
          setState(() {
            _isSearching = false;
            _searchQuery = '';
          });
        } else {
          StatefulNavigationShell.of(context).goBranch(0);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: _isSelectionMode
            ? IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: _clearSelection)
            : Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.black),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
          title: _isSearching
              ? TextField(
                  focusNode: _searchFocusNode,
                  autofocus: true,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: const InputDecoration(
                    hintText: 'Search partners...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                )
              : Text(
                  _isSelectionMode ? '${_selectedCPIds.length} Selected' : 'Channel Partners',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
          actions: [
            if (_isSelectionMode) ...[
              IconButton(
                icon: const Icon(Icons.select_all_rounded, color: Colors.black87),
                onPressed: () => _selectAllFiltered(filteredCPs),
                tooltip: 'Select all',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.black87),
                onPressed: () => _deleteSelectedCPs(cpVM),
                tooltip: 'Move to Bin',
              ),
            ] else ...[
              if (_isSearching)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchQuery = '';
                    });
                  },
                )
              else ...[
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.black87),
                  onPressed: () => setState(() => _isSearching = true),
                  tooltip: 'Search',
                ),
                IconButton(
                  icon: const Icon(Icons.tune_rounded, color: Colors.black87),
                  onPressed: _showCPFilterSheet,
                  tooltip: 'Filter',
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.black87),
                  onSelected: (value) {
                    if (value == 'import_contacts') {
                      _importContacts(cpVM, authVM);
                    } else if (value == 'filter') {
                      _showCPFilterSheet();
                    } else if (value == 'profile') {
                      context.push('/profile');
                    } else if (value == 'select') {
                      setState(() {
                        if (filteredCPs.isNotEmpty) {
                          _selectedCPIds.add(filteredCPs.first.id);
                        }
                      });
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'select',
                      child: Row(
                        children: [
                          Icon(Icons.check_box_outlined, color: Colors.black54),
                          SizedBox(width: 12),
                          Text('Select Partners'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'import_contacts',
                      child: Row(
                        children: [
                          Icon(Icons.contact_phone_outlined, color: Colors.black54),
                          SizedBox(width: 12),
                          Text('Import Contacts'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'filter',
                      child: Row(
                        children: [
                          Icon(Icons.tune_rounded, color: Colors.black54),
                          SizedBox(width: 12),
                          Text('Filter Partners'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(Icons.account_circle_outlined, color: Colors.black54),
                          SizedBox(width: 12),
                          Text('Profile / Score'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
        drawer: const AppDrawer(),
        body: cpVM.isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF6B22)),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🚀 NAYA: Clean text tabs with underline (No Containers)
                  Container(
                    color: Colors.white,
                    width: double.infinity,
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicatorColor: const Color(0xFFFF6B22),
                      indicatorWeight: 3.0,
                      dividerColor: Colors.transparent,
                      labelColor: Colors.black,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                      unselectedLabelColor: Colors.grey.shade500,
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                      tabs: tabs.map((tab) {
                        final items = _filterCPsForTab(tab['id']!, filteredCPs, authVM);
                        return Tab(text: '${tab['label']} (${items.length})');
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 4), // Thoda space tabs aur list ke beech

                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: tabs.map<Widget>((tab) {
                        final items = _filterCPsForTab(tab['id']!, filteredCPs, authVM);
                        return _buildCPList(items, leadVM, tabId: tab['id']!);
                      }).toList(),
                    ),
                  ),
                ],
              ),
        floatingActionButton: (authVM.appRole != AppRole.cp)
            ? Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: FloatingActionButton(
                  onPressed: () => context.push('/add-cp'),
                  backgroundColor: const Color(0xFFFBE64E),
                  child: const Icon(Icons.add, color: Color(0xFF6B5800)),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildCPList(List<CPModel> list, LeadViewModel leadVM, {String tabId = '', bool groupByMonth = false}) {
    if (list.isEmpty) {
      return const Center(
        child: Text(
          'No Channel Partners found for this category.',
          style: TextStyle(color: Colors.grey, fontSize: 15),
        ),
      );
    }

    // Grouping logic (Status or Month)
    final Map<String, List<CPModel>> grouped = {};
    for (var cp in list) {
      String key;
      if (groupByMonth) {
        final ts = cp.rawData['timestamp'];
        if (ts is Timestamp) {
          key = DateFormat('MMMM yyyy').format(ts.toDate());
        } else {
          key = 'Prior Records';
        }
      } else {
        key = cp.status.isEmpty ? 'Inactive' : cp.status;
      }
      
      if (!grouped.containsKey(key)) grouped[key] = [];
      grouped[key]!.add(cp);
    }

    final sortedHeaders = grouped.keys.toList()..sort((a, b) {
      if (groupByMonth) {
        // Sort months newest to oldest
        if (a == 'Prior Records') return 1;
        if (b == 'Prior Records') return -1;
        try {
          final dateA = DateFormat('MMMM yyyy').parse(a);
          final dateB = DateFormat('MMMM yyyy').parse(b);
          return dateB.compareTo(dateA);
        } catch (_) {
          return a.compareTo(b);
        }
      } else {
        // Sort status (Active first)
        if (a.toLowerCase() == 'active') return -1;
        if (b.toLowerCase() == 'active') return 1;
        return a.compareTo(b);
      }
    });

    return ListView.builder(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      itemCount: sortedHeaders.length,
      itemBuilder: (context, index) {
        final header = sortedHeaders[index];
        final items = grouped[header]!;
        _sortCPsByNewest(items);
        final isExpanded = _expandedCategories.contains(header);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _toggleCategory(header),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Text(
                        header.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: groupByMonth ? Colors.blueGrey.shade800 : _getStatusColor(header),
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (groupByMonth ? Colors.blueGrey.shade800 : _getStatusColor(header)).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${items.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: groupByMonth ? Colors.blueGrey.shade800 : _getStatusColor(header),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: (groupByMonth ? Colors.blueGrey.shade800 : _getStatusColor(header)).withOpacity(0.7),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (isExpanded)
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (context, i) => Divider(height: 1, color: Colors.grey.shade100, indent: 70),
                itemBuilder: (context, i) {
                  return _CPTile(
                    cp: items[i], 
                    leadCount: _leadCountForCP(items[i], leadVM),
                    isSelected: _selectedCPIds.contains(items[i].id),
                    onToggle: () => _toggleCPSelection(items[i].id),
                    isSelectionMode: _isSelectionMode,
                  );
                },
              ),
          ],
        );
      },
    );
  }

  int _leadCountForCP(CPModel cp, LeadViewModel leadVM) {
    return leadVM.leads.where((lead) {
      final source = lead.rawData['source']?.toString().toLowerCase() ?? '';
      final caller = lead.rawData['caller']?.toString().toLowerCase() ?? '';
      final cpNameStr = cp.cpName.toLowerCase();
      final cpFullNameStr = cp.fullName.toLowerCase();
      return source == cpNameStr || caller == cpNameStr || source == cpFullNameStr || caller == cpFullNameStr;
    }).length;
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'active') return Colors.green.shade700;
    if (s == 'pending') return Colors.blue.shade700;
    return Colors.grey.shade600;
  }

  void _sortCPsByNewest(List<CPModel> list) {
    list.sort((a, b) {
      final t1 = a.rawData['timestamp'] ?? a.rawData['createdAt'] ?? a.rawData['updatedAt'];
      final t2 = b.rawData['timestamp'] ?? b.rawData['createdAt'] ?? b.rawData['updatedAt'];

      if (t1 is Timestamp && t2 is Timestamp) {
        return t2.compareTo(t1); // Newest first
      } else if (t1 is Timestamp) {
        return -1; // a has timestamp, b doesn't -> a comes first
      } else if (t2 is Timestamp) {
        return 1; // b has timestamp, a doesn't -> b comes first
      }
      return 0;
    });
  }
}

class _CPTile extends StatefulWidget {
  final CPModel cp;
  final int leadCount;
  final bool isSelected;
  final VoidCallback onToggle;
  final bool isSelectionMode;

  const _CPTile({
    required this.cp, 
    required this.leadCount, 
    required this.isSelected, 
    required this.onToggle, 
    required this.isSelectionMode
  });

  @override
  State<_CPTile> createState() => _CPTileState();
}

class _CPTileState extends State<_CPTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);
    final cpVM = Provider.of<CPViewModel>(context, listen: false);
    final bool isAdmin = authVM.appRole == AppRole.admin || authVM.appRole == AppRole.superAdmin;
    final favUids = List<dynamic>.from(widget.cp.rawData['favUids'] ?? []);
    final bool isFav = favUids.contains(authVM.userUid);
    final bool isPending = !widget.cp.isApproved || widget.cp.status.toLowerCase().contains('pending');

    final bool isCustomerRole = widget.cp.rawData['role']?.toString().toLowerCase() == 'viewer' ||
        widget.cp.profession.toLowerCase() == 'viewer';
    final bool isUpgradeRequested = widget.cp.rawData['cpUpgradeRequested'] == true ||
        widget.cp.rawData['upgradeStatus'] == 'Waiting for Approval';

    final String firstLetter = widget.cp.fullName.trim().isEmpty ? '?' : widget.cp.fullName.trim()[0].toUpperCase();
    
    final String rawStatus = widget.cp.status.trim().toUpperCase();
    String displayStatus = rawStatus.isEmpty ? 'INACTIVE' : rawStatus;
    if (isCustomerRole) {
      if (isUpgradeRequested) {
        displayStatus = 'WAITING APPROVAL';
      } else {
        displayStatus = 'CUSTOMER';
      }
    } else if (rawStatus.contains('ACTIVE')) {
      displayStatus = 'ACTIVE';
    } else if (rawStatus.contains('PENDING')) {
      displayStatus = 'PENDING';
    }

    Color statusColor;
    if (displayStatus == 'ACTIVE') {
      statusColor = Colors.green.shade700;
    } else if (displayStatus == 'PENDING' || isPending || displayStatus == 'WAITING APPROVAL') {
      statusColor = Colors.amber.shade800;
    } else if (displayStatus == 'CUSTOMER') {
      statusColor = Colors.blue.shade600;
    } else {
      statusColor = Colors.grey.shade600;
    }

    return Container(
      color: widget.isSelected ? Colors.blue.withValues(alpha: 0.05) : Colors.white,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (widget.isSelectionMode) {
              widget.onToggle();
            } else {
              context.push('/cp-detail/${widget.cp.id}', extra: widget.cp);
            }
          },
          onLongPress: widget.onToggle,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: widget.isSelectionMode ? widget.onToggle : () => setState(() => _isExpanded = !_isExpanded),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: widget.isSelected ? Colors.blue : const Color(0xFFF5F5F5),
                          child: widget.isSelected 
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : Text(
                                firstLetter,
                                style: const TextStyle(color: Color(0xFF888888), fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.cp.fullName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.cp.location.isEmpty ? "No location" : widget.cp.location} • ${widget.leadCount} leads',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.08), 
                          borderRadius: BorderRadius.circular(20), 
                          border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.2),
                        ),
                        child: Text(
                          displayStatus,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => cpVM.toggleFavorite(widget.cp.id, authVM.userUid, favUids),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.red : Colors.grey.shade400,
                          size: 20,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _makeCall(widget.cp.contactNo),
                      child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.phone_outlined, color: Colors.blue, size: 20)),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _sendWhatsApp(widget.cp.contactNo),
                      child: const Padding(padding: EdgeInsets.only(right: 12, top: 4, bottom: 4, left: 4), child: Icon(Icons.chat_bubble_outline_rounded, color: Colors.green, size: 20)),
                    ),
                  ],
                ),
              ),
              if (_isExpanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      const SizedBox(height: 8),
                      _buildDetailRow('Profession', widget.cp.profession),
                      _buildDetailRow('Added By', widget.cp.addedBy ?? 'Unknown'),
                      _buildDetailRow('RERA ID', widget.cp.reraId.isEmpty ? 'N/A' : widget.cp.reraId),
                      if (widget.cp.rawData['timestamp'] != null && widget.cp.rawData['timestamp'] is Timestamp)
                        _buildDetailRow('Joined On', DateFormat('dd MMM yyyy').format((widget.cp.rawData['timestamp'] as Timestamp).toDate())),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (isAdmin && isCustomerRole)
                            ElevatedButton.icon(
                              onPressed: () async {
                                final docId = widget.cp.id;
                                final col = widget.cp.rawData['collection'] == 'customers' ? 'customers' : 'cps';

                                await FirebaseFirestore.instance.collection(col).doc(docId).set({
                                  'role': 'cp',
                                  'isApproved': true,
                                  'cpUpgradeRequested': false,
                                  'upgradeStatus': 'Approved',
                                  'status': 'Channel Partner',
                                  'profession': 'Channel Partner',
                                }, SetOptions(merge: true));

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Customer Upgraded & Approved as Channel Partner!'), backgroundColor: Colors.green),
                                  );
                                }
                              },
                              icon: const Icon(Icons.workspace_premium_rounded, size: 16, color: Colors.white),
                              label: const Text('APPROVE AS CP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF6B22),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            )
                          else if (isAdmin && isPending)
                            ElevatedButton.icon(
                              onPressed: () async {
                                await cpVM.approveCP(widget.cp.id, authVM.actorMetadata);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Partner Approved!'), backgroundColor: Colors.green),
                                  );
                                }
                              },
                              icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                              label: const Text('APPROVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                          OutlinedButton.icon(
                            onPressed: () => context.push('/cp-detail/${widget.cp.id}', extra: widget.cp),
                            icon: const Icon(Icons.visibility_outlined, size: 16),
                            label: const Text('View Profile'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFF6B22),
                              side: const BorderSide(color: Color(0xFFFF6B22)),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 12, color: Colors.black87)),
        ],
      ),
    );
  }

  Future<void> _makeCall(String number) async {
    if (number.isEmpty) return;
    final Uri url = Uri.parse('tel:$number');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  Future<void> _sendWhatsApp(String number) async {
    if (number.isEmpty) return;
    String cleanNumber = number.replaceAll(RegExp(r'[^0-9]'), '');
    final Uri url = Uri.parse('https://wa.me/91$cleanNumber');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }
}
