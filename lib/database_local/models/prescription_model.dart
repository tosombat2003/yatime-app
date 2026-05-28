class PrescriptionModel {
  final String prescriptionId;
  final String? userId;
  final String? medId;
  final String? doseAmount;
  final String? startDate;
  final String? endDate;
  final String? instructions;
  final String? timeToNotify;
  final String? source;
  final String? createdAt;
  final int isSynced;
  final String? lastModified;
  final String? syncAt;
  final int isDeleted;
  final String? updatedBy;

  PrescriptionModel({
    required this.prescriptionId,
    this.userId,
    this.medId,
    this.doseAmount,
    this.startDate,
    this.endDate,
    this.instructions,
    this.timeToNotify,
    this.source,
    this.createdAt,
    this.isSynced = 0,
    this.lastModified,
    this.syncAt,
    this.isDeleted = 0,
    this.updatedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'prescription_id': prescriptionId,
      'user_id': userId,
      'med_id': medId,
      'dose_amount': doseAmount,
      'start_date': startDate,
      'end_date': endDate,
      'instructions': instructions,
      'time_to_notify': timeToNotify,
      'source': source,
      'created_at': createdAt,
      'is_synced': isSynced,
      'last_modified': lastModified,
      'sync_at': syncAt,
      'is_deleted': isDeleted,
      'updated_by': updatedBy,
    };
  }

  factory PrescriptionModel.fromMap(Map<String, dynamic> map) {
    return PrescriptionModel(
      prescriptionId: map['prescription_id'],
      userId: map['user_id'],
      medId: map['med_id'],
      doseAmount: map['dose_amount'],
      startDate: map['start_date'],
      endDate: map['end_date'],
      instructions: map['instructions'],
      timeToNotify: map['time_to_notify'],
      source: map['source'],
      createdAt: map['created_at'],
      isSynced: map['is_synced'],
      lastModified: map['last_modified'],
      syncAt: map['sync_at'],
      isDeleted: map['is_deleted'],
      updatedBy: map['updated_by'],
    );
  }
  PrescriptionModel copyWith({
  String? prescriptionId,
  String? userId,
  String? medId,
  String? doseAmount,
  String? startDate,
  String? endDate,
  String? instructions,
  String? timeToNotify,
  String? source,
  String? createdAt,
  int? isSynced,
  String? lastModified,
  String? syncAt,
  int? isDeleted,
  String? updatedBy,
}) {
  return PrescriptionModel(
    prescriptionId: prescriptionId ?? this.prescriptionId,
    userId: userId ?? this.userId,
    medId: medId ?? this.medId,
    doseAmount: doseAmount ?? this.doseAmount,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    instructions: instructions ?? this.instructions,
    timeToNotify: timeToNotify ?? this.timeToNotify,
    source: source ?? this.source,
    createdAt: createdAt ?? this.createdAt,
    isSynced: isSynced ?? this.isSynced,
    lastModified: lastModified ?? this.lastModified,
    syncAt: syncAt ?? this.syncAt,
    isDeleted: isDeleted ?? this.isDeleted,
    updatedBy: updatedBy ?? this.updatedBy,
  );
}
}