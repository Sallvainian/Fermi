importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js");

// Initialize the Firebase app in the service worker
// Firebase configuration from firebase_options.dart
const firebaseConfig = {
  apiKey: "AIzaSyD_nLVRdyd6ZlIyFrRGCW5IStXnM2-uUac",
  authDomain: "teacher-dashboard-flutterfire.firebaseapp.com",
  projectId: "teacher-dashboard-flutterfire",
  storageBucket: "teacher-dashboard-flutterfire.firebasestorage.app",
  messagingSenderId: "218352465432",
  appId: "1:218352465432:web:6e1c0fa4f21416df38b56d"
};

firebase.initializeApp(firebaseConfig);

// Retrieve firebase messaging
const messaging = firebase.messaging();

// Note: Token retrieval should be done in the main app after permission is granted,
// not in the service worker. The service worker only handles background messages.

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log("[firebase-messaging-sw.js] Received background message ", payload);
  
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: "/icons/icon-192.png",
    badge: "/icons/icon-72.png",
    data: payload.data
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification clicks
self.addEventListener('notificationclick', (event) => {
  console.log('[firebase-messaging-sw.js] Notification click received.');
  
  event.notification.close();
  
  // Handle the click action based on the notification data
  if (event.notification.data && event.notification.data.type === 'voip_call') {
    // Open the app and handle the call
    event.waitUntil(
      clients.openWindow('/')
    );
  }
});