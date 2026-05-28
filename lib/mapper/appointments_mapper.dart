import 'package:cloud_firestore/cloud_firestore.dart';
import '../database_local/models/appointments_model.dart';

class AppointmentMapper {
  static Map<String, dynamic> toFirestore(AppointmentModel a) {
    return {
      'user_id': a.userId,
      'doctor_name': a.doctorName,
      'department': a.department,
      'location': a.location,
      'appointment_type': a.appointmentType,
      'status': a.status,
      'advice': a.advice,
      'appointment_date': Timestamp.fromDate(DateTime.parse(a.appointmentDate)),
      'appointment_time': a.appointmentTime,
      'created_at': a.createdAt != null 
          ? Timestamp.fromDate(DateTime.parse(a.createdAt!))
          : FieldValue.serverTimestamp(),
      'last_modified': FieldValue.serverTimestamp(),
    };
  }

  static AppointmentModel fromFirestore(Map<String, dynamic> data, String docId) {
    //  Helper ป้องกัน Crash
    String safeDate(dynamic field) {
      if (field is Timestamp) {
        return field.toDate().toIso8601String().split('T')[0];
      }
      return DateTime.now().toIso8601String().split('T')[0]; // Default กันตาย
    }
    String safeDateTime(dynamic field) {
      if (field is Timestamp) {
        return field.toDate().toIso8601String();
      }
      return DateTime.now().toIso8601String(); // Default กันตาย
    }

    return AppointmentModel(
      appointmentId: docId,
      userId: data['user_id']?.toString() ?? '',
      doctorName: data['doctor_name']?.toString() ?? 'Unknown Doctor',
      department: data['department']?.toString(),
      location: data['location']?.toString(),
      appointmentType: data['appointment_type']?.toString(),
      status: data['status'].toString(),
      advice: data['advice']?.toString(),

      appointmentDate: safeDate(data['appointment_date']),
      appointmentTime: data['appointment_time']?.toString() ?? '00:00',

      createdAt: safeDateTime(data['created_at']),
      lastModified: safeDateTime(data['last_modified']),
      
      isSynced: 1,
    );
  }
}