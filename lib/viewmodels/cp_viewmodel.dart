import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cp_model.dart';

class CPViewModel extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<CPModel> _cps = [];
  bool _isLoading = true;

  List<CPModel> get cps => _cps;
  bool get isLoading => _isLoading;

  CPViewModel() {
    fetchCPs();
  }

  void fetchCPs() {
    _db.collection('cps').orderBy('timestamp', descending: true).snapshots().listen((snapshot) {
      _cps = snapshot.docs.map((doc) => CPModel.fromMap(doc.data(), doc.id)).toList();
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      print("Firebase CP Fetch Error: $error");
      _isLoading = false;
      notifyListeners();
    });
  }

  // Naya CP Add aur Update karne ka function (RERA ID aur saare fields ke sath)
  Future<void> addOrUpdateCP({
    String? id, // <-- NAYA: Update ke waqt duplicate rokne ke liye
    required String cpName,
    required String profession,
    required String contactNo,
    required String location,
    required String officeRef,
    required String advisorReachedBy,
    required String callerRef,
    required String status,
    required String reraId, // <-- NAYA: RERA ID add kiya
  }) async {
    final Map<String, dynamic> data = {
      'cpName': cpName,
      'profession': profession,
      'contactNo': contactNo,
      'location': location,
      'officeRef': officeRef,
      'advisorReachedBy': advisorReachedBy,
      'callerRef': callerRef,
      'status': status,
      'reraId': reraId, // <-- Database me save hoga
    };

    if (id != null && id.isNotEmpty) {
      // AGAR ID HAI: Purane wale ko update karo (Duplicate nahi banega)
      await _db.collection('cps').doc(id).update(data);
    } else {
      // AGAR ID NAHI HAI: Naya entry banao
      data['timestamp'] = FieldValue.serverTimestamp();
      await _db.collection('cps').add(data);
    }
  }
}