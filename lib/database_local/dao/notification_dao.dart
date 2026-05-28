import 'package:sqflite/sqflite.dart';
import 'package:ya_time/database_local/db_sqlite_helper.dart';
import 'package:ya_time/database_local/models/notification_model.dart';

class NotificationDao {
  final String _tableName = 'notifications';
  Future<Database> get _database async => await DatabaseHelper.instance.database;

  // เพิ่มการแจ้งเตือน
  Future<int> insertNotification(NotificationModel noti) async {
    final db = await _database;
    return await db.insert(_tableName, noti.toMap());
  }

  // ดึงรายการแจ้งเตือน (เฉพาะที่ถึงเวลาแล้ว หรือเป็นอดีต)
  Future<List<NotificationModel>> getHistoryNotifications() async {
    final db = await _database;
    final now = DateTime.now().toIso8601String();
    
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'date <= ?', // เอาเฉพาะที่ถึงเวลาเตือนแล้ว
      whereArgs: [now],
      orderBy: 'date DESC', // ใหม่สุดขึ้นก่อน
    );
    return maps.map((map) => NotificationModel.fromMap(map)).toList();
  }

  // นับจำนวนที่ยังไม่ได้อ่าน
  Future<int> getUnreadCount() async {
    final db = await _database;
    final now = DateTime.now().toIso8601String();
    
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM $_tableName WHERE is_read = 0 AND date <= ?',
      [now]
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // อ่านแล้ว
  Future<void> markAsRead(int id) async {
    final db = await _database;
    await db.update(
      _tableName,
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // อ่านทั้งหมด
  Future<void> markAllAsRead() async {
    final db = await _database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      _tableName,
      {'is_read': 1},
      where: 'date <= ?',
      whereArgs: [now],
    );
  }
  
  // ลบรายการ
  Future<void> deleteNotification(int id) async {
    final db = await _database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }
  // ลบทั้งหมด
  Future<void> deleteAllNotifications() async {
    final db = await _database;
    await db.delete(_tableName);
  }

  Future<bool> isPayloadExist(String payload) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'payload = ?',
      whereArgs: [payload],
    );
    return maps.isNotEmpty;
  }
}