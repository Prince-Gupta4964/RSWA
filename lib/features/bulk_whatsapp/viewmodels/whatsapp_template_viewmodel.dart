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
