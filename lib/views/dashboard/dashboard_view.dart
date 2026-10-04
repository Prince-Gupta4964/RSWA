import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/lead_model.dart';
import '../../services/storage_helper.dart';
import '../../utils/record_access.dart';
import '../../utils/role_permissions.dart';
import '../../viewmodels/app_configuration_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/lead_viewmodel.dart';
import '../leads/lead_list_view.dart';
import '../cp_network/complete_profile_view.dart';
import '../../widgets/app_drawer.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _topKey = GlobalKey();
  final FocusNode _searchFocusNode = FocusNode(); // 🚀 NAYA: Focus control

  String _currentNavTab = '';
  String _searchQuery = '';
  // ignore: unused_field
  String? _statusFilter;

  // 🚀 NAYA: Search bar toggle state
  bool _isSearching = false;
  int? _lastSearchTriggerCount; // 🚀 Track triggers
  int? _lastFilterTriggerCount; // 🚀 NAYA: Track filter triggers

  late TabController _tabController;
  late List<Map<String, String>> _tabs;

  @override
  void initState() {
    super.initState();

    final authVM = Provider.of<AuthViewModel>(context, listen: false);

    _tabs = [
      {'id': 'my_leads', 'label': 'My Clients'},
      if (authVM.canSeeAllLeads) {'id': 'all_clients', 'label': 'All Clients'},
      {'id': 'paid_leads', 'label': 'Paid'},
      {'id': 'advisor', 'label': 'Advisor'},
      {'id': 'fav_leads', 'label': 'Fav'},
    ];

    _tabController = TabController(length: _tabs.length, vsync: this);

    _currentNavTab = 'my_leads';
    _tabController.index = 0;

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentNavTab = _tabs[_tabController.index]['id']!;
        });
      }
    });

    // 🚀 NAYA: Auto-close search when focus is lost
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && _isSearching && _searchQuery.isEmpty) {
        setState(() {
          _isSearching = false;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (authVM.isAuthenticated && authVM.appRole == AppRole.viewer) {
        final bool isComplete = authVM.userData?['isProfileComplete'] == true &&
                                (authVM.userData?['contactNo'] ?? '').toString().trim().isNotEmpty;
        if (!isComplete) {
          context.go('/customer-form');
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Live data synced successfully.'),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _handleHardRefresh() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refreshing and updating app...'), backgroundColor: Color(0xFFFF6B22)),
      );
      await Future.delayed(const Duration(milliseconds: 800));
      StorageHelper.reloadApp();
    } else {
      await _handleRefresh();
    }
  }

  void _showSortFilterSheet(LeadViewModel leadVM, String tabId) {
    final List<String> bhkOptions = leadVM.leads
        .map((l) => l.rawData['needsBHK']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    final List<Map<String, dynamic>> sortOptions = [
      {'label': 'Date (Newest)', 'field': 'Date', 'asc': false, 'icon': Icons.calendar_today},
      {'label': 'Date (Oldest)', 'field': 'Date', 'asc': true, 'icon': Icons.history},
      {'label': 'Name (A-Z)', 'field': 'Name', 'asc': true, 'icon': Icons.sort_by_alpha},
      {'label': 'Name (Z-A)', 'field': 'Name', 'asc': false, 'icon': Icons.sort_by_alpha},
      {'label': 'Budget (High to Low)', 'field': 'Budget', 'asc': false, 'icon': Icons.currency_rupee},
      {'label': 'Budget (Low to High)', 'field': 'Budget', 'asc': true, 'icon': Icons.currency_rupee},
      {'label': 'Total Days (Oldest first)', 'field': 'Total Days', 'asc': true, 'icon': Icons.timelapse},
      {'label': 'Total Days (Newest first)', 'field': 'Total Days', 'asc': false, 'icon': Icons.timelapse},
      {'label': 'Total Calls (Most first)', 'field': 'Total Calls', 'asc': false, 'icon': Icons.call},
      {'label': 'Final Amount (High to Low)', 'field': 'Final Amount', 'asc': false, 'icon': Icons.payments_outlined},
    ];

    final List<String> groupByOptions = [
      'Status', 'Company', 'Project', 'Source', 'Referral', 
      'Nearest Station', 'Advisor', 'Caller', 'Reached By', 'Created Month', 
      'Configuration', 'Gender', 'Demo Done'
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              minChildSize: 0.4,
              expand: false,
              builder: (context, scrollController) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: ListView(
                  controller: scrollController,
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 24),
                    Text('Group & Sort: ${_tabs.firstWhere((t) => t['id'] == tabId)['label']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),

                    // --- GROUP BY SECTION ---
                    const Text('GROUP BY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: groupByOptions.map((opt) {
                        final bool isSelected = leadVM.getGroupBy(tabId) == opt;
                        return ChoiceChip(
                          label: Text(opt, style: const TextStyle(fontSize: 12)),
                          selected: isSelected,
                          selectedColor: const Color(0xFFFF6B22).withValues(alpha: 0.2),
                          checkmarkColor: const Color(0xFFFF6B22),
                          labelStyle: TextStyle(color: isSelected ? const Color(0xFFFF6B22) : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                          onSelected: (val) {
                            if (val) {
                              leadVM.setGroupBy(tabId, opt);
                              setSheetState(() {});
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),

                    // --- SORTING SECTION ---
                    const Text('SORT BY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: sortOptions.map((opt) {
                        final bool isSelected = leadVM.getSortBy(tabId) == opt['field'] && leadVM.getIsAscending(tabId) == opt['asc'];
                        return ChoiceChip(
                          label: Text(opt['label'], style: const TextStyle(fontSize: 12)),
                          selected: isSelected,
                          selectedColor: const Color(0xFFFF6B22).withValues(alpha: 0.2),
                          checkmarkColor: const Color(0xFFFF6B22),
                          labelStyle: TextStyle(color: isSelected ? const Color(0xFFFF6B22) : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                          onSelected: (val) {
                            if (val) {
                              leadVM.setSort(tabId, opt['field'], opt['asc']);
                              setSheetState(() {});
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),

                    // --- FILTER SECTION ---
                    const Text('FILTER BY BHK', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: bhkOptions.map((bhk) {
                        final bool isSelected = leadVM.getFilters(tabId)['needsBHK'] == bhk;
                        return ChoiceChip(
                          label: Text(bhk, style: const TextStyle(fontSize: 12)),
                          selected: isSelected,
                          onSelected: (val) {
                            leadVM.updateFilter(tabId, 'needsBHK', val ? bhk : null);
                            setSheetState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),

                    // --- ACTIONS ---
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              leadVM.clearFilters(tabId);
                              Navigator.pop(context);
                            },
                            child: const Text('Clear All'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B22)),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Apply', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  // 🚀 NAYA: Cleaned filter
  String _getCreatorUid(dynamic createdBy) {
    if (createdBy is Map) return createdBy['uid']?.toString() ?? '';
    if (createdBy is String) return createdBy;
    return '';
  }

  List<LeadModel> _filterLeads(List<LeadModel> allLeads, String tabId, AuthViewModel authVM) {
    return allLeads.where((lead) {
      if (tabId == 'all_clients') {
        if (!authVM.canSeeAllLeads) return false;
      } else if (tabId == 'my_leads') {
        final creatorUid = _getCreatorUid(lead.rawData['createdBy']);
        if (creatorUid != authVM.userUid) return false;
      } else if (tabId == 'paid_leads') {
        final milestones = ['Visit', 'Revisit', 'Token', 'Loan process', 'Downpayment', 'Registration', 'Disbursement', 'Possession'];
        final stage = lead.rawData['journeyStage']?.toString() ?? 'Visit';
        final idx = milestones.indexOf(stage);
        if (idx < 2) return false;

        if (!authVM.canSeeAllLeads) {
          final creatorUid = _getCreatorUid(lead.rawData['createdBy']);
          if (creatorUid != authVM.userUid) return false;
        }
      } else if (tabId == 'fav_leads') {
        if (!lead.favUids.contains(authVM.userUid)) return false;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!lead.name.toLowerCase().contains(q) &&
            !lead.contact.toLowerCase().contains(q)) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);
    final leadVM = Provider.of<LeadViewModel>(context);
    final configVM = Provider.of<AppConfigurationViewModel>(context); // 🚀 NAYA

    // 🚀 NAYA: Handle Double-Tap Search Trigger
    if (_lastSearchTriggerCount == null) {
      _lastSearchTriggerCount = configVM.searchTriggerCount;
    } else if (configVM.searchTriggerCount > _lastSearchTriggerCount! && configVM.activeSearchTab == 'dashboard') {
      _lastSearchTriggerCount = configVM.searchTriggerCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _isSearching = true);
          // 🚀 Tiny delay ensures the TextField is rendered before requesting focus
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) _searchFocusNode.requestFocus();
          });
        }
      });
    }

    // 🚀 NAYA: Handle Long-Press Filter Trigger
    if (_lastFilterTriggerCount == null) {
      _lastFilterTriggerCount = configVM.leadFilterTriggerCount;
    } else if (configVM.leadFilterTriggerCount > _lastFilterTriggerCount!) {
      _lastFilterTriggerCount = configVM.leadFilterTriggerCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showSortFilterSheet(leadVM, _currentNavTab);
        }
      });
    }

    // 🚀 Navigation Guard: Incomplete profile always goes to CompleteProfileView
    if (authVM.appRole == AppRole.cp && !authVM.isProfileComplete) {
      return const CompleteProfileView();
    }

    final allVisibleLeads = filterVisibleLeads(
      leads: leadVM.leads,
      canSeeAllLeads: authVM.canSeeAllLeads,
      userUid: authVM.userUid,
      userEmail: authVM.userEmail,
      userName: authVM.userName,
    );

    allVisibleLeads.sort((a, b) {
      final t1 = a.rawData['timestamp'];
      final t2 = b.rawData['timestamp'];
      if (t1 == null || t2 == null) return 0;
      if (t1 is! Timestamp || t2 is! Timestamp) return 0;
      return t2.compareTo(t1);
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        
        // 1. Close search if active (Explicitly unfocus too)
        if (_isSearching) {
          _searchFocusNode.unfocus();
          setState(() {
            _isSearching = false;
            _searchQuery = '';
          });
          return;
        }

        // 2. Switch to first tab if not there
        if (_tabController.index != 0) {
          _tabController.animateTo(0);
          return;
        }

        // 3. Otherwise, stay on dashboard (let system handle if we want to allow exit, but user said NO)
        // If we want to allow exit on a double-back, we'd need more logic.
        // For now, we stay on dashboard.
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Builder(
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
            hintText: 'Search leads...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          style: const TextStyle(color: Colors.black, fontSize: 16),
        )
            : const Text(
          'Dashboard',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
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
              icon: const Icon(Icons.search, color: Colors.black),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.tune_rounded, color: Colors.black),
              onPressed: () => _showSortFilterSheet(leadVM, _currentNavTab),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.black),
              onSelected: (value) {
                if (value == 'sort_filter') {
                  _showSortFilterSheet(leadVM, _currentNavTab);
                } else if (value == 'refresh') {
                  _handleHardRefresh();
                } else if (value == 'notifications') {
                  // Do nothing
                } else if (value == 'profile') {
                  context.push('/profile');
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'sort_filter',
                  child: Row(
                    children: [
                      Icon(Icons.tune_rounded, color: Colors.black54),
                      SizedBox(width: 12),
                      Text('Group By & Filter By'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded, color: Colors.black54),
                      SizedBox(width: 12),
                      Text('Refresh App'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'notifications',
                  child: Row(
                    children: [
                      Icon(Icons.notifications_none_rounded, color: Colors.black54),
                      SizedBox(width: 12),
                      Text('Notifications'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline_rounded, color: Colors.black54),
                      SizedBox(width: 12),
                      Text('My Score'),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      drawer: const AppDrawer(),

      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: const Color(0xFFFF6B22),
        child: NestedScrollView(
          controller: _scrollController,
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      if (authVM.appRole == AppRole.cp && !authVM.isApproved)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade100),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lock_clock_rounded, color: Colors.red.shade700, size: 20),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Verification Pending: Leads & projects access will be enabled after Admin approval.',
                                  style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    // 🚀 NAYA: Center Alignment Add Kar Diya
                    tabAlignment: TabAlignment.center,
                    indicatorColor: const Color(0xFFFF6B22),
                    indicatorWeight: 3.0,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.black,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    unselectedLabelColor: Colors.grey.shade500,
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    padding: EdgeInsets.zero,
                    // 🚀 NAYA: Symmetrical padding se perfect center mein aayega
                    labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                    tabs: _tabs.map((tab) => Tab(text: tab['label'])).toList(),
                  ),
                ),
              ),
            ];
          },
          // 🚀 TabBarView already handles Left/Right swipe
          body: TabBarView(
            controller: _tabController,
            children: _tabs.map((tab) {
              // 🚀 NAYA: Restricted view for unapproved CPs
              if (authVM.appRole == AppRole.cp && !authVM.isApproved) {
                 return Center(
                   child: Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 40),
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         Icon(Icons.lock_person_outlined, size: 64, color: Colors.grey.shade300),
                         const SizedBox(height: 24),
                         const Text(
                           'Restricted Access',
                           style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                         ),
                         const SizedBox(height: 12),
                         Text(
                           'Your leads and project lists will be visible here once your profile is verified by an Admin.',
                           textAlign: TextAlign.center,
                           style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.5),
                         ),
                       ],
                     ),
                   ),
                 );
              }
              
              final tabLeads = _filterLeads(allVisibleLeads, tab['id']!, authVM);

              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 12),
                  LeadListView(
                    tabId: tab['id']!,
                    leads: tabLeads,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    emptyMessage: 'No leads found in this category.',
                    isModernStyle: true,
                  ),
                  const SizedBox(height: 80),
                ],
              );
            }).toList(),
          ),
        ),
      ),

      floatingActionButton: authVM.canAddLeads
          ? Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: FloatingActionButton(
                heroTag: 'dashboard_fab',
                onPressed: () => context.push('/add-lead'),
                backgroundColor: const Color(0xFFFBE64E),
                child: const Icon(Icons.add, color: Color(0xFF6B5800), size: 28),
              ),
            )
          : null,
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverTabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}