class ScheduleModel {
  final int? schedId;
  final String prescriptionId; 
  final String scheduledTime;
  final String? scheduledDate;
  final String status;
  final String? actualTakenTime;

  ScheduleModel({
    this.schedId,
    required this.prescriptionId, //บังคับใส่ เพราะเป็น Foreign Key สำคัญ
    required this.scheduledTime,
    this.scheduledDate,
    this.status = 'pending',
    this.actualTakenTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'sched_id': schedId,
      'prescription_id': prescriptionId,
      'scheduled_time': scheduledTime,
      'scheduled_date': scheduledDate,
      'status': status,
      'actual_taken_time': actualTakenTime,
    };
  }

  factory ScheduleModel.fromMap(Map<String, dynamic> map) {
    return ScheduleModel(
      schedId: map['sched_id'] as int?,
      // แก้จาก int เป็น String ให้ตรงกับ UUID ใน DB
      prescriptionId: map['prescription_id'] as String, 
      scheduledTime: map['scheduled_time'] as String,
      scheduledDate: map['scheduled_date'] as String?,
      status: map['status'] as String? ?? 'pending',
      actualTakenTime: map['actual_taken_time'] as String?,
    );
  }
  
  // แก้ไข DataType ใน copyWith ให้เป็น String ทั้งหมด
  ScheduleModel copyWith({
    int? schedId,
    String? prescriptionId, // เปลี่ยนจาก int? เป็น String?
    String? scheduledTime,
    String? scheduledDate,
    String? status,
    String? actualTakenTime,
  }) {
    return ScheduleModel(
      schedId: schedId ?? this.schedId,
      prescriptionId: prescriptionId ?? this.prescriptionId,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      status: status ?? this.status,
      actualTakenTime: actualTakenTime ?? this.actualTakenTime,
    );
  }
}