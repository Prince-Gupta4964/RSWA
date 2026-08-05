import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../utils/role_permissions.dart';

class AppBottomNav extends StatelessWidget {
  // ORIGINAL FIELDS RETAINED
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
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);
    final isCPOrBuilder = authVM.appRole == AppRole.cp || authVM.appRole == AppRole.builder;

    final items = <_NavItem>[
      _NavItem(
        keyName: 'dashboard',
        label: 'Home',
        icon: Icons.home_rounded,
        onTap: onDashboardTap ?? () => context.go('/dashboard'),
      ),
      _NavItem(
        keyName: 'projects',
        label: projectsLabel,
        icon: Icons.business_rounded,
        onTap: () => context.go('/projects'),
      ),
      _NavItem(
        keyName: 'cp',
        label: 'CP',
        icon: Icons.people_rounded,
        onTap: () => context.go('/cp-list'),
      ),
      //if (!isCPOrBuilder)
       // _NavItem(
        //  keyName: 'builders',
        //  label: 'Builder',
          //icon: Icons.engineering_rounded,
        //  onTap: () => context.go('/builders'),
        //),
      if (!isCPOrBuilder)
        _NavItem(
          keyName: 'monitoring',
          label: 'Stats',
          icon: Icons.bar_chart_rounded,
          onTap: onMonitoringTap ?? () => {},
        ),
      if (!isCPOrBuilder)
        _NavItem(
          keyName: 'leads',
          label: 'Score',
          icon: Icons.assistant_photo_rounded,
          onTap: () => {},
        ),
    ];

    int selectedIndex = items.indexWhere((item) => item.keyName == currentTab);
    if (selectedIndex == -1) selectedIndex = 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // Background solid white rakha hai
        borderRadius: borderRadius ?? const BorderRadius.vertical(top: Radius.circular(20)),
        // 🚀 NAYA: Border hata di aur Shadow laga di jaisa aapne manga tha
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            color: Colors.black.withOpacity(0.08), // Smooth drop shadow
            offset: const Offset(0, -4), // Shadow thoda upar ki taraf
          )
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: GNav(
            rippleColor: Colors.grey.shade200,
            hoverColor: Colors.grey.shade50,
            gap: 8,

            // 🚀 NAYA: Spelling/Text ko visible karne ke liye Dark color use kiya
            activeColor: Colors.black87,

            // 🚀 NAYA: Inactive icons ko ekdum lighter grey kar diya (Screenshot jaisa)
            color: Colors.grey.shade400,

            iconSize: 24,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            duration: const Duration(milliseconds: 400),

            // 🚀 NAYA: Background transparent aur Border Add ki hai (Screenshot look)
            tabBackgroundColor: Colors.transparent,
            tabActiveBorder: Border.all(color: Colors.black87, width: 1.2),

            tabs: items.map((item) => GButton(
              icon: item.icon,
              text: item.label,
              textStyle: const TextStyle(
                color: Colors.black87, // Text ekdum clear dikhega
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            )).toList(),

            selectedIndex: selectedIndex,
            onTabChange: (index) {
              items[index].onTap();
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String keyName;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _NavItem({
    required this.keyName,
    required this.label,
    required this.icon,
    required this.onTap,
  });
}