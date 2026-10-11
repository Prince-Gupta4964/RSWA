import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/whatsapp_template_model.dart';

class WhatsAppTemplateViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<WhatsAppTemplateModel> _templates = [];
  bool _isLoading = false;

  List<WhatsAppTemplateModel> get templates => _templates;
  bool get isLoading => _isLoading;

  Future<void> fetchTemplates(String userUid) async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('whatsapp_templates')
          .where('createdByUid', isEqualTo: userUid)
          .orderBy('createdAt', descending: true)
          .get();

      _templates = snapshot.docs
          .map((doc) => WhatsAppTemplateModel.fromMap(doc.data(), doc.id))
          .toList();

      if (_templates.isEmpty) {
        _templates = [
          WhatsAppTemplateModel(
            id: 'prebuilt_1',
            title: '🏢 Exclusive Property Launch',
            messageBody: 'Hello {{name}}! 👋 We are excited to invite you to the grand launch of our new luxury residential project. Special pre-launch prices available for early investors!',
            footerText: 'Property+ Real Estate',
            buttons: [
              {"type": "url", "text": "View Details", "url": "https://propertyplus.app"},
              {"type": "phone", "text": "Call Agent", "phone": "919876543210"}
            ],
            createdByUid: userUid,
            createdByName: 'System',
            createdAt: DateTime.now(),
          ),
          WhatsAppTemplateModel(
            id: 'prebuilt_2',
            title: '📅 Site Visit Invitation',
            messageBody: 'Hi {{name}}, would you like to schedule a free site visit this weekend for our premium properties? Pick up and drop service available!',
            footerText: 'Book Your Slot Today',
            buttons: [
              {"type": "url", "text": "Book Visit", "url": "https://propertyplus.app/site-visit"},
            ],
            createdByUid: userUid,
            createdByName: 'System',
            createdAt: DateTime.now(),
          ),
          WhatsAppTemplateModel(
            id: 'prebuilt_3',
            title: '🎉 Festive Special Offer & Brochure',
            messageBody: 'Dear {{name}}, unlock exclusive festive discounts on verified properties across Mumbai & Pune. Check out the attached brochure for complete pricing!',
            footerText: 'Limited Period Offer',
            buttons: [
              {"type": "url", "text": "Explore Projects", "url": "https://propertyplus.app/projects"},
            ],
            mediaUrl: 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=800&q=80',
            mediaType: 'image',
            createdByUid: userUid,
            createdByName: 'System',
            createdAt: DateTime.now(),
          ),
        ];
      }
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        debugPrint('Templates Index is building. Please click the link in the console to create it.');
      } else {
        debugPrint('Error fetching templates: $e');
      }
    } catch (e) {
      debugPrint('Error fetching templates: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTemplate(WhatsAppTemplateModel template) async {
    try {
      final docRef = await _firestore.collection('whatsapp_templates').add(template.toMap());
      _templates.insert(0, WhatsAppTemplateModel(
        id: docRef.id,
        title: template.title,
        messageBody: template.messageBody,
        createdByUid: template.createdByUid,
        createdByName: template.createdByName,
        createdAt: template.createdAt,
        footerText: template.footerText,
        buttons: template.buttons,
        mediaUrl: template.mediaUrl,
        mediaType: template.mediaType,
      ));
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding template: $e');
      rethrow;
    }
  }

  Future<void> deleteTemplate(String id) async {
    try {
      await _firestore.collection('whatsapp_templates').doc(id).delete();
      _templates.removeWhere((t) => t.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting template: $e');
      rethrow;
    }
  }
}
