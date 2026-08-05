enum AppRole { superAdmin, admin, officeStaff, builder, cp, unknown }

String appRoleKey(AppRole role) {
  switch (role) {
    case AppRole.superAdmin:
      return 'super_admin';
    case AppRole.admin:
      return 'admin';
    case AppRole.officeStaff:
      return 'office_staff';
    case AppRole.builder:
      return 'builder';
    case AppRole.cp:
      return 'cp';
    case AppRole.unknown:
      return 'unknown';
  }
}

AppRole parseAppRole(String? rawRole) {
  switch ((rawRole ?? '').trim().toLowerCase()) {
    case 'super admin':
      return AppRole.superAdmin;
    case 'admin':
      return AppRole.admin;
    case 'office staff':
      return AppRole.officeStaff;
    case 'builder':
      return AppRole.builder;
    case 'cp':
    case 'channel partner':
      return AppRole.cp;
    default:
      return AppRole.unknown;
  }
}

String appRoleLabel(AppRole role) {
  switch (role) {
    case AppRole.superAdmin:
      return 'Super Admin';
    case AppRole.admin:
      return 'Admin';
    case AppRole.officeStaff:
      return 'Office Staff';
    case AppRole.builder:
      return 'Builder';
    case AppRole.cp:
      return 'CP';
    case AppRole.unknown:
      return 'Unknown';
  }
}

class AppPermissions {
  final bool canManageUsers;
  final bool canManageRoles;
  final bool canConfigureForms;
  final bool canConfigureTabs;
  final bool canCreateCustomFilters;
  final bool canSeeAllProjects;
  final bool canSeeAllLeads;
  final bool canSeeMonitoring;
  final bool canAddProjects;
  final bool canAddLeads;
  final List<String> dashboardTabs;

  const AppPermissions({
    required this.canManageUsers,
    required this.canManageRoles,
    required this.canConfigureForms,
    required this.canConfigureTabs,
    required this.canCreateCustomFilters,
    required this.canSeeAllProjects,
    required this.canSeeAllLeads,
    required this.canSeeMonitoring,
    required this.canAddProjects,
    required this.canAddLeads,
    required this.dashboardTabs,
  });

  bool get seesOwnLeadsOnly => !canSeeAllLeads;
  bool get seesOwnProjectsOnly => !canSeeAllProjects;

  static AppPermissions forRole(AppRole role) {
    switch (role) {
      case AppRole.superAdmin:
        return const AppPermissions(
          canManageUsers: true,
          canManageRoles: true,
          canConfigureForms: true,
          canConfigureTabs: true,
          canCreateCustomFilters: true,
          canSeeAllProjects: true,
          canSeeAllLeads: true,
          canSeeMonitoring: true,
          canAddProjects: true,
          canAddLeads: true,
          dashboardTabs: [
            'dashboard',
            'projects',
            'leads',
            'cp',
            'monitoring',
            'admin',
          ],
        );
      case AppRole.admin:
        return const AppPermissions(
          canManageUsers: true,
          canManageRoles: true,
          canConfigureForms: true,
          canConfigureTabs: true,
          canCreateCustomFilters: true,
          canSeeAllProjects: true,
          canSeeAllLeads: true,
          canSeeMonitoring: true,
          canAddProjects: true,
          canAddLeads: true,
          dashboardTabs: [
            'dashboard',
            'projects',
            'leads',
            'cp',
            'monitoring',
            'admin',
          ],
        );
      case AppRole.officeStaff:
        return const AppPermissions(
          canManageUsers: false,
          canManageRoles: false,
          canConfigureForms: false,
          canConfigureTabs: false,
          canCreateCustomFilters: false,
          canSeeAllProjects: true,
          canSeeAllLeads: true,
          canSeeMonitoring: true,
          canAddProjects: true,
          canAddLeads: true,
          dashboardTabs: ['dashboard', 'projects', 'leads', 'cp', 'monitoring'],
        );
      case AppRole.builder:
      case AppRole.cp:
        return const AppPermissions(
          canManageUsers: false,
          canManageRoles: false,
          canConfigureForms: false,
          canConfigureTabs: false,
          canCreateCustomFilters: false,
          canSeeAllProjects: true,
          canSeeAllLeads: false,
          canSeeMonitoring: false,
          canAddProjects: true,
          canAddLeads: true,
          dashboardTabs: ['dashboard', 'projects', 'leads'],
        );
      case AppRole.unknown:
        return const AppPermissions(
          canManageUsers: false,
          canManageRoles: false,
          canConfigureForms: false,
          canConfigureTabs: false,
          canCreateCustomFilters: false,
          canSeeAllProjects: false,
          canSeeAllLeads: false,
          canSeeMonitoring: false,
          canAddProjects: false,
          canAddLeads: false,
          dashboardTabs: ['dashboard'],
        );
    }
  }
}
