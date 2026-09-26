import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/cp_model.dart';

class CPViewModel extends ChangeNotifier {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  List<CPModel> _cps = [];
  bool _isLoading = true;

  List<CPModel> get cps => _cps;
  bool get isLoading => _isLoading;

  // 🚀 NAYA: Data "Learning" helpers
  List<String> getUniqueValues(String fieldId) {
    return _cps
        .map((c) => c.rawData[fieldId]?.toString().trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
  }

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
  Future<void> addOrUpdateCP(
    Map<String, dynamic> cpData, {
    String? id,
    Map<String, dynamic>? actorMetadata,
  }) async {
    final Map<String, dynamic> data = Map.from(cpData);
    
    data['role'] = 'cp';
    data['isActive'] = (data['status'] ?? '').toString().toLowerCase() != 'inactive';
    data['updatedAt'] = FieldValue.serverTimestamp();
    
    if (actorMetadata != null) {
      data['updatedBy'] = actorMetadata;
      if ((data['parentUid'] == null || data['parentUid'].toString().isEmpty) && actorMetadata['uid'] != null) {
        data['parentUid'] = actorMetadata['uid'];
      }
      if ((data['addedBy'] == null || data['addedBy'].toString().isEmpty) && actorMetadata['name'] != null) {
        data['addedBy'] = actorMetadata['name'];
      }
    }

    if (id != null && id.isNotEmpty) {
      await _db.collection('cps').doc(id).update(data);
    } else {
      data['timestamp'] = FieldValue.serverTimestamp();
      if (actorMetadata != null) {
        data['createdBy'] = actorMetadata;
        if (data['parentUid'] == null || data['parentUid'].toString().isEmpty) {
          data['parentUid'] = actorMetadata['uid'];
        }
        if (data['addedBy'] == null || data['addedBy'].toString().isEmpty) {
          data['addedBy'] = actorMetadata['name'];
        }
      }
      await _db.collection('cps').add(data);
    }
  }

  // --- TOGGLE FAVORITE CP ---
  Future<void> toggleFavorite(String cpId, String userId, List<dynamic> currentFavs) async {
    final List<String> newFavs = List<String>.from(currentFavs);
    if (newFavs.contains(userId)) {
      newFavs.remove(userId);
    } else {
      newFavs.add(userId);
    }
    await _db.collection('cps').doc(cpId).update({'favUids': newFavs});
  }

  // --- APPROVE CP ---
  Future<void> approveCP(String cpId, Map<String, dynamic>? actorMetadata) async {
    final Map<String, dynamic> updateData = {
      'isApproved': true,
      'status': 'Active Partner',
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (actorMetadata != null) {
      updateData['updatedBy'] = actorMetadata;
    }

    await _db.collection('cps').doc(cpId).update(updateData);
  }

  // --- MOVE TO RECYCLE BIN (Optimized) ---
  Future<void> softDeleteMultipleCPs(List<String> cpIds) async {
    try {
      final batch = _db.batch();
      
      await Future.wait(cpIds.map((id) async {
        final docRef = _db.collection('cps').doc(id);
        
        final localCP = _cps.where((c) => c.id == id).firstOrNull;
        final data = localCP?.rawData ?? (await docRef.get()).data();
        
        if (data == null) return;

        // 1. Create Recycle Bin Document
        final recycleRef = _db.collection('recyclebin').doc();
        batch.set(recycleRef, {
          'originalId': id,
          'type': 'cp',
          'sourceCollection': 'cps',
          'data': data,
          'deletedAt': FieldValue.serverTimestamp(),
        });

        // 2. Delete original CP
        batch.delete(docRef);
      }));

      await batch.commit();
    } catch (e) {
      debugPrint("Error moving CPs to recycle bin: $e");
      rethrow;
    }
  }

  @Deprecated('Use RecycleBinViewModel instead')
  Future<void> restoreCP(String cpId) async {}

  @Deprecated('Use RecycleBinViewModel instead')
  Future<void> permanentlyDeleteCP(String cpId) async {}
}
