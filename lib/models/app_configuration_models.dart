import '../utils/role_permissions.dart';

class DynamicLeadField {
  final String id;
  final String label;
  final String type;
  final List<String> options;
  final List<String> roles; // <-- NAYA: Kis role ko dikhega
  final bool isRequired;
  final bool isVisible;
  final int order;

  const DynamicLeadField({
    required this.id,
    required this.label,
    required this.type,
    required this.options,
    required this.roles,
    required this.isRequired,
    required this.isVisible,
    required this.order,
  });

  factory DynamicLeadField.fromMap(Map<String, dynamic> data) {
    return DynamicLeadField(
      id: (data['id'] ?? '').toString(),
      label: (data['label'] ?? 'Untitled field').toString(),
      type: (data['type'] ?? 'text').toString(),
      options: (data['options'] as List<dynamic>? ?? const [])
          .map((option) => option.toString())
          .where((option) => option.trim().isNotEmpty)
          .toList(),
      roles: (data['roles'] as List<dynamic>? ?? const ['all'])
          .map((role) => role.toString())
          .toList(),
      isRequired: data['isRequired'] == true,
      isVisible: data['isVisible'] != false,
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap({int? order}) => {
    'id': id,
    'label': label,
    'type': type,
    'options': options,
    'roles': roles,
    'isRequired': isRequired,
    'isVisible': isVisible,
    'order': order ?? this.order,
  };

  DynamicLeadField copyWith({
    String? id,
    String? label,
    String? type,
    List<String>? options,
    List<String>? roles,
    bool? isRequired,
    bool? isVisible,
    int? order,
  }) {
    return DynamicLeadField(
      id: id ?? this.id,
      label: label ?? this.label,
      type: type ?? this.type,
      options: options ?? this.options,
      roles: roles ?? this.roles,
      isRequired: isRequired ?? this.isRequired,
      isVisible: isVisible ?? this.isVisible,
      order: order ?? this.order,
    );
  }
}

class DashboardTabConfig {
  final String id;
  final String label;
  final String destination;
  final List<String> roles;
  final bool isVisible;
  final int order;

  const DashboardTabConfig({
    required this.id,
    required this.label,
    required this.destination,
    required this.roles,
    required this.isVisible,
    required this.order,
  });

  bool isVisibleFor(AppRole role) {
    final roleKey = appRoleKey(role);
    return isVisibleForRoleKey(roleKey);
  }

  bool isVisibleForRoleKey(String roleKey) {
    return isVisible && (roles.contains('all') || roles.contains(roleKey));
  }

  factory DashboardTabConfig.fromMap(Map<String, dynamic> data) {
    return DashboardTabConfig(
      id: (data['id'] ?? '').toString(),
      label: (data['label'] ?? 'Untitled').toString(),
      destination: (data['destination'] ?? 'dashboard').toString(),
      roles: (data['roles'] as List<dynamic>? ?? const ['all'])
          .map((role) => role.toString())
          .toList(),
      isVisible: data['isVisible'] != false,
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap({int? order}) => {
    'id': id,
    'label': label,
    'destination': destination,
    'roles': roles,
    'isVisible': isVisible,
    'order': order ?? this.order,
  };

  DashboardTabConfig copyWith({
    String? id,
    String? label,
    String? destination,
    List<String>? roles,
    bool? isVisible,
    int? order,
  }) {
    return DashboardTabConfig(
      id: id ?? this.id,
      label: label ?? this.label,
      destination: destination ?? this.destination,
      roles: roles ?? this.roles,
      isVisible: isVisible ?? this.isVisible,
      order: order ?? this.order,
    );
  }
}

class RoleDefinition {
  final String key;
  final String label;
  final String baseRole;
  final bool isSystem;

  const RoleDefinition({
    required this.key,
    required this.label,
    required this.baseRole,
    required this.isSystem,
  });

  factory RoleDefinition.fromMap(Map<String, dynamic> data) {
    return RoleDefinition(
      key: (data['key'] ?? '').toString(),
      label: (data['label'] ?? 'Untitled role').toString(),
      baseRole: (data['baseRole'] ?? 'CP').toString(),
      isSystem: false,
    );
  }

  Map<String, dynamic> toMap() => {
    'key': key,
    'label': label,
    'baseRole': baseRole,
  };
}

class CustomFormConfig {
  final String id;
  final String label;
  final List<String> roles;
  final List<DynamicLeadField> fields;
  final bool isVisible;
  final int order;

  const CustomFormConfig({
    required this.id,
    required this.label,
    required this.roles,
    required this.fields,
    required this.isVisible,
    required this.order,
  });

  factory CustomFormConfig.fromMap(Map<String, dynamic> data) {
    final rawFields = data['fields'] as List<dynamic>? ?? const [];
    return CustomFormConfig(
      id: (data['id'] ?? '').toString(),
      label: (data['label'] ?? 'Untitled form').toString(),
      roles: (data['roles'] as List<dynamic>? ?? const [])
          .map((role) => role.toString())
          .toList(),
      fields: rawFields
          .whereType<Map>()
          .map(
            (field) => DynamicLeadField.fromMap(
              field.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(),
      isVisible: data['isVisible'] != false,
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap({int? order}) => {
    'id': id,
    'label': label,
    'roles': roles,
    'fields': [
      for (var index = 0; index < fields.length; index++)
        fields[index].toMap(order: index),
    ],
    'isVisible': isVisible,
    'order': order ?? this.order,
  };

  CustomFormConfig copyWith({
    String? label,
    List<String>? roles,
    List<DynamicLeadField>? fields,
    bool? isVisible,
    int? order,
  }) {
    return CustomFormConfig(
      id: id,
      label: label ?? this.label,
      roles: roles ?? this.roles,
      fields: fields ?? this.fields,
      isVisible: isVisible ?? this.isVisible,
      order: order ?? this.order,
    );
  }
}
