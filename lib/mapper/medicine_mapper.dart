import 'package:cloud_firestore/cloud_firestore.dart';
import '../database_local/models/medicine_model.dart';

class MedicationMapper {
  static Map<String, dynamic> toFirestore(MedicationModel m) {
    return {
      'med_name': m.medName,
      'med_generic_name': m.medGenericName,
      'dosage_strength': m.dosageStrength,
      'type': m.type,
      'is_custom': m.isCustom == 1,
      'owner_user_id': m.ownerUserId,
      
      // แปลง DateTime เป็น Timestamp (Handle null)
      'created_at': m.createdAt != null 
          ? Timestamp.fromDate(DateTime.parse(m.createdAt!)) 
          : FieldValue.serverTimestamp(),
      
      'last_modified': m.lastModified != null
          ? Timestamp.fromDate(DateTime.parse(m.lastModified!))
          : FieldValue.serverTimestamp(),
          
      'is_deleted': m.isDeleted == 1,
    };
  }

  static MedicationModel fromFirestore(Map<String, dynamic> data, String docId) {
    //  Helper Function: ช่วยแปลง Timestamp อย่างปลอดภัย
    String? safeDate(dynamic field) {
      if (field is Timestamp) {
        return field.toDate().toIso8601String();
      }
      return null;
    }

    return MedicationModel(
      medId: docId,
      //  ใช้ ?.toString() ?? '' เพื่อกันค่า Null
      medName: data['med_name']?.toString() ?? 'Unknown Medicine',
      medGenericName: data['med_generic_name']?.toString(),
      dosageStrength: data['dosage_strength']?.toString(),
      type: data['type']?.toString(),
      isCustom: (data['is_custom'] == true) ? 1 : 0,
      ownerUserId: data['owner_user_id']?.toString(),
      
      createdAt: safeDate(data['created_at']),
      lastModified: safeDate(data['last_modified']),
      
      isDeleted: (data['is_deleted'] == true) ? 1 : 0,
      isSynced: 1, //  Set เป็น 1 เสมอเมื่อมาจาก Cloud
    );
  }
}