import 'package:ya_time/database_local/dao/prescription_dao.dart';
import 'package:ya_time/database_local/dao/schedules_dao.dart';
import 'package:ya_time/database_local/dao/medicine_dao.dart';
import 'package:ya_time/database_local/models/prescription_model.dart';
import 'package:ya_time/database_local/models/medicine_model.dart';
import 'package:ya_time/database_local/models/schedules_model.dart';
import 'package:ya_time/service/addmed_service.dart';
import 'package:ya_time/database_remote/db_firestore_helper.dart';
import 'package:ya_time/service/connectivity_service.dart';
import 'package:ya_time/database_local/repositories/medication_repository.dart';
import 'package:ya_time/service/notification_service.dart';

class EditMedicationService {
  final MedicationDao _medicationDao = MedicationDao();
  final PrescriptionDao _prescriptionDao = PrescriptionDao();
  final ScheduleDao _scheduleDao = ScheduleDao();
  final AddMedicationService _addMedService = AddMedicationService();
  final FirebaseHelper _firebaseHelper = FirebaseHelper();
  final ConnectivityService _connectivity = ConnectivityService();

  /// ===============================
  /// PUBLIC METHOD (UI เรียก)
  /// ===============================
  Future<void> editMedication({
    required String userId,
    required String prescriptionId,
    required String medId,

    // medication fields
    String? medName,
    String? genericName,
    String? dosageStrength,
    String? type,

    // prescription fields
    String? doseAmount,
    String? instructions,
    String? startDate,
    String? endDate,
    String? timeToNotify,

    bool rescheduleFromToday = false,
  }) async {
    final now = DateTime.now().toIso8601String();

    // ===============================
    // 1️ OFFLINE FLOW (ต้องเสร็จ 100%)
    // ===============================
    final result = await _editOffline(
      userId: userId,
      prescriptionId: prescriptionId,
      medId: medId,
      medName: medName,
      genericName: genericName,
      dosageStrength: dosageStrength,
      type: type,
      doseAmount: doseAmount,
      instructions: instructions,
      startDate: startDate,
      endDate: endDate,
      timeToNotify: timeToNotify,
      rescheduleFromToday: rescheduleFromToday,
      now: now,
    );

    // ===============================
    // 2️ ONLINE FLOW (ไม่ block UI)
    // ===============================
    _syncToFirebaseIfOnline(
      userId: userId,
      medication: result.updatedMed,
      prescription: result.updatedPrescription,
    );
  }

  // =========================================================
  // OFFLINE: แก้ข้อมูล + schedule ทั้งหมดในเครื่อง
  // =========================================================
  Future<_EditResult> _editOffline({
    required String userId,
    required String prescriptionId,
    required String medId,
    required String now,

    String? medName,
    String? genericName,
    String? dosageStrength,
    String? type,

    String? doseAmount,
    String? instructions,
    String? startDate,
    String? endDate,
    String? timeToNotify,

    required bool rescheduleFromToday,
  }) async {
    final oldMed = await _medicationDao.getMedicationById(medId);
    final oldPrescription = await _prescriptionDao.getPrescriptionById(
      prescriptionId,
    );

    if (oldMed == null || oldPrescription == null) {
      throw Exception("Medication or Prescription not found");
    }

    // ---------------------------------------------------------
    // ขั้นตอนสำคัญ 1: ล้างแจ้งเตือนในระบบ Android ก่อนลบข้อมูลใน DB
    // ---------------------------------------------------------
    final today = DateTime.now().toIso8601String().substring(0, 10);

    // ดึงรายการ schedule ทั้งหมดของใบสั่งยานี้
    final List<ScheduleModel> pendingSchedules = await _scheduleDao
        .getSchedulesByPrescriptionId(prescriptionId);

    for (var schedule in pendingSchedules) {
      // ยกเลิกเฉพาะอันที่ยังไม่ถึงเวลา (Pending) และตั้งแต่วันนี้เป็นต้นไป
      if (schedule.status == 'pending' &&
          (schedule.scheduledDate ?? "").compareTo(today) >= 0) {
        if (schedule.schedId != null) {
          //1. ยกเลิกตัวเตือนหลัก
          await NotificationService().cancelNotification(schedule.schedId!);
          
          //2. (เพิ่มใหม่) ยกเลิกตัวเตือนกันลืมด้วย!! (ID + 100000)
          await NotificationService().cancelNotification(schedule.schedId! + 100000);
        }
      }
    }

    // ===== Update Medication (โค้ดเดิม) =====
    final updatedMed = MedicationModel(
      medId: medId,
      medName: medName ?? oldMed.medName,
      medGenericName: genericName ?? oldMed.medGenericName,
      dosageStrength: dosageStrength ?? oldMed.dosageStrength,
      type: type ?? oldMed.type,
      isCustom: oldMed.isCustom,
      ownerUserId: oldMed.ownerUserId,
      createdAt: oldMed.createdAt,
      lastModified: now,
      isSynced: 0,
      isDeleted: oldMed.isDeleted,
      syncAt: oldMed.syncAt,
    );
    await _medicationDao.updateMedication(updatedMed);

    // ===== Update Prescription (โค้ดเดิม) =====
    final updatedPrescription = PrescriptionModel(
      prescriptionId: prescriptionId,
      userId: userId,
      medId: medId,
      doseAmount: doseAmount ?? oldPrescription.doseAmount,
      startDate: startDate ?? oldPrescription.startDate,
      endDate: endDate ?? oldPrescription.endDate,
      instructions: instructions ?? oldPrescription.instructions,
      timeToNotify: timeToNotify ?? oldPrescription.timeToNotify,
      source: oldPrescription.source,
      createdAt: oldPrescription.createdAt,
      lastModified: now,
      isSynced: 0,
      isDeleted: oldPrescription.isDeleted,
      updatedBy: userId,
      syncAt: oldPrescription.syncAt,
    );
    await _prescriptionDao.updatePrescription(updatedPrescription);

    // ===== Delete future pending schedules (โค้ดเดิม) =====
    await _scheduleDao.deleteFuturePendingSchedules(prescriptionId, today);

    // ===== Generate schedules (โค้ดเดิม) =====
    DateTime? startFrom;
    if (rescheduleFromToday) {
      startFrom = DateTime.now();
    }

    await _addMedService.generateSchedules(
      updatedPrescription,
      startGenerationFrom: startFrom,
    );

    // ---------------------------------------------------------
    // ขั้นตอนสำคัญ 2: ตั้งแจ้งเตือนใหม่เข้าสู่ระบบ Android
    // ---------------------------------------------------------
    // หลังจาก generate เสร็จ เราจะได้ sched_id ชุดใหม่ใน DB
    // ต้องสั่งให้มันไปกวาด ID ใหม่เหล่านั้นมาจองคิวแจ้งเตือน
    final MedicationRepository medicationRepo = MedicationRepository();
    await medicationRepo.syncAllNotifications();

    return _EditResult(
      updatedMed: updatedMed,
      updatedPrescription: updatedPrescription,
    );
  }

  // =========================================================
  // ONLINE: ยิง Firebase เฉพาะกรณี "ยังไม่ถูกลบ"
  // =========================================================
  Future<void> _syncToFirebaseIfOnline({
    required String userId,
    required MedicationModel medication,
    required PrescriptionModel prescription,
  }) async {
    final hasNet = await _connectivity.hasInternet();
    if (!hasNet) return;

    //RULE สำคัญที่สุด
    if (medication.isDeleted == 1 || prescription.isDeleted == 1) {
      print('⛔ Skip sync deleted record: ${medication.medName}');
      return;
    }

    try {
      await _firebaseHelper.uploadCustomMedicine(userId, medication);
      await _firebaseHelper.uploadPrescription(userId, prescription);
      print('☁️ Synced edited medication: ${medication.medName}');
    } catch (e) {
      // ไม่ throw
      //ให้ SyncService จัดการตอนหลัง
      print("⚠ Firebase sync failed: $e");
    }
  }
}

/// =========================================================
/// Helper result class
/// =========================================================
class _EditResult {
  final MedicationModel updatedMed;
  final PrescriptionModel updatedPrescription;

  _EditResult({required this.updatedMed, required this.updatedPrescription});
}