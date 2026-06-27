import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lead_model.dart';

class LeadViewModel extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<LeadModel> _leads = [];
  bool _isLoading = true;

  List<LeadModel> get leads => _leads;
  bool get isLoading => _isLoading;

  LeadViewModel() {
    fetchLeads();
  }

  void fetchLeads() {
    _db.collection('leads').snapshots().listen((snapshot) {
      _leads = snapshot.docs.map((doc) => LeadModel.fromMap(doc.data(), doc.id)).toList();
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      print("Firebase Fetch Error: $error");
      _isLoading = false;
      notifyListeners();
    });
  }

  // NAYA LOGIC: addOrUpdateLead
  Future<void> addOrUpdateLead({
    String? id, // <-- Yeh ID duplicate banne se rokegi
    required String date,
    required String company,
    required String subCompany,
    required String name,
    required String profession,
    required String whatsapp,
    required String contact2,
    required String address,
    required String leadType,
    required String status,
    required String source,
    required String remark,
    required String email,
    required String gender,
    required String demoDone,
    required String livingIn,
    required String needsBHK,
    required String downPayment,
    required String finalAmount,
    required String monthlyIncome,
    required String majorProblem,
    required String majorRequirement,
    required String bookingDate,
    required String freeTime,
    required String cameWith,
    required String dob,
    required String religion,
    required String advisor,
    required String reachedBy,
    required String caller,
  }) async {
    final Map<String, dynamic> data = {
      'date': date,
      'company': company,
      'subCompany': subCompany,
      'name': name,
      'profession': profession,
      'whatsapp': whatsapp,
      'contact2': contact2,
      'address': address,
      'leadType': leadType,
      'status': status,
      'source': source,
      'remark': remark,
      'email': email,
      'gender': gender,
      'demoDone': demoDone,
      'livingIn': livingIn,
      'needsBHK': needsBHK,
      'downPayment': downPayment,
      'finalAmount': finalAmount,
      'monthlyIncome': monthlyIncome,
      'majorProblem': majorProblem,
      'majorRequirement': majorRequirement,
      'bookingDate': bookingDate,
      'freeTime': freeTime,
      'cameWith': cameWith,
      'dob': dob,
      'religion': religion,
      'advisor': advisor,
      'reachedBy': reachedBy,
      'caller': caller,
    };

    if (id != null && id.isNotEmpty) {
      // AGAR ID HAI: Purane wale ko update karo (Duplicate nahi banega)
      await _db.collection('leads').doc(id).update(data);
    } else {
      // AGAR ID NAHI HAI: Naya entry banao
      data['timestamp'] = FieldValue.serverTimestamp();
      await _db.collection('leads').add(data);
    }
  }
}