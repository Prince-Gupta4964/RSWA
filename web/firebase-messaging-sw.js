importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

const firebaseConfig = {
    apiKey: 'AIzaSyBx5xJ6nOhNxz33rgNvPR9b3Y8VAIkDmSE',
    appId: '1:813321513896:web:e4da142eeb965551b84b9d',
    messagingSenderId: '813321513896',
    projectId: 'rswaapps',
    authDomain: 'rswaapps.firebaseapp.com',
    storageBucket: 'rswaapps.firebasestorage.app',
    measurementId: 'G-W2YL32W260'
};

firebase.initializeApp(firebaseConfig);

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
    console.log('[firebase-messaging-sw.js] Received background message ', payload);
    const notificationTitle = payload.notification.title;
    const notificationOptions = {
        body: payload.notification.body,
        icon: '/favicon.png'
    };

    self.registration.showNotification(notificationTitle, notificationOptions);
});
