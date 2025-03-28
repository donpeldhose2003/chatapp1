importScripts("https://www.gstatic.com/firebasejs/10.10.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.10.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyC-H2RuqHW8FVRwxO9FmPfyOr4oS0z4Irk",
  authDomain: "chatapp-5274b.firebaseapp.com",
  projectId: "chatapp-5274b",
  storageBucket: "chatapp-5274b.appspot.com",
  messagingSenderId: "210973143138",
  appId: "1:210973143138:web:687605d103049816dbe13b",
  measurementId: "G-VWD09WXPZ5",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log("[firebase-messaging-sw.js] Received background message ", payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: "/firebase-logo.png", // Change this if needed
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
