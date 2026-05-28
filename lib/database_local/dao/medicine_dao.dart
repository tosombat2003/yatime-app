import 'dart:async';

import 'package:sqflite/sqflite.dart';
import 'package:ya_time/database_local/db_sqlite_helper.dart';
import 'package:ya_time/database_local/models/medicine_model.dart'; // MedicationModel

final DatabaseHelper dbHelper = DatabaseHelper(); 

class MedicationDao {
  final String _tableName = 'medications';
  Future<Database> get _database async => await DatabaseHelper.instance.database;

  Future<int> insertMedication(MedicationModel med) async {
    final db = await _database;
    return await db.insert(_tableName, med.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // เปลี่ยนจาก int เป็น String
  Future<MedicationModel?> getMedicationById(String medId) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(_tableName, where: 'med_id = ?', whereArgs: [medId]);
    return maps.isNotEmpty ? MedicationModel.fromMap(maps.first) : null;
  }

  Future<List<MedicationModel>> getAllMedications() async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(_tableName, where: 'is_deleted = 0');
    return maps.map((map) => MedicationModel.fromMap(map)).toList();
  }
  
  Future<int> updateMedication(MedicationModel med) async {
    final db = await _database;
    // ทุกครั้งที่แก้ ต้องตั้ง is_synced = 0 และอัปเดต last_modified
    final values = med.toMap();
    values['is_synced'] = 0;
    values['last_modified'] = DateTime.now().toIso8601String();

    return await db.update(_tableName, values, where: 'med_id = ?', whereArgs: [med.medId]);
  }

  
  Future<List<MedicationModel>> getUnsyncMedications(String userId) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'is_synced = 0 AND owner_user_id = ?',
      whereArgs: [userId],
    );
    return maps.map((map) => MedicationModel.fromMap(map)).toList();
  }

   //Soft Delete เพื่อให้ Sync ได้
  Future<int> softDeleteMedication(String id) async {
    final db = await _database;
    return await db.update(
      _tableName,
      {
        'is_deleted': 1,
        'is_synced': 0,
        'last_modified': DateTime.now().toIso8601String(),
      },
      where: 'med_id = ?',
      whereArgs: [id],
    );
  }

  Future<List<MedicationModel>> getAllMedicationsIncludingDeleted() async {
    final db = await _database;
    // ไม่ใส่ where is_deleted = 0
    final List<Map<String, dynamic>> maps = await db.query(_tableName); 
    return maps.map((map) => MedicationModel.fromMap(map)).toList();
  }

//hard delete
Future<int> hardDeleteMedication(String id) async {
  final db = await _database;
  return await db.delete(
    _tableName,
    where: 'med_id = ?',
    whereArgs: [id],
  );
}

  Future<void> markAsSynced(String id,String userId) async {
    final db = await _database;
    await db.update(
      _tableName,
      {
        'is_synced': 1,
        'sync_at': DateTime.now().toIso8601String(),
      },
      where: 'med_id = ? AND owner_user_id = ?',
      whereArgs: [id, userId],
    );
  }

// Future<void> upsertMedication(MedicationModel medication) async {
//   final db = await _database;

//   await db.insert(
//     _tableName,
//     medication.toMap(),
//     conflictAlgorithm: ConflictAlgorithm.replace,
//   );
// }

Future<void> upsertMedication(MedicationModel medication, {bool fromCloud = false}) async {
    final db = await _database;
    
    // แปลง Model เป็น Map เพื่อแก้ไขค่า
    final data = medication.toMap();
    
    // ถ้ามาจาก Cloud ให้บังคับ is_synced = 1
    if (fromCloud) {
      data['is_synced'] = 1;
      // ถ้ามี field sync_at ก็อัปเดตด้วยก็ได้
      data['sync_at'] = DateTime.now().toIso8601String(); 
    }

    await db.insert(
      _tableName,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

Future<List<MedicationModel>>getDeletedMedications(String userId) async{
  final db = await _database;
  final List<Map<String, dynamic>> maps = await db.query(
    _tableName,
    where: 'is_deleted = 1 AND owner_user_id = ?',
    whereArgs: [userId],
  );
  return maps.map((map) => MedicationModel.fromMap(map)).toList();
}
}

