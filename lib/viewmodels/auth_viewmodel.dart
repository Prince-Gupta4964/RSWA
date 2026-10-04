
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/storage_helper.dart';
import '../utils/role_permissions.dart';

class AuthViewModel extends ChangeNotifier {
  // Accessing instances directly
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  final _googleSignIn = GoogleSignIn.instance;

  String? _userId;
  String? _userRole;
  AppRole _permissionRole = AppRole.unknown;
  Map<String, dynamic>? _userData;
  bool _isCheckingSession = true;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSubscription;
  String? _subscribedUserId;
  String? _currentReferralCode; // 🚀 NAYA: Global tracking for Web Google login
  String? _signupMode; // 🚀 NAYA
  GoogleSignInAccount? _lastGoogleUser;

  String? get userId => _userId;
  String? get userRole => _userRole;
  GoogleSignInAccount? get lastGoogleUser => _lastGoogleUser;
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

  bool _allowNotifications = true;
  bool get allowNotifications => _allowNotifications;

  Future<void> setAllowNotifications(bool value) async {
    _allowNotifications = value;
    if (_userId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('allow_notifications_$_userId', value);
    }
    notifyListeners();
  }

  // 🚀 NAYA: Status getters for CPs
  bool get isApproved {
    if (_permissionRole == AppRole.cp) {
      final bool isPendingStatus = _userData?['cpUpgradeRequested'] == true ||
          _userData?['upgradeStatus']?.toString().toLowerCase() == 'waiting for approval' ||
          _userData?['status']?.toString().toLowerCase() == 'pending' ||
          _userData?['isApproved'] == false ||
          _userData?['isApproved']?.toString().toLowerCase() == 'false' ||
          _userData?['isApproved'] == null;
      
      if (isPendingStatus) return false;

      final val = _userData?['isApproved'];
      return val == true || val?.toString().toLowerCase() == 'true';
    }
    return true;
  }
  bool get isProfileComplete => _userData?['isProfileComplete'] == true || _permissionRole != AppRole.cp;

  bool get canAddProjects => permissions.canAddProjects && isApproved;
  bool get canAddLeads => permissions.canAddLeads && isApproved;

  Map<String, dynamic> get actorMetadata => {
    'uid': userUid,
    'email': userEmail,
    'name': userName,
    'role': roleLabel,
  };

  Future<void> updateReferralCode(String? code) async {
    _currentReferralCode = code;
    if (code != null && code.trim().isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rswa_pending_referral_code', code.trim());
    }
    notifyListeners();
  }

  AuthViewModel() {
    // 🚀 NAYA: Extract referral code from URL / hash fragment on startup (for Web OAuth redirects)
    try {
      String? ref = Uri.base.queryParameters['ref'];
      if (ref == null || ref.isEmpty) {
        final fragment = Uri.base.fragment;
        if (fragment.contains('?')) {
          final queryString = fragment.split('?').last;
          final uriQuery = Uri.splitQueryString(queryString);
          if (uriQuery.containsKey('ref') && uriQuery['ref'] != null) {
            ref = uriQuery['ref'];
          }
        }
      }
      if (ref != null && ref.trim().isNotEmpty) {
        _currentReferralCode = ref.trim();
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString('rswa_pending_referral_code', ref!.trim());
        });
        debugPrint('AUTH: Extracted and saved referral code from URL: $ref');
      }
    } catch (e) {
      debugPrint('AUTH: Error extracting referral code on startup: $e');
    }

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
    _lastGoogleUser = googleUser;
    try {
      final email = googleUser.email.trim().toLowerCase();
      var userDoc = await _findUserByEmail(email, email);
      
      // 🚀 NAYA: If user doesn't exist, automatically register them using current referral code
      if (userDoc == null) {
        String? activeRefCode = _currentReferralCode;
        if (activeRefCode == null || activeRefCode.isEmpty) {
          final prefs = await SharedPreferences.getInstance();
          activeRefCode = prefs.getString('rswa_pending_referral_code');
        }

        await _registerNewCP(email, googleUser.displayName, activeRefCode);
        userDoc = await _findUserByEmail(email, email);

        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('rswa_pending_referral_code');
      }

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

  Future<void> _registerNewCP(String email, String? displayName, String? referralCode) async {
    String? referrerUid;
    String referrerName = "Self Signup";
    String ref2Name = "";
    String ref3Name = "";

    // 🚀 NAYA: Robust multi-level lookup for Referrer across cps & users (matching last 10 digits)
    if (referralCode != null && referralCode.trim().isNotEmpty) {
      final String cleanCode = referralCode.trim().replaceAll(RegExp(r'\D'), '');
      final last10 = cleanCode.length >= 10 ? cleanCode.substring(cleanCode.length - 10) : cleanCode;

      DocumentSnapshot<Map<String, dynamic>>? foundReferrerDoc;

      for (var col in ['cps', 'users', 'customers']) {
        try {
          final query = await _firestore.collection(col).get();
          for (var doc in query.docs) {
            final data = doc.data();
            final rCode = (data['referralCode'] ?? '').toString().trim();
            final cNo = (data['contactNo'] ?? data['whatsappNo'] ?? '').toString().trim().replaceAll(RegExp(r'\D'), '');
            if (rCode == cleanCode || rCode == referralCode.trim() || (cNo.isNotEmpty && (cNo == cleanCode || cNo.endsWith(last10)))) {
              foundReferrerDoc = doc;
              break;
            }
          }
          if (foundReferrerDoc != null) break;
        } catch (e) {
          debugPrint('AUTH: Referrer lookup error in $col: $e');
        }
      }

      if (foundReferrerDoc != null) {
        final referrerData = foundReferrerDoc.data()!;
        referrerUid = foundReferrerDoc.id;
        referrerName = referrerData['cpName'] ?? referrerData['name'] ?? referrerData['fullName'] ?? 'Partner';
        ref2Name = (referrerData['referralName1'] ?? referrerData['addedBy'] ?? '').toString();
        ref3Name = (referrerData['referralName2'] ?? '').toString();
        debugPrint('AUTH: Found referrer $referrerName ($referrerUid) for code $referralCode');
      } else {
        debugPrint('AUTH: No referrer found for code $referralCode - marking as Self Signup');
      }
    }

    // Create new document
    final bool isCustomer = _signupMode == 'customer' || _signupMode == 'viewer';
    final String targetRole = isCustomer ? 'viewer' : 'cp';
    final String collection = isCustomer ? 'customers' : 'cps';

    await _firestore.collection(collection).doc(email).set({
      'email': email,
      'name': displayName ?? 'New User',
      'cpName': displayName ?? 'New User',
      'role': targetRole,
      'isActive': true,
      'isApproved': isCustomer, // True for viewers, false for CPs until admin approval
      'isProfileComplete': targetRole == 'viewer',
      'parentUid': referrerUid,
      'addedBy': referrerName,
      'referralName1': referrerName,
      'referralName2': ref2Name,
      'referralName3': ref3Name,
      'referralCode': '', 
      'timestamp': FieldValue.serverTimestamp(),
    });
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
    final password = rawPassword.trim();

    if (email.isEmpty || password.isEmpty) {
      return 'Please enter your email and password.';
    }

    _isCheckingSession = true;
    notifyListeners();
    try {
      debugPrint('AUTH: Starting login for email: [$email]');
      
      final userDoc = await _findUserByEmail(rawEmail, email);
      
      if (userDoc == null) {
        debugPrint('AUTH: No document found in users or cps for email: $email');
        _clearSessionData();
        return 'No account is registered with this email.';
      }

      debugPrint('AUTH: Document found: ${userDoc.reference.path}. Validating...');

      final validationError = _applyUserDocument(
        userDoc,
        password: password,
      );
      
      if (validationError != null) {
        debugPrint('AUTH: Validation failed: $validationError');
        return validationError;
      }

      debugPrint('AUTH: Credentials valid. Updating login audit...');
      await _updateLastLogin(userDoc);
      
      debugPrint('AUTH: Saving session to local storage...');
      await StorageHelper.saveSession(_userId!);
      
      debugPrint('AUTH: Initializing real-time listener for user data...');
      _listenToCurrentUser(_userId!);
      
      debugPrint('AUTH: Login successful for $userName');
      return null;
    } on FirebaseException catch (error) {
      debugPrint('AUTH FIREBASE ERROR [${error.code}]: ${error.message}');
      _clearSessionData();
      return 'Login failed: ${error.message}';
    } catch (e, stack) {
      debugPrint('AUTH UNEXPECTED ERROR: $e');
      debugPrint(stack.toString());
      _clearSessionData();
      return 'An unexpected error occurred during login.';
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

    debugPrint('AUTH: Checking user documents by ID: $candidateIds');
    for (final documentId in candidateIds) {
      try {
        final userDoc = await _firestore.collection('users').doc(documentId).get();
        if (userDoc.exists) return userDoc;
      } catch (e) {
        debugPrint('AUTH: Doc lookup error for $documentId: $e');
      }
    }

    debugPrint('AUTH: Falling back to field query for email: $normalizedEmail');
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

  Future<String?> signInWithGoogle({String? referralCode, String? mode}) async {
    _isCheckingSession = true;
    if (referralCode != null) _currentReferralCode = referralCode;
    _signupMode = mode; // 🚀 NAYA: Store mode for registration
    notifyListeners();
    try {
      final GoogleSignInAccount? account = await _googleSignIn.authenticate();
      if (account != null) {
        await _handleGoogleUserChanged(account);
      }
      
      if (isAuthenticated) return null;
      
      final savedId = await StorageHelper.getSession();
      if (savedId != null) {
        await loadUserById(savedId, updateLoginAudit: false);
        if (isAuthenticated) return null;
      }

      return null; // Return null so it proceeds to redirect smoothly
    } catch (e) {
      debugPrint('GOOGLE LOGIN ERROR: $e');
      if (e.toString().contains('canceled') || e.toString().contains('cancelled')) {
         _isCheckingSession = false;
         notifyListeners();
         return 'Google Sign-In was cancelled.';
      }
      return null; // Don't block login on web sync hiccups
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

  Future<bool> loadUserById(
    String requestedUserId, {
    bool updateLoginAudit = true,
  }) async {
    var userDoc = await _firestore.collection('customers').doc(requestedUserId).get();
    if (!userDoc.exists) {
      userDoc = await _firestore.collection('users').doc(requestedUserId).get();
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
    }
    final validationError = _applyUserDocument(userDoc);
    if (validationError != null) return false;
    if (updateLoginAudit) await _updateLastLogin(userDoc);
    _listenToCurrentUser(userDoc.id);
    return true;
  }

  Future<bool> _loadUserById(
    String requestedUserId, {
    required bool updateLoginAudit,
  }) => loadUserById(requestedUserId, updateLoginAudit: updateLoginAudit);

  void _listenToCurrentUser(String userId) {
    if (_subscribedUserId == userId) return;
    _userSubscription?.cancel();
    _subscribedUserId = userId;
    
    String collection = 'users';
    if (_userData?['collection'] == 'cps') {
      collection = 'cps';
    } else if (_userData?['collection'] == 'customers') {
      collection = 'customers';
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
    final bool isFromCustomers = userDoc.reference.path.startsWith('customers/');
    final isFromCPS = userDoc.reference.path.startsWith('cps/');
    if (isFromCustomers && storedRole.isEmpty) storedRole = 'viewer';
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
    _userData = {
      ...data,
      'id': userDoc.id,
      'collection': isFromCustomers ? 'customers' : (isFromCPS ? 'cps' : 'users'),
    };
    _userRole = storedRole;
    _permissionRole = permissionRole;

    SharedPreferences.getInstance().then((prefs) {
      _allowNotifications = prefs.getBool('allow_notifications_$_userId') ?? true;
      notifyListeners();
    });

    // 🚀 NAYA: Automatically sync FCM token for push notifications
    syncFcmToken();

    return null;
  }

  Future<void> syncFcmToken() async {
    if (_userId == null || kIsWeb) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        String collection = _userData?['collection'] == 'cps' ? 'cps' : 'users';
        await _firestore.collection(collection).doc(_userId).set({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('FCM: Synced FCM Token for $_userId');
      }
    } catch (e) {
      debugPrint('FCM: Error syncing FCM token: $e');
    }
  }

  Future<void> _updateLastLogin(DocumentSnapshot<Map<String, dynamic>> userDoc) async {
    try {
      await userDoc.reference.update({ 'lastLogin': FieldValue.serverTimestamp() });
      syncFcmToken();
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
