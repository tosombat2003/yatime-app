import 'editmed_service.dart';

class ResumeMedicationService {
  final EditMedicationService _editService = EditMedicationService();

  Future<void> resumeMedication({
    required String userId,
    required String prescriptionId,
    required String medId,
    required DateTime startDate,
    required DateTime endDate,
    String? doseAmount, // เพิ่มเผื่อเปลี่ยนโดส
  }) async {
    final startStr = startDate.toIso8601String().substring(0, 10);
    final endStr = endDate.toIso8601String().substring(0, 10);

    await _editService.editMedication(
      userId: userId,
      prescriptionId: prescriptionId,
      medId: medId,
      startDate: startStr,
      endDate: endStr,
      doseAmount: doseAmount,
      rescheduleFromToday: true, // เพื่อให้ลบตารางงานที่ค้าง (ถ้ามี) และสร้างใหม่
    );
  }
}
