// Firebase Messaging Service Worker - Minimal, no caching, no takeover
importScripts('https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js');

// Initialize Firebase app in the service worker
firebase.initializeApp({
  apiKey: "AIzaSyD_nLVRdyd6ZlIyFrRGCW5IStXnM2-uUac",
  authDomain: "teacher-dashboard-flutterfire.firebaseapp.com",
  projectId: "teacher-dashboard-flutterfire",
  storageBucket: "teacher-dashboard-flutterfire.firebasestorage.app",
  messagingSenderId: "218352465432",
  appId: "1:218352465432:web:6e1c0fa4f21416df38b56d"
});

const messaging = firebase.messaging();

// Handle background push messages only
messaging.onBackgroundMessage((payload) => {
  console.log('[FCM SW] Background message:', payload);
  
  const title = payload.notification?.title || 'New message';
  const options = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    data: payload.data || {}
  };
  
  self.registration.showNotification(title, options);
});

// Handle notification clicks
self.addEventListener('notificationclick', (event) => {
  console.log('[FCM SW] Notification click');
  event.notification.close();
  
  const url = event.notification?.data?.click_action || '/';
  event.waitUntil(
    clients.openWindow(url)
  );
});

// IMPORTANT: This SW should NOT handle skipWaiting or claim clients
// It should remain in waiting state and not control the page