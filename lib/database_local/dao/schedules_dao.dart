import 'package:sqflite/sqflite.dart';
import 'package:ya_time/database_local/db_sqlite_helper.dart';
import 'package:ya_time/database_local/models/schedules_model.dart';

final DatabaseHelper dbHelper = DatabaseHelper();

class ScheduleDao {
  final String _tableName = 'schedules';
  Future<Database> get _database async => await DatabaseHelper.instance.database;

  Future<int> insertSchedule(ScheduleModel schedule) async {
    final db = await _database;
    return await db.insert(_tableName, schedule.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ค้นหาตาม UUID ของใบสั่งยา
  Future<List<ScheduleModel>> getSchedulesByPrescriptionId(String prescriptionId) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'prescription_id = ?',
      whereArgs: [prescriptionId],
      orderBy: 'scheduled_date ASC, scheduled_time ASC',
    );
    return maps.map((map) => ScheduleModel.fromMap(map)).toList();
  }

  // Future<List<ScheduleModel>> getSchedulesByDate(String date) async {
  //   final db = await _database;
  //   final List<Map<String, dynamic>> maps = await db.query(
  //     _tableName,
  //     where: 'scheduled_date = ?',
  //     whereArgs: [date],
  //     orderBy: 'scheduled_time ASC',
  //   );
  //   return maps.map((map) => ScheduleModel.fromMap(map)).toList();
  // }

Future<List<ScheduleModel>> getSchedulesByDate(String date) async {
  try {
    print('🔵 DAO: กำลังดึง schedules สำหรับวันที่: $date');
    
    final db = await _database;
    
    //เพิ่ม LIMIT 100 เพื่อป้องกันข้อมูลล้น
    final List<Map<String, dynamic>> maps = await db.query(
      'schedules',
      where: 'scheduled_date = ?',
      whereArgs: [date],
      orderBy: 'scheduled_time ASC',
      limit: 100, //เพิ่มนี้
    );

    print('✅ DAO: พบ ${maps.length} schedules');

    return maps.map((map) => ScheduleModel.fromMap(map)).toList();
  } catch (e, stackTrace) {
    print('❌ DAO Error: $e');
    print('Stack Trace: $stackTrace');
    return [];
  }
}
  Future<int> updateScheduleStatus({
    required int scheduleId, // ID ในเครื่องเป็น int
    required String newStatus,
    String? actualTakenTime,
  }) async {
    final db = await _database;
    return await db.update(
      _tableName,
      {
        'status': newStatus,
        'actual_taken_time': actualTakenTime ?? DateTime.now().toIso8601String(),
      },
      where: 'sched_id = ?',
      whereArgs: [scheduleId],
    );
  }

  // ลบข้อมูลจริงได้เลย เพราะไม่ได้ซิงค์
  Future<int> deleteSchedulesByPrescriptionId(String prescriptionId) async {
    final db = await _database;
    return await db.delete(_tableName, where: 'prescription_id = ?', whereArgs: [prescriptionId]);
  }

  //check if schedule exists
  Future<bool> checkScheduleExists({
    required String prescriptionId,
    required String scheduledDate,
    required String scheduledTime,
  }) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'prescription_id = ? AND scheduled_date = ? AND scheduled_time = ?',
      whereArgs: [prescriptionId, scheduledDate, scheduledTime],
    );
    return maps.isNotEmpty;
  }

  //ลบเฉพาะตารางล่วงหน้าที่ยังไม่ได้ทำ (สำหรับการ Reschedule)
  Future<int> deleteFuturePendingSchedules(String prescriptionId, String fromDate) async {
    final db = await _database;
    return await db.delete(
      _tableName,
      where: 'prescription_id = ? AND scheduled_date >= ? AND status = ?',
      whereArgs: [prescriptionId, fromDate, 'pending'],
    );
  }

}
