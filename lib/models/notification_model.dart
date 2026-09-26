import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String recipientName;
  final String title;
  final String body;
  final Timestamp? timestamp;
  final bool isRead;
  final String type;

  const NotificationModel({
    required this.id,
    required this.recipientName,
    required this.title,
    required this.body,
    this.timestamp,
    required this.isRead,
    required this.type,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> data, String documentId) {
    return NotificationModel(
      id: documentId,
      recipientName: data['recipientName']?.toString().trim() ?? '',
      title: data['title']?.toString() ?? '',
      body: data['body']?.toString() ?? '',
      timestamp: data['timestamp'] is Timestamp ? data['timestamp'] as Timestamp : null,
      isRead: data['isRead'] == true || data['isRead']?.toString().toLowerCase() == 'true',
      type: data['type']?.toString() ?? 'general',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'recipientName': recipientName,
      'title': title,
      'body': body,
      'timestamp': timestamp ?? FieldValue.serverTimestamp(),
      'isRead': isRead,
      'type': type,
    };
  }
}
