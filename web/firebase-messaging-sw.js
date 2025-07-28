importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js");
importScripts("/firebase-config.js");

// Initialize the Firebase app in the service worker
// Firebase configuration is loaded from firebase-config.js

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