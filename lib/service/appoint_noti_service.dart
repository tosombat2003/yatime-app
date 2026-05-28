//import 'package:ya_time/database_local/models/appointments_model.dart';
import 'package:ya_time/database_local/dao/appointments_dao.dart';
import 'package:ya_time/service/notification_service.dart';
import 'package:ya_time/app_session.dart';

class AppointNotificationService {
  final AppointmentDao _appointmentDao = AppointmentDao();
  final NotificationService _notiService = NotificationService();

  Future<void> syncAppointmentNotifications() async {
    final userId = AppSession.instance.getUserId();
    if (userId == null) return;

    print("📅 ดึงข้อมูลการนัดหมาย...");
    
    // ดึงนัดหมายทั้งหมดของ User
    final appointments = await _appointmentDao.getAppointmentsByUserId(userId);
    final now = DateTime.now();

    for (var appt in appointments) {
      if (appt.status == 'completed') continue; // ข้ามอันที่หาหมอเสร็จแล้ว

      // แปลงวันที่และเวลานัดเป็น DateTime
      final DateTime? apptDateTime = _parseApptDateTime(appt.appointmentDate, appt.appointmentTime);
      if (apptDateTime == null || apptDateTime.isBefore(now)) continue;

      // สร้าง ID พื้นฐานจาก hashcode ของ ID (เพราะ appointmentId เป็น String แต่ Noti ใช้ int)
      // ใช้ .abs() เพื่อให้ได้ค่าบวกเสมอ
      final int baseId = appt.appointmentId.hashCode.abs(); 

      // --------------------------------------------------
      // 1. แจ้งเตือนล่วงหน้า 1 วัน (เวลา 20:00 น. ของวันก่อนหน้า)
      // --------------------------------------------------
      final DateTime dayBefore = apptDateTime.subtract(const Duration(days: 1));
      final DateTime notifyDayBefore = DateTime(dayBefore.year, dayBefore.month, dayBefore.day, 18, 0); // 2ทุ่ม

      if (notifyDayBefore.isAfter(now)) {
        await _notiService.scheduleNotification(
          id: baseId + 1, // ID ชุดที่ 1
          title: "พรุ่งนี้มีนัดหาหมอนะคะ 🏥",
          body: "เตรียมเอกสารและพักผ่อนให้เพียงพอนะครับ นัดเวลา ${appt.appointmentTime} น.",
          scheduledTime: notifyDayBefore,
          saveToHistory: true, 
          type: 'appointment', // ระบุประเภท
          payload: 'appoint|${appt.appointmentId}|day_before',
        );
      }

      // --------------------------------------------------
      // 2. แจ้งเตือนก่อนนัด 3 ชั่วโมง (เผื่อเวลาเดินทาง)
      // --------------------------------------------------
      final DateTime notifyBeforeHours = apptDateTime.subtract(const Duration(hours: 3));
      
      if (notifyBeforeHours.isAfter(now)) {
        await _notiService.scheduleNotification(
          id: baseId + 2, // ID ชุดที่ 2
          title: "ใกล้ถึงเวลานัดคุณหมอแล้ว 🚗",
          body: "อีก 3 ชั่วโมงจะถึงเวลานัด (${appt.appointmentTime} น.) เตรียมตัวออกเดินทางได้เลยครับ",
          scheduledTime: notifyBeforeHours,
          saveToHistory: true, 
          type: 'appointment',
          payload: 'appoint|${appt.appointmentId}|3hr_before',
        );
      }

      // --------------------------------------------------
      // 3. ถามไถ่หลังกลับบ้าน (เวลา 17:00 น. ของวันนัด)
      // --------------------------------------------------
      final DateTime notifyAfter = DateTime(apptDateTime.year, apptDateTime.month, apptDateTime.day, 17, 0); // 5โมงเย็น
      
      if (notifyAfter.isAfter(now)) {
        await _notiService.scheduleNotification(
          id: baseId + 3, // ID ชุดที่ 3
          title: "ไปหาหมอมาหรือยังคะ? 😊",
          body: "ถ้ากลับถึงบ้านแล้ว อย่าลืมมากด 'เสร็จสิ้น' ในแอปเพื่อบันทึกประวัตินะคะ",
          scheduledTime: notifyAfter,
          saveToHistory: true, 
          type: 'appointment',
          payload: 'appoint|${appt.appointmentId}|after',
        );
      }
    }
    print("✅ ตั้งแจ้งเตือนนัดหมายเสร็จสิ้น");
  }

  DateTime? _parseApptDateTime(String dateStr, String timeStr) {
    try {
      // dateStr = "2024-01-31", timeStr = "09:00"
      return DateTime.parse("$dateStr $timeStr:00");
    } catch (e) {
      return null;
    }
  }
}