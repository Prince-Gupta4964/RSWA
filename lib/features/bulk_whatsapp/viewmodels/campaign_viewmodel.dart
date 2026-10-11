import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/campaign_model.dart';
import '../services/whatsapp_api_service.dart';
import '../../../models/lead_model.dart';

class CampaignViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<CampaignModel> _campaigns = [];
  bool _isLoading = false;

  List<CampaignModel> get campaigns => _campaigns;
  bool get isLoading => _isLoading;

  Future<void> fetchCampaigns(String userUid) async {
    _isLoading = true;
    notifyListeners();

    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _firestore
            .collection('whatsapp_campaigns')
            .where('createdByUid', isEqualTo: userUid)
            .orderBy('createdAt', descending: true)
            .get();
      } catch (e) {
        debugPrint('Campaigns index query failed, falling back to simple query: $e');
        snapshot = await _firestore
            .collection('whatsapp_campaigns')
            .where('createdByUid', isEqualTo: userUid)
            .get();
      }

      _campaigns = snapshot.docs
          .map((doc) => CampaignModel.fromMap(doc.data(), doc.id))
          .toList();

      _campaigns.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      debugPrint('Error fetching campaigns: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteCampaign(String campaignId) async {
    try {
      await _firestore.collection('whatsapp_campaigns').doc(campaignId).delete();
      _campaigns.removeWhere((c) => c.id == campaignId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting campaign: $e');
    }
  }

  Future<void> startCampaign({
    required String name,
    required List<LeadModel> targets,
    required String createdByUid,
    required String createdByName,
    required String messageType, // 'text', 'image', 'document', 'buttons'
    String? messageBody,
    String? mediaUrl,
    String? fileName,
    List<Map<String, dynamic>>? buttons,
    String? footerText,
    int delayMin = 0,
    int delayMax = 1,
  }) async {
    final int total = targets.length;
    
    // 1. Create Initial Campaign Doc
    final docRef = await _firestore.collection('whatsapp_campaigns').add({
      'name': name,
      'status': 'Running',
      'total': total,
      'sent': 0,
      'pending': total,
      'failed': 0,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Refresh immediately to show it in the dashboard
    await fetchCampaigns(createdByUid);

    int sent = 0;
    int failed = 0;

    // 2. Loop through leads and send
    for (int i = 0; i < targets.length; i++) {
      final lead = targets[i];
      
      String parsedMessage = messageBody?.replaceAll('[Name]', lead.fullName).replaceAll('{{name}}', lead.fullName) ?? '';

      final success = await WhatsAppApiService.sendMessage(
        phoneNumber: lead.contact,
        message: parsedMessage,
        type: messageType,
        imageUrl: (messageType == 'image' || messageType == 'buttons') ? mediaUrl : null,
        documentUrl: messageType == 'document' ? mediaUrl : null,
        fileName: fileName,
        buttons: buttons,
        footerText: footerText,
      );

      if (success) {
        sent++;
      } else {
        failed++;
      }

      // Update Firebase on every few messages or each (if list is small)
      await _firestore.collection('whatsapp_campaigns').doc(docRef.id).update({
        'sent': sent,
        'failed': failed,
        'pending': total - (sent + failed),
        'status': (sent + failed) == total ? 'Completed' : 'Running',
      });
      
      // Update local state to reflect live progress
      final idx = _campaigns.indexWhere((c) => c.id == docRef.id);
      if (idx != -1) {
        final old = _campaigns[idx];
        _campaigns[idx] = CampaignModel(
          id: old.id,
          name: old.name,
          status: (sent + failed) == total ? 'Completed' : 'Running',
          total: old.total,
          sent: sent,
          pending: total - (sent + failed),
          failed: failed,
          createdByUid: old.createdByUid,
          createdByName: old.createdByName,
          createdAt: old.createdAt,
        );
        notifyListeners();
      }

      // Delay logic
      if (i < targets.length - 1) {
        int delaySeconds = delayMin + (delayMax > delayMin ? (DateTime.now().millisecond % (delayMax - delayMin + 1)) : 0);
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }
  }
}
