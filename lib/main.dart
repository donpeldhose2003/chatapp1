import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'login_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (kIsWeb) {
      // Firebase Initialization for Web
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
      // Firebase Initialization for Mobile
      await Firebase.initializeApp();
    }
  } catch (e) {
    print("Firebase initialization failed: $e");
  }

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
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.deepPurple,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.black), // Replaces bodyText1
          bodyMedium: TextStyle(color: Colors.black), // Replaces bodyText2
          bodySmall: TextStyle(color: Colors.grey),   // Optional: For smaller text
        ),
      ),
      home: AuthWrapper(), // ✅ Check if the user is logged in or not
    );
  }
}

// 📌 Checks authentication state and directs to the appropriate screen
class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text("Error: ${snapshot.error}"),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return ChatScreen(); // ✅ Redirect to ChatScreen if logged in
        } else {
          return LoginScreen(); // ✅ Redirect to LoginScreen if not logged in
        }
      },
    );
  }
}