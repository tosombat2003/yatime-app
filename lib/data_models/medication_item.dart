import 'package:ya_time/database_local/models/schedules_model.dart';
import 'package:ya_time/database_local/models/medicine_model.dart';
import 'package:ya_time/database_local/models/prescription_model.dart';

/// Model สำหรับเก็บข้อมูลยาที่รวมจาก 3 ตาราง
/// ใช้สำหรับแสดงผลใน UI
class MedicationItem {
  final ScheduleModel schedule;
  final PrescriptionModel prescription;
  final MedicationModel medication;

  MedicationItem({
    required this.schedule,
    required this.prescription,
    required this.medication,
  });

  // Helper methods สำหรับ ui
  String get name => medication.medName ;
  String get genericName => medication.medGenericName ?? '';
  String get dosage => medication.dosageStrength ?? 'ไม่ระบุ';
  String get amount => prescription.doseAmount ?? '';
  String get instructions => prescription.instructions ?? '';
  String get time => schedule.scheduledTime;
  String get status => schedule.status;
}