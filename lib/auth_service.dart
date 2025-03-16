import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Register function with Firestore
  Future<User?> register(String email, String password) async {
    try {
      // 1️⃣ Register user in Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        print("✅ User registered: ${user.uid}");

        // 2️⃣ Add user to Firestore Database
        await _firestore.collection("users").doc(user.uid).set({
          "uid": user.uid,
          "email": email,
          "username": email.split("@")[0], // Extract username from email
          "profilePic": "", // Placeholder for profile picture
          "status": "Hey there! I'm using Chat App",
          "createdAt": FieldValue.serverTimestamp(),
        }).then((_) {
          print("✅ Firestore entry created successfully");
        }).catchError((error) {
          print("❌ Firestore write error: $error");
        });

        return user;
      }
    } catch (e) {
      print("❌ Error: ${e.toString()}");
      return null;
    }
    return null;
  }

  // Login function
  Future<User?> login(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print("❌ Login error: ${e.toString()}");
      return null;
    }
  }

  // Logout function
  Future<void> logout() async {
    await _auth.signOut();
  }
}
