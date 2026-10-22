const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendTaskAssignmentNotification = functions.firestore
    .document('notifications/{notificationId}')
    .onCreate(async (snap, context) => {
      const data = snap.data();
      if (!data) {
        return null;
      }

      const fcmToken = data.recipientFcmToken;
      if (!fcmToken) {
        console.log('No FCM token for recipient:', data.recipientName);
        return null;
      }

      const title = data.title || 'Property+ | New Notification';
      const body = data.body || '';

      const message = {
        token: fcmToken,
        notification: {
          title: title,
          body: body,
        },
        data: {
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          type: data.type || 'general',
        },
        android: {
          notification: {
            sound: 'default',
            priority: 'high',
            channelId: 'task_notifications',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      };

      try {
        const response = await admin.messaging().send(message);
        console.log('Successfully sent message:', response);
        return null;
      } catch (error) {
        console.error('Error sending message:', error);
        return null;
      }
    });
