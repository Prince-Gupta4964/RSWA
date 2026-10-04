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
    List<CPModel> cpsList = [];
    List<CPModel> customersList = [];

    void updateCombined() {
      final combined = [...cpsList, ...customersList];
      combined.sort((a, b) {
        final t1 = a.rawData['timestamp'];
        final t2 = b.rawData['timestamp'];
        if (t1 is Timestamp && t2 is Timestamp) {
          return t2.compareTo(t1);
        }
        return 0;
      });
      _cps = combined;
      _isLoading = false;
      notifyListeners();
    }

    _db.collection('cps').snapshots().listen((snapshot) {
      cpsList = snapshot.docs.map((doc) {
        final data = doc.data();
        data['collection'] = 'cps';
        return CPModel.fromMap(data, doc.id);
      }).toList();
      updateCombined();
    }, onError: (error) {
      debugPrint("Firebase CP Fetch Error: $error");
    });

    _db.collection('customers').snapshots().listen((snapshot) {
      customersList = snapshot.docs.map((doc) {
        final data = doc.data();
        data['collection'] = 'customers';
        data['role'] = data['role'] ?? 'viewer';
        data['profession'] = data['profession'] ?? 'Customer';
        return CPModel.fromMap(data, doc.id);
      }).toList();
      updateCombined();
    }, onError: (error) {
      debugPrint("Firebase Customer Fetch Error: $error");
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
  Future<void> toggleFavorite(String cpId, String userId, List<dynamic> currentFavs, {String collection = 'cps'}) async {
    final List<String> newFavs = List<String>.from(currentFavs);
    if (newFavs.contains(userId)) {
      newFavs.remove(userId);
    } else {
      newFavs.add(userId);
    }
    await _db.collection(collection).doc(cpId).update({'favUids': newFavs});
  }

  // --- APPROVE CP ---
  Future<void> approveCP(String cpId, Map<String, dynamic>? actorMetadata, {bool isCustomerUpgrade = false, String collection = 'cps'}) async {
    final Map<String, dynamic> updateData = {
      'isApproved': true,
      'status': 'Active Partner',
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (isCustomerUpgrade) {
      updateData['role'] = 'cp';
      updateData['cpUpgradeRequested'] = false;
      updateData['upgradeStatus'] = 'Approved';
    }

    if (actorMetadata != null) {
      updateData['updatedBy'] = actorMetadata;
    }

    await _db.collection(collection).doc(cpId).update(updateData);
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
