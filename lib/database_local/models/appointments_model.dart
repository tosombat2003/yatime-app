class AppointmentModel {
  final String appointmentId;
  final String? userId;
  final String appointmentDate;
  final String appointmentTime;
  final String? doctorName;
  final String? department;
  final String? location;
  final String? appointmentType;
  final String status;
  final String? advice;
  final String? createdAt;
  final int isSynced;
  final String? lastModified;
  final String? syncAt;

  AppointmentModel({
    required this.appointmentId,
    this.userId,
    required this.appointmentDate,
    required this.appointmentTime,
    this.doctorName,
    this.department,
    this.location,
    this.appointmentType,
    this.status = 'scheduled',
    this.advice,
    this.createdAt,
    this.isSynced = 0,
    this.lastModified,
    this.syncAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'appointment_id': appointmentId,
      'user_id': userId,
      'appointment_date': appointmentDate,
      'appointment_time': appointmentTime,
      'doctor_name': doctorName,
      'department': department,
      'location': location,
      'appointment_type': appointmentType,
      'status': status,
      'advice': advice,
      'created_at': createdAt,
      'is_synced': isSynced,
      'last_modified': lastModified,
      'sync_at': syncAt,
    };
  }

  factory AppointmentModel.fromMap(Map<String, dynamic> map) {
    return AppointmentModel(
      appointmentId: map['appointment_id'],
      userId: map['user_id'],
      appointmentDate: map['appointment_date'],
      appointmentTime: map['appointment_time'],
      doctorName: map['doctor_name'],
      department: map['department'],
      location: map['location'],
      appointmentType: map['appointment_type'],
      status: map['status'],
      advice: map['advice'],
      createdAt: map['created_at'],
      isSynced: map['is_synced'],
      lastModified: map['last_modified'],
      syncAt: map['sync_at'],
    );
  }
}