import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/app_configuration_models.dart';
import '../../models/app_user_model.dart';
import '../../utils/role_permissions.dart';
import '../../viewmodels/app_configuration_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/user_management_viewmodel.dart';
import '../../widgets/app_drawer.dart';

class AdminConsoleView extends StatelessWidget {
  const AdminConsoleView({super.key});

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    final isSuperAdmin = authVM.appRole == AppRole.superAdmin;

    if (!authVM.canManageUsers) {
      return const Scaffold(body: _NoAdminAccess());
    }

    final tabs = <Tab>[
      const Tab(text: 'Users'),
      if (isSuperAdmin) const Tab(text: 'CP Access'),
      if (isSuperAdmin) const Tab(text: 'Roles'),
      if (isSuperAdmin) const Tab(text: 'Lead Form'),
      if (isSuperAdmin) const Tab(text: 'Custom Forms'),
      if (isSuperAdmin) const Tab(text: 'Tabs'),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        StatefulNavigationShell.of(context).goBranch(0);
      },
      child: DefaultTabController(
        length: tabs.length,
        child: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            scrolledUnderElevation: 0,
            elevation: 0,
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.black),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            title: const Text(
              'Admin Console',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            bottom: TabBar(
              isScrollable: true,
              labelColor: const Color(0xFFFF6B22),
              indicatorColor: const Color(0xFFFF6B22),
              dividerColor: const Color(0xFFE5E7EB),
              tabs: tabs,
            ),
          ),
          drawer: const AppDrawer(),
          body: TabBarView(
            children: [
              const _UsersTab(),
              if (isSuperAdmin) const _CpAccessTab(),
              if (isSuperAdmin) const _RolesTab(),
              if (isSuperAdmin) const _LeadFormTab(),
              if (isSuperAdmin) const _CustomFormsTab(),
              if (isSuperAdmin) const _DashboardTabsTab(),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoAdminAccess extends StatelessWidget {
  const _NoAdminAccess();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 44, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            const Text(
              'Admin access is required.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    final usersVM = context.watch<UserManagementViewModel>();
    final configVM = context.watch<AppConfigurationViewModel>();
    final users = usersVM.users.where((user) {
      final query = _query.trim().toLowerCase();
      return query.isEmpty ||
          user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          user.role.toLowerCase().contains(query);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Search users',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                tooltip: 'Add user',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B22),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _showUserEditor(
                  context,
                  authVM,
                  roleDefinitions: configVM.roleDefinitions,
                ),
                icon: const Icon(Icons.person_add_alt_1_outlined),
              ),
            ],
          ),
        ),
        Expanded(
          child: usersVM.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF6B22)),
                )
              : usersVM.error != null
              ? Center(child: Text(usersVM.error!))
              : users.isEmpty
              ? const Center(child: Text('No users found.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: users.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _UserTile(
                    user: users[index],
                    canEdit: _canManageUser(authVM, users[index]),
                    canSeeCredentials:
                        authVM.appRole == AppRole.superAdmin &&
                        users[index].appRole == AppRole.cp,
                    onEdit: () => _showUserEditor(
                      context,
                      authVM,
                      roleDefinitions: configVM.roleDefinitions,
                      existingUser: users[index],
                    ),
                    onActiveChanged: (value) async {
                      try {
                        await usersVM.setUserActive(
                          actorRole: authVM.appRole,
                          user: users[index],
                          isActive: value,
                        );
                      } catch (error) {
                        if (!context.mounted) return;
                        _showError(context, error);
                      }
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  final AppUserModel user;
  final bool canEdit;
  final bool canSeeCredentials;
  final VoidCallback onEdit;
  final ValueChanged<bool> onActiveChanged;

  const _UserTile({
    required this.user,
    required this.canEdit,
    required this.canSeeCredentials,
    required this.onEdit,
    required this.onActiveChanged,
  });

  @override
  Widget build(BuildContext context) {
    final name = user.name.isEmpty ? user.email : user.name;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFFFF1EA),
              foregroundColor: const Color(0xFFFF6B22),
              child: Text(
                name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 7,
                    runSpacing: 5,
                    children: [
                      _RoleChip(label: user.role),
                      _StatusChip(isActive: user.isActive),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Switch.adaptive(
                  value: user.isActive,
                  activeColor: const Color(0xFFFF6B22),
                  onChanged: canEdit ? onActiveChanged : null,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canSeeCredentials)
                      IconButton(
                        tooltip: 'View credentials',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _showCredentials(context, user),
                        icon: const Icon(Icons.key_outlined),
                      ),
                    if (canEdit)
                      IconButton(
                        tooltip: 'Edit user',
                        visualDensity: VisualDensity.compact,
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CpAccessTab extends StatelessWidget {
  const _CpAccessTab();

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    final usersVM = context.watch<UserManagementViewModel>();
    final configVM = context.watch<AppConfigurationViewModel>();
    final cpUsers = usersVM.channelPartners;

    return usersVM.isLoading
        ? const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF6B22)),
          )
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cpUsers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final user = cpUsers[index];
              return _UserTile(
                user: user,
                canEdit: _canManageUser(authVM, user),
                canSeeCredentials: true,
                onEdit: () => _showUserEditor(
                  context,
                  authVM,
                  roleDefinitions: configVM.roleDefinitions,
                  existingUser: user,
                ),
                onActiveChanged: (value) async {
                  try {
                    await usersVM.setUserActive(
                      actorRole: authVM.appRole,
                      user: user,
                      isActive: value,
                    );
                  } catch (error) {
                    if (!context.mounted) return;
                    _showError(context, error);
                  }
                },
              );
            },
          );
  }
}

class _LeadFormTab extends StatelessWidget {
  const _LeadFormTab();

  @override
  Widget build(BuildContext context) {
    final configurationVM = context.watch<AppConfigurationViewModel>();
    final fields = configurationVM.allLeadFields;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Custom Lead Fields',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final field = await _showFieldEditor(context);
                  if (field == null || !context.mounted) return;
                  await _saveFields(context, [...fields, field]);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B22),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Field'),
              ),
            ],
          ),
        ),
        Expanded(
          child: fields.isEmpty
              ? const Center(child: Text('No custom lead fields.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: fields.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final field = fields[index];
                    return _ConfigTile(
                      title: field.label,
                      subtitle:
                          '${_fieldTypeLabel(field.type)}${field.isRequired ? ' · Required' : ''}',
                      isVisible: field.isVisible,
                      onVisibilityChanged: (value) => _saveFields(
                        context,
                        _replaceAt(
                          fields,
                          index,
                          field.copyWith(isVisible: value),
                        ),
                      ),
                      onEdit: () async {
                        final updated = await _showFieldEditor(
                          context,
                          existing: field,
                        );
                        if (updated == null || !context.mounted) return;
                        await _saveFields(
                          context,
                          _replaceAt(fields, index, updated),
                        );
                      },
                      onDelete: () => _saveFields(
                        context,
                        _removeAt(fields, index),
                      ),
                      onMoveUp: index == 0
                          ? null
                          : () => _saveFields(context, _moveItem(fields, index, -1)),
                      onMoveDown: index == fields.length - 1
                          ? null
                          : () => _saveFields(context, _moveItem(fields, index, 1)),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _RolesTab extends StatelessWidget {
  const _RolesTab();

  @override
  Widget build(BuildContext context) {
    final configVM = context.watch<AppConfigurationViewModel>();
    final customRoles = configVM.roleDefinitions
        .where((role) => !role.isSystem)
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Custom Roles',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final role = await _showRoleEditor(context);
                  if (role == null || !context.mounted) return;
                  final duplicate = configVM.roleDefinitions.any(
                    (item) => item.label.toLowerCase() == role.label.toLowerCase(),
                  );
                  if (duplicate) {
                    _showError(context, 'A role with this name already exists.');
                    return;
                  }
                  await _saveRoles(context, [...customRoles, role]);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B22),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Role'),
              ),
            ],
          ),
        ),
        Expanded(
          child: customRoles.isEmpty
              ? const Center(child: Text('No custom roles.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: customRoles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final role = customRoles[index];
                    return _ConfigTile(
                      title: role.label,
                      subtitle: 'Base access: ${role.baseRole}',
                      isVisible: true,
                      showVisibility: false,
                      onVisibilityChanged: (_) {},
                      onEdit: () async {
                        final updated = await _showRoleEditor(
                          context,
                          existing: role,
                        );
                        if (updated == null || !context.mounted) return;
                        await _saveRoles(
                          context,
                          _replaceAt(customRoles, index, updated),
                        );
                      },
                      onDelete: () => _saveRoles(
                        context,
                        _removeAt(customRoles, index),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CustomFormsTab extends StatelessWidget {
  const _CustomFormsTab();

  @override
  Widget build(BuildContext context) {
    final configVM = context.watch<AppConfigurationViewModel>();
    final forms = configVM.customForms;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Custom Forms',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final form = await _showCustomFormEditor(
                    context,
                    roleDefinitions: configVM.roleDefinitions,
                  );
                  if (form == null || !context.mounted) return;
                  await _createCustomForm(context, form);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B22),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Form'),
              ),
            ],
          ),
        ),
        Expanded(
          child: forms.isEmpty
              ? const Center(child: Text('No custom forms.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: forms.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final form = forms[index];
                    return _ConfigTile(
                      title: form.label,
                      subtitle: '${form.fields.length} fields · ${_rolesLabel(form.roles, configVM.roleDefinitions)}',
                      isVisible: form.isVisible,
                      onVisibilityChanged: (value) => _updateCustomForm(
                        context,
                        form.copyWith(isVisible: value),
                      ),
                      onEdit: () async {
                        final updated = await _showCustomFormEditor(
                          context,
                          existing: form,
                          roleDefinitions: configVM.roleDefinitions,
                        );
                        if (updated == null || !context.mounted) return;
                        await _updateCustomForm(context, updated);
                      },
                      onDelete: () => _deleteCustomForm(context, form.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _DashboardTabsTab extends StatelessWidget {
  const _DashboardTabsTab();

  @override
  Widget build(BuildContext context) {
    final configurationVM = context.watch<AppConfigurationViewModel>();
    final tabs = configurationVM.dashboardTabs
        .where((tab) => !tab.destination.startsWith('form:'))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Dashboard Tabs',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final tab = await _showTabEditor(
                    context,
                    roleDefinitions: configurationVM.roleDefinitions,
                  );
                  if (tab == null || !context.mounted) return;
                  await _saveTabs(context, [...tabs, tab]);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B22),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Tab'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: tabs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final tab = tabs[index];
              return _ConfigTile(
                title: tab.label,
                subtitle: '${_destinationLabel(tab.destination)} · ${_rolesLabel(tab.roles, configurationVM.roleDefinitions)}',
                isVisible: tab.isVisible,
                onVisibilityChanged: (value) => _saveTabs(
                  context,
                  _replaceAt(tabs, index, tab.copyWith(isVisible: value)),
                ),
                onEdit: () async {
                  final updated = await _showTabEditor(
                    context,
                    existing: tab,
                    roleDefinitions: configurationVM.roleDefinitions,
                  );
                  if (updated == null || !context.mounted) return;
                  await _saveTabs(context, _replaceAt(tabs, index, updated));
                },
                onDelete: () => _saveTabs(context, _removeAt(tabs, index)),
                onMoveUp: index == 0
                    ? null
                    : () => _saveTabs(context, _moveItem(tabs, index, -1)),
                onMoveDown: index == tabs.length - 1
                    ? null
                    : () => _saveTabs(context, _moveItem(tabs, index, 1)),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ConfigTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isVisible;
  final bool showVisibility;
  final ValueChanged<bool> onVisibilityChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const _ConfigTile({
    required this.title,
    required this.subtitle,
    required this.isVisible,
    this.showVisibility = true,
    required this.onVisibilityChanged,
    required this.onEdit,
    required this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (showVisibility)
              Switch.adaptive(
                value: isVisible,
                activeColor: const Color(0xFFFF6B22),
                onChanged: onVisibilityChanged,
              ),
            PopupMenuButton<String>(
              tooltip: 'Configure',
              onSelected: (value) {
                switch (value) {
                  case 'up':
                    onMoveUp?.call();
                    break;
                  case 'down':
                    onMoveDown?.call();
                    break;
                  case 'edit':
                    onEdit();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'up',
                  enabled: onMoveUp != null,
                  child: const Text('Move up'),
                ),
                PopupMenuItem(
                  value: 'down',
                  enabled: onMoveDown != null,
                  child: const Text('Move down'),
                ),
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;

  const _RoleChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1EA),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFFFF6B22),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isActive;

  const _StatusChip({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF047857) : const Color(0xFF6B7280);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

bool _canManageUser(AuthViewModel authVM, AppUserModel user) {
  return authVM.appRole == AppRole.superAdmin ||
      (authVM.appRole == AppRole.admin && !user.isSuperAdmin);
}

void _showCredentials(BuildContext context, AppUserModel user) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(user.name.isEmpty ? 'CP Credentials' : user.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText('User ID: ${user.id}'),
          const SizedBox(height: 10),
          SelectableText('Email: ${user.email}'),
          const SizedBox(height: 10),
          SelectableText('Password: ${user.password}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<void> _showUserEditor(
  BuildContext context,
  AuthViewModel authVM, {
  required List<RoleDefinition> roleDefinitions,
  AppUserModel? existingUser,
}) async {
  final nameController = TextEditingController(text: existingUser?.name ?? '');
  final emailController = TextEditingController(text: existingUser?.email ?? '');
  final passwordController = TextEditingController(
    text: existingUser?.password ?? '',
  );
  final isSuperAdmin = authVM.appRole == AppRole.superAdmin;
  final roleOptions = roleDefinitions
      .where(
        (role) => isSuperAdmin || role.key != 'super_admin',
      )
      .toList();
  var selectedRole = roleOptions.firstWhere(
    (role) => role.label.toLowerCase() == existingUser?.role.toLowerCase(),
    orElse: () => roleOptions.firstWhere(
      (role) => role.key == 'cp',
      orElse: () => roleOptions.first,
    ),
  );
  var isActive = existingUser?.isActive ?? true;

  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  existingUser == null ? 'Add User' : 'Edit User',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RoleDefinition>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: roleOptions
                      .map(
                        (role) => DropdownMenuItem(
                          value: role,
                          child: Text(role.label),
                        ),
                      )
                      .toList(),
                  onChanged: (role) {
                    if (role != null) setSheetState(() => selectedRole = role);
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active account'),
                  value: isActive,
                  activeColor: const Color(0xFFFF6B22),
                  onChanged: (value) => setSheetState(() => isActive = value),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B22),
                  ),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final email = emailController.text.trim();
                    final password = passwordController.text;
                    if (name.isEmpty || !email.contains('@') || password.isEmpty) {
                      _showError(context, 'Enter a name, valid email, and password.');
                      return;
                    }
                    try {
                      await sheetContext.read<UserManagementViewModel>().saveUser(
                        actorRole: authVM.appRole,
                        existingUser: existingUser,
                        name: name,
                        email: email,
                        password: password,
                        role: selectedRole.label,
                        baseRole: selectedRole.baseRole,
                        isActive: isActive,
                      );
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    } catch (error) {
                      if (!sheetContext.mounted) return;
                      _showError(sheetContext, error);
                    }
                  },
                  child: const Text('Save User'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  } finally {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
  }
}

Future<DynamicLeadField?> _showFieldEditor(
  BuildContext context, {
  DynamicLeadField? existing,
}) async {
  final labelController = TextEditingController(text: existing?.label ?? '');
  final optionsController = TextEditingController(
    text: existing?.options.join(', ') ?? '',
  );
  var type = existing?.type ?? 'text';
  var isRequired = existing?.isRequired ?? false;
  var result = await showModalBottomSheet<DynamicLeadField>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              existing == null ? 'Add Lead Field' : 'Edit Lead Field',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: 'Field label'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: type,
              decoration: const InputDecoration(labelText: 'Field type'),
              items: const [
                DropdownMenuItem(value: 'text', child: Text('Text')),
                DropdownMenuItem(value: 'multiline', child: Text('Long text')),
                DropdownMenuItem(value: 'number', child: Text('Number')),
                DropdownMenuItem(value: 'choice', child: Text('Choice list')),
              ],
              onChanged: (value) => setSheetState(() => type = value ?? type),
            ),
            if (type == 'choice') ...[
              const SizedBox(height: 12),
              TextField(
                controller: optionsController,
                decoration: const InputDecoration(
                  labelText: 'Choices',
                  hintText: 'Example: Hot, Warm, Cold',
                ),
              ),
            ],
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Required field'),
              value: isRequired,
              activeColor: const Color(0xFFFF6B22),
              onChanged: (value) => setSheetState(() => isRequired = value),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B22),
              ),
              onPressed: () {
                final label = labelController.text.trim();
                final options = optionsController.text
                    .split(',')
                    .map((option) => option.trim())
                    .where((option) => option.isNotEmpty)
                    .toList();
                if (label.isEmpty || (type == 'choice' && options.isEmpty)) {
                  _showError(
                    context,
                    type == 'choice'
                        ? 'Enter a label and at least one choice.'
                        : 'Enter a field label.',
                  );
                  return;
                }
                Navigator.pop(
                  sheetContext,
                  DynamicLeadField(
                    id: existing?.id ??
                        '${_fieldKey(label)}_${DateTime.now().millisecondsSinceEpoch}',
                    label: label,
                    type: type,
                    options: options,
                    roles: existing?.roles ?? const ['all'],
                    isRequired: isRequired,
                    isVisible: existing?.isVisible ?? true,
                    order: existing?.order ?? 0,
                  ),
                );
              },
              child: const Text('Save Field'),
            ),
          ],
        ),
      ),
    ),
  );
  labelController.dispose();
  optionsController.dispose();
  return result;
}

Future<DashboardTabConfig?> _showTabEditor(
  BuildContext context, {
  DashboardTabConfig? existing,
  required List<RoleDefinition> roleDefinitions,
}) async {
  final labelController = TextEditingController(text: existing?.label ?? '');
  var destination = existing?.destination ?? 'dashboard';
  var roles = {...(existing?.roles ?? const <String>['all'])};
  var result = await showModalBottomSheet<DashboardTabConfig>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                existing == null ? 'Add Dashboard Tab' : 'Edit Dashboard Tab',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: labelController,
                decoration: const InputDecoration(labelText: 'Tab label'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: destination,
                decoration: const InputDecoration(labelText: 'Open section'),
                items: _tabDestinations.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setSheetState(
                  () => destination = value ?? destination,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Visible to',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: roleDefinitions.map((role) {
                  final selected = roles.contains(role.key);
                  return FilterChip(
                    label: Text(role.label),
                    selected: selected,
                    selectedColor: const Color(0xFFFFF1EA),
                    checkmarkColor: const Color(0xFFFF6B22),
                    onSelected: (value) => setSheetState(() {
                      if (value) {
                        roles.add(role.key);
                      } else {
                        roles.remove(role.key);
                      }
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B22),
                ),
                onPressed: () {
                  final label = labelController.text.trim();
                  if (label.isEmpty || roles.isEmpty) {
                    _showError(context, 'Enter a label and select at least one role.');
                    return;
                  }
                  Navigator.pop(
                    sheetContext,
                    DashboardTabConfig(
                      id: existing?.id ??
                          '${_fieldKey(label)}_${DateTime.now().millisecondsSinceEpoch}',
                      label: label,
                      destination: destination,
                      roles: roles.toList(),
                      isVisible: existing?.isVisible ?? true,
                      order: existing?.order ?? 0,
                    ),
                  );
                },
                child: const Text('Save Tab'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  labelController.dispose();
  return result;
}

Future<RoleDefinition?> _showRoleEditor(
  BuildContext context, {
  RoleDefinition? existing,
}) async {
  final labelController = TextEditingController(text: existing?.label ?? '');
  var baseRole = existing?.baseRole ?? 'CP';
  final result = await showModalBottomSheet<RoleDefinition>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              existing == null ? 'Create Role' : 'Edit Role',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: labelController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Role name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: baseRole,
              decoration: const InputDecoration(labelText: 'Base access level'),
              items: const [
                DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                DropdownMenuItem(value: 'Office Staff', child: Text('Office Staff')),
                DropdownMenuItem(value: 'Builder', child: Text('Builder')),
                DropdownMenuItem(value: 'CP', child: Text('CP')),
              ],
              onChanged: (value) => setSheetState(
                () => baseRole = value ?? baseRole,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B22),
              ),
              onPressed: () {
                final label = labelController.text.trim();
                if (label.isEmpty) {
                  _showError(context, 'Enter a role name.');
                  return;
                }
                Navigator.pop(
                  sheetContext,
                  RoleDefinition(
                    key: existing?.key ??
                        'role_${_fieldKey(label)}_${DateTime.now().millisecondsSinceEpoch}',
                    label: label,
                    baseRole: baseRole,
                    isSystem: false,
                  ),
                );
              },
              child: const Text('Save Role'),
            ),
          ],
        ),
      ),
    ),
  );
  labelController.dispose();
  return result;
}

Future<CustomFormConfig?> _showCustomFormEditor(
  BuildContext context, {
  CustomFormConfig? existing,
  required List<RoleDefinition> roleDefinitions,
}) async {
  final labelController = TextEditingController(text: existing?.label ?? '');
  final roles = {...(existing?.roles ?? const <String>['cp'])};
  final fields = List<DynamicLeadField>.from(existing?.fields ?? const []);
  var isVisible = existing?.isVisible ?? true;
  final result = await showModalBottomSheet<CustomFormConfig>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                existing == null ? 'Create Custom Form' : 'Edit Custom Form',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: labelController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Form name'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Visible to',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: roleDefinitions.map((role) {
                  final selected = roles.contains(role.key);
                  return FilterChip(
                    label: Text(role.label),
                    selected: selected,
                    selectedColor: const Color(0xFFFFF1EA),
                    checkmarkColor: const Color(0xFFFF6B22),
                    onSelected: (value) => setSheetState(() {
                      if (value) {
                        roles.add(role.key);
                      } else {
                        roles.remove(role.key);
                      }
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Form Fields',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final field = await _showFieldEditor(context);
                      if (field == null) return;
                      setSheetState(() => fields.add(field));
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Field'),
                  ),
                ],
              ),
              if (fields.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('Add at least one field.'),
                )
              else
                ...fields.asMap().entries.map(
                  (entry) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.value.label),
                    subtitle: Text(_fieldTypeLabel(entry.value.type)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit field',
                          onPressed: () async {
                            final updated = await _showFieldEditor(
                              context,
                              existing: entry.value,
                            );
                            if (updated == null) return;
                            setSheetState(() => fields[entry.key] = updated);
                          },
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Delete field',
                          onPressed: () => setSheetState(
                            () => fields.removeAt(entry.key),
                          ),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Visible tab'),
                value: isVisible,
                activeColor: const Color(0xFFFF6B22),
                onChanged: (value) => setSheetState(() => isVisible = value),
              ),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B22),
                ),
                onPressed: () {
                  final label = labelController.text.trim();
                  if (label.isEmpty || roles.isEmpty || fields.isEmpty) {
                    _showError(
                      context,
                      'Enter a form name, select roles, and add a field.',
                    );
                    return;
                  }
                  Navigator.pop(
                    sheetContext,
                    CustomFormConfig(
                      id: existing?.id ??
                          'form_${_fieldKey(label)}_${DateTime.now().millisecondsSinceEpoch}',
                      label: label,
                      roles: roles.toList(),
                      fields: fields,
                      isVisible: isVisible,
                      order: existing?.order ?? 0,
                    ),
                  );
                },
                child: const Text('Save Form'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  labelController.dispose();
  return result;
}

Future<void> _saveRoles(
  BuildContext context,
  List<RoleDefinition> roles,
) async {
  try {
    await context.read<AppConfigurationViewModel>().saveCustomRoles(roles);
  } catch (error) {
    if (!context.mounted) return;
    _showError(context, error);
  }
}

Future<void> _createCustomForm(
  BuildContext context,
  CustomFormConfig form,
) async {
  try {
    await context.read<AppConfigurationViewModel>().createCustomForm(form);
  } catch (error) {
    if (!context.mounted) return;
    _showError(context, error);
  }
}

Future<void> _updateCustomForm(
  BuildContext context,
  CustomFormConfig form,
) async {
  try {
    await context.read<AppConfigurationViewModel>().updateCustomForm(form);
  } catch (error) {
    if (!context.mounted) return;
    _showError(context, error);
  }
}

Future<void> _deleteCustomForm(BuildContext context, String formId) async {
  try {
    await context.read<AppConfigurationViewModel>().deleteCustomForm(formId);
  } catch (error) {
    if (!context.mounted) return;
    _showError(context, error);
  }
}

Future<void> _saveFields(
  BuildContext context,
  List<DynamicLeadField> fields,
) async {
  try {
    await context.read<AppConfigurationViewModel>().saveLeadFields(fields);
  } catch (error) {
    if (!context.mounted) return;
    _showError(context, error);
  }
}

Future<void> _saveTabs(
  BuildContext context,
  List<DashboardTabConfig> tabs,
) async {
  try {
    await context.read<AppConfigurationViewModel>().saveDashboardTabs(tabs);
  } catch (error) {
    if (!context.mounted) return;
    _showError(context, error);
  }
}

List<T> _replaceAt<T>(List<T> items, int index, T item) {
  final updated = List<T>.from(items);
  updated[index] = item;
  return updated;
}

List<T> _removeAt<T>(List<T> items, int index) {
  final updated = List<T>.from(items);
  updated.removeAt(index);
  return updated;
}

List<T> _moveItem<T>(List<T> items, int index, int direction) {
  final updated = List<T>.from(items);
  final item = updated.removeAt(index);
  updated.insert(index + direction, item);
  return updated;
}

void _showError(BuildContext context, Object error) {
  final message = error is StateError ? error.message.toString() : error.toString();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
  );
}

String _fieldKey(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

String _fieldTypeLabel(String type) {
  switch (type) {
    case 'multiline':
      return 'Long text';
    case 'number':
      return 'Number';
    case 'choice':
      return 'Choice list';
    default:
      return 'Text';
  }
}

String _destinationLabel(String destination) =>
    _tabDestinations[destination] ?? destination;

String _rolesLabel(List<String> roles, List<RoleDefinition> roleDefinitions) {
  return roleDefinitions
      .where((entry) => roles.contains(entry.key))
      .map((entry) => entry.label)
      .join(', ');
}

const _tabDestinations = <String, String>{
  'dashboard': 'Overview',
  'projects': 'Projects',
  'leads': 'Leads',
  'cp': 'Network',
  'monitoring': 'Monitoring',
  'admin': 'Admin Console',
};
