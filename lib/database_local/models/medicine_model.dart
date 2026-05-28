class MedicationModel {
  final String medId;
  final String medName;
  final String? medGenericName;
  final String? dosageStrength;
  final String? type;
  final int isCustom;
  final String? ownerUserId;
  final String? createdAt;
  final int isSynced;
  final String? lastModified;
  final String? syncAt;
  final int isDeleted;

  MedicationModel({
    required this.medId,
    required this.medName,
    this.medGenericName,
    this.dosageStrength,
    this.type,
    this.isCustom = 0,
    this.ownerUserId,
    this.createdAt,
    this.isSynced = 0,
    this.lastModified,
    this.syncAt,
    this.isDeleted = 0,
  });

//แก้ไขข้อมูล
  Map<String, dynamic> toMap() {
    return {
      'med_id': medId,
      'med_name': medName,
      'med_generic_name': medGenericName,
      'dosage_strength': dosageStrength,
      'type': type,
      'is_custom': isCustom,
      'owner_user_id': ownerUserId,
      'created_at': createdAt,
      'is_synced': isSynced,
      'last_modified': lastModified,
      'sync_at': syncAt,
      'is_deleted': isDeleted,
    };
  }

//ดึงข้อมูล
  factory MedicationModel.fromMap(Map<String, dynamic> map) {
    return MedicationModel(
      medId: map['med_id'],
      medName: map['med_name'],
      medGenericName: map['med_generic_name'],
      dosageStrength: map['dosage_strength'],
      type: map['type'],
      isCustom: map['is_custom'],
      ownerUserId: map['owner_user_id'],
      createdAt: map['created_at'],
      isSynced: map['is_synced'],
      lastModified: map['last_modified'],
      syncAt: map['sync_at'],
      isDeleted: map['is_deleted'],
    );
  }
  MedicationModel copyWith({
  String? medId,
  String? medName,
  String? medGenericName,
  String? dosageStrength,
  String? type,
  int? isCustom,
  String? ownerUserId,
  String? createdAt,
  int? isSynced,
  String? lastModified,
  String? syncAt,
  int? isDeleted,
}) {
  return MedicationModel(
    medId: medId ?? this.medId,
    medName: medName ?? this.medName,
    medGenericName: medGenericName ?? this.medGenericName,
    dosageStrength: dosageStrength ?? this.dosageStrength,
    type: type ?? this.type,
    isCustom: isCustom ?? this.isCustom,
    ownerUserId: ownerUserId ?? this.ownerUserId,
    createdAt: createdAt ?? this.createdAt,
    isSynced: isSynced ?? this.isSynced,
    lastModified: lastModified ?? this.lastModified,
    syncAt: syncAt ?? this.syncAt,
    isDeleted: isDeleted ?? this.isDeleted,
  );
}
}