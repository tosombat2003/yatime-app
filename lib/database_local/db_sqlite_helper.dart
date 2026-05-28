import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

  static DatabaseHelper get instance => _instance;

  DatabaseHelper._internal();

  static final _dbbaseName = 'yatime.db';
  static final _dbVersion = 1;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), _dbbaseName);
    return await openDatabase(
      path, 
      version: _dbVersion, 
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Table users
    await db.execute('''
     CREATE TABLE users (
      user_id TEXT PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      username TEXT,
      name TEXT,
      pic TEXT,
      provider TEXT DEFAULT 'google',
      
      is_email_verified INTEGER DEFAULT 0,
      last_login_at TEXT,
      
      created_at TEXT DEFAULT (datetime('now')),
      last_modified TEXT DEFAULT (datetime('now')),
      
      is_active INTEGER DEFAULT 1,
      is_synced INTEGER DEFAULT 0,
      sync_at TEXT
    )
  ''');

    // Table medications
    await db.execute('''
    CREATE TABLE medications (
      med_id TEXT PRIMARY KEY,
      med_name TEXT NOT NULL,
      med_generic_name TEXT,
      dosage_strength TEXT,
      type TEXT,
      
      is_custom INTEGER DEFAULT 0,
      owner_user_id TEXT,

      created_at TEXT DEFAULT (datetime('now')),    -- สร้างเมื่อ
      is_synced INTEGER DEFAULT 0,
      last_modified TEXT DEFAULT (datetime('now')),
      sync_at TEXT,
      is_deleted INTEGER DEFAULT 0,

      FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
    )
  ''');

    // Table prescriptions
    await db.execute('''
    CREATE TABLE prescriptions (
      prescription_id TEXT PRIMARY KEY,
      user_id TEXT,
      med_id TEXT,
      dose_amount TEXT,
      start_date TEXT,
      end_date TEXT,
      instructions TEXT,
      time_to_notify TEXT,
      source TEXT,

      created_at TEXT DEFAULT (datetime('now')),    -- สร้างเมื่อ
      is_synced INTEGER DEFAULT 0,                  -- sync หรือยัง 
      last_modified TEXT DEFAULT (datetime('now')), -- แก้ไขล่าสุด
      sync_at TEXT,                                 -- sync ล่าสุด
      is_deleted INTEGER DEFAULT 0,                 -- ยังไม่ลบจริง

      updated_by TEXT, -- หมอหรือผู้ใช้

      FOREIGN KEY (user_id) REFERENCES users (user_id),
      FOREIGN KEY (med_id) REFERENCES medications (med_id)
    )
  ''');

    // Table schedules
    await db.execute('''
    CREATE TABLE schedules (
      sched_id INTEGER PRIMARY KEY AUTOINCREMENT,
      prescription_id TEXT,
      scheduled_time TEXT NOT NULL,
      scheduled_date TEXT,
      status TEXT DEFAULT 'pending',
      actual_taken_time TEXT,
      FOREIGN KEY (prescription_id) REFERENCES prescriptions (prescription_id)
    )
  ''');

    // Table appointments
    await db.execute('''
    CREATE TABLE appointments (
      appointment_id TEXT PRIMARY KEY,
      user_id TEXT,
      appointment_date TEXT,
      appointment_time TEXT,
      doctor_name TEXT,
      department TEXT,
      location TEXT,
      appointment_type TEXT,
      status TEXT DEFAULT 'scheduled',
      advice TEXT,

      created_at TEXT DEFAULT (datetime('now')),
      is_synced INTEGER DEFAULT 0,
      last_modified TEXT DEFAULT (datetime('now')),
      sync_at TEXT,
      FOREIGN KEY (user_id) REFERENCES users (user_id)
    )
  ''');

    await db.execute('''
      CREATE TABLE notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        body TEXT,
        payload TEXT,
        date TEXT,
        is_read INTEGER DEFAULT 0,
        type TEXT
      )
    ''');
  }

  Future<void> closeAndDeleteDB() async {
    try {
      final path = join(await getDatabasesPath(), _dbbaseName);
      
      // 1. ปิด Connection เดิมก่อน (สำคัญมาก ไม่งั้นไฟล์จะถูกล็อค)
      if (_database != null) {
        if (_database!.isOpen) {
          await _database!.close();
        }
        _database = null; // เคลียร์ตัวแปร static เพื่อให้ครั้งหน้ามัน init ใหม่
      }

      // 2. สั่งลบไฟล์ Database ทิ้ง (sqflite จะจัดการลบไฟล์ journal/wal ให้ด้วย)
      await deleteDatabase(path);
      
      print('💥 Database ถูกลบทิ้งเรียบร้อย (Reset Factory)');
    } catch (e) {
      print('❌ ลบ Database ไม่สำเร็จ: $e');
    }
  }
}
