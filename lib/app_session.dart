// 

import 'package:firebase_auth/firebase_auth.dart';

class AppSession {
  // Singleton pattern
  static final AppSession _instance = AppSession._internal();
  factory AppSession() => _instance;
  AppSession._internal();

  static AppSession get instance => _instance;

  // Firebase Auth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ดึง User ID ปัจจุบัน
  String? getUserId() {
    return _auth.currentUser?.uid;
  }

  // ดึง User Email
  String? getUserEmail() {
    return _auth.currentUser?.email;
  }

  // ดึง User Name
  String? getUserName() {
    return _auth.currentUser?.displayName;
  }

  // ดึง User Photo URL
  String? getUserPhotoUrl() {
    return _auth.currentUser?.photoURL;
  }

  // ตรวจสอบว่า Login หรือยัง
  bool isLoggedIn() {
    return _auth.currentUser != null;
  }

  // ดึง Firebase User object
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}