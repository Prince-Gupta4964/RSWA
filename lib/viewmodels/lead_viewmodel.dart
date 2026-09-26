import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lead_model.dart';

class LeadViewModel extends ChangeNotifier {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  List<LeadModel> _leads = [];
  bool _isLoading = true;

  // 🚀 Tab-Specific Sorting, Filtering & Grouping State
  final Map<String, String> _tabSortBy = {};
  final Map<String, bool> _tabIsAscending = {};
  final Map<String, String> _tabGroupBy = {};
  final Map<String, Map<String, dynamic>> _tabFilters = {};

  List<LeadModel> get leads => _leads;
  bool get isLoading => _isLoading;

  String getSortBy(String tabId) => _tabSortBy[tabId] ?? 'Date';
  bool getIsAscending(String tabId) => _tabIsAscending[tabId] ?? false;
  String getGroupBy(String tabId) => _tabGroupBy[tabId] ?? 'Status';
  Map<String, dynamic> getFilters(String tabId) => _tabFilters[tabId] ?? {};

  // Legacy getters for backward compatibility if needed, though we should transition to tabId-based
  String get sortBy => _tabSortBy['default'] ?? 'Date';
  bool get isAscending => _tabIsAscending['default'] ?? false;
  String get groupBy => _tabGroupBy['default'] ?? 'Status';
  Map<String, dynamic> get filters => _tabFilters['default'] ?? {};

  // 🚀 NAYA: Data "Learning" helpers
  List<String> getUniqueValues(String fieldId) {
    return _leads
        .map((l) => l.rawData[fieldId]?.toString().trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
  }

  LeadViewModel() {
    _loadAllTabSettings();
    fetchLeads();
  }

  Future<void> _loadAllTabSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    
    for (String key in keys) {
      if (key.startsWith('tab_sort_by_')) {
        final tabId = key.replaceFirst('tab_sort_by_', '');
        _tabSortBy[tabId] = prefs.getString(key) ?? 'Date';
      } else if (key.startsWith('tab_sort_asc_')) {
        final tabId = key.replaceFirst('tab_sort_asc_', '');
        _tabIsAscending[tabId] = prefs.getBool(key) ?? false;
      } else if (key.startsWith('tab_group_by_')) {
        final tabId = key.replaceFirst('tab_group_by_', '');
        _tabGroupBy[tabId] = prefs.getString(key) ?? 'Status';
      }
    }
    notifyListeners();
  }

  void setSort(String tabId, String field, bool ascending) async {
    _tabSortBy[tabId] = field;
    _tabIsAscending[tabId] = ascending;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tab_sort_by_$tabId', field);
    await prefs.setBool('tab_sort_asc_$tabId', ascending);
  }

  void setGroupBy(String tabId, String value) async {
    _tabGroupBy[tabId] = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tab_group_by_$tabId', value);
  }

  void updateFilter(String tabId, String key, dynamic value) {
    if (!_tabFilters.containsKey(tabId)) _tabFilters[tabId] = {};
    
    if (value == null || (value is String && value.isEmpty)) {
      _tabFilters[tabId]!.remove(key);
    } else {
      _tabFilters[tabId]![key] = value;
    }
    notifyListeners();
  }

  void clearFilters(String tabId) {
    _tabFilters[tabId]?.clear();
    notifyListeners();
  }

  List<LeadModel> applyFiltersAndSort(List<LeadModel> inputLeads, String tabId) {
    List<LeadModel> results = List.from(inputLeads);
    final filters = getFilters(tabId);
    final sortBy = getSortBy(tabId);
    final isAscending = getIsAscending(tabId);

    // 1. Apply Filters
    if (filters.isNotEmpty) {
      results = results.where((lead) {
        bool match = true;

        if (filters.containsKey('needsBHK')) {
          if (lead.rawData['needsBHK'] != filters['needsBHK']) match = false;
        }

        if (filters.containsKey('company')) {
          if (lead.rawData['company'] != filters['company']) match = false;
        }

        if (filters.containsKey('minPrice')) {
          double price = double.tryParse(lead.rawData['finalAmount']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0;
          if (price < filters['minPrice']) match = false;
        }

        if (filters.containsKey('maxPrice')) {
          double price = double.tryParse(lead.rawData['finalAmount']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0;
          if (price > filters['maxPrice']) match = false;
        }

        return match;
      }).toList();
    }

    // 2. Apply Sorting
    results.sort((a, b) {
      dynamic valA, valB;

      switch (sortBy) {
        case 'Date':
          valA = a.rawData['timestamp'];
          valB = b.rawData['timestamp'];
          if (valA == null) return 1;
          if (valB == null) return -1;
          if (valA is! Timestamp || valB is! Timestamp) return 0;
          return isAscending ? valA.compareTo(valB) : valB.compareTo(valA);

        case 'Name':
          valA = a.name.toLowerCase();
          valB = b.name.toLowerCase();
          break;

        case 'Budget':
          valA = double.tryParse(a.rawData['budget']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0.0;
          valB = double.tryParse(b.rawData['budget']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0.0;
          break;

        case 'Total Days':
          valA = a.rawData['timestamp'] is Timestamp ? (a.rawData['timestamp'] as Timestamp).millisecondsSinceEpoch : 0;
          valB = b.rawData['timestamp'] is Timestamp ? (b.rawData['timestamp'] as Timestamp).millisecondsSinceEpoch : 0;
          break;

        case 'Total Calls':
          valA = a.rawData['callCount'] ?? 0;
          valB = b.rawData['callCount'] ?? 0;
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
      return isAscending ? res : -res;
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

    // 🚀 NAYA: Increment callCount if this was a call
    final s = data['status']?.toString().toLowerCase() ?? '';
    if (s == 'contacted' || s == 'call' || s == 'whatsapp') {
      updateData['callCount'] = FieldValue.increment(1);
    }

    if (updateLeadStatus && data['status'] != null) {
      if (s == 'hot' || s == 'warm' || s == 'cold' || s == 'book' || s == 'paid' || s == 'out') {
        updateData['status'] = data['status'];
      }
    }

    await _db.collection('leads').doc(leadId).update(updateData);
  }

  Future<void> updateFollowUp(String leadId, String followupId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('leads').doc(leadId).collection('followups').doc(followupId).update(data);
    
    await _db.collection('leads').doc(leadId).update({
      'lastFollowUp': FieldValue.serverTimestamp(),
    });
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
