import 'package:sqflite/sqflite.dart';
import 'package:ya_time/database_local/db_sqlite_helper.dart';
import 'package:ya_time/database_local/models/prescription_model.dart';

final DatabaseHelper dbHelper = DatabaseHelper();

class PrescriptionDao {
  final String _tableName = 'prescriptions';
  Future<Database> get _database async =>
      await DatabaseHelper.instance.database;

  Future<int> insertPrescription(PrescriptionModel prescription) async {
    final db = await _database;
    return await db.insert(_tableName, prescription.toMap());
  }

  Future<PrescriptionModel?> getPrescriptionById(String id) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'prescription_id = ? AND is_deleted = 0',
      whereArgs: [id],
      orderBy: 'created_at DESC',
    );
    return maps.isNotEmpty ? PrescriptionModel.fromMap(maps.first) : null;
  }

  Future<List<PrescriptionModel>> getPrescriptionsByUserId(
    String userId,
  ) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'user_id = ? AND is_deleted = 0',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => PrescriptionModel.fromMap(map)).toList();
  }

  Future<int> updatePrescription(PrescriptionModel prescription) async {
    final db = await _database;
    // ทุกครั้งที่แก้ ต้องตั้ง is_synced = 0 และอัปเดต last_modified
    final values = prescription.toMap();
    values['is_synced'] = 0;
    values['last_modified'] = DateTime.now().toIso8601String();

    return await db.update(
      _tableName,
      values,
      where: 'prescription_id = ?',
      whereArgs: [prescription.prescriptionId],
    );
  }

  //Soft Delete เพื่อให้ Sync ได้
  Future<int> softDeletePrescription(String id) async {
    final db = await _database;
    return await db.update(
      _tableName,
      {
        'is_deleted': 1,
        'is_synced': 0,
        'last_modified': DateTime.now().toIso8601String(),
      },
      where: 'prescription_id = ?',
      whereArgs: [id],
    );
  }

//hard delete
Future<int> hardDeletePrescription(String id) async {
  final db = await _database;
  return await db.delete(
    _tableName,
    where: 'prescription_id = ?',
    whereArgs: [id],
  );
}

Future<List<PrescriptionModel>> getAllPrescriptionsIncludingDeleted() async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(_tableName);
    return maps.map((map) => PrescriptionModel.fromMap(map)).toList();
  }

  Future<List<PrescriptionModel>> getUnsyncPrescriptions(String userId) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'is_synced = 0 AND user_id = ?',
      whereArgs: [userId],
    );
    return maps.map((map) => PrescriptionModel.fromMap(map)).toList();
  }

  Future<void> markAsSynced(String id, String userId) async {
    final db = await _database;
    await db.update(
      _tableName,
      {'is_synced': 1, 'sync_at': DateTime.now().toIso8601String()},
      where: 'prescription_id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

// Future<void> upsertPrescription(PrescriptionModel prescription) async {
//   final db = await _database;

//   await db.insert(
//     _tableName,
//     prescription.toMap(),
//     conflictAlgorithm: ConflictAlgorithm.replace,
//   );
// }

Future<void> upsertPrescription(PrescriptionModel prescription, {bool fromCloud = false}) async {
    final db = await _database;
    
    final data = prescription.toMap();
    
    //  บังคับ Synced ถ้ามาจาก Cloud
    if (fromCloud) {
      data['is_synced'] = 1;
      data['sync_at'] = DateTime.now().toIso8601String();
    }

    await db.insert(
      _tableName,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }


Future<List<PrescriptionModel>>getDeletedPrescriptions(String userId) async{
  final db = await _database;
  final List<Map<String, dynamic>> maps = await db.query(
    _tableName,
    where: 'is_deleted = 1 AND user_id = ?',
    whereArgs: [userId],
  );
  return maps.map((map) => PrescriptionModel.fromMap(map)).toList();
}

}
