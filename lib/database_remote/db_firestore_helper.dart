import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ya_time/database_local/models/prescription_model.dart';
import 'package:ya_time/database_local/models/appointments_model.dart';
import 'package:ya_time/database_local/models/medicine_model.dart';
import 'package:ya_time/database_local/models/user_model.dart';

import 'package:ya_time/mapper/prescription_mapper.dart';
import 'package:ya_time/mapper/appointments_mapper.dart';
import 'package:ya_time/mapper/medicine_mapper.dart';
import 'package:ya_time/mapper/user_mapper.dart';

class FirebaseHelper {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // ตั้ง Timeout 10 วินาที
  static const Duration _firebaseTimeout = Duration(seconds: 10);

// ================= USERS =================

  /// อัปโหลดข้อมูล User ไปยัง Firestore
  Future<void> uploadUser(UserModel user) async {
    try {
      await _firestore
          .collection('users')
          .doc(user.userId)
          .set(
            UserMapper.toFirestore(user),
            SetOptions(merge: true),
          )
          .timeout(_firebaseTimeout);
      print('✅ Upload user สำเร็จ: ${user.userId}');
    } catch (e) {
      print('⚠️ uploadUser exception: $e');
      // ไม่ throw เพื่อให้ app ใช้งานได้ต่อแม้ Firebase ไม่เว็บ
    }
  }

  /// ดึงข้อมูล User จาก Firestore
  Future<UserModel?> fetchUser(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .get()
          .timeout(_firebaseTimeout);

      if (!doc.exists) return null;

      return UserMapper.fromFirestore(
        doc.data()!,
        doc.id,
      );
    } catch (e) {
      print('⚠️ fetchUser error: $e');
      return null;
    }
  }

  // ================= PRESCRIPTIONS =================

  Future<void> uploadPrescription(
    String userId,
    PrescriptionModel prescription,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('prescriptions')
          .doc(prescription.prescriptionId)
          .set(
            PrescriptionMapper.toFirestore(prescription),
            SetOptions(merge: true),
          );
    } catch (e) {
      print('⚠️ uploadPrescription error: $e');
    }
  }

  Future<List<PrescriptionModel>> fetchPrescriptions(String userId) async {
    try {
      //  ใช้ try-catch แทน catchError เพื่อแก้ปัญหา Type
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('prescriptions')
          .get()
          .timeout(_firebaseTimeout);

      return snapshot.docs.map((doc) {
        return PrescriptionMapper.fromFirestore(
          doc.data(),
          doc.id,
        );
      }).toList();
    } catch (e) {
      print('⚠️ fetchPrescriptions timeout or error: $e');
      return []; //  คืนค่า List ว่างเมื่อ error
    }
  }

  // ================= APPOINTMENTS =================

  Future<void> uploadAppointment(
    String userId,
    AppointmentModel appointment,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('appointments')
          .doc(appointment.appointmentId)
          .set(
            AppointmentMapper.toFirestore(appointment),
            SetOptions(merge: true),
          );
    } catch (e) {
      print('⚠️ uploadAppointment error: $e');
    }
  }

  Future<List<AppointmentModel>> fetchAppointments(String userId) async {
    try {
      //  ใช้ try-catch แทน catchError
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('appointments')
          .get()
          .timeout(_firebaseTimeout);

      return snapshot.docs.map((doc) {
        return AppointmentMapper.fromFirestore(
          doc.data(),
          doc.id,
        );
      }).toList();
    } catch (e) {
      print('⚠️ fetchAppointments timeout or error: $e');
      return []; // คืนค่า List ว่างเมื่อ error
    }
  }

  // ================= MEDICINES (custom only) =================

  Future<void> uploadCustomMedicine(
    String userId,
    MedicationModel medicine,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('medicines')
          .doc(medicine.medId)
          .set(
            MedicationMapper.toFirestore(medicine),
            SetOptions(merge: true),
          );
    } catch (e) {
      print('⚠️ uploadCustomMedicine error: $e');
    }
  }

  Future<List<MedicationModel>> fetchCustomMedicines(String userId) async {
    try {
      // ใช้ try-catch แทน catchError
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('medicines')
          .get()
          .timeout(_firebaseTimeout);

      return snapshot.docs.map((doc) {
        return MedicationMapper.fromFirestore(
          doc.data(),
          doc.id,
        );
      }).toList();
    } catch (e) {
      print('⚠️ fetchCustomMedicines timeout or error: $e');
      return []; // คืนค่า List ว่างเมื่อ error
    }
  }

  // ================= DELETION METHODS =================

  Future<void> markPrescriptionDeleted(
    String userId,
    PrescriptionModel prescription,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('prescriptions')
          .doc(prescription.prescriptionId)
          .set(
            {
              ...PrescriptionMapper.toFirestore(prescription),
              'is_deleted': true,
            },
            SetOptions(merge: true),
          );
    } catch (e) {
      print('⚠️ markPrescriptionDeleted error: $e');
    }
  }

  Future<void> markMedicineDeleted(
    String userId,
    MedicationModel medicine,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('medicines')
          .doc(medicine.medId)
          .set(
            {
              ...MedicationMapper.toFirestore(medicine),
              'is_deleted': true,
            },
            SetOptions(merge: true),
          );
    } catch (e) {
      print('⚠️ markMedicineDeleted error: $e');
    }
  }

  /// ลบใบสั่งยาจาก Firestore
  Future<void> deletePrescription(String userId, String prescriptionId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('prescriptions')
          .doc(prescriptionId)
          .delete();
    } catch (e) {
      print('⚠️ deletePrescription error: $e');
    }
  }

  /// ลบนัดหมายจาก Firestore (เผื่อไว้ใช้ในอนาคต)
  Future<void> deleteAppointment(String userId, String appointmentId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('appointments')
          .doc(appointmentId)
          .delete();
    } catch (e) {
      print('⚠️ deleteAppointment error: $e');
    }
  }

  /// ลบข้อมูลยา Custom จาก Firestore
  Future<void> deleteCustomMedicine(String userId, String medId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('medicines')
          .doc(medId)
          .delete();
    } catch (e) {
      print('⚠️ deleteCustomMedicine error: $e');
    }
  }
}