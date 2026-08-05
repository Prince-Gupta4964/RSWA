import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/lead_model.dart';
import '../../services/storage_helper.dart';
import '../../utils/record_access.dart';
import '../../viewmodels/app_configuration_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/lead_viewmodel.dart';
import '../../widgets/app_bottom_nav.dart';
import '../leads/lead_list_view.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _topKey = GlobalKey();
  final GlobalKey _monitoringKey = GlobalKey();

  String _currentNavTab = '';
  String _searchQuery = '';
  String? _statusFilter;

  // 🚀 NAYA: Search bar toggle state
  bool _isSearching = false;

  late TabController _tabController;
  late List<Map<String, String>> _tabs;

  @override
  void initState() {
    super.initState();

    final authVM = Provider.of<AuthViewModel>(context, listen: false);

    _tabs = [
      if (authVM.canSeeAllLeads) {'id': 'all_clients', 'label': 'All Clients'},
      {'id': 'my_leads', 'label': 'My Clients'},
      {'id': 'paid_leads', 'label': 'Paid'},
      {'id': 'advisor', 'label': 'Advisor'},
      {'id': 'fav_leads', 'label': 'Fav'},
    ];

    _tabController = TabController(length: _tabs.length, vsync: this);

    if (authVM.canSeeAllLeads) {
      _currentNavTab = 'all_clients';
      _tabController.index = 0;
    } else {
      _currentNavTab = 'my_leads';
      _tabController.index = 0;
    }

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentNavTab = _tabs[_tabController.index]['id']!;
        });
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

  Future<void> _scrollToSection(GlobalKey key, {required String navTab}) async {
    setState(() {
      _currentNavTab = navTab;
      int idx = _tabs.indexWhere((t) => t['id'] == navTab);
      if (idx != -1) _tabController.index = idx;
    });

    if (key == _topKey) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
      return;
    }
    final sectionContext = key.currentContext;
    if (sectionContext == null) return;

    await Scrollable.ensureVisible(
      sectionContext,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      alignment: 0.08,
    );
  }

  void _showSortFilterSheet(LeadViewModel leadVM) {
    final List<String> bhkOptions = leadVM.leads
        .map((l) => l.rawData['needsBHK']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    final List<Map<String, dynamic>> sortOptions = [
      {'label': 'Date (Newest)', 'field': 'Date', 'asc': false, 'icon': Icons.calendar_today},
      {'label': 'Date (Oldest)', 'field': 'Date', 'asc': true, 'icon': Icons.history},
      {'label': 'Name (A-Z)', 'field': 'Name', 'asc': true, 'icon': Icons.sort_by_alpha},
      {'label': 'Final Amount (High to Low)', 'field': 'Final Amount', 'asc': false, 'icon': Icons.currency_rupee},
      {'label': 'Monthly Income (High to Low)', 'field': 'Monthly Income', 'asc': false, 'icon': Icons.payments_outlined},
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
              initialChildSize: 0.6,
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
                    const Text('Sort & Filter', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),

                    // --- SORTING SECTION ---
                    const Text('SORT BY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: sortOptions.map((opt) {
                        final bool isSelected = leadVM.sortBy == opt['field'] && leadVM.isAscending == opt['asc'];
                        return ChoiceChip(
                          label: Text(opt['label'], style: const TextStyle(fontSize: 12)),
                          selected: isSelected,
                          selectedColor: const Color(0xFFFF6B22).withValues(alpha: 0.2),
                          checkmarkColor: const Color(0xFFFF6B22),
                          labelStyle: TextStyle(color: isSelected ? const Color(0xFFFF6B22) : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                          onSelected: (val) {
                            if (val) {
                              leadVM.setSort(opt['field'], opt['asc']);
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
                        final bool isSelected = leadVM.filters['needsBHK'] == bhk;
                        return ChoiceChip(
                          label: Text(bhk, style: const TextStyle(fontSize: 12)),
                          selected: isSelected,
                          onSelected: (val) {
                            leadVM.updateFilter('needsBHK', val ? bhk : null);
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
                              leadVM.clearFilters();
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

  void _openProfileSheet(AuthViewModel authVM) {
    final messenger = ScaffoldMessenger.of(context);
    final parentContext = context;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  authVM.userName.isEmpty ? 'Signed In User' : authVM.userName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  authVM.userEmail.isEmpty
                      ? 'No email found'
                      : authVM.userEmail,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1EA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    authVM.roleLabel,
                    style: const TextStyle(
                      color: Color(0xFFFF6B22),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await authVM.logout();
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Logged out successfully.'),
                        ),
                      );
                      if (parentContext.mounted) {
                        parentContext.go('/login');
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 🚀 NAYA: Cleaned filter
  List<LeadModel> _filterLeads(List<LeadModel> allLeads, String tabId, AuthViewModel authVM) {
    return allLeads.where((lead) {
      if (tabId == 'all_clients') {
        if (!authVM.canSeeAllLeads) return false;
      } else if (tabId == 'my_leads') {
        final creatorUid = lead.rawData['createdBy']?['uid']?.toString() ?? '';
        if (creatorUid != authVM.userUid) return false;
      } else if (tabId == 'paid_leads') {
        final milestones = ['Visit', 'Revisit', 'Token', 'Loan process', 'Downpayment', 'Registration', 'Disbursement', 'Possession'];
        final stage = lead.rawData['journeyStage']?.toString() ?? 'Visit';
        final idx = milestones.indexOf(stage);
        if (idx < 2) return false;

        if (!authVM.canSeeAllLeads) {
          final creatorUid = lead.rawData['createdBy']?['uid']?.toString() ?? '';
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

    return Scaffold(
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
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.black),
              onSelected: (value) {
                if (value == 'sort_filter') {
                  _showSortFilterSheet(leadVM);
                } else if (value == 'refresh') {
                  _handleHardRefresh();
                } else if (value == 'notifications') {
                  // Do nothing
                } else if (value == 'profile') {
                  _openProfileSheet(authVM);
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'sort_filter',
                  child: Row(
                    children: [
                      Icon(Icons.tune_rounded, color: Colors.black54),
                      SizedBox(width: 12),
                      Text('Sort & Filter'),
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
                      Text('Profile'),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildAdminDrawer(authVM),

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
                    children: const [
                      SizedBox(height: 8),
                      // Removed Priority Cards from here as requested
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
              final tabLeads = _filterLeads(allVisibleLeads, tab['id']!, authVM);

              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 12),
                  LeadListView(
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

      floatingActionButton: authVM.permissions.canAddLeads
          ? Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: FloatingActionButton(
          onPressed: () => context.push('/add-lead'),
          backgroundColor: const Color(0xFFFF6B22),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      )
          : null,

      bottomNavigationBar: AppBottomNav(
        currentTab: 'dashboard',
        backgroundColor: Colors.white,
        activeIconColor: Colors.black87,
        activeLabelColor: Colors.black87,
        inactiveIconColor: Colors.grey.shade400,
        activeBackgroundColor: Colors.transparent,
        projectsLabel: 'Projects',
        cpLabel: 'Network',
        onDashboardTap: () {
          setState(() {
            _currentNavTab = 'my_leads';
            int idx = _tabs.indexWhere((t) => t['id'] == 'my_leads');
            if (idx != -1) _tabController.index = idx;
          });
          _scrollToSection(_topKey, navTab: 'my_leads');
        },
        onMonitoringTap: authVM.canSeeMonitoring
            ? () => _scrollToSection(_monitoringKey, navTab: 'monitoring')
            : null,
        onAdminTap: authVM.canManageUsers || authVM.permissions.canManageRoles
            ? () => context.go('/admin-console')
            : null,
      ),
    );
  }

  Widget? _buildAdminDrawer(AuthViewModel authVM) {
    if (!authVM.canSeeMonitoring && !authVM.canManageUsers) return null;

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFFFF6B22),
                    child: Text(
                      authVM.userName.isEmpty ? '?' : authVM.userName[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authVM.userName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        authVM.roleLabel,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Overview'),
              onTap: () => Navigator.pop(context),
            ),
            if (authVM.canManageUsers)
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('User Management'),
                onTap: () => context.go('/admin-console'),
              ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Form Settings'),
              onTap: () {},
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () => authVM.logout(),
            ),
            const SizedBox(height: 10),
          ],
        ),
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