import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/builder_model.dart';

class BuilderViewModel extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<BuilderModel> _builders = [];
  bool _isLoading = true;

  List<BuilderModel> get builders => _builders;
  bool get isLoading => _isLoading;

  BuilderViewModel() {
    fetchBuilders();
  }

  void fetchBuilders() {
    _db.collection('builders').snapshots().listen((snapshot) {
      _builders = snapshot.docs.map((doc) => BuilderModel.fromMap(doc.data(), doc.id)).toList();
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      debugPrint("Firebase Builder Fetch Error: $error");
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> addOrUpdateBuilder({
    String? id,
    required String name,
    required String companyName,
    required String contact,
    required String email,
    required String address,
    List<String>? linkedProjectIds,
  }) async {
    final Map<String, dynamic> data = {
      'name': name,
      'companyName': companyName,
      'contact': contact,
      'email': email,
      'address': address,
      'linkedProjectIds': linkedProjectIds ?? [],
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (id != null && id.isNotEmpty) {
      await _db.collection('builders').doc(id).update(data);
    } else {
      data['createdAt'] = FieldValue.serverTimestamp();
      await _db.collection('builders').add(data);
    }
  }

  Future<void> linkProject(String builderId, String projectId) async {
    await _db.collection('builders').doc(builderId).update({
      'linkedProjectIds': FieldValue.arrayUnion([projectId]),
    });
  }

  Future<void> unlinkProject(String builderId, String projectId) async {
    await _db.collection('builders').doc(builderId).update({
      'linkedProjectIds': FieldValue.arrayRemove([projectId]),
    });
  }
}
