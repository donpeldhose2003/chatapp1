import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'login_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_screen.dart'; // Admin panel

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ✅ Background Message Handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("📩 Background message received: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyC-H2RuqHW8FVRwxO9FmPfyOr4oS0z4Irk",
          authDomain: "chatapp-5274b.firebaseapp.com",
          projectId: "chatapp-5274b",
          storageBucket: "chatapp-5274b.appspot.com",
          messagingSenderId: "210973143138",
          appId: "1:210973143138:web:687605d103049816dbe13b",
          measurementId: "G-VWD09WXPZ5",
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    print("❌ Firebase initialization failed: $e");
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chat App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black),
          bodyMedium: TextStyle(color: Colors.black),
          bodySmall: TextStyle(color: Colors.grey),
        ),
      ),
      home: const SplashScreen(), // ✅ Show Splash Screen First
    );
  }
}

// ✅ SPLASH SCREEN TO AVOID WHITE SCREEN & HANDLE NOTIFICATIONS
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// ✅ Initialize App and Request Notifications
  Future<void> _initializeApp() async {
  try {
    await _initializeFirebase();
    await _requestNotificationPermission();
    
    // Subscribe the logged-in user to their own notification topic
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        FirebaseMessaging.instance.subscribeToTopic(user.uid);
        print("✅ Subscribed to personal topic: ${user.uid}");
      }
    });

  } catch (e) {
    print("❌ Error during initialization: $e");
  } finally {
    setState(() {
      _isLoading = false;
    });
    _navigateToNextScreen();
  }
}


  /// ✅ Initialize Firebase
  Future<void> _initializeFirebase() async {
    if (!kIsWeb) {
      await Firebase.initializeApp();
    }
  }

  /// ✅ Request Notification Permission Automatically
  Future<void> _requestNotificationPermission() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      print("❌ Notifications permission denied.");
    } else {
      print("✅ Notifications permission granted.");
    }
  }

  /// ✅ Navigate to AuthWrapper after initialization
  void _navigateToNextScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => AuthWrapper()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text("Loading complete...", style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

// ✅ AUTH WRAPPER TO HANDLE LOGIN & CHAT NAVIGATION
class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text("Error: ${snapshot.error}",
                  style: const TextStyle(color: Colors.red))),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('admins')
                .doc(snapshot.data!.email)
                .get(),
            builder: (context, adminSnapshot) {
              if (adminSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (adminSnapshot.hasData &&
                  adminSnapshot.data != null &&
                  adminSnapshot.data!.exists &&
                  adminSnapshot.data!['role'] == 'admin') {
                return AdminScreen();
              }

              return ChatScreen();
            },
          );
        } else {
          return LoginScreen();
        }
      },
    );
  }
}