import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/storage_helper.dart';
import '../utils/role_permissions.dart';

class AuthViewModel extends ChangeNotifier {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  final _googleSignIn = GoogleSignIn.instance;

  String? _userId;
  String? _userRole;
  AppRole _permissionRole = AppRole.unknown;
  Map<String, dynamic>? _userData;
  bool _isCheckingSession = true;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSubscription;
  String? _subscribedUserId;

  String? get userId => _userId;
  String? get userRole => _userRole;
  Map<String, dynamic>? get userData => _userData;
  bool get isCheckingSession => _isCheckingSession;
  bool get isAuthenticated => _userId != null && _userData != null;
  AppRole get appRole => _permissionRole;
  AppPermissions get permissions => AppPermissions.forRole(appRole);
  String get roleLabel => _userRole?.trim().isNotEmpty == true
      ? _userRole!.trim()
      : appRoleLabel(appRole);
  String get userEmail => (_userData?['email'] ?? '').toString().trim();
  String get userUid => _userId ?? '';
  String get userName {
    final name =
        (_userData?['name'] ??
                _userData?['fullName'] ??
                _userData?['displayName'] ??
                '')
            .toString()
            .trim();
    return name.isEmpty ? userUid : name;
  }

  bool get canSeeAllLeads => permissions.canSeeAllLeads;
  bool get canSeeAllProjects => permissions.canSeeAllProjects;
  bool get canSeeMonitoring => permissions.canSeeMonitoring;
  bool get canManageUsers => permissions.canManageUsers;
  bool get canConfigureForms => permissions.canConfigureForms;
  bool get canConfigureTabs => permissions.canConfigureTabs;

  Map<String, dynamic> get actorMetadata => {
    'uid': userUid,
    'email': userEmail,
    'name': userName,
    'role': roleLabel,
  };

  AuthViewModel() {
    // Listen for users from programmatic flow (Mobile) or renderButton (Web)
    _googleSignIn.authenticationEvents.listen((event) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        debugPrint('AUTH: Google Sign-In Event detected for ${event.user.email}');
        _handleGoogleUserChanged(event.user);
      }
    });

    // On Web, the Google SDK handles auto-sign-in via the rendered button or FedCM
    
    _restoreSession();
  }

  Future<void> _handleGoogleUserChanged(GoogleSignInAccount googleUser) async {
    try {
      final email = googleUser.email.trim().toLowerCase();
      var userDoc = await _findUserByEmail(email, email);
      if (userDoc == null) {
        _clearSessionData();
        notifyListeners();
        return;
      }

      final validationError = _applyUserDocument(userDoc, skipPassword: true);
      if (validationError != null) {
        notifyListeners();
        return;
      }

      await _updateLastLogin(userDoc);
      await StorageHelper.saveSession(_userId!);
      _listenToCurrentUser(_userId!);
      notifyListeners();
    } catch (e) {
      debugPrint('Error handling Google user change: $e');
    }
  }

  Future<void> _restoreSession() async {
    _isCheckingSession = true;
    notifyListeners(); 
    
    try {
      debugPrint('AUTH: Starting session restoration...');
      final savedUserId = await StorageHelper.getSession();

      if (savedUserId != null && savedUserId.trim().isNotEmpty) {
        debugPrint('AUTH: Found saved UID in storage: $savedUserId');
        final success = await _loadUserById(
          savedUserId.trim(),
          updateLoginAudit: false,
        );
        
        if (!success) {
          debugPrint('AUTH: Failed to load user from Firestore. Session might be invalid.');
          // Don't clear immediately on network error, but if doc is missing, clear.
          // await StorageHelper.clearSession(); 
        } else {
          debugPrint('AUTH: Session restored successfully for $userName');
        }
      } else {
        debugPrint('AUTH: No saved UID found in storage.');
        _clearSessionData();
      }
    } catch (e) {
      debugPrint('AUTH ERROR (Restore Session): $e');
    } finally {
      _isCheckingSession = false;
      notifyListeners();
    }
  }

  Future<String?> signInWithEmailAndPassword(
    String rawEmail,
    String rawPassword,
  ) async {
    final email = rawEmail.trim().toLowerCase();
    if (email.isEmpty || rawPassword.isEmpty) {
      return 'Please enter your email and password.';
    }

    _isCheckingSession = true;
    notifyListeners();
    try {
      final userDoc = await _findUserByEmail(rawEmail, email);
      if (userDoc == null) {
        _clearSessionData();
        return 'No account is registered with this email.';
      }

      final validationError = _applyUserDocument(
        userDoc,
        password: rawPassword,
      );
      if (validationError != null) return validationError;

      await _updateLastLogin(userDoc);
      await StorageHelper.saveSession(_userId!);
      _listenToCurrentUser(_userId!);
      return null;
    } on FirebaseException catch (error) {
      _clearSessionData();
      return 'Login failed: ${error.message}';
    } catch (e) {
      _clearSessionData();
      return 'Login Failed: $e';
    } finally {
      _isCheckingSession = false;
      notifyListeners();
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findUserByEmail(
    String rawEmail,
    String normalizedEmail,
  ) async {
    final candidateIds = <String>{
      rawEmail.trim(),
      normalizedEmail,
    }..removeWhere((value) => value.isEmpty);

    for (final documentId in candidateIds) {
      try {
        final userDoc = await _firestore.collection('users').doc(documentId).get();
        if (userDoc.exists) return userDoc;
      } catch (_) {}
    }

    final normalizedQuery = await _firestore
        .collection('users')
        .where('email', isEqualTo: normalizedEmail)
        .limit(1)
        .get();
    if (normalizedQuery.docs.isNotEmpty) return normalizedQuery.docs.first;

    final cpQuery = await _firestore
        .collection('cps')
        .where('email', isEqualTo: normalizedEmail)
        .limit(1)
        .get();
    if (cpQuery.docs.isNotEmpty) return cpQuery.docs.first;

    return null;
  }

  Future<String?> signInWithGoogle() async {
    _isCheckingSession = true;
    notifyListeners();
    try {
      // 🚀 FIXED: In 7.x GIS SDK, programmatic popups require authenticate()
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      final email = googleUser.email.trim().toLowerCase();
      
      var userDoc = await _findUserByEmail(email, email);
      if (userDoc == null) {
        _clearSessionData();
        return 'Your Google account ($email) is not registered.';
      }

      final validationError = _applyUserDocument(userDoc, skipPassword: true);
      if (validationError != null) return validationError;

      await _updateLastLogin(userDoc);
      await StorageHelper.saveSession(_userId!);
      _listenToCurrentUser(_userId!);
      return null;
    } catch (e) {
      debugPrint('GOOGLE LOGIN ERROR: $e');
      if (e.toString().contains('canceled')) {
         _isCheckingSession = false;
         notifyListeners();
         return 'Google Sign-In was cancelled.';
      }
      return 'Google Login Failed: $e';
    } finally {
      _isCheckingSession = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _userSubscription?.cancel();
    _userSubscription = null;
    _subscribedUserId = null;
    await StorageHelper.clearSession();
    _clearSessionData();
    _isCheckingSession = false;
    notifyListeners();
  }

  Future<bool> _loadUserById(
    String requestedUserId, {
    required bool updateLoginAudit,
  }) async {
    final userDoc = await _firestore.collection('users').doc(requestedUserId).get();
    if (!userDoc.exists) {
        final cpDoc = await _firestore.collection('cps').doc(requestedUserId).get();
        if (cpDoc.exists) {
             final validationError = _applyUserDocument(cpDoc);
             if (validationError != null) return false;
             if (updateLoginAudit) await _updateLastLogin(cpDoc);
             _listenToCurrentUser(cpDoc.id);
             return true;
        }
        return false;
    }
    final validationError = _applyUserDocument(userDoc);
    if (validationError != null) return false;
    if (updateLoginAudit) await _updateLastLogin(userDoc);
    _listenToCurrentUser(userDoc.id);
    return true;
  }

  void _listenToCurrentUser(String userId) {
    if (_subscribedUserId == userId) return;
    _userSubscription?.cancel();
    _subscribedUserId = userId;
    
    String collection = 'users';
    if (_userData?['collection'] == 'cps') {
      collection = 'cps';
    }

    _userSubscription = _firestore.collection(collection).doc(userId).snapshots().listen(
      (snapshot) async {
        final validationError = _applyUserDocument(snapshot);
        if (validationError != null) {
          await _userSubscription?.cancel();
          _userSubscription = null;
          await StorageHelper.clearSession();
          _subscribedUserId = null;
        }
        notifyListeners();
      },
      onError: (_) {},
    );
  }

  String? _applyUserDocument(
    DocumentSnapshot<Map<String, dynamic>> userDoc, {
    String? password,
    bool skipPassword = false,
  }) {
    if (!userDoc.exists || userDoc.data() == null) {
      _clearSessionData();
      return 'Account not found.';
    }

    final data = userDoc.data()!;
    final isActive = data['isActive'] == true ||
        data['isActive']?.toString().toLowerCase() == 'true' ||
        data['status']?.toString().toLowerCase() == 'active';
    
    if (!isActive) {
      _clearSessionData();
      return 'Account inactive.';
    }

    String storedRole = (data['role'] ?? '').toString().trim();
    final isFromCPS = userDoc.reference.path.startsWith('cps/');
    if (isFromCPS && storedRole.isEmpty) storedRole = 'cp';

    final directRole = parseAppRole(storedRole);
    final permissionRole = directRole == AppRole.unknown
        ? parseAppRole(data['baseRole']?.toString())
        : directRole;
    
    if (permissionRole == AppRole.unknown || storedRole.isEmpty) {
      _clearSessionData();
      return 'Invalid role.';
    }

    if (!skipPassword && password != null && data['password']?.toString() != password) {
      _clearSessionData();
      return 'Incorrect credentials.';
    }

    _userId = userDoc.id;
    _userData = {...data, 'id': userDoc.id, 'collection': isFromCPS ? 'cps' : 'users'};
    _userRole = storedRole;
    _permissionRole = permissionRole;
    return null;
  }

  Future<void> _updateLastLogin(DocumentSnapshot<Map<String, dynamic>> userDoc) async {
    try {
      await userDoc.reference.update({ 'lastLogin': FieldValue.serverTimestamp() });
    } catch (_) {}
  }

  void _clearSessionData() {
    _userId = null;
    _userRole = null;
    _permissionRole = AppRole.unknown;
    _userData = null;
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }
}
