import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/builder_model.dart';

class BuilderViewModel extends ChangeNotifier {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  List<BuilderModel> _builders = [];
  List<BuilderModel> _standardBuilders = [];
  List<BuilderModel> _cpBuilders = [];
  bool _isLoading = true;

  List<BuilderModel> get builders => _builders;
  bool get isLoading => _isLoading;

  BuilderViewModel() {
    fetchBuilders();
  }

  void fetchBuilders() {
    // Listen to standard builders
    _db.collection('builders').snapshots().listen((snapshot) {
      _standardBuilders = snapshot.docs.map((doc) => BuilderModel.fromMap(doc.data(), doc.id, collection: 'builders')).toList();
      _combineBuilders();
    }, onError: (error) {
      debugPrint("Firebase Builder Fetch Error: $error");
      _isLoading = false;
      notifyListeners();
    });

    // Listen to all CPs and filter for Builders in memory (more robust)
    _db.collection('cps').snapshots().listen((snapshot) {
      _cpBuilders = snapshot.docs
          .where((doc) {
            final data = doc.data();
            final type = (data['partnerType'] ?? '').toString().trim().toLowerCase();
            return type == 'builder';
          })
          .map((doc) => BuilderModel.fromMap(doc.data(), doc.id, collection: 'cps'))
          .toList();
      
      debugPrint("Fetched ${_cpBuilders.length} CP-Builders from Firestore");
      _combineBuilders();
    }, onError: (error) {
      debugPrint("Firebase CP Fetch Error: $error");
    });
  }

  void _combineBuilders() {
    _builders = [..._standardBuilders, ..._cpBuilders];
    debugPrint("Total Builders Combined: ${_builders.length}");
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addOrUpdateBuilder({
    String? id,
    String collection = 'builders', // 🚀 NAYA: Specify which collection to update
    required String name,
    required String companyName,
    required String contact,
    required String email,
    required String address,
    List<String>? linkedProjectIds,
  }) async {
    final Map<String, dynamic> data = {
      collection == 'cps' ? 'cpName' : 'name': name,
      'companyName': companyName,
      collection == 'cps' ? 'contactNo' : 'contact': contact,
      'email': email,
      'address': address,
      'linkedProjectIds': linkedProjectIds ?? [],
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (id != null && id.isNotEmpty) {
      await _db.collection(collection).doc(id).update(data);
    } else {
      data['createdAt'] = FieldValue.serverTimestamp();
      await _db.collection('builders').add(data);
    }
  }

  Future<void> linkProject(String builderId, String projectId) async {
    final builder = _builders.firstWhere((b) => b.id == builderId);
    await _db.collection(builder.sourceCollection).doc(builderId).update({
      'linkedProjectIds': FieldValue.arrayUnion([projectId]),
    });
  }

  Future<void> unlinkProject(String builderId, String projectId) async {
    final builder = _builders.firstWhere((b) => b.id == builderId);
    await _db.collection(builder.sourceCollection).doc(builderId).update({
      'linkedProjectIds': FieldValue.arrayRemove([projectId]),
    });
  }
}
