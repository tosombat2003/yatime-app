import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ya_time/database_local/dao/user_dao.dart';
import 'package:ya_time/database_local/models/user_model.dart';
import 'package:ya_time/database_remote/db_firestore_helper.dart';
import 'package:ya_time/service/notification_service.dart';
import 'package:ya_time/database_local/dao/prescription_dao.dart';
import 'package:ya_time/database_local/dao/medicine_dao.dart';
import 'package:ya_time/database_local/dao/appointments_dao.dart';
import 'package:ya_time/database_local/db_sqlite_helper.dart';
import 'package:ya_time/service/sync_service.dart';
import 'package:ya_time/service/connectivity_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static AuthService get instance => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final UserDao _userDao = UserDao();
  final FirebaseHelper _firebaseHelper = FirebaseHelper();
  final SyncService _syncService = SyncService();
  final AppointmentDao _appointmentDao = AppointmentDao();
  final MedicationDao _medicineDao = MedicationDao();
  final PrescriptionDao _prescriptionDao = PrescriptionDao();
  final ConnectivityService _connectivity = ConnectivityService();

  /// เข้าสู่ระบบด้วย Google
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

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
        // 1. บันทึกลง SQLite
        await saveGoogleUser(firebaseUser);

        // 2. ดึงข้อมูลที่เพิ่งเซฟ (เพื่อเอารูปเดิม ถ้ามี) มาสร้างส่งขึ้น Firebase
        final existingUser = await _userDao.getUserById(firebaseUser.uid);
        
        final userModel = UserModel.fromFirebaseUser(
          uid: firebaseUser.uid,
          email: firebaseUser.email!,
          displayName: firebaseUser.displayName,
          // 🚫 ไม่ใช้ firebaseUser.photoURL เพื่อทิ้งรูป Google
          photoURL: existingUser?.pic, 
          emailVerified: firebaseUser.emailVerified,
        );

        // สั่ง uploadUser เพื่อสร้าง "ตัวบ้าน" จริงๆ บน Firestore
        await _firebaseHelper.uploadUser(userModel);
      }
      return firebaseUser;
    } catch (e) {
      print('Google Sign-In Error: $e');
      rethrow;
    }
  }

  /// บันทึก user จาก Google Sign-In ลง SQLite
  Future<void> saveGoogleUser(User firebaseUser) async {
    try {
      //  เช็คก่อนว่ามี user นี้ในเครื่องไหม
      final existingUser = await _userDao.getUserById(firebaseUser.uid);

      final userModel = UserModel.fromFirebaseUser(
        uid: firebaseUser.uid,
        email: firebaseUser.email!,
        displayName: firebaseUser.displayName,
        // 🚫 ไม่ใช้ firebaseUser.photoURL ให้ใช้รูปเดิมในเครื่อง (ถ้าไม่มีจะเป็น null)
        photoURL: existingUser?.pic, 
        emailVerified: firebaseUser.emailVerified,
      );
      await _userDao.saveUser(userModel);
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel?> getCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    return await _userDao.getUserById(firebaseUser.uid);
  }

  User? getCurrentFirebaseUser() => _auth.currentUser;
  bool isLoggedIn() => _auth.currentUser != null;
  String? getCurrentUserId() => _auth.currentUser?.uid;

  // ===============================
  // Update User Info
  // ===============================

  /// อัปเดต last login time
  Future<void> updateLastLogin(String userId) async {
    try {
      await _userDao.updateLastLogin(userId);
      print('✅ อัปเดต last login สำเร็จ');
    } catch (e) {
      print('❌ Error updating last login: $e');
      rethrow;
    }
  }

  /// อัปเดตชื่อผู้ใช้
  Future<void> updateUserName(String userId, String newName) async {
    try {
      // อัปเดตใน SQLite
      await _userDao.updateName(userId, newName);

      // อัปเดตใน Firebase (ถ้าต้องการ sync)
      await _auth.currentUser?.updateDisplayName(newName);

      print('✅ อัปเดตชื่อสำเร็จ: $newName');
    } catch (e) {
      print('❌ Error updating name: $e');
      rethrow;
    }
  }

  /// อัปเดตรูปโปรไฟล์
/// อัปเดตรูปโปรไฟล์
  Future<void> updateProfilePicture(String userId, String picUrl) async {
    try {
      // อัปเดตใน SQLite
      await _userDao.updateProfilePicture(userId, picUrl);

      // อัปเดตใน Firebase (ถ้าต้องการ sync)
      // ถ้า picUrl เป็นค่าว่าง ให้เซ็ตเป็น null ใน Firebase
      await _auth.currentUser?.updatePhotoURL(picUrl.isEmpty ? null : picUrl);

      print('✅ อัปเดตรูปโปรไฟล์สำเร็จ');
    } catch (e) {
      print('❌ Error updating profile picture: $e');
      rethrow;
    }
  }

  /// อัปเดตข้อมูล user ทั้งหมด
  /// อัปเดตข้อมูล user ทั้งหมด
  Future<void> updateUserProfile({String? name, String? picUrl}) async {
    final userId = getCurrentUserId();
    if (userId == null) throw Exception('User not logged in');

    // 1. ✅ บันทึกลง Local (SQLite) ก่อนเสมอ
    try {
      if (name != null) await _userDao.updateName(userId, name);
      
      // ✅ แก้ไขให้รองรับกรณีที่ picUrl เป็น null หรือค่าว่าง (เพื่อตั้งเป็น "ไม่มีรูป")
      await _userDao.updateProfilePicture(userId, picUrl ?? '');
      
      print('✅ Saved user profile to SQLite (Offline Ready)');
    } catch (e) {
      print('❌ Failed to save locally: $e');
      rethrow;
    }

    // 2. พยายาม Sync ขึ้น Cloud
    _trySyncUserToCloud(userId, displayName: name, photoURL: picUrl);
  }

  // ฟังก์ชันช่วย Sync (ทำงานเบื้องหลัง)
  Future<void> _trySyncUserToCloud(
    String userId, {
    String? displayName,
    String? photoURL,
  }) async {
    try {
      // เช็คเน็ตก่อน
      final hasNet = await _connectivity.hasInternet();
      if (!hasNet) {
        print('📴 No internet, skipping user sync (will sync later)');
        return;
      }

      print('🔄 Syncing user profile to cloud...');

      // อัปเดต Firebase Auth Profile (Optional: เพื่อให้หน้า Login Google สวยๆ)
      if (displayName != null)
        await _auth.currentUser?.updateDisplayName(displayName);
      if (photoURL != null && photoURL.startsWith('http')) {
        // อัปเดต PhotoURL เฉพาะถ้าเป็น URL จริงๆ (ถ้าเป็น asset path ไม่ต้องส่งไป Auth)
        await _auth.currentUser?.updatePhotoURL(photoURL);
      }

      // อัปเดต Firestore Document (ตัวจริง)
      // ดึงข้อมูลล่าสุดจาก SQLite มาส่ง เพื่อความชัวร์ว่าครบถ้วน
      final userModel = await _userDao.getUserById(userId);
      if (userModel != null) {
        await _firebaseHelper.uploadUser(userModel);

        // ✅ สำคัญ: ถ้าสำเร็จ ให้กลับมาติ๊กถูกใน SQLite ว่า Sync แล้ว
        await _userDao.markAsSynced(userId);
        print('☁️ Synced User Profile to Cloud Success');
      }
    } catch (e) {
      print('⚠️ Sync User Profile Failed (User safe locally): $e');
      // ไม่ต้อง throw เพราะข้อมูลอยู่ในเครื่องแล้ว ปลอดภัย
    }
  }

  // ===============================
  // Sign Out
  // ===============================

  /// ออกจากระบบ
  Future<void> signOut() async {
    // ... (โค้ด signOut อันใหม่ที่มี syncAll + cancelAllNotifications + closeAndDeleteDB)
    try {
      print('⏳ กำลังออกจากระบบ...');
      final userId = getCurrentUserId();
      if (userId != null) {
        try {
          await _syncService.syncAll(userId, isManual: true);
        } catch (_) {}
      }
      await NotificationService().cancelAllNotifications();
      await DatabaseHelper.instance.closeAndDeleteDB();
      await _googleSignIn.signOut();
      await _auth.signOut();
      print('✅ ออกจากระบบเรียบร้อย');
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> hasUnsyncedData() async {
    final userId = getCurrentUserId();

    if (userId == null) return false;

    final unsyncedMeds = await _medicineDao.getUnsyncMedications(userId);
    final unsyncedPrescs = await _prescriptionDao.getUnsyncPrescriptions(
      userId,
    );
    final unsyncedAppts = await _appointmentDao.getUnsyncAppointments(userId);

    // ถ้ามีอย่างใดอย่างหนึ่ง > 0 แสดงว่ามีข้อมูลค้าง
    return unsyncedMeds.isNotEmpty ||
        unsyncedPrescs.isNotEmpty ||
        unsyncedAppts.isNotEmpty;
  }


  // ===============================
  // Account Management
  // ===============================

  /// ปิดใช้งานบัญชี (Soft delete)
  Future<void> deactivateAccount() async {
    try {
      await NotificationService().cancelAllNotifications();
      final userId = getCurrentUserId();
      if (userId == null) {
        throw Exception('User not logged in');
      }

      await _userDao.deactivateUser(userId);
      await signOut();

      print('✅ ปิดใช้งานบัญชีสำเร็จ');
    } catch (e) {
      print('❌ Error deactivating account: $e');
      rethrow;
    }
  }

  /// ลบบัญชีถาวร (Hard delete)
  Future<void> deleteAccount() async {
    try {
      await NotificationService().cancelAllNotifications();
      final userId = getCurrentUserId();
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // ลบจาก SQLite
      await _userDao.deleteUser(userId);

      // ลบจาก Firebase
      await _auth.currentUser?.delete();

      // Sign out
      await signOut();

      print('✅ ลบบัญชีสำเร็จ');
    } catch (e) {
      print('❌ Error deleting account: $e');
      rethrow;
    }
  }

  // ===============================
  // Authentication State
  // ===============================

  /// Stream สำหรับฟัง authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// ฟัง user state changes
  Stream<User?> get userChanges => _auth.userChanges();

  // ===============================
  // Utility Functions
  // ===============================

  /// Reload user data จาก Firebase
  Future<void> reloadUser() async {
    try {
      await _auth.currentUser?.reload();
      print('✅ Reload user สำเร็จ');
    } catch (e) {
      print('❌ Error reloading user: $e');
      rethrow;
    }
  }

  /// Sync user data จาก Firebase ไปยัง SQLite
  Future<void> syncUserData() async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        throw Exception('User not logged in');
      }

      // Reload ข้อมูลล่าสุดจาก Firebase
      await firebaseUser.reload();

      // บันทึกลง SQLite
      await saveGoogleUser(firebaseUser);

      print('✅ Sync user data สำเร็จ');
    } catch (e) {
      print('❌ Error syncing user data: $e');
      rethrow;
    }
  }

  /// ตรวจสอบว่า email verified หรือยัง
  bool isEmailVerified() {
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// ส่ง verification email
  Future<void> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
      print('✅ ส่ง verification email สำเร็จ');
    } catch (e) {
      print('❌ Error sending verification email: $e');
      rethrow;
    }
  }

}
