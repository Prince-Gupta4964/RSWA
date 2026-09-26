import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/project_model.dart';

class ProjectViewModel extends ChangeNotifier {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  List<ProjectModel> _projects = [];
  bool _isLoading = true;

  List<ProjectModel> get projects => _projects;
  bool get isLoading => _isLoading;

  ProjectViewModel() {
    fetchProjects();
    migrateOldProjectDocumentsToNameIds();
  }

  String _sanitizeDocId(String name) {
    if (name.trim().isEmpty) return 'Unnamed Project';
    return name.trim().replaceAll('/', '-').replaceAll('\\', '-').replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _isMigrating = false;

  /// 🚀 NAYA: Migrates old random-ID project documents to Document IDs named after the Project Name
  Future<void> migrateOldProjectDocumentsToNameIds() async {
    if (_isMigrating) return;
    _isMigrating = true;
    try {
      final snapshot = await _db.collection('projects').get();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final rawName = (data['projectName'] ?? '').toString().trim();
        if (rawName.isEmpty) continue;

        final targetId = _sanitizeDocId(rawName);
        final currentId = doc.id;

        // If current doc ID is not equal to target Project Name ID
        if (currentId != targetId) {
          debugPrint("PROJECT MIGRATION: Migrating '$rawName' ($currentId -> $targetId)");

          await _db.collection('projects').doc(targetId).set(data, SetOptions(merge: true));

          final inventoryDocs = await _db.collection('projects').doc(currentId).collection('inventory').get();
          for (var invDoc in inventoryDocs.docs) {
            await _db.collection('projects').doc(targetId).collection('inventory').doc(invDoc.id).set(invDoc.data());
            await invDoc.reference.delete();
          }

          await doc.reference.delete();
          debugPrint("PROJECT MIGRATION SUCCESS: Migrated '$rawName' to ID '$targetId'");
        }
      }
    } catch (e) {
      debugPrint("PROJECT MIGRATION ERROR: $e");
    } finally {
      _isMigrating = false;
    }
  }

  void fetchProjects() {
    _db
        .collection('projects')
        .snapshots()
        .listen(
          (snapshot) {
            _projects = snapshot.docs
                .map((doc) => ProjectModel.fromMap(doc.data(), doc.id))
                .toList();

            _projects.sort((a, b) {
              final tsA = a.rawData['timestamp'] is Timestamp ? (a.rawData['timestamp'] as Timestamp).millisecondsSinceEpoch : 0;
              final tsB = b.rawData['timestamp'] is Timestamp ? (b.rawData['timestamp'] as Timestamp).millisecondsSinceEpoch : 0;
              if (tsA != tsB) return tsB.compareTo(tsA);
              return b.id.compareTo(a.id);
            });

            _isLoading = false;
            notifyListeners();
          },
          onError: (error) {
            debugPrint("Firebase Fetch Error: $error");
            _isLoading = false;
            notifyListeners();
          },
        );
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
    List<String>? builderIds,
    String? actorUid,
    String? actorEmail,
    String? actorName,
    String? actorRole,
  }) async {
    final String isApproved = propertyDetails['isApproved']?.toString() ?? 'No';
    propertyDetails['isApproved'] = isApproved;

    final Map<String, dynamic> data = {
      'projectName': projectName,
      'reraId': reraId,
      'legality': legality,
      'propertyType': propertyType,
      'contactPerson': contactPerson,
      'contactNumber': contactNumber,
      'propertyDetails': propertyDetails,
      'isApproved': isApproved,
      'builderIds': builderIds ?? [],
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': {
        'uid': actorUid ?? '',
        'email': actorEmail ?? '',
        'name': actorName ?? '',
        'role': actorRole ?? '',
      },
    };

    final String targetDocId = _sanitizeDocId(projectName);

    if (id != null && id.isNotEmpty) {
      if (id != targetDocId) {
        // Project Name was changed, move document to new Project Name ID
        final oldDoc = await _db.collection('projects').doc(id).get();
        if (oldDoc.exists && oldDoc.data() != null) {
          final mergedData = {...oldDoc.data()!, ...data};
          await _db.collection('projects').doc(targetDocId).set(mergedData, SetOptions(merge: true));
          
          final inventoryDocs = await _db.collection('projects').doc(id).collection('inventory').get();
          for (var invDoc in inventoryDocs.docs) {
            await _db.collection('projects').doc(targetDocId).collection('inventory').doc(invDoc.id).set(invDoc.data());
            await invDoc.reference.delete();
          }

          await _db.collection('projects').doc(id).delete();
        } else {
          await _db.collection('projects').doc(targetDocId).set(data, SetOptions(merge: true));
        }
      } else {
        await _db.collection('projects').doc(id).set(data, SetOptions(merge: true));
      }
    } else {
      data['createdByUid'] = actorUid;
      data['timestamp'] = FieldValue.serverTimestamp();
      data['createdBy'] = {
        'uid': actorUid ?? '',
        'email': actorEmail ?? '',
        'name': actorName ?? '',
        'role': actorRole ?? '',
      };
      await _db.collection('projects').doc(targetDocId).set(data, SetOptions(merge: true));
    }
  }

  // --- NAYA FUNCTION: Inventory Add Karne Ke Liye ---
  Future<void> addInventory(
    String projectId,
    Map<String, dynamic> inventoryData,
  ) async {
    inventoryData['timestamp'] = FieldValue.serverTimestamp();
    // Project ke andar 'inventory' naam ka sub-folder (sub-collection) banega
    await _db
        .collection('projects')
        .doc(projectId)
        .collection('inventory')
        .add(inventoryData);
  }

  // --- MOVE TO RECYCLE BIN (Optimized) ---
  Future<void> softDeleteMultipleProjects(List<String> projectIds) async {
    try {
      final batch = _db.batch();
      
      // Parallelize fetching data and sub-collections for all projects
      await Future.wait(projectIds.map((projectId) async {
        final docRef = _db.collection('projects').doc(projectId);
        
        // Try to get data from memory first to avoid a network hop if possible
        // If not, we fetch it.
        final localProject = _projects.where((p) => p.id == projectId).firstOrNull;
        final data = localProject?.rawData ?? (await docRef.get()).data();
        
        if (data == null) return;

        // 1. Create Recycle Bin Document
        final recycleRef = _db.collection('recyclebin').doc();
        batch.set(recycleRef, {
          'originalId': projectId,
          'type': 'project',
          'sourceCollection': 'projects',
          'data': data,
          'deletedAt': FieldValue.serverTimestamp(),
        });

        // 2. Handle sub-collections (Inventory) - Fetching in parallel
        final inventoryDocs = await docRef.collection('inventory').get();
        for (var invDoc in inventoryDocs.docs) {
          batch.set(recycleRef.collection('inventory').doc(invDoc.id), invDoc.data());
          batch.delete(invDoc.reference);
        }

        // 3. Delete original project
        batch.delete(docRef);
      }));

      await batch.commit();
    } catch (e) {
      debugPrint("Error moving projects to recycle bin: $e");
      rethrow;
    }
  }

  // --- RESTORE Logic moved to RecycleBinViewModel, but keeping stubs for safety or updating them ---
  // Actually, I should probably remove these from here and only use RecycleBinViewModel in the RecycleBinView.
  
  @Deprecated('Use RecycleBinViewModel instead')
  Future<void> restoreProject(String projectId) async {}

  @Deprecated('Use RecycleBinViewModel instead')
  Future<void> permanentlyDeleteProject(String projectId) async {}

  // --- DELETE PROJECT (Maintains compatibility) ---
  Future<void> deleteProject(String projectId) async {
    await softDeleteMultipleProjects([projectId]);
  }

  // --- DELETE MULTIPLE PROJECTS ---
  Future<void> deleteMultipleProjects(List<String> projectIds) async {
    await softDeleteMultipleProjects(projectIds);
  }

  Future<void> toggleHotStatus(String projectId, bool isHot) async {
    await _db.collection('projects').doc(projectId).update({
      'isHot': isHot,
    });
  }

  // --- NAYA FUNCTION: Approval Status Change (Approved, Reject, Hold, Process) ---
  Future<void> updateProjectApprovalStatus(
    String projectId,
    String status, {
    Map<String, dynamic>? actorMetadata,
  }) async {
    final bool isApprovedBool = status == 'Approved';
    final String isApprovedStr = isApprovedBool ? 'Yes' : 'No';

    final docRef = _db.collection('projects').doc(projectId);
    final docSnapshot = await docRef.get();

    Map<String, dynamic> propertyDetails = {};
    if (docSnapshot.exists && docSnapshot.data() != null) {
      final data = docSnapshot.data()!;
      if (data['propertyDetails'] is Map) {
        propertyDetails = Map<String, dynamic>.from(data['propertyDetails']);
      }
    }
    propertyDetails['isApproved'] = isApprovedStr;

    final Map<String, dynamic> updateData = {
      'isApproved': isApprovedStr,
      'approvalStatus': status,
      'propertyDetails': propertyDetails,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (actorMetadata != null) {
      updateData['updatedBy'] = actorMetadata;
    }

    await docRef.update(updateData);
  }
}
