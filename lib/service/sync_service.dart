import 'package:flutter/material.dart';
import 'package:ya_time/service/connectivity_service.dart';
import 'package:ya_time/database_remote/db_firestore_helper.dart';
import 'package:ya_time/database_local/dao/prescription_dao.dart';
import 'package:ya_time/database_local/dao/appointments_dao.dart';
import 'package:ya_time/database_local/dao/medicine_dao.dart';
import 'package:ya_time/database_local/dao/schedules_dao.dart';
import 'package:ya_time/service/addmed_service.dart';
import 'package:ya_time/database_local/repositories/medication_repository.dart';
//import 'package:ya_time/service/notification_service.dart';
import 'package:ya_time/database_local/dao/user_dao.dart';
import 'package:ya_time/service/appoint_noti_service.dart';
import 'package:ya_time/service/notification_service.dart';

class SyncService {
  final ConnectivityService _connectivityService = ConnectivityService();
  final FirebaseHelper _firebaseHelper = FirebaseHelper();
  final PrescriptionDao _prescriptionDao = PrescriptionDao();
  final AppointmentDao _appointmentDao = AppointmentDao();
  final MedicationDao _medicineDao = MedicationDao();
  final ScheduleDao _scheduleDao = ScheduleDao();
  final AddMedicationService _addMedService = AddMedicationService();
  final MedicationRepository _medicationRepository = MedicationRepository();
  final UserDao _userDao = UserDao();
  final AppointNotificationService _appointNotiService = AppointNotificationService();

  bool _isSyncing = false;
  static DateTime? _lastAutoSyncTime;

  void initReactiveSync(
    String userId, {
    VoidCallback? onSyncStart,
    VoidCallback? onSyncEnd,
  }) {
    _connectivityService.hasInternet().then((hasNet) async {
      await _medicationRepository.syncAllNotifications();
      if (hasNet) {
        await syncAll(userId, onSyncStart: onSyncStart, onSyncEnd: onSyncEnd);
      }
    });

    _connectivityService.onConnectionChanged.listen((isOnline) async {
      if (isOnline && !_isSyncing) {
        await Future.delayed(const Duration(seconds: 3));
        final realInternet = await _connectivityService.hasInternet();
        if (realInternet) {
          await syncAll(userId, onSyncStart: onSyncStart, onSyncEnd: onSyncEnd);
        }
      }
    });
  }

  Future<void> syncAll(
    String userId, {
    VoidCallback? onSyncStart,
    VoidCallback? onSyncEnd,
    bool isManual = false,
  }) async {
    if (_isSyncing) return;

    if (!isManual) {
      if (_lastAutoSyncTime != null &&
          DateTime.now().difference(_lastAutoSyncTime!).inSeconds < 10) {
        return;
      }
      _lastAutoSyncTime = DateTime.now();
    }

    final hasInternet = await _connectivityService.hasInternet();
    if (!hasInternet) return;

    try {
      _isSyncing = true;
      if (onSyncStart != null) onSyncStart();
      print('🔄 Sync Process Started...');

      await _performSync(userId);

      await _medicationRepository.syncAllNotifications();
      await _appointNotiService.syncAppointmentNotifications();
      print('🔔 Notifications (Meds & Appoints) synced');

      print('========== ✅ Sync completed successfully ==========');
    } catch (e) {
      print('❌ Sync error: $e');
    } finally {
      _isSyncing = false;
      if (onSyncEnd != null) onSyncEnd();
    }
  }

  Future<void> _performSync(String userId) async {
    // 1 PUSH DELETED
    final delPrescs = await _prescriptionDao.getDeletedPrescriptions(userId);
    final delMeds = await _medicineDao.getDeletedMedications(userId);
    await _pushDeletedRecords(userId, delPrescs, delMeds);

    await Future.delayed(const Duration(milliseconds: 100));

    await _pushUnsyncedUser(userId);
    // 2 PULL & MERGE
    await _pullAndMergeRemoteData(userId);

    await Future.delayed(const Duration(milliseconds: 100));

    // 3 PUSH UNSYNCED
    final unsyncedMeds = await _medicineDao.getUnsyncMedications(userId);
    final unsyncedPrescs = await _prescriptionDao.getUnsyncPrescriptions(
      userId,
    );
    final unsyncedAppts = await _appointmentDao.getUnsyncAppointments(userId);
    await _pushUnsyncedRecords(
      userId,
      unsyncedMeds,
      unsyncedPrescs,
      unsyncedAppts,
    );
  }

  // --- ลบข้อมูล ---
  Future<void> _pushDeletedRecords(
    String userId,
    List delPrescs,
    List delMeds,
  ) async {
    // 1. จัดการใบสั่งยา (Prescriptions)
    for (final presc in delPrescs) {
      try {
        // เอาออก: if (presc.isSynced == 1) เพราะตอนนี้ is_synced มันเป็น 0 อยู่
        
        // เปลี่ยนเป็น uploadPrescription (เพื่อส่งค่า is_deleted = 1 ขึ้นไป)
        await _firebaseHelper.uploadPrescription(userId, presc);
        
        // อัปเดตสถานะในเครื่องว่า Sync แล้ว (ยังคงเป็น is_deleted=1)
        await _prescriptionDao.markAsSynced(presc.prescriptionId, userId);

        // ลบ Schedules ที่เกี่ยวข้อง (ในเครื่อง)
        await _scheduleDao.deleteSchedulesByPrescriptionId(
          presc.prescriptionId,
        );
        await Future.delayed(const Duration(milliseconds: 20));
      } catch (e) {
        print('⚠️ Push Deleted Presc Error: $e');
      }
    }

    // 2. จัดการยา (Medications)
    for (final med in delMeds) {
      try {
        //  เอาออก: if (med.isSynced == 1)

        // เปลี่ยนเป็น uploadCustomMedicine
        await _firebaseHelper.uploadCustomMedicine(userId, med);

        // อัปเดตสถานะในเครื่อง
        await _medicineDao.markAsSynced(med.medId, userId);
        
        await Future.delayed(const Duration(milliseconds: 20));
      } catch (e) {
        print('⚠️ Push Deleted Med Error: $e');
      }
    }
  }

  // --- อัปโหลดข้อมูล ---
  Future<void> _pushUnsyncedRecords(
    String userId,
    List unsyncedMeds,
    List unsyncedPrescs,
    List unsyncedAppts,
  ) async {
    for (final med in unsyncedMeds) {
      try {
        await _firebaseHelper.uploadCustomMedicine(userId, med);
        await _medicineDao.markAsSynced(med.medId, userId);
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (_) {}
    }

    for (final presc in unsyncedPrescs) {
      try {
        await _firebaseHelper.uploadPrescription(userId, presc);
        await _prescriptionDao.markAsSynced(presc.prescriptionId, userId);
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (_) {}
    }

    for (final appt in unsyncedAppts) {
      try {
        await _firebaseHelper.uploadAppointment(userId, appt);
        await _appointmentDao.markAsSynced(appt.appointmentId, userId);
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (_) {}
    }
  }

  // --- ดึงข้อมูลและ Merge ---
  Future<void> _pullAndMergeRemoteData(String userId) async {
    print('📥 Pulling data from Firebase...');

    final results = await Future.wait([
      _firebaseHelper.fetchPrescriptions(userId),
      _firebaseHelper.fetchCustomMedicines(userId),
      _firebaseHelper.fetchAppointments(userId),
    ]);

    final remotePrescs = results[0] as List<dynamic>;
    final remoteMeds = results[1] as List<dynamic>;
    final remoteAppts = results[2] as List<dynamic>;

    print('📥 Got: ${remotePrescs.length} Prescs, ${remoteMeds.length} Meds');

    final localPrecsMap = await _getAllLocalPrescsAsMap(userId);
    final localMedsMap = await _getAllLocalMedsAsMap(userId);
    final localApptsMap = await _getAllLocalApptsAsMap(userId);

    //MERGE MEDICINES
    for (final remote in remoteMeds) {
      final local = localMedsMap[remote.medId];
      if (local == null ||
          _isNewerRemote(local.lastModified, remote.lastModified)) {
        if (remote.isDeleted == 1) {
          await _medicineDao.hardDeleteMedication(remote.medId);
        } else {
          await _medicineDao.upsertMedication(remote, fromCloud: true);
        }
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }

    //MERGE PRESCRIPTIONS
    bool scheduleChanged = false;

    for (final remote in remotePrescs) {
      final local = localPrecsMap[remote.prescriptionId];
      if (local == null ||
          _isNewerRemote(local.lastModified, remote.lastModified)) {
        
        if (remote.isDeleted == 1) {
          await _prescriptionDao.hardDeletePrescription(remote.prescriptionId);
          
          //เปลี่ยนตรงนี้ 1: เรียกใช้ _cleanupSchedules แทน deleteSchedules...
          await _cleanupSchedules(remote.prescriptionId); 
          
          scheduleChanged = true;
        } else {
          await _prescriptionDao.upsertPrescription(remote, fromCloud: true);
          
          // เปลี่ยนตรงนี้ 2: เรียกใช้ _cleanupSchedules แทน deleteSchedules...
          await _cleanupSchedules(remote.prescriptionId);
          
          await _addMedService.generateSchedules(remote);
          scheduleChanged = true;
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    // 3️ MERGE APPOINTMENTS
    for (final remote in remoteAppts) {
      final local = localApptsMap[remote.appointmentId];
      if (local == null ||
          _isNewerRemote(local.lastModified, remote.lastModified)) {
        await _appointmentDao.upsertAppointment(remote, fromCloud: true);
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }

    // ถ้ามีการเปลี่ยนแปลงตารางเวลา ให้รีเฟรช Notification ทันที
    if (scheduleChanged) {
      print("🔄 Schedules changed via Sync -> Refreshing Notifications...");
      await _medicationRepository.syncAllNotifications();
    }
  }

  //user
  Future<void> _pushUnsyncedUser(String userId) async {
    try {
      final user = await _userDao.getUnsyncedUser(userId);
      if (user != null) {
        print('👤 Found unsynced user profile, uploading...');
        await _firebaseHelper.uploadUser(user);
        await _userDao.markAsSynced(userId);
        print('✅ User profile synced.');
      }
    } catch (e) {
      print('⚠️ Failed to sync user profile: $e');
    }
  }

  // --- Helpers ---
Future<Map<String, dynamic>> _getAllLocalPrescsAsMap(String userId) async {
    //เปลี่ยนมาใช้ getAll...IncludingDeleted แทน
    final prescs = await _prescriptionDao.getAllPrescriptionsIncludingDeleted();
    // กรองเอาเฉพาะของ User นี้ (เผื่อในอนาคตมีหลาย User ในเครื่อง)
    final myPrescs = prescs.where((p) => p.userId == userId).toList();
    return {for (var p in myPrescs) p.prescriptionId: p};
  }

  Future<Map<String, dynamic>> _getAllLocalMedsAsMap(String userId) async {
    //เปลี่ยนมาใช้ getAll...IncludingDeleted แทน
    final meds = await _medicineDao.getAllMedicationsIncludingDeleted();
    final myMeds = meds.where((m) => m.ownerUserId == userId).toList();
    return {for (var m in myMeds) m.medId: m};
  }

  Future<Map<String, dynamic>> _getAllLocalApptsAsMap(String userId) async {
    final appts = await _appointmentDao.getAppointmentsByUserId(userId);
    return {for (var a in appts) a.appointmentId: a};
  }

Future<void> _cleanupSchedules(String prescriptionId) async {
    // 1. ดึงรายการ Schedule ที่กำลังจะโดนลบออกมาก่อน
    final schedules = await _scheduleDao.getSchedulesByPrescriptionId(prescriptionId);
    
    // 2. วนลูปยกเลิกการแจ้งเตือนที่ค้างอยู่ในระบบ Android
    for (var s in schedules) {
      if (s.schedId != null) {
        // ยกเลิกทั้งรอบปกติ และรอบกันลืม (ID + 100000)
        await NotificationService().cancelNotification(s.schedId!);
        await NotificationService().cancelNotification(s.schedId! + 100000);
      }
    }

    // 3. ค่อยลบข้อมูลออกจาก Database
    await _scheduleDao.deleteSchedulesByPrescriptionId(prescriptionId);
  }

  bool _isNewerRemote(String? localTime, String? remoteTime) {
    if (remoteTime == null) return false;
    if (localTime == null) return true;
    try {
      return DateTime.parse(remoteTime).isAfter(DateTime.parse(localTime));
    } catch (e) {
      return false;
    }
  }
}
