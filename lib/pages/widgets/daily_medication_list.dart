import 'package:flutter/material.dart';
import 'package:ya_time/data_models/medication_item.dart';
import 'package:ya_time/pages/widgets/medicine_card.dart';
import 'package:ya_time/database_local/repositories/medication_repository.dart';

class DailyMedicationList extends StatelessWidget {
  final bool isLoading;
  final Map<String, List<MedicationItem>> medicationsByTime;
  final Future<void> Function() onRefresh;
  final Function(MedicationItem, String) onAction;
  final Function(List<MedicationItem>) onTakeAll;
  final Map<String, GlobalKey> sectionKeys;

  const DailyMedicationList({
    super.key,
    required this.isLoading,
    required this.medicationsByTime,
    required this.onRefresh,
    required this.onAction,
    required this.onTakeAll,
    required this.sectionKeys,
  });

  // Helper: เช็คว่าถึงเวลาหรือยัง (ล่วงหน้า 30 นาที)
  bool _isTimeForSection(List<MedicationItem> items) {
    if (items.isEmpty) return false;
    try {
      // ดึงวันที่และเวลามาจากยาตัวแรกในกลุ่ม
      final item = items.first;
      if (item.schedule.scheduledDate == null) return true;

      // สร้าง DateTime ที่เป็นวันที่และเวลาของยานั้นจริงๆ (ไม่ใช่วันนี้)
      final scheduledDateTime = DateTime.parse('${item.schedule.scheduledDate} ${item.schedule.scheduledTime}:00');
      final now = DateTime.now();
      
      // ส่วนต่างเวลา: ถ้าน้อยกว่าหรือเท่ากับ 30 นาที (เป็นบวกคือก่อนเวลา, เป็นลบคือเลยเวลามาแล้ว)
      final diff = scheduledDateTime.difference(now).inMinutes;
      
      // ยอมให้กดได้ถ้า: อยู่ในช่วง 30 นาทีก่อนถึง หรือ เลยเวลามาแล้ว
      return diff <= 30;
    } catch (e) {
      return true; // กันเหนียว
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.teal),
            SizedBox(height: 16),
            Text('กำลังโหลดข้อมูล...'),
          ],
        ),
      );
    }

    if (medicationsByTime.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.medical_services_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('ไม่มีตารางยาในวันนี้', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: Colors.teal,
      // เปลี่ยนจาก ListView.builder เป็น SingleChildScrollView + Column
      // เพื่อให้เราใช้ GlobalKey ในการ Scroll ได้แม่นยำกว่า
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: medicationsByTime.keys.map((time) {
            final items = medicationsByTime[time]!;
            
            //ผูก Key ไว้ที่แต่ละ Section (เวลา)
            return Container(
              key: sectionKeys[time], // แปะป้ายบอกตำแหน่งตรงนี้
              child: _buildTimeSection(time, items),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTimeSection(String time, List<MedicationItem> items) {
    final int pendingCount = MedicationRepository().getPendingCount(items);
    
    // ตรวจสอบเวลาสำหรับ Section นี้
    final bool canTake = _isTimeForSection(items);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        // Header เวลา
        Row(
          children: [
            Text(time, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: pendingCount > 0 ? Colors.orange[100] : Colors.green[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${items.length} รายการ',
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: pendingCount > 0 ? Colors.orange[900] : Colors.green[900],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // รายการการ์ดยา
        ...items.map((item) {
          final bool isActive = item.schedule.status == 'pending';
          DateTime? scheduledDateTime;
          if (item.schedule.scheduledDate != null) {
            try {
              scheduledDateTime = DateTime.parse('${item.schedule.scheduledDate} ${item.schedule.scheduledTime}:00');
            } catch (_) {}
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: MedicineCard(
              scheduleId: item.schedule.schedId,
              scheduledDateTime: scheduledDateTime,
              name: item.medication.medName,
              genericName: item.medication.medGenericName ?? '',
              amount: item.prescription.doseAmount ?? '',
              dosage: item.medication.dosageStrength ?? 'ไม่ระบุ',
              instructions: item.prescription.instructions ?? '',
              time: time,

              medicineType: item.medication.type, 
              
              isActive: isActive,
              type: MedicineCardFor.actionView,
              status: item.schedule.status,
              onAction: (action) => onAction(item, action),
            ),
          );
        }),

        // ปุ่มกินยาทั้งหมด (Logic ใหม่)
        if (pendingCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(60, 8, 60, 0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                // ถ้ายังไม่ถึงเวลา ให้เป็น null (กดไม่ได้)
                onPressed: canTake ? () => onTakeAll(items) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300], // สีตอนกดไม่ได้
                  disabledForegroundColor: Colors.grey[500],
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: canTake ? 2 : 0,
                ),
                child: Text(
                  canTake 
                    ? "กินยาทั้งหมด ($pendingCount รายการ)" 
                    : "ยังไม่ถึงเวลา ($time)",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );
  }
}