import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ya_time/database_local/dao/user_dao.dart';
import 'package:ya_time/database_local/models/user_model.dart';
import 'package:ya_time/database_remote/db_firestore_helper.dart';
import 'package:ya_time/main.dart';
import 'package:ya_time/service/connectivity_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserDao _userDao = UserDao();
  final FirebaseHelper _firebaseHelper = FirebaseHelper();
  final ConnectivityService _connectivityService = ConnectivityService();

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 300,
                  height: 300,
                  child: Center(
                    child: Image.asset(
                      'assets/icon/logo_nobg.png',
                      width: 300,
                      height: 300,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.medical_services,
                        size: 100,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'ยินดีต้อนรับสู่แอปยาไทม์',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'เตือนกินยาตรงเวลา ไม่พลาดทุกมื้อ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 60),
                _isLoading
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    : _buildGoogleSignInButton(),
                const SizedBox(height: 24),
                const Text(
                  'กดปุ่มเดียว เข้าใช้งานได้ทันที\nไม่ต้องจำรหัสผ่าน',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: _handleGoogleSignIn,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Image(
                  image: AssetImage('assets/icon/google_logo.png'),
                  width: 18,
                  height: 18,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.error, size: 18, color: Colors.red),
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'เข้าสู่ระบบด้วย Google',
                style: TextStyle(
                  color: Color(0xFF333333),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    //1. เช็คเน็ตก่อนเริ่ม
    final hasNet = await _connectivityService.hasInternet();
    if (!hasNet) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text('ไม่มีการเชื่อมต่ออินเทอร์เน็ต')),
              ],
            ),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return; // 🛑 จบการทำงานทันทีถ้าไม่มีเน็ต
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('🔵 เริ่ม Google Sign-In...');

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('⚠️ User ยกเลิก Sign-In');
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        print('🔵 ตรวจสอบประวัติผู้ใช้จาก Cloud...');

        UserModel? existingCloudUser = await _firebaseHelper.fetchUser(
          firebaseUser.uid,
        );
        UserModel userModel;

        if (existingCloudUser != null) {
          print('🌟 พบข้อมูลผู้ใช้เก่า โหลดรูปโปรไฟล์เดิมมาใช้...');
          userModel = existingCloudUser.copyWith(
            lastLoginAt: DateTime.now().toIso8601String(),
          );
        } else {
          print('🆕 ผู้ใช้ใหม่ สร้างโปรไฟล์แบบ No Profile...');
          userModel = UserModel.fromFirebaseUser(
            uid: firebaseUser.uid,
            email: firebaseUser.email!,
            displayName: firebaseUser.displayName,
            photoURL: null, // 🚫 ห้ามใส่ firebaseUser.photoURL เด็ดขาด
            emailVerified: firebaseUser.emailVerified,
          );

          // ล้างรูประดับลึกใน Firebase Auth ด้วย เผื่อมันหลอน
          await firebaseUser.updatePhotoURL(null);
        }

        // 1. บันทึกลงเครื่อง (SQLite)
        await _userDao.saveUser(userModel);
        print('✅ บันทึก SQLite สำเร็จ!');

        // 2. อัปโหลดอัปเดตเวลาเข้าสู่ระบบไปที่ Firestore
        print('🔵 กำลัง Sync User ไปยัง Firestore...');
        try {
          await _firebaseHelper.uploadUser(userModel);
          print('✅ Sync User สำเร็จ!');
        } catch (e) {
          print('⚠️ Sync User ไม่สำเร็จ: $e');
        }

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          print('🔵 กำลัง Navigate ไปหน้า MainNavigationPage...');
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainNavigationPage()),
            (route) => false,
          );
          print('✅ Navigate สำเร็จ!');
        }
      }
    } on PlatformException catch (e) {
      print('❌ PlatformException: ${e.code} - ${e.message}');
      String errorMessage = 'เกิดข้อผิดพลาดในการเชื่อมต่อ';
      if (e.code == 'network_error')
        errorMessage = 'กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      print('❌ FirebaseAuthException: ${e.code} - ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Firebase Error: ${e.message}'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } catch (e) {
      print('❌ Unknown Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เข้าสู่ระบบไม่สำเร็จ: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
