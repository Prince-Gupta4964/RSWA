import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/project_model.dart';

class ProjectViewModel extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<ProjectModel> _projects = [];
  bool _isLoading = true;

  List<ProjectModel> get projects => _projects;
  bool get isLoading => _isLoading;

  ProjectViewModel() {
    fetchProjects();
  }

  void fetchProjects() {
    _db.collection('projects').snapshots().listen((snapshot) {
      _projects = snapshot.docs.map((doc) => ProjectModel.fromMap(doc.data(), doc.id)).toList();
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      print("Firebase Fetch Error: $error");
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> addOrUpdateProject({
    String? id,
    required String projectName,
    required String reraId,
    required String legality,
    required String propertyType,
    required String contactPerson,
    required String contactNumber,
    required Map<String, dynamic> propertyDetails,
  }) async {
    final Map<String, dynamic> data = {
      'projectName': projectName,
      'reraId': reraId,
      'legality': legality,
      'propertyType': propertyType,
      'contactPerson': contactPerson,
      'contactNumber': contactNumber,
      'propertyDetails': propertyDetails,
    };

    if (id != null && id.isNotEmpty) {
      await _db.collection('projects').doc(id).update(data);
    } else {
      data['timestamp'] = FieldValue.serverTimestamp();
      await _db.collection('projects').add(data);
    }
  }

  // --- NAYA FUNCTION: Inventory Add Karne Ke Liye ---
  Future<void> addInventory(String projectId, Map<String, dynamic> inventoryData) async {
    inventoryData['timestamp'] = FieldValue.serverTimestamp();
    // Project ke andar 'inventory' naam ka sub-folder (sub-collection) banega
    await _db.collection('projects').doc(projectId).collection('inventory').add(inventoryData);
  }
}