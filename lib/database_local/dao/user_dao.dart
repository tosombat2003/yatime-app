import 'package:sqflite/sqflite.dart';
import 'package:ya_time/database_local/db_sqlite_helper.dart';
import 'package:ya_time/database_local/models/user_model.dart';

class UserDao {
  final String _tableName = 'users';

  Future<Database> get _database async => await DatabaseHelper.instance.database;

  // บันทึกหรืออัปเดตผู้ใช้ (สำหรับ Google Sign-In)
  Future<int> saveUser(UserModel user) async {
    final db = await _database;
    return await db.insert(
      _tableName,
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // บันทึกผู้ใช้ใหม่
  Future<int> insertUser(UserModel user) async {
    final db = await _database;
    return await db.insert(
      _tableName,
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort, // จะ error ถ้าซ้ำ
    );
  }

  // ดึงผู้ใช้ทั้งหมด
  Future<List<UserModel>> getAllUsers() async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(_tableName);
    return maps.map((map) => UserModel.fromMap(map)).toList();
  }

  // ดึงผู้ใช้ที่ active อย่างเดียว
  Future<List<UserModel>> getActiveUsers() async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'is_active = ?',
      whereArgs: [1],
    );
    return maps.map((map) => UserModel.fromMap(map)).toList();
  }

  // ดึงผู้ใช้ตาม ID
  Future<UserModel?> getUserById(String userId) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return maps.isNotEmpty ? UserModel.fromMap(maps.first) : null;
  }

  // ดึงผู้ใช้ตาม Email
  Future<UserModel?> getUserByEmail(String email) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'email = ?',
      whereArgs: [email],
    );
    return maps.isNotEmpty ? UserModel.fromMap(maps.first) : null;
  }

  // อัปเดตข้อมูลผู้ใช้
  Future<int> updateUser(UserModel user) async {
    final db = await _database;
    return await db.update(
      _tableName,
      user.toMap(),
      where: 'user_id = ?',
      whereArgs: [user.userId],
    );
  }

  // อัปเดต last_login_at
  Future<int> updateLastLogin(String userId) async {
    final db = await _database;
    return await db.update(
      _tableName,
      {
        'last_login_at': DateTime.now().toIso8601String(),
        'last_modified': DateTime.now().toIso8601String(),
      },
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // อัปเดตรูปโปรไฟล์
 Future<int> updateName(String userId, String name) async {
    final db = await _database;
    return await db.update(
      _tableName,
      {
        'name': name,
        'last_modified': DateTime.now().toIso8601String(),
        'is_synced': 0, // เพิ่ม: บอกว่าข้อมูลนี้ยังไม่ได้ซิงค์
      },
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // อัปเดตรูปโปรไฟล์ (แก้ให้ตั้ง is_synced = 0)
  Future<int> updateProfilePicture(String userId, String picUrl) async {
    final db = await _database;
    return await db.update(
      _tableName,
      {
        // ถ้าส่ง string ว่างมา แปลว่าผู้ใช้ตั้งใจลบรูป ให้เซฟเป็น null
        'pic': picUrl.isEmpty ? null : picUrl, 
        'last_modified': DateTime.now().toIso8601String(),
        'is_synced': 0, 
      },
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // เพิ่มฟังก์ชันใหม่: ติ๊กถูกว่าซิงค์แล้ว
  Future<void> markAsSynced(String userId) async {
    final db = await _database;
    await db.update(
      _tableName,
      {
        'is_synced': 1,
        'sync_at': DateTime.now().toIso8601String(),
      },
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // ปิดใช้งานบัญชี (Soft delete)
  Future<int> deactivateUser(String userId) async {
    final db = await _database;
    return await db.update(
      _tableName,
      {
        'is_active': 0,
        'last_modified': DateTime.now().toIso8601String(),
      },
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // เปิดใช้งานบัญชี
  Future<int> activateUser(String userId) async {
    final db = await _database;
    return await db.update(
      _tableName,
      {
        'is_active': 1,
        'last_modified': DateTime.now().toIso8601String(),
      },
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // ลบผู้ใช้จริงๆ (Hard delete)
  Future<int> deleteUser(String userId) async {
    final db = await _database;
    return await db.delete(
      _tableName,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // ลบผู้ใช้ทั้งหมด 
  Future<int> deleteAllUsers() async {
    final db = await _database;
    return await db.delete(_tableName);
  }

  // ตรวจสอบว่ามีผู้ใช้หรือไม่
  Future<bool> hasUsers() async {
    final db = await _database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_tableName WHERE is_active = 1'),
    );
    return (count ?? 0) > 0;
  }

  // นับจำนวนผู้ใช้ทั้งหมด
  Future<int> getUserCount() async {
    final db = await _database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_tableName'),
    );
    return count ?? 0;
  }
  
  Future<UserModel?> getUnsyncedUser(String userId) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'user_id = ? AND is_synced = 0',
      whereArgs: [userId],
    );
    return maps.isNotEmpty ? UserModel.fromMap(maps.first) : null;
  }
}