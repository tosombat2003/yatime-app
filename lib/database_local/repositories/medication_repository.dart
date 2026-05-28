import 'package:ya_time/database_local/dao/schedules_dao.dart';
import 'package:ya_time/database_local/dao/medicine_dao.dart';
import 'package:ya_time/database_local/dao/prescription_dao.dart';
import 'package:ya_time/database_local/models/schedules_model.dart';
import 'package:ya_time/database_local/models/medicine_model.dart';
import 'package:ya_time/database_local/models/prescription_model.dart';
import 'package:ya_time/data_models/medication_item.dart';
import 'package:ya_time/service/addmed_service.dart';
import 'package:ya_time/service/notification_service.dart';
import 'package:ya_time/database_local/db_sqlite_helper.dart';

class MedicationRepositoryException implements Exception {
  final String message;
  final dynamic originalError;

  MedicationRepositoryException(this.message, [this.originalError]);

  @override
  String toString() =>
      'MedicationRepositoryException: $message${originalError != null ? " - $originalError" : ""}';
}

class MedicationRepository {
  final ScheduleDao _scheduleDao = ScheduleDao();
  final MedicationDao _medicineDao = MedicationDao();
  final PrescriptionDao _prescriptionDao = PrescriptionDao();

  // ========================================================
  // 🧹 ฟังก์ชันผู้ช่วย: กวาดล้างแจ้งเตือนทั้งหมดของ Schedule นี้
  // ========================================================
  Future<void> _cancelRelatedNotifications(int scheduleId) async {
    // 1. ยกเลิกแจ้งเตือนรอบปกติ
    await NotificationService().cancelNotification(scheduleId);
    
    // 2. ยกเลิกแจ้งเตือน "กันลืม"
    await NotificationService().cancelNotification(scheduleId + 100000);
    
    // 3. ยกเลิกแจ้งเตือน "เลื่อน" (Snooze) เผื่อผู้ใช้เคยกดเลื่อนเอาไว้
    await NotificationService().cancelNotification(scheduleId + 5001);
    await NotificationService().cancelNotification(scheduleId + 5002);
    await NotificationService().cancelNotification(scheduleId + 5003);
  }
  // ========================================================

  Future<Map<String, List<MedicationItem>>> getMedicationsByDate(
    DateTime date,
  ) async {
    try {
      print(
        '🔵 Repository: กำลังดึงข้อมูลยาวันที่ ${date.toString().split(' ')[0]}',
      );

      final result = await _fetchMedicationsInternal(date);

      print('✅ Repository: ดึงข้อมูลสำเร็จ ${result.length} ช่วงเวลา');
      return result;
    } catch (error, stackTrace) {
      print("❌ getMedicationsByDate Error: $error");
      print("Stack Trace: $stackTrace");
      return {};
    }
  }

  Future<Map<String, List<MedicationItem>>> _fetchMedicationsInternal(
    DateTime date,
  ) async {
    try {
      final String dateStr = date.toString().split(' ')[0];
      final startTime = DateTime.now();

      final List<ScheduleModel> schedules = await _scheduleDao
          .getSchedulesByDate(dateStr);

      if (schedules.isEmpty) {
        return {};
      }

      final List<MedicationItem> items = [];

      for (final schedule in schedules) {
        final item = await _getMedicationItem(schedule);
        if (item != null) {
          items.add(item);
        }
      }

      print(
        '✅ ประมวลผลเสร็จ: ${items.length} รายการ (${DateTime.now().difference(startTime).inMilliseconds}ms)',
      );

      final grouped = _groupByTime(items);
      return grouped;
    } catch (error, stackTrace) {
      print('❌ _fetchMedicationsInternal Error: $error');
      print('Stack Trace: $stackTrace');
      rethrow;
    }
  }

  Future<MedicationItem?> _getMedicationItem(ScheduleModel schedule) async {
    try {
      final PrescriptionModel? prescription = await _prescriptionDao
          .getPrescriptionById(schedule.prescriptionId);

      if (prescription == null || prescription.medId == null) return null;

      final MedicationModel? medication = await _medicineDao.getMedicationById(
        prescription.medId!,
      );

      if (medication == null) return null;

      return MedicationItem(
        schedule: schedule,
        prescription: prescription,
        medication: medication,
      );
    } catch (error) {
      print(
        "⚠️ _getMedicationItem Error for schedule ${schedule.schedId}: $error",
      );
      return null;
    }
  }

  Future<List<MedicationItem>> getCurrentMedications(String userId) async {
    try {
      final List<PrescriptionModel> prescriptions = await _prescriptionDao
          .getPrescriptionsByUserId(userId);

      final DateTime now = DateTime.now();
      final List<MedicationItem> items = [];

      for (var prescription in prescriptions) {
        if (_isPrescriptionActive(prescription, now)) {
          final MedicationItem? item = await _getMedicationItemForInfo(
            prescription,
          );
          if (item != null) {
            items.add(item);
          }
        }
      }

      items.sort((a, b) {
        return (b.prescription.createdAt ?? "").compareTo(
          a.prescription.createdAt ?? "",
        );
      });

      return items;
    } catch (error) {
      print("❌ getCurrentMedications Error: $error");
      throw MedicationRepositoryException("ไม่สามารถดึงยาปัจจุบันได้", error);
    }
  }

  Future<List<MedicationItem>> getUsedMedications(String userId) async {
    try {
      final List<PrescriptionModel> prescriptions = await _prescriptionDao
          .getPrescriptionsByUserId(userId);

      final DateTime now = DateTime.now();
      final List<MedicationItem> items = [];

      for (var prescription in prescriptions) {
        if (_isPrescriptionExpired(prescription, now)) {
          final MedicationItem? item = await _getMedicationItemForInfo(
            prescription,
          );
          if (item != null) {
            items.add(item);
          }
        }
      }

      items.sort((a, b) {
        return (b.prescription.createdAt ?? "").compareTo(
          a.prescription.createdAt ?? "",
        );
      });

      return items;
    } catch (error) {
      print("❌ getUsedMedications Error: $error");
      throw MedicationRepositoryException("ไม่สามารถดึงประวัติยาได้", error);
    }
  }

  Future<void> markAsPending(int scheduleId) async {
    try {
      await _scheduleDao.updateScheduleStatus(
        scheduleId: scheduleId,
        newStatus: 'pending',
        actualTakenTime: null,
      );
      await syncAllNotifications();
    } catch (error) {
      print("❌ markAsPending Error: $error");
      throw MedicationRepositoryException("ไม่สามารถย้อนสถานะได้", error);
    }
  }

  Future<void> markAsTaken(int scheduleId, {String? takenTime}) async {
    try {
      await _scheduleDao.updateScheduleStatus(
        scheduleId: scheduleId,
        newStatus: 'taken',
        actualTakenTime: takenTime ?? DateTime.now().toIso8601String(),
      );

      // กวาดล้างแจ้งเตือนทั้งหมดของยานี้
      await _cancelRelatedNotifications(scheduleId);
      
      //สำคัญมาก: สั่งคำนวณแจ้งเตือนใหม่ เพื่อหา "หัวหน้ากลุ่ม" คนใหม่ให้ยาที่ยังไม่ได้กิน
      await syncAllNotifications(); 
    } catch (error) {
      print("❌ markAsTaken Error: $error");
      throw MedicationRepositoryException("ไม่สามารถบันทึกการกินยาได้", error);
    }
  }

  Future<void> markAsSkipped(int scheduleId) async {
    try {
      await _scheduleDao.updateScheduleStatus(
        scheduleId: scheduleId,
        newStatus: 'skipped',
        actualTakenTime: null,
      );
      
      await _cancelRelatedNotifications(scheduleId);
      await syncAllNotifications();
    } catch (error) {
      print("❌ markAsSkipped Error: $error");
      throw MedicationRepositoryException("ไม่สามารถข้ามยาได้", error);
    }
  }

  Future<int> markAllAsTaken(List<MedicationItem> items) async {
    try {
      int count = 0;
      final String now = DateTime.now().toIso8601String();
      for (var item in items) {
        if (item.schedule.status == 'pending' &&
            item.schedule.schedId != null) {
          await _scheduleDao.updateScheduleStatus(
            scheduleId: item.schedule.schedId!,
            newStatus: 'taken',
            actualTakenTime: now,
          );
          
          await _cancelRelatedNotifications(item.schedule.schedId!);
          count++;
        }
      }
      await syncAllNotifications();
      return count;
    } catch (error) {
      print("❌ markAllAsTaken Error: $error");
      throw MedicationRepositoryException(
        "ไม่สามารถบันทึกการกินยาทั้งหมดได้",
        error,
      );
    }
  }

  //auto skip
  Future<void> autoMarkAsMissed() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();

      final List<Map<String, dynamic>> maps = await db.query(
        'schedules',
        where: 'status = ?',
        whereArgs: ['pending'],
      );

      final List<ScheduleModel> pendings = maps
          .map((m) => ScheduleModel.fromMap(m))
          .toList();

      int updatedCount = 0;

      for (var schedule in pendings) {
        if (schedule.scheduledDate == null) continue;

        final scheduleTime = DateTime.parse(
          "${schedule.scheduledDate} ${schedule.scheduledTime}",
        );

        final diff = now.difference(scheduleTime).inMinutes;

        if (diff > 90) {
          await _scheduleDao.updateScheduleStatus(
            scheduleId: schedule.schedId!,
            newStatus: 'skipped', 
            actualTakenTime: null,
          );

          if (schedule.schedId != null) {
            // ✅ เปลี่ยนมากวาดล้างให้หมดเหมือนกัน
            await _cancelRelatedNotifications(schedule.schedId!);
          }
          updatedCount++;
        }
      }

      if (updatedCount > 0) {
        print(
          "Auto-Clean: เปลี่ยนสถานะเป็น Missed ย้อนหลังจำนวน $updatedCount รายการ",
        );
      }
    } catch (e) {
      print("❌ AutoMarkAsMissed Error: $e");
    }
  }

  int getPendingCount(List<MedicationItem> items) {
    return items.where((item) => item.schedule.status == 'pending').length;
  }

  Future<MedicationItem?> _getMedicationItemForInfo(
    PrescriptionModel prescription,
  ) async {
    try {
      if (prescription.prescriptionId == '') return null;

      final String medId = prescription.medId!;
      final MedicationModel? medication = await _medicineDao.getMedicationById(
        medId,
      );

      if (medication == null) return null;

      final String prescriptionId = prescription.prescriptionId;
      final List<ScheduleModel> schedules = await _scheduleDao
          .getSchedulesByPrescriptionId(prescriptionId);

      final List<String> uniqueTimes =
          schedules
              .map((s) => s.scheduledTime)
              .where((t) => t.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      final String timeDisplay = uniqueTimes.isEmpty
          ? "-"
          : uniqueTimes.join(' | ');

      final ScheduleModel dummySchedule = ScheduleModel(
        prescriptionId: prescription.prescriptionId,
        scheduledTime: timeDisplay,
        status: 'info',
      );

      return MedicationItem(
        schedule: dummySchedule,
        prescription: prescription,
        medication: medication,
      );
    } catch (error) {
      return null;
    }
  }

  Map<String, List<MedicationItem>> _groupByTime(List<MedicationItem> items) {
    final Map<String, List<MedicationItem>> grouped = {};
    for (var item in items) {
      final String timeKey = item.time;
      if (!grouped.containsKey(timeKey)) {
        grouped[timeKey] = [];
      }
      grouped[timeKey]!.add(item);
    }
    final sortedKeys = grouped.keys.toList()..sort();
    return {for (var key in sortedKeys) key: grouped[key]!};
  }

  bool _isPrescriptionActive(PrescriptionModel p, DateTime now) {
    if (p.endDate == null) return true;
    final DateTime end = DateTime.parse(p.endDate!);
    final DateTime endOnly = DateTime(end.year, end.month, end.day);
    final DateTime today = DateTime(now.year, now.month, now.day);
    return !endOnly.isBefore(today);
  }

  bool _isPrescriptionExpired(PrescriptionModel p, DateTime now) {
    if (p.endDate == null) return false;
    final DateTime end = DateTime.parse(p.endDate!);
    final DateTime endOnly = DateTime(end.year, end.month, end.day);
    final DateTime today = DateTime(now.year, now.month, now.day);
    return endOnly.isBefore(today);
  }

  Future<void> rescheduleMedication(PrescriptionModel prescription) async {
    try {
      final AddMedicationService addMedService = AddMedicationService();
      final DateTime now = DateTime.now();
      final String todayStr = now.toIso8601String().split('T')[0];

      await _scheduleDao.deleteFuturePendingSchedules(
        prescription.prescriptionId,
        todayStr,
      );

      await addMedService.generateSchedules(
        prescription,
        startGenerationFrom: now,
      );
    } catch (error) {
      print("❌ rescheduleMedication Error: $error");
      rethrow;
    }
  }

  Future<void> syncAllNotifications() async {
    try {
      print('🔵 เริ่ม Sync Notifications (แบบจัดกลุ่มตามเวลา)...');
      final String todayStr = DateTime.now().toString().split(' ')[0];
      final db = await DatabaseHelper.instance.database;

      final List<Map<String, dynamic>> maps = await db.query(
        'schedules',
        where: 'status = ? AND scheduled_date >= ?',
        whereArgs: ['pending', todayStr],
      );

      final List<ScheduleModel> pendingSchedules = maps
          .map((map) => ScheduleModel.fromMap(map))
          .toList();

      Map<String, List<MedicationItem>> groupedSchedules = {};
      
      for (var schedule in pendingSchedules) {
        final MedicationItem? item = await _getMedicationItem(schedule);
        if (item == null) continue;

        String dateTimeKey = "${schedule.scheduledDate} ${schedule.scheduledTime}";
        if (!groupedSchedules.containsKey(dateTimeKey)) {
          groupedSchedules[dateTimeKey] = [];
        }
        groupedSchedules[dateTimeKey]!.add(item);
      }

      int countGroup = 0;
      final now = DateTime.now();

      for (var entry in groupedSchedules.entries) {
        DateTime scheduledDateTime = DateTime.parse(entry.key);
        List<MedicationItem> itemsInGroup = entry.value;

        if (scheduledDateTime.isBefore(now)) continue;

        int representativeId = itemsInGroup.first.schedule.schedId!;
        
        List<String> medNames = itemsInGroup.map((e) => e.medication.medName).toList();
        String medNamesText = medNames.join(', ');

        String normalBody = itemsInGroup.length == 1
            ? "ยา: $medNamesText"
            : "เวลา ${itemsInGroup.first.schedule.scheduledTime} น. มี ${itemsInGroup.length} รายการ: $medNamesText";

        String missedBody = itemsInGroup.length == 1
            ? "อย่าลืมทานยา $medNamesText นะคะ"
            : "อย่าลืมทานยา ${itemsInGroup.length} รายการนะคะ: $medNamesText";

        await NotificationService().scheduleNotification(
          id: representativeId,
          title: "ได้เวลาทานยาแล้วค่ะ 💊",
          body: normalBody,
          scheduledTime: scheduledDateTime,
          saveToHistory: false, 
          type: 'medication',
          payload: representativeId.toString(),
        );

        final int missedNotiId = representativeId + 100000;
        final DateTime missedTime = scheduledDateTime.add(
          const Duration(minutes: 60), // แจ้งเตือนกันลืมหลังเวลานัด 1 ชั่วโมง
        );

        if (missedTime.isAfter(now)) {
          await NotificationService().scheduleNotification(
            id: missedNotiId,
            title: "มื้อนี้คุณลืมทานยาหรือเปล่าคะ?",
            body: missedBody, // ใช้ข้อความที่ปรับให้เนียนแล้ว
            scheduledTime: missedTime,
            payload: 'missed|$representativeId', 
            saveToHistory: true,
            type: 'missed_med',
          );
        }
        
        countGroup++;
      }
      print("✅ Sync Notifications สำเร็จ: ตั้งแจ้งเตือนทั้งหมด $countGroup รอบเวลา");
    } catch (error) {
      print("❌ Sync Notifications Error: $error");
    }
  }
}