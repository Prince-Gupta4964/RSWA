import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lead_model.dart';

class LeadViewModel extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<LeadModel> _leads = [];
  bool _isLoading = true;

  // 🚀 Sorting & Filtering State
  String _sortBy = 'Date';
  bool _isAscending = false;
  Map<String, dynamic> _filters = {};

  List<LeadModel> get leads => _leads;
  bool get isLoading => _isLoading;

  String get sortBy => _sortBy;
  bool get isAscending => _isAscending;
  Map<String, dynamic> get filters => _filters;

  // 🚀 NAYA: Data "Learning" helpers
  List<String> getUniqueValues(String fieldId) {
    return _leads
        .map((l) => l.rawData[fieldId]?.toString().trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
  }

  LeadViewModel() {
    fetchLeads();
  }

  void setSort(String field, bool ascending) {
    _sortBy = field;
    _isAscending = ascending;
    notifyListeners();
  }

  void updateFilter(String key, dynamic value) {
    if (value == null || (value is String && value.isEmpty)) {
      _filters.remove(key);
    } else {
      _filters[key] = value;
    }
    notifyListeners();
  }

  void clearFilters() {
    _filters.clear();
    notifyListeners();
  }

  List<LeadModel> applyFiltersAndSort(List<LeadModel> inputLeads) {
    List<LeadModel> results = List.from(inputLeads);

    // 1. Apply Filters
    if (_filters.isNotEmpty) {
      results = results.where((lead) {
        bool match = true;

        if (_filters.containsKey('needsBHK')) {
          if (lead.rawData['needsBHK'] != _filters['needsBHK']) match = false;
        }

        if (_filters.containsKey('company')) {
          if (lead.rawData['company'] != _filters['company']) match = false;
        }

        if (_filters.containsKey('minPrice')) {
          double price = double.tryParse(lead.rawData['finalAmount']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0;
          if (price < _filters['minPrice']) match = false;
        }

        if (_filters.containsKey('maxPrice')) {
          double price = double.tryParse(lead.rawData['finalAmount']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0;
          if (price > _filters['maxPrice']) match = false;
        }

        return match;
      }).toList();
    }

    // 2. Apply Sorting
    results.sort((a, b) {
      dynamic valA, valB;

      switch (_sortBy) {
        case 'Date':
          valA = a.rawData['timestamp'];
          valB = b.rawData['timestamp'];
          if (valA == null) return 1;
          if (valB == null) return -1;
          if (valA is! Timestamp || valB is! Timestamp) return 0;
          return _isAscending ? valA.compareTo(valB) : valB.compareTo(valA);

        case 'Name':
          valA = a.name.toLowerCase();
          valB = b.name.toLowerCase();
          break;

        case 'Final Amount':
          valA = double.tryParse(a.rawData['finalAmount']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0.0;
          valB = double.tryParse(b.rawData['finalAmount']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0.0;
          break;

        case 'Monthly Income':
          valA = double.tryParse(a.rawData['monthlyIncome']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0.0;
          valB = double.tryParse(b.rawData['monthlyIncome']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0.0;
          break;

        default:
          return 0;
      }

      int res = 0;
      if (valA is Comparable && valB is Comparable) {
        res = valA.compareTo(valB);
      }
      return _isAscending ? res : -res;
    });

    return results;
  }

  void fetchLeads() {
    _db
        .collection('leads')
        .snapshots()
        .listen(
          (snapshot) {
            _leads = snapshot.docs
                .map((doc) => LeadModel.fromMap(doc.data(), doc.id))
                .toList();
            _isLoading = false;
            notifyListeners();
          },
          onError: (error) {
            print("Firebase Fetch Error: $error");
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  Future<void> addOrUpdateLead(Map<String, dynamic> data, {String? id, Map<String, dynamic>? actorMetadata}) async {
    final Map<String, dynamic> docData = Map.from(data);
    
    docData['updatedAt'] = FieldValue.serverTimestamp();
    if (actorMetadata != null) {
      docData['updatedBy'] = actorMetadata;
    }

    if (id != null && id.isNotEmpty) {
      await _db.collection('leads').doc(id).update(docData);
    } else {
      docData['timestamp'] = FieldValue.serverTimestamp();
      if (actorMetadata != null) {
        docData['createdBy'] = actorMetadata;
      }
      await _db.collection('leads').add(docData);
    }
  }

  Future<void> updateLeadJourney(String leadId, String stage, Map<String, dynamic> actorMetadata) async {
    await _db.collection('leads').doc(leadId).update({
      'journeyStage': stage,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actorMetadata,
    });
  }

  Stream<QuerySnapshot> getFollowUps(String leadId) {
    return _db.collection('leads').doc(leadId).collection('followups').orderBy('timestamp', descending: true).snapshots();
  }

  Future<void> addFollowUp(String leadId, Map<String, dynamic> data, {bool updateLeadStatus = true}) async {
    data['timestamp'] = FieldValue.serverTimestamp();
    await _db.collection('leads').doc(leadId).collection('followups').add(data);
    
    final Map<String, dynamic> updateData = {
      'lastFollowUp': FieldValue.serverTimestamp(),
    };

    if (updateLeadStatus && data['status'] != null) {
      final s = data['status'].toString().toLowerCase();
      if (s == 'hot' || s == 'warm' || s == 'cold' || s == 'book' || s == 'paid' || s == 'out') {
        updateData['status'] = data['status'];
      }
    }

    await _db.collection('leads').doc(leadId).update(updateData);
  }

  Future<void> toggleFavorite(String leadId, String userId, List<String> currentFavs) async {
    final List<String> newFavs = List.from(currentFavs);
    if (newFavs.contains(userId)) {
      newFavs.remove(userId);
    } else {
      newFavs.add(userId);
    }
    await _db.collection('leads').doc(leadId).update({
      'favUids': newFavs,
    });
  }
}
