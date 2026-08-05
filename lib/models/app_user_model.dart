import '../utils/role_permissions.dart';

class AppUserModel {
  final String id;
  final String name;
  final String email;
  final String password;
  final String role;
  final String baseRole;
  final bool isActive;

  const AppUserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    required this.baseRole,
    required this.isActive,
  });

  AppRole get appRole {
    final directRole = parseAppRole(role);
    return directRole == AppRole.unknown ? parseAppRole(baseRole) : directRole;
  }
  bool get isSuperAdmin => parseAppRole(role) == AppRole.superAdmin;

  factory AppUserModel.fromMap(Map<String, dynamic> data, String id) {
    return AppUserModel(
      id: id,
      name: (data['name'] ?? data['fullName'] ?? '').toString().trim(),
      email: (data['email'] ?? '').toString().trim(),
      password: (data['password'] ?? '').toString(),
      role: (data['role'] ?? '').toString(),
      baseRole: (data['baseRole'] ?? '').toString(),
      isActive: data['isActive'] == true ||
          data['isActive']?.toString().toLowerCase() == 'true',
    );
  }
}
