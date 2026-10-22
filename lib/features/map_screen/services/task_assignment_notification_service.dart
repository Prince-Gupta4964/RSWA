import 'package:cloud_firestore/cloud_firestore.dart';

class TaskAssignmentNotificationService {
  TaskAssignmentNotificationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> sendAssignmentNotification({
    required String assignee,
    required String taskTitle,
    required String senderName,
    required String senderUid,
    required String senderEmail,
    required bool notificationsEnabled,
  }) async {
    final recipient = assignee.trim();
    if (recipient.isEmpty || !notificationsEnabled) return;
    final normalizedAssignee = recipient.toLowerCase();
    if (normalizedAssignee == senderName.trim().toLowerCase() ||
        normalizedAssignee == senderUid.trim().toLowerCase() ||
        normalizedAssignee == senderEmail.trim().toLowerCase()) {
      return;
    }

    String? targetFcmToken;
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      for (final doc in usersSnapshot.docs) {
        final data = doc.data();
        final name = (data['name'] ?? '').toString().trim();
        final fullName = (data['fullName'] ?? '').toString().trim();
        final email = (data['email'] ?? '').toString().trim();
        final token = (data['fcmToken'] ?? '').toString();

        if (token.isNotEmpty &&
            (name.toLowerCase() == recipient.toLowerCase() ||
             fullName.toLowerCase() == recipient.toLowerCase() ||
             email.toLowerCase() == recipient.toLowerCase() ||
             doc.id.toLowerCase() == recipient.toLowerCase())) {
          targetFcmToken = token;
          break;
        }
      }

      if (targetFcmToken == null) {
        final cpsSnapshot = await _firestore.collection('cps').get();
        for (final doc in cpsSnapshot.docs) {
          final data = doc.data();
          final cpName = (data['cpName'] ?? data['name'] ?? data['fullName'] ?? '').toString().trim();
          final email = (data['email'] ?? '').toString().trim();
          final token = (data['fcmToken'] ?? '').toString();

          if (token.isNotEmpty &&
              (cpName.toLowerCase() == recipient.toLowerCase() ||
               email.toLowerCase() == recipient.toLowerCase() ||
               doc.id.toLowerCase() == recipient.toLowerCase())) {
            targetFcmToken = token;
            break;
          }
        }
      }
    } catch (e) {
      // ignore
    }

    await _firestore.collection('notifications').add({
      'recipientName': recipient,
      'recipientFcmToken': targetFcmToken,
      'title': 'New Task Assigned',
      'body': '$senderName assigned you a task: "$taskTitle"',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'type': 'task_assigned',
    });
  }
}
