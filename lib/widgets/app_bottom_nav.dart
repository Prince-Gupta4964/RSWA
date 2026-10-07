import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../viewmodels/app_configuration_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart'; // 🚀 NAYA
import '../utils/role_permissions.dart'; // 🚀 NAYA

class AppBottomNav extends StatefulWidget {
  final StatefulNavigationShell? navigationShell;
  final String currentTab;
  final Color backgroundColor;
  final BoxBorder? border;
  final BorderRadius? borderRadius;
  final Color activeIconColor;
  final Color activeLabelColor;
  final Color inactiveIconColor;
  final Color? activeBackgroundColor;
  final List<Color>? activeGradientColors;
  final String projectsLabel;
  final String cpLabel;
  final VoidCallback? onDashboardTap;
  final VoidCallback? onMonitoringTap;
  final VoidCallback? onAdminTap;

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
    this.activeBackgroundColor,
    this.activeGradientColors,
    this.projectsLabel = 'Projects',
    this.cpLabel = 'Network',
    this.onDashboardTap,
    this.onMonitoringTap,
    this.onAdminTap,
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
      _NavItem(
        keyName: 'dashboard',
        label: 'Leads',
        icon: Icons.home_rounded,
        branchIndex: 0,
        customOnTap: widget.onDashboardTap,
      ),
      _NavItem(
        keyName: 'projects',
        label: widget.projectsLabel,
        icon: Icons.business_rounded,
        branchIndex: 1,
      ),
      _NavItem(
        keyName: 'cp',
        label: 'CP',
        icon: Icons.people_rounded,
        branchIndex: 2,
      ),
      _NavItem(
        keyName: 'map',
        label: 'MAP',
        icon: Icons.map_rounded,
        branchIndex: 5,
      ),
    ];

    final items = allItems.where((item) => allowedTabs.contains(item.keyName)).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.borderRadius ?? const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, -4),
          )
        ],
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
                  onTap: () {
                    configVM.handleFastTap(
                      item.keyName,
                      item.customOnTap ?? () => _onTabTap(item.branchIndex),
                    );
                  },
                  onLongPress: () {
                    debugPrint('NAV LONG PRESS: ${item.keyName}');
                    if (item.keyName == 'dashboard') {
                      configVM.triggerLeadFilter();
                    } else if (item.keyName == 'projects') {
                      configVM.triggerProjectFilter();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.grey.shade50 : Colors.grey.shade50.withValues(alpha: 0),
                      borderRadius: BorderRadius.circular(25),
                      border: isSelected
                          ? Border.all(color: Colors.black87, width: 1.2)
                          : Border.all(color: Colors.black87.withValues(alpha: 0), width: 1.2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          size: 20,
                          color: isSelected ? Colors.black87 : Colors.grey.shade400,
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              item.label,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
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
      widget.navigationShell!.goBranch(
        index,
        initialLocation: index == widget.navigationShell!.currentIndex,
      );
    } else {
      // Fallback
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

  const _NavItem({
    required this.keyName,
    required this.label,
    required this.icon,
    required this.branchIndex,
    this.customOnTap,
  });
}
