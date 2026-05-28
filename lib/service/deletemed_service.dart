import 'package:ya_time/database_local/dao/prescription_dao.dart';
import 'package:ya_time/database_local/dao/schedules_dao.dart';
import 'package:ya_time/database_local/dao/medicine_dao.dart';
import 'package:ya_time/database_remote/db_firestore_helper.dart';
import 'package:ya_time/service/connectivity_service.dart';
import 'package:ya_time/service/notification_service.dart';
//import 'package:ya_time/database_local/models/prescription_model.dart';
import 'package:ya_time/database_local/models/medicine_model.dart';

class DeleteMedicationService {
  final PrescriptionDao _prescriptionDao = PrescriptionDao();
  final ScheduleDao _scheduleDao = ScheduleDao();
  final MedicationDao _medicationDao = MedicationDao();
  final FirebaseHelper _firebaseHelper = FirebaseHelper();
  final ConnectivityService _connectivity = ConnectivityService();
  final NotificationService _notificationService = NotificationService();

  Future<void> deleteMedication(String userId, String prescriptionId) async {
    try {
      // 1. ดึงข้อมูลก่อนลบ 
      final prescription = await _prescriptionDao.getPrescriptionById(prescriptionId);
      if (prescription == null) return;

      final medId = prescription.medId;

      // ---------------------------------------------------------
      // PART 1: เคลียร์ Notification
      // ---------------------------------------------------------
      final schedules = await _scheduleDao.getSchedulesByPrescriptionId(prescriptionId);
      for (var schedule in schedules) {
        if (schedule.schedId != null) {
          await _notificationService.cancelNotification(schedule.schedId!);
          await _notificationService.cancelNotification(schedule.schedId! + 100000);
        }
      }

      // ---------------------------------------------------------
      // PART 2: จัดการ Database ในเครื่อง (OFFLINE FIRST)
      // ---------------------------------------------------------
      // ลบตารางเวลาทิ้งเลย (เพราะไม่กระทบการ Sync)
      await _scheduleDao.deleteSchedulesByPrescriptionId(prescriptionId);

      final String nowStr = DateTime.now().toIso8601String();

      // สร้าง Object ตัวใหม่ที่เปลี่ยนสถานะเป็นลบ และ อัปเดตเวลาให้ล่าสุด!
      final updatedPresc = prescription.copyWith(
        isDeleted: 1,
        isSynced: 0,
        lastModified: nowStr,
      );

      //บังคับใช้ Soft Delete เสมอ ป้องกันปัญหา "ยาซอมบี้"
      await _prescriptionDao.softDeletePrescription(prescriptionId);

      // จัดการกับตัวยา (Medication)
      MedicationModel? updatedMed;
      if (medId != null) {
        final med = await _medicationDao.getMedicationById(medId);
        if (med != null && med.isCustom == 1) { 
          updatedMed = med.copyWith(
            isDeleted: 1,
            isSynced: 0,
            lastModified: nowStr,
          );
          await _medicationDao.softDeleteMedication(medId);
        }
      }

      // ---------------------------------------------------------
      // PART 3: จัดการ Cloud (ONLINE FLOW)
      // ---------------------------------------------------------
      final hasNet = await _connectivity.hasInternet();
      if (hasNet) {
        try {
          print("☁️ Syncing delete to Firebase...");
          
          //ส่งข้อมูลที่อัปเดตเวลา (nowStr) ขึ้นไปทับของเก่า คลาวด์จะได้รู้ว่านี่คือของใหม่ล่าสุด
          await _firebaseHelper.markPrescriptionDeleted(userId, updatedPresc);
          await _prescriptionDao.markAsSynced(prescriptionId, userId);

          if (updatedMed != null) {
             await _firebaseHelper.markMedicineDeleted(userId, updatedMed);
             await _medicationDao.markAsSynced(medId!, userId);
          }
          
          print("✅ Cloud delete synced successfully.");
        } catch (e) {
          print("⚠️ Failed to sync delete to cloud: $e");
        }
      }

    } catch (e) {
      print('❌ Error in deleteMedication: $e');
      rethrow;
    }
  }
}