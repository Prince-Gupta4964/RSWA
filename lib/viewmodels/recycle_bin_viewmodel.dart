import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/project_model.dart';
import '../models/cp_model.dart';

class RecycleBinViewModel extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  List<DocumentSnapshot> _deletedItems = [];
  bool _isLoading = true;

  List<DocumentSnapshot> get deletedItems => _deletedItems;
  bool get isLoading => _isLoading;

  List<ProjectModel> get deletedProjects => _deletedItems
      .where((doc) => doc['type'] == 'project')
      .map((doc) => ProjectModel.fromMap(doc['data'], doc['originalId']))
      .toList();

  List<CPModel> get deletedCPs => _deletedItems
      .where((doc) => doc['type'] == 'cp')
      .map((doc) => CPModel.fromMap(doc['data'], doc['originalId']))
      .toList();

  RecycleBinViewModel() {
    _listenToRecycleBin();
  }

  void _listenToRecycleBin() {
    _db.collection('recyclebin')
        .orderBy('deletedAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _deletedItems = snapshot.docs;
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint('Recycle Bin Listen Error: $e');
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> moveToRecycleBin({
    required String originalId,
    required String type,
    required String sourceCollection,
    required Map<String, dynamic> data,
  }) async {
    final batch = _db.batch();
    
    // 1. Create Recycle Bin Document
    final recycleRef = _db.collection('recyclebin').doc();
    batch.set(recycleRef, {
      'originalId': originalId,
      'type': type,
      'sourceCollection': sourceCollection,
      'data': data,
      'deletedAt': FieldValue.serverTimestamp(),
    });

    // 2. Handle sub-collections (Inventory for Projects)
    if (type == 'project') {
      final inventoryDocs = await _db.collection(sourceCollection).doc(originalId).collection('inventory').get();
      for (var invDoc in inventoryDocs.docs) {
        batch.set(recycleRef.collection('inventory').doc(invDoc.id), invDoc.data());
        batch.delete(invDoc.reference);
      }
    }

    // 3. Delete original document
    batch.delete(_db.collection(sourceCollection).doc(originalId));

    await batch.commit();
  }

  Future<void> restoreMultiple(List<String> recycleDocIds) async {
    final batch = _db.batch();
    
    // Process all restorations in parallel for speed
    await Future.wait(recycleDocIds.map((docId) async {
      final doc = await _db.collection('recyclebin').doc(docId).get();
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      final String originalId = data['originalId'];
      final String sourceCollection = data['sourceCollection'];
      final Map<String, dynamic> originalData = Map<String, dynamic>.from(data['data']);
      final String type = data['type'];

      // Restore main document
      batch.set(_db.collection(sourceCollection).doc(originalId), originalData);

      // Restore sub-collections
      if (type == 'project') {
        final inventoryDocs = await _db.collection('recyclebin').doc(docId).collection('inventory').get();
        for (var invDoc in inventoryDocs.docs) {
          batch.set(_db.collection(sourceCollection).doc(originalId).collection('inventory').doc(invDoc.id), invDoc.data());
        }
      }

      // Delete from recycle bin
      batch.delete(doc.reference);
    }));

    await batch.commit();
  }

  Future<void> deleteMultipleForever(List<String> recycleDocIds) async {
    final batch = _db.batch();
    
    // Process all deletions in parallel
    await Future.wait(recycleDocIds.map((docId) async {
      final docRef = _db.collection('recyclebin').doc(docId);
      
      // Delete subcollections first
      final inventoryDocs = await docRef.collection('inventory').get();
      for (var d in inventoryDocs.docs) {
        batch.delete(d.reference);
      }
      batch.delete(docRef);
    }));
    
    await batch.commit();
  }

  @Deprecated('Use restoreMultiple instead for better performance')
  Future<void> restoreFromRecycleBin(String recycleDocId) async {
    await restoreMultiple([recycleDocId]);
  }

  @Deprecated('Use deleteMultipleForever instead for better performance')
  Future<void> deleteForever(String recycleDocId) async {
    await deleteMultipleForever([recycleDocId]);
  }
}
