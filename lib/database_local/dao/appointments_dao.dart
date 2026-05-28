import 'package:sqflite/sqflite.dart';
import 'package:ya_time/database_local/db_sqlite_helper.dart';
import 'package:ya_time/database_local/models/appointments_model.dart';

final DatabaseHelper dbHelper = DatabaseHelper(); 

class AppointmentDao {
  final String _tableName = 'appointments';
  Future<Database> get _database async => await DatabaseHelper.instance.database;

  Future<int> insertAppointment(AppointmentModel appointment) async {
    final db = await _database;
    return await db.insert(_tableName, appointment.toMap());
  }

  Future<AppointmentModel?> getAppointmentById(String id) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(_tableName, where: 'appointment_id = ?', whereArgs: [id]);
    return maps.isNotEmpty ? AppointmentModel.fromMap(maps.first) : null;
  }

  Future<List<AppointmentModel>> getAppointmentsByUserId(String userId) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'appointment_date ASC, appointment_time ASC',
    );
    return maps.map((map) => AppointmentModel.fromMap(map)).toList();
  }
  
  Future<int> updateAppointmentStatus({required String id, required String newStatus}) async {
    final db = await _database;
    return await db.update(
      _tableName,
      {
        'status': newStatus, 
        'is_synced': 0, // ต้องซิงค์สถานะใหม่ไปบอกหมอ
        'last_modified': DateTime.now().toIso8601String()
      },
      where: 'appointment_id = ?',
      whereArgs: [id],
    );
  }

  Future<List<AppointmentModel>> getUnsyncAppointments(String userId) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'is_synced = 0 AND user_id = ?',
      whereArgs: [userId],
    );
    return maps.map((map) => AppointmentModel.fromMap(map)).toList();
  }

  Future<void> markAsSynced(String id, String userId) async {
    final db = await _database;
    await db.update(
      _tableName,
      {
        'is_synced': 1,
        'sync_at': DateTime.now().toIso8601String(),
      },
      where: 'appointment_id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }
// Future<void> upsertAppointment(AppointmentModel appointment) async {
//   final db = await _database;

//   await db.insert(
//     _tableName,
//     appointment.toMap(),
//     conflictAlgorithm: ConflictAlgorithm.replace,
//   );
// }

Future<void> upsertAppointment(AppointmentModel appointment, {bool fromCloud = false}) async {
    final db = await _database;
    
    final data = appointment.toMap();
    
    //บังคับ Synced ถ้ามาจาก Cloud
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


}