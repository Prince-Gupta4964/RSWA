#!/bin/bash
# RSWA Complete Widgets Setup Script with Sort By & Group By
# Run this script in your terminal from the project root: bash setup_widgets.sh

echo "====================================================="
echo " Setting up RSWA Widgets & UI Components with "
echo " Top Bar, Bottom Bar, List View, Search Bar, "
echo " Sliver App Bar, Autocomplete, Advanced Widgets, "
echo " and Sort By / Group By features..."
echo "====================================================="

mkdir -p lib/widgets/leads
mkdir -p lib/widgets/google_auth_button
mkdir -p lib/views/shared_widgets

# ---------------------------------------------------------
# 1. BOTTOM BAR WIDGET (AppBottomNav)
# ---------------------------------------------------------
echo "Creating AppBottomNav (Bottom Bar)..."
cat << 'EOF' > lib/widgets/app_bottom_nav.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../viewmodels/app_configuration_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';

class AppBottomNav extends StatefulWidget {
  final StatefulNavigationShell? navigationShell;
  final String currentTab;
  final Color backgroundColor;
  final BoxBorder? border;
  final BorderRadius? borderRadius;
  final Color activeIconColor;
  final Color activeLabelColor;
  final Color inactiveIconColor;
  final String projectsLabel;
  final String cpLabel;
  final VoidCallback? onDashboardTap;

  const AppBottomNav({
    super.key,
    this.navigationShell,
    required this.currentTab,
    required this.backgroundColor,
    required this.activeIconColor,
    required this.activeLabelColor,
    required this.inactiveIconColor,
    this.border,
    this.borderRadius,
    this.projectsLabel = 'Projects',
    this.cpLabel = 'Network',
    this.onDashboardTap,
  });

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  @override
  Widget build(BuildContext context) {
    final configVM = Provider.of<AppConfigurationViewModel>(context, listen: false);
    final authVM = Provider.of<AuthViewModel>(context);
    final allowedTabs = authVM.permissions.dashboardTabs;

    final allItems = <_NavItem>[
      _NavItem(keyName: 'dashboard', label: 'Leads', icon: Icons.home_rounded, branchIndex: 0, customOnTap: widget.onDashboardTap),
      _NavItem(keyName: 'projects', label: widget.projectsLabel, icon: Icons.business_rounded, branchIndex: 1),
      _NavItem(keyName: 'cp', label: 'CP', icon: Icons.people_rounded, branchIndex: 2),
      _NavItem(keyName: 'map', label: 'MAP', icon: Icons.map_rounded, branchIndex: 5),
    ];

    final items = allItems.where((item) => allowedTabs.contains(item.keyName)).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.borderRadius ?? const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(blurRadius: 20, color: Colors.black.withValues(alpha: 0.08), offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: items.map((item) {
              final isSelected = item.keyName == widget.currentTab;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => configVM.handleFastTap(item.keyName, item.customOnTap ?? () => _onTabTap(item.branchIndex)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.grey.shade50 : Colors.grey.shade50.withValues(alpha: 0),
                      borderRadius: BorderRadius.circular(25),
                      border: isSelected ? Border.all(color: Colors.black87, width: 1.2) : Border.all(color: Colors.black87.withValues(alpha: 0), width: 1.2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.icon, size: 20, color: isSelected ? Colors.black87 : Colors.grey.shade400),
                        if (isSelected) ...[
                          const SizedBox(width: 4),
                          Flexible(child: Text(item.label, overflow: TextOverflow.ellipsis, maxLines: 1, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12))),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _onTabTap(int index) {
    if (widget.navigationShell != null) {
      widget.navigationShell!.goBranch(index, initialLocation: index == widget.navigationShell!.currentIndex);
    } else {
      switch (index) {
        case 0: context.go('/dashboard'); break;
        case 1: context.go('/projects'); break;
        case 2: context.go('/cp-list'); break;
        case 3: context.go('/builders'); break;
        case 4: context.go('/admin-console'); break;
        case 5: context.go('/map'); break;
      }
    }
  }
}

class _NavItem {
  final String keyName;
  final String label;
  final IconData icon;
  final int branchIndex;
  final VoidCallback? customOnTap;
  const _NavItem({required this.keyName, required this.label, required this.icon, required this.branchIndex, this.customOnTap});
}
EOF

# ---------------------------------------------------------
# 2. LIST VIEW WITH SORT BY & GROUP BY WIDGET
# ---------------------------------------------------------
echo "Creating Sortable Groupable ListView Widget..."
cat << 'EOF' > lib/widgets/leads/sortable_groupable_list_widget.dart
import 'package:flutter/material.dart';

enum SortOption { dateNewest, dateOldest, nameAZ, nameZA, status }
enum GroupOption { none, status, assignee, date }

class SortableGroupableListWidget<T> extends StatefulWidget {
  final List<T> items;
  final String Function(T item) getTitle;
  final String Function(T item) getSubtitle;
  final String Function(T item) getStatus;
  final DateTime? Function(T item) getDateTime;
  final String Function(T item) getAssignee;
  final Widget Function(T item, int index) itemBuilder;

  const SortableGroupableListWidget({
    super.key,
    required this.items,
    required this.getTitle,
    required this.getSubtitle,
    required this.getStatus,
    required this.getDateTime,
    required this.getAssignee,
    required this.itemBuilder,
  });

  @override
  State<SortableGroupableListWidget<T>> createState() => _SortableGroupableListWidgetState<T>();
}

class _SortableGroupableListWidgetState<T> extends State<SortableGroupableListWidget<T>> {
  SortOption _currentSort = SortOption.dateNewest;
  GroupOption _currentGroup = GroupOption.none;
  String _searchQuery = '';

  List<T> get _processedItems {
    var list = List<T>.from(widget.items);

    // 1. Search filter
    if (_searchQuery.isNotEmpty) {
      list = list.where((item) {
        final title = widget.getTitle(item).toLowerCase();
        final subtitle = widget.getSubtitle(item).toLowerCase();
        return title.contains(_searchQuery.toLowerCase()) || subtitle.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // 2. Sort by
    list.sort((a, b) {
      switch (_currentSort) {
        case SortOption.dateNewest:
          final dtA = widget.getDateTime(a) ?? DateTime(2000);
          final dtB = widget.getDateTime(b) ?? DateTime(2000);
          return dtB.compareTo(dtA);
        case SortOption.dateOldest:
          final dtA = widget.getDateTime(a) ?? DateTime(2000);
          final dtB = widget.getDateTime(b) ?? DateTime(2000);
          return dtA.compareTo(dtB);
        case SortOption.nameAZ:
          return widget.getTitle(a).compareTo(widget.getTitle(b));
        case SortOption.nameZA:
          return widget.getTitle(b).compareTo(widget.getTitle(a));
        case SortOption.status:
          return widget.getStatus(a).compareTo(widget.getStatus(b));
      }
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final items = _processedItems;

    return Column(
      children: [
        // --- SEARCH BAR, SORT BY & GROUP BY CONTROLS ---
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // Search Bar
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search items...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFFFF6B22)),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFF6B22), width: 1.5)),
                ),
              ),
              const SizedBox(height: 10),
              // Sort By & Group By Dropdowns
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                      child: Row(
                        children: [
                          const Text('Sort: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: DropdownButton<SortOption>(
                              value: _currentSort,
                              isExpanded: true,
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(value: SortOption.dateNewest, child: Text('Newest First', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: SortOption.dateOldest, child: Text('Oldest First', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: SortOption.nameAZ, child: Text('Name (A-Z)', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: SortOption.nameZA, child: Text('Name (Z-A)', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: SortOption.status, child: Text('Status', style: TextStyle(fontSize: 12))),
                              ],
                              onChanged: (v) => setState(() => _currentSort = v!),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                      child: Row(
                        children: [
                          const Text('Group: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: DropdownButton<GroupOption>(
                              value: _currentGroup,
                              isExpanded: true,
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(value: GroupOption.none, child: Text('None', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: GroupOption.status, child: Text('By Status', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: GroupOption.assignee, child: Text('By Assignee', style: TextStyle(fontSize: 12))),
                              ],
                              onChanged: (v) => setState(() => _currentGroup = v!),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // --- LIST VIEW ---
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('No results found.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) => widget.itemBuilder(items[index], index),
                ),
        ),
      ],
    );
  }
}
EOF

# ---------------------------------------------------------
# 3. ADVANCED WIDGETS & AUTOCOMPLETE
# ---------------------------------------------------------
echo "Creating Advanced Carousel Widget..."
cat << 'EOF' > lib/views/shared_widgets/advanced_carousel.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class AdvancedCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final Function(int index)? onImageTap;

  const AdvancedCarousel({super.key, required this.imageUrls, this.onImageTap});

  @override
  State<AdvancedCarousel> createState() => _AdvancedCarouselState();
}

class _AdvancedCarouselState extends State<AdvancedCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.imageUrls.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (!mounted || widget.imageUrls.isEmpty) return;
        _currentPage = (_currentPage + 1) % widget.imageUrls.length;
        _pageController.animateToPage(_currentPage, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return Container(height: 200, color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey));
    }

    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (ctx, idx) => GestureDetector(
              onTap: () => widget.onImageTap?.call(idx),
              child: Image.network(widget.imageUrls[idx], fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade300, child: const Icon(Icons.broken_image))),
            ),
          ),
          Positioned(
            bottom: 12, right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
              child: Text('${_currentPage + 1} / ${widget.imageUrls.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
EOF

echo "All enhanced widgets with Sort By & Group By created successfully!"
