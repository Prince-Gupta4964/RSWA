import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../models/app_configuration_models.dart';
import '../utils/role_permissions.dart';

class AppConfigurationViewModel extends ChangeNotifier {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  List<DynamicLeadField> _leadFields = const [];
  List<DashboardTabConfig> _dashboardTabs = _defaultTabs;
  List<RoleDefinition> _customRoles = const [];
  List<CustomFormConfig> _customForms = const [];
  List<String> _leadStatuses = const ['Paid', 'Book', 'Hot', 'Warm', 'Cold', 'Think', 'Hold', 'Out'];
  Map<String, Map<String, List<String>>> _fieldOptions = {};
  bool _isLoading = true;

  // 🚀 NAYA: Search Trigger logic
  String? _activeSearchTab;
  int _searchTriggerCount = 0;
  String? get activeSearchTab => _activeSearchTab;
  int get searchTriggerCount => _searchTriggerCount;

  // 🚀 NAYA: Filter Trigger logic
  int _leadFilterTriggerCount = 0;
  int get leadFilterTriggerCount => _leadFilterTriggerCount;

  void triggerLeadFilter() {
    _leadFilterTriggerCount++;
    notifyListeners();
  }

  int _projectFilterTriggerCount = 0;
  int get projectFilterTriggerCount => _projectFilterTriggerCount;

  void triggerProjectFilter() {
    _projectFilterTriggerCount++;
    notifyListeners();
  }

  // Manual timer to ensure NO DELAY on single tap
  DateTime? _lastTapTime;
  String? _lastTappedTab;

  void handleFastTap(String tabKey, VoidCallback originalOnTap) {
    final now = DateTime.now();
    
    // Check if this was a fast second tap for search
    if (_lastTappedTab == tabKey && 
        _lastTapTime != null && 
        now.difference(_lastTapTime!) < const Duration(milliseconds: 500)) {
      _activeSearchTab = tabKey;
      _searchTriggerCount++;
      _lastTapTime = null; // Reset
      notifyListeners();
    } else {
      // 1. Trigger the tab switch IMMEDIATELY (No delay)
      originalOnTap();
      _lastTapTime = now;
      _lastTappedTab = tabKey;
    }
  }

  void triggerSearch(String tab) {
    _activeSearchTab = tab;
    _searchTriggerCount++;
    notifyListeners();
  }

  List<DynamicLeadField> get leadFields {
    final List<DynamicLeadField> fields = _leadFields.where((field) => field.isVisible).toList();
    fields.sort((a, b) => a.order.compareTo(b.order));
    return fields;
  }
  List<DynamicLeadField> get allLeadFields => List.unmodifiable(_leadFields);
  List<DashboardTabConfig> get dashboardTabs => List.unmodifiable(_dashboardTabs);
  List<String> get leadStatuses => List.unmodifiable(_leadStatuses);
  List<RoleDefinition> get roleDefinitions => [
    ..._systemRoles,
    ..._customRoles,
  ];
  List<CustomFormConfig> get customForms => List.unmodifiable(_customForms);
  Map<String, Map<String, List<String>>> get fieldOptions => _fieldOptions;
  bool get isLoading => _isLoading;

  AppConfigurationViewModel() {
    _listenToLeadFields();
    _listenToTabs();
    _listenToRoles();
    _listenToCustomForms();
    _listenToStatuses();
    _listenToFieldOptions();
  }

  List<DashboardTabConfig> tabsForRole(AppRole role) {
    return tabsForRoleKey(appRoleKey(role));
  }

  List<DashboardTabConfig> tabsForUserRole(String roleLabel) {
    return tabsForRoleKey(roleKeyForLabel(roleLabel));
  }

  List<DashboardTabConfig> tabsForRoleKey(String roleKey) {
    final List<DashboardTabConfig> tabs = _dashboardTabs
        .where((tab) => tab.isVisibleForRoleKey(roleKey))
        .toList();
    tabs.sort((a, b) => a.order.compareTo(b.order));
    return tabs;
  }

  String roleKeyForLabel(String roleLabel) {
    final normalized = roleLabel.trim().toLowerCase();
    for (final role in roleDefinitions) {
      if (role.label.trim().toLowerCase() == normalized) return role.key;
    }
    final systemRole = parseAppRole(roleLabel);
    return appRoleKey(systemRole);
  }

  RoleDefinition? roleForLabel(String roleLabel) {
    final normalized = roleLabel.trim().toLowerCase();
    for (final role in roleDefinitions) {
      if (role.label.trim().toLowerCase() == normalized) return role;
    }
    return null;
  }

  CustomFormConfig? customFormById(String id) {
    for (final form in _customForms) {
      if (form.id == id) return form;
    }
    return null;
  }

  void _listenToLeadFields() {
    _db.collection('app_config').doc('lead_form').snapshots().listen((snapshot) {
      final rawFields = snapshot.data()?['fields'] as List<dynamic>?;
      if (rawFields == null) {
        _leadFields = const [];
      } else {
        final List<DynamicLeadField> fields = rawFields
            .whereType<Map>()
            .map(
              (field) => DynamicLeadField.fromMap(
                field.map((key, value) => MapEntry(key.toString(), value)),
              ),
            )
            .toList();
        fields.sort((a, b) => a.order.compareTo(b.order));
        _leadFields = fields;
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  void _listenToTabs() {
    _db.collection('app_config').doc('dashboard_tabs').snapshots().listen((snapshot) {
      final rawTabs = snapshot.data()?['tabs'] as List<dynamic>?;
      if (rawTabs == null) {
        _dashboardTabs = _defaultTabs;
      } else {
        final List<DashboardTabConfig> tabs = rawTabs
            .whereType<Map>()
            .map(
              (tab) => DashboardTabConfig.fromMap(
                tab.map((key, value) => MapEntry(key.toString(), value)),
              ),
            )
            .toList();
        tabs.sort((a, b) => a.order.compareTo(b.order));
        _dashboardTabs = tabs;
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  void _listenToRoles() {
    _db.collection('app_config').doc('roles').snapshots().listen((snapshot) {
      final rawRoles = snapshot.data()?['roles'] as List<dynamic>?;
      _customRoles = rawRoles == null
          ? const []
          : rawRoles
              .whereType<Map>()
              .map(
                (role) => RoleDefinition.fromMap(
                  role.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .where((role) => role.key.isNotEmpty && role.label.isNotEmpty)
              .toList();
      notifyListeners();
    });
  }

  void _listenToCustomForms() {
    _db.collection('app_config').doc('custom_forms').snapshots().listen((snapshot) {
      final rawForms = snapshot.data()?['forms'] as List<dynamic>?;
      if (rawForms == null) {
        _customForms = const [];
      } else {
        final List<CustomFormConfig> forms = rawForms
            .whereType<Map>()
            .map(
              (form) => CustomFormConfig.fromMap(
                form.map((key, value) => MapEntry(key.toString(), value)),
              ),
            )
            .toList();
        forms.sort((a, b) => a.order.compareTo(b.order));
        _customForms = forms;
      }
      notifyListeners();
    });
  }

  void _listenToStatuses() {
    _db.collection('app_config').doc('lead_statuses').snapshots().listen((snapshot) {
      final data = snapshot.data();
      if (data != null && data['statuses'] is List) {
        _leadStatuses = List<String>.from(data['statuses']);
        notifyListeners();
      } else if (!snapshot.exists) {
        // Initialize with defaults if not exists
        saveLeadStatuses(['Paid', 'Book', 'Hot', 'Warm', 'Cold', 'Think', 'Hold', 'Out']);
      }
    });
  }

  void _listenToFieldOptions() {
    _db.collection('app_config').doc('field_options').snapshots().listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        final Map<String, Map<String, List<String>>> parsed = {};
        data.forEach((formKey, fields) {
          if (fields is Map) {
            final Map<String, List<String>> fieldMap = {};
            fields.forEach((fieldId, options) {
              if (options is List) {
                fieldMap[fieldId.toString()] = List<String>.from(options);
              }
            });
            parsed[formKey.toString()] = fieldMap;
          }
        });
        _fieldOptions = parsed;
        notifyListeners();
      }
    });
  }

  List<String> getOptionsForField(String formName, String fieldId, List<String> defaultOptions) {
    if (_fieldOptions.containsKey(formName) && _fieldOptions[formName]!.containsKey(fieldId)) {
      final custom = _fieldOptions[formName]![fieldId]!;
      if (custom.isNotEmpty) return custom;
    }
    return defaultOptions;
  }

  Future<void> saveFieldOptions(Map<String, Map<String, List<String>>> options) async {
    await _db.collection('app_config').doc('field_options').set(
      options,
      SetOptions(merge: true),
    );
  }

  Future<void> saveLeadStatuses(List<String> statuses) async {
    await _db.collection('app_config').doc('lead_statuses').set({
      'statuses': statuses,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveLeadFields(List<DynamicLeadField> fields) async {
    final orderedFields = [
      for (var index = 0; index < fields.length; index++)
        fields[index].toMap(order: index),
    ];
    await _db.collection('app_config').doc('lead_form').set({
      'fields': orderedFields,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveDashboardTabs(List<DashboardTabConfig> tabs) async {
    final orderedTabs = [
      for (var index = 0; index < tabs.length; index++)
        tabs[index].toMap(order: index),
    ];
    await _db.collection('app_config').doc('dashboard_tabs').set({
      'tabs': orderedTabs,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveCustomRoles(List<RoleDefinition> roles) async {
    await _db.collection('app_config').doc('roles').set({
      'roles': roles.where((role) => !role.isSystem).map((role) => role.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveCustomForms(List<CustomFormConfig> forms) async {
    await _db.collection('app_config').doc('custom_forms').set({
      'forms': [
        for (var index = 0; index < forms.length; index++)
          forms[index].toMap(order: index),
      ],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> createCustomForm(CustomFormConfig form) async {
    final formWithOrder = form.copyWith(order: _customForms.length);
    final tab = DashboardTabConfig(
      id: 'form_${form.id}',
      label: form.label,
      destination: 'form:${form.id}',
      roles: form.roles,
      isVisible: form.isVisible,
      order: _dashboardTabs.length,
    );
    final batch = _db.batch();
    batch.set(_db.collection('app_config').doc('custom_forms'), {
      'forms': [
        ..._customForms.map((item) => item.toMap()),
        formWithOrder.toMap(order: _customForms.length),
      ],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_db.collection('app_config').doc('dashboard_tabs'), {
      'tabs': [
        ..._dashboardTabs.map((item) => item.toMap()),
        tab.toMap(order: _dashboardTabs.length),
      ],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> updateCustomForm(CustomFormConfig form) async {
    final updatedForms = _customForms
        .map((item) => item.id == form.id ? form : item)
        .toList();
    final updatedTabs = _dashboardTabs
        .map(
          (tab) => tab.destination == 'form:${form.id}'
              ? tab.copyWith(
                  label: form.label,
                  roles: form.roles,
                  isVisible: form.isVisible,
                )
              : tab,
        )
        .toList();
    final batch = _db.batch();
    batch.set(_db.collection('app_config').doc('custom_forms'), {
      'forms': [
        for (var index = 0; index < updatedForms.length; index++)
          updatedForms[index].toMap(order: index),
      ],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_db.collection('app_config').doc('dashboard_tabs'), {
      'tabs': [
        for (var index = 0; index < updatedTabs.length; index++)
          updatedTabs[index].toMap(order: index),
      ],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> deleteCustomForm(String formId) async {
    final batch = _db.batch();
    batch.set(_db.collection('app_config').doc('custom_forms'), {
      'forms': _customForms
          .where((form) => form.id != formId)
          .map((form) => form.toMap())
          .toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_db.collection('app_config').doc('dashboard_tabs'), {
      'tabs': _dashboardTabs
          .where((tab) => tab.destination != 'form:$formId')
          .map((tab) => tab.toMap())
          .toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }
}

const _systemRoles = <RoleDefinition>[
  RoleDefinition(
    key: 'super_admin',
    label: 'Super Admin',
    baseRole: 'Super Admin',
    isSystem: true,
  ),
  RoleDefinition(key: 'admin', label: 'Admin', baseRole: 'Admin', isSystem: true),
  RoleDefinition(
    key: 'office_staff',
    label: 'Office Staff',
    baseRole: 'Office Staff',
    isSystem: true,
  ),
  RoleDefinition(
    key: 'builder',
    label: 'Builder',
    baseRole: 'Builder',
    isSystem: true,
  ),
  RoleDefinition(key: 'cp', label: 'CP', baseRole: 'CP', isSystem: true),
];

const _allRoles = <String>[
  'super_admin',
  'admin',
  'office_staff',
  'builder',
  'cp',
];

const _defaultTabs = <DashboardTabConfig>[
  DashboardTabConfig(
    id: 'my_leads',
    label: 'My leads',
    destination: 'dashboard',
    roles: _allRoles,
    isVisible: true,
    order: 0,
  ),
  DashboardTabConfig(
    id: 'flats_leads',
    label: 'Flats leads',
    destination: 'dashboard',
    roles: _allRoles,
    isVisible: true,
    order: 1,
  ),
  DashboardTabConfig(
    id: 'bunglow_leads',
    label: 'Bunglow lead',
    destination: 'dashboard',
    roles: _allRoles,
    isVisible: true,
    order: 2,
  ),
  DashboardTabConfig(
    id: 'plot_leads',
    label: 'Plot leads',
    destination: 'dashboard',
    roles: _allRoles,
    isVisible: true,
    order: 3,
  ),
  DashboardTabConfig(
    id: 'builders',
    label: 'Builders',
    destination: 'builders',
    roles: _allRoles,
    isVisible: true,
    order: 4,
  ),
  DashboardTabConfig(
    id: 'cp',
    label: 'Network',
    destination: 'cp',
    roles: <String>['super_admin', 'admin', 'office_staff'],
    isVisible: true,
    order: 5,
  ),
  DashboardTabConfig(
    id: 'monitoring',
    label: 'Monitoring',
    destination: 'monitoring',
    roles: <String>['super_admin', 'admin', 'office_staff'],
    isVisible: true,
    order: 6,
  ),
  DashboardTabConfig(
    id: 'admin',
    label: 'Admin',
    destination: 'admin',
    roles: <String>['super_admin', 'admin'],
    isVisible: true,
    order: 7,
  ),
];
