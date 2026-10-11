class WhatsAppTemplateModel {
  final String id;
  final String title;
  final String messageBody;
  final String createdByUid;
  final String createdByName;
  final DateTime createdAt;
  final String? footerText;
  final List<Map<String, dynamic>> buttons;
  final String? mediaUrl;
  final String? mediaType;

  WhatsAppTemplateModel({
    required this.id,
    required this.title,
    required this.messageBody,
    required this.createdByUid,
    required this.createdByName,
    required this.createdAt,
    this.footerText,
    this.buttons = const [],
    this.mediaUrl,
    this.mediaType,
  });

  factory WhatsAppTemplateModel.fromMap(Map<String, dynamic> data, String id) {
    return WhatsAppTemplateModel(
      id: id,
      title: data['title'] ?? '',
      messageBody: data['messageBody'] ?? '',
      createdByUid: data['createdByUid'] ?? '',
      createdByName: data['createdByName'] ?? '',
      createdAt: data['createdAt'] != null ? data['createdAt'].toDate() : DateTime.now(),
      footerText: data['footerText'],
      buttons: data['buttons'] != null ? List<Map<String, dynamic>>.from(data['buttons']) : [],
      mediaUrl: data['mediaUrl'],
      mediaType: data['mediaType'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'messageBody': messageBody,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'createdAt': createdAt,
      'footerText': footerText,
      'buttons': buttons,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
    };
  }
}
