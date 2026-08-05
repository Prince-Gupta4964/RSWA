import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/app_user_model.dart';
import '../utils/role_permissions.dart';

class UserManagementViewModel extends ChangeNotifier {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  List<AppUserModel> _users = const [];
  bool _isLoading = true;
  String? _error;

  List<AppUserModel> get users => _users;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<AppUserModel> get channelPartners =>
      _users.where((user) => user.appRole == AppRole.cp).toList();

  UserManagementViewModel() {
    _listenToUsers();
  }

  void _listenToUsers() {
    _db.collection('users').snapshots().listen(
      (snapshot) {
        _users = snapshot.docs
            .map((document) => AppUserModel.fromMap(document.data(), document.id))
            .toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object error) {
        _isLoading = false;
        _error = 'Unable to load users.';
        notifyListeners();
      },
    );
  }

  Future<void> saveUser({
    required AppRole actorRole,
    AppUserModel? existingUser,
    required String name,
    required String email,
    required String password,
    required String role,
    required String baseRole,
    required bool isActive,
  }) async {
    _ensureUserChangeAllowed(
      actorRole: actorRole,
      existingUser: existingUser,
      requestedRoleLabel: role,
    );

    final normalizedEmail = email.trim().toLowerCase();
    final matchingEmails = await _db
        .collection('users')
        .where('email', isEqualTo: normalizedEmail)
        .get();
    final anotherUserExists = matchingEmails.docs.any(
      (document) => document.id != existingUser?.id,
    );
    if (anotherUserExists) {
      throw StateError('A user with this email already exists.');
    }

    final payload = <String, dynamic>{
      'name': name.trim(),
      'email': normalizedEmail,
      'password': password,
      'role': role,
      'baseRole': baseRole,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (existingUser == null) {
      payload['createdAt'] = FieldValue.serverTimestamp();
      await _db.collection('users').add(payload);
    } else {
      await _db.collection('users').doc(existingUser.id).update(payload);
    }
  }

  Future<void> setUserActive({
    required AppRole actorRole,
    required AppUserModel user,
    required bool isActive,
  }) async {
    _ensureUserChangeAllowed(
      actorRole: actorRole,
      existingUser: user,
      requestedRoleLabel: user.role,
    );
    await _db.collection('users').doc(user.id).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _ensureUserChangeAllowed({
    required AppRole actorRole,
    required AppUserModel? existingUser,
    required String requestedRoleLabel,
  }) {
    final isSuperAdmin = actorRole == AppRole.superAdmin;
    final isAdmin = actorRole == AppRole.admin;
    if (!isSuperAdmin && !isAdmin) {
      throw StateError('You do not have permission to manage users.');
    }
    if (isAdmin &&
        (parseAppRole(requestedRoleLabel) == AppRole.superAdmin ||
            existingUser?.appRole == AppRole.superAdmin)) {
      throw StateError('Only a Super Admin can manage Super Admin accounts.');
    }
    if (requestedRoleLabel.trim().isEmpty) {
      throw StateError('Select a valid role.');
    }
  }
}
