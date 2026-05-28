import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:ya_time/database_local/dao/medicine_dao.dart';
import 'package:ya_time/database_local/dao/prescription_dao.dart';
import 'package:ya_time/database_local/dao/schedules_dao.dart';

import 'package:ya_time/database_local/models/medicine_model.dart';
import 'package:ya_time/database_local/models/prescription_model.dart';
import 'package:ya_time/database_local/models/schedules_model.dart';

import 'package:ya_time/database_remote/db_firestore_helper.dart';
import 'package:ya_time/service/connectivity_service.dart';

import 'package:ya_time/database_local/repositories/medication_repository.dart';

class AddMedicationService {
  final MedicationDao _medicationDao = MedicationDao();
  final PrescriptionDao _prescriptionDao = PrescriptionDao();
  final ScheduleDao _scheduleDao = ScheduleDao();
  final FirebaseHelper _firebaseHelper = FirebaseHelper();
  final ConnectivityService _connectivity = ConnectivityService();

  final _uuid = const Uuid();
  final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd');
  String _formatDate(DateTime date) => _dateFormatter.format(date);
  final MedicationRepository _medicationRepository = MedicationRepository();

  Future<void> addMedication({
    required String userId,
    required String medName,
    String? genericName,
    String? dosageStrength,
    String? type,
    String? doseAmount,
    String? instructions,
    required String startDate,
    String? endDate,
    String? timeToNotify,
    required List<String> times,
  }) async {
    final String nowStr = _formatDate(DateTime.now());

    // ===============================
    // 1️ OFFLINE FIRST
    // ===============================
    final String medId = _uuid.v4();
    final med = MedicationModel(
      medId: medId,
      medName: medName,
      medGenericName: genericName,
      dosageStrength: dosageStrength,
      type: type,
      isCustom: 1,
      ownerUserId: userId,
      createdAt: nowStr,
      lastModified: nowStr,
      isSynced: 0,
      isDeleted: 0,
    );
    await _medicationDao.insertMedication(med);

    final String prescriptionId = _uuid.v4();
    final prescription = PrescriptionModel(
      prescriptionId: prescriptionId,
      userId: userId,
      medId: medId,
      doseAmount: doseAmount,
      startDate: startDate,
      endDate: endDate,
      instructions: instructions,
      timeToNotify: timeToNotify,
      source: 'user',
      createdAt: nowStr,
      lastModified: nowStr,
      isSynced: 0,
      isDeleted: 0,
    );
    await _prescriptionDao.insertPrescription(prescription);

    if (endDate != null) {
      await generateSchedules(prescription);
    }

    await _medicationRepository.syncAllNotifications();
    print('🔔 Notifications scheduled for new medication');

    // ===============================
    // 2️ ONLINE FLOW (เหมือน edit)
    // ===============================
    final hasNet = await _connectivity.hasInternet();
    if (!hasNet) return;

    try {
      await _firebaseHelper.uploadCustomMedicine(userId, med);
      await _firebaseHelper.uploadPrescription(userId, prescription);

      await _medicationDao.markAsSynced(medId, userId);
      await _prescriptionDao.markAsSynced(prescriptionId, userId);

      print('☁️ Synced new medication: ${med.medName}');
    } catch (e) {
      print('⚠️ AddMedication sync failed: $e');
      // ไม่ throw → ให้ SyncService เก็บ
    }
  }

Future<void> generateSchedules(
    PrescriptionModel prescription, {
    DateTime? startGenerationFrom,
  }) async {
    // 1. เช็คแค่ startDate กับ timeToNotify ก็พอ (endDate ยอมให้เป็น null ได้เผื่อกินตลอดไป)
    if (prescription.startDate == null ||
        prescription.timeToNotify == null ||
        prescription.medId == null) {
      print("⚠️ Missing required fields for schedule generation");
      return;
    }

    List<String> times = prescription.timeToNotify!
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // 2. กำหนดวันเริ่ม: ถ้ามี startGenerationFrom (เช่น Sync มา) ให้เริ่มจาก "วันนี้"
    // แต่ถ้า "วันนี้" มันเลย "วันจบ" ของยาไปแล้ว ก็ไม่ต้องสร้าง
    DateTime calculationStart = startGenerationFrom ?? DateTime.now();
    
    // แปลง startDate ของยาให้เป็น DateTime
    DateTime prescriptStart = DateTime.parse(prescription.startDate!);

    // จุดเริ่มจริง = มากกว่าระหว่าง (วันนี้ vs วันเริ่มกินยา)
    // เพื่อไม่ให้สร้างย้อนหลังจนรก database
    DateTime actualStart = calculationStart.isAfter(prescriptStart) 
        ? calculationStart 
        : prescriptStart;

    DateTime startDateOnly = DateTime(actualStart.year, actualStart.month, actualStart.day);

    // 3. กำหนดวันจบ: ถ้าไม่มี endDate (กินตลอดไป) ให้สร้างล่วงหน้าสัก 60 วัน หรือ 1 ปี
    // (แล้วค่อยมี logic มาเติมวันหลัง) หรือบังคับ user กรอกวันจบ
    DateTime endDateOnly;
    if (prescription.endDate != null) {
      DateTime end = DateTime.parse(prescription.endDate!);
      endDateOnly = DateTime(end.year, end.month, end.day);
    } else {
      // กรณีไม่มีวันจบ ให้สร้างล่วงหน้า 30 วันไปก่อน (กันบั๊ก)
      endDateOnly = startDateOnly.add(const Duration(days: 30));
    }

    int totalDays = endDateOnly.difference(startDateOnly).inDays + 1;
    
    // ถ้าวันจบ น้อยกว่า วันเริ่ม (คือยาหมดอายุไปแล้ว) ก็ไม่ต้องทำอะไร
    if (totalDays <= 0) {
      print("⚠️ Prescription expired or invalid dates, skipping schedules.");
      return;
    }

    print("📅 Generating schedules for $totalDays days starting $startDateOnly");

    for (int i = 0; i < totalDays; i++) {
      String dateStr = startDateOnly
          .add(Duration(days: i))
          .toIso8601String()
          .substring(0, 10);

      for (final time in times) {
        bool exists = await _scheduleDao.checkScheduleExists(
          prescriptionId: prescription.prescriptionId,
          scheduledDate: dateStr,
          scheduledTime: time,
        );

        if (!exists) {
          await _scheduleDao.insertSchedule(
            ScheduleModel(
              prescriptionId: prescription.prescriptionId,
              scheduledTime: time,
              scheduledDate: dateStr,
              status: 'pending',
            ),
          );
        }
      }
    }
  }

}
