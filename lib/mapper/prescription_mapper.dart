import 'package:cloud_firestore/cloud_firestore.dart';
import '../database_local/models/prescription_model.dart';

class PrescriptionMapper {
  static Map<String, dynamic> toFirestore(PrescriptionModel p) {
    return {
      'user_id': p.userId,
      'med_id': p.medId,
      'dose_amount': p.doseAmount,
      'instructions': p.instructions,
      'time_to_notify': p.timeToNotify != null && p.timeToNotify!.isNotEmpty
          ? p.timeToNotify!.split(',').map((e) => e.trim()).toList()
          : [],
      'source': p.source,
      'updated_by': p.updatedBy,
      
      'start_date': p.startDate != null
          ? Timestamp.fromDate(DateTime.parse(p.startDate!))
          : null,
      'end_date': p.endDate != null
          ? Timestamp.fromDate(DateTime.parse(p.endDate!))
          : null,
      'created_at': p.createdAt != null
          ? Timestamp.fromDate(DateTime.parse(p.createdAt!))
          : Timestamp.now(),
      'last_modified': p.lastModified != null
          ? Timestamp.fromDate(DateTime.parse(p.lastModified!))
          : FieldValue.serverTimestamp(),
          
      'is_deleted': p.isDeleted == 1,
    };
  }

  static PrescriptionModel fromFirestore(Map<String, dynamic> data, String docId) {
     //  Helper สำหรับ Date
    String? safeDateStr(dynamic field) {
      if (field is Timestamp) {
        return field.toDate().toIso8601String().split('T')[0];
      }
      return null;
    }
    String? safeDateTimeStr(dynamic field) {
      if (field is Timestamp) {
        return field.toDate().toIso8601String();
      }
      return null;
    }

    return PrescriptionModel(
      prescriptionId: docId,
      userId: data['user_id']?.toString() ?? '',
      medId: data['med_id']?.toString(),
      doseAmount: data['dose_amount']?.toString(),
      instructions: data['instructions']?.toString(),
      
      // Handle List<dynamic> อย่างปลอดภัย
      timeToNotify: data['time_to_notify'] is List
          ? (data['time_to_notify'] as List).map((e) => e.toString()).join(',')
          : null,
          
      source: data['source']?.toString(),
      updatedBy: data['updated_by']?.toString(),
      
      startDate: safeDateStr(data['start_date']),
      endDate: safeDateStr(data['end_date']),
      
      createdAt: safeDateTimeStr(data['created_at']),
      lastModified: safeDateTimeStr(data['last_modified']),
      
      isDeleted: data['is_deleted'] == true ? 1 : 0,
      isSynced: 1,
    );
  }
}