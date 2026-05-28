import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:ya_time/firebase_options.dart';
import 'package:ya_time/database_local/db_sqlite_helper.dart';
import 'package:ya_time/service/notification_service.dart';
import 'package:ya_time/service/appoint_noti_service.dart';
import 'package:ya_time/service/sync_service.dart';
import 'package:ya_time/auth/auth_service.dart';
import 'package:ya_time/app_session.dart';
import 'package:ya_time/database_local/models/user_model.dart';
import 'package:provider/provider.dart';
import 'package:ya_time/providers/theme_provider.dart';

import 'pages/login_screen.dart';
import 'pages/home_screen.dart';
import 'pages/appoint_screen.dart';
import 'pages/add_med_screen.dart';
import 'pages/med_info_screen.dart';
import 'pages/setting_screen.dart';
import 'pages/notification_screen.dart';
import 'pages/reminder_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print("Firebase failed: $e");
  }

  try {
    await DatabaseHelper().database;
  } catch (e) {
    print("Database failed: $e");
  }

  try {
    await NotificationService().init();
    AppointNotificationService().syncAppointmentNotifications();
  } catch (e) {
    print("Notification failed: $e");
  }

  int? initialScheduleId;
  int initialRetryCount = 0;

  try {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

    if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
      final payload =
          notificationAppLaunchDetails!.notificationResponse?.payload;
      if (payload != null) {
        if (payload.contains('|')) {
          final parts = payload.split('|');
          initialScheduleId = int.tryParse(parts[0]);
          initialRetryCount = int.tryParse(parts[1]) ?? 0;
        } else {
          initialScheduleId = int.tryParse(payload);
        }
      }
    }
  } catch (_) {}

  runApp(
   MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: MyApp(
        startScheduleId: initialScheduleId,
        startRetryCount: initialRetryCount,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final int? startScheduleId;
  final int startRetryCount;

  const MyApp({super.key, this.startScheduleId, this.startRetryCount = 0});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Ya Time',
      debugShowCheckedModeBanner: false,
      
      themeMode: themeProvider.themeMode,
      
      //โหมดสว่าง
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.grey[50], // สีพื้นหลังจอ
        cardColor: Colors.white, // สีกล่อง/การ์ด
        iconTheme: const IconThemeData(color: Colors.black87), // สีไอคอนเริ่มต้น
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        textTheme: const TextTheme(
          // ถ้าไม่ระบุสี Text ระบบจะใช้สีดำให้อัตโนมัติ
          bodyLarge: TextStyle(fontSize: 18),
          bodyMedium: TextStyle(fontSize: 16),
        ),
      ),

      //โหมดมืด
      darkTheme: ThemeData(
        brightness: Brightness.dark, // สำคัญมาก ตัวนี้จะบอกให้ Text เปลี่ยนเป็นสีขาวอัตโนมัติ!
        primaryColor: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFF121212), // สีพื้นหลังจอโหมดมืด
        cardColor: const Color.fromARGB(255, 49, 49, 49), // สีกล่อง/การ์ดโหมดมืด
        iconTheme: const IconThemeData(color: Colors.white70), // สีไอคอนโหมดมืด
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F1F1F),
          foregroundColor: Colors.tealAccent,
        ),
        //bottomAppBarTheme: const BottomAppBarTheme(color: Color(0xFF1E1E1E)),
        colorScheme: const ColorScheme.dark(
          primary: Colors.teal, 
          secondary: Colors.tealAccent,
          surface: Color(0xFF1E1E1E), 
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 18 ,color: Colors.white70),
          bodyMedium: TextStyle(fontSize: 16, color: Colors.white70),
        ),
      ),

      home: AuthCheckScreen(
        startScheduleId: startScheduleId,
        startRetryCount: startRetryCount,
      ),
    );
  }
}

class AuthCheckScreen extends StatefulWidget {
  final int? startScheduleId;
  final int startRetryCount;
  const AuthCheckScreen({
    super.key,
    this.startScheduleId,
    this.startRetryCount = 0,
  });

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    final user = AuthService.instance.getCurrentFirebaseUser();

    if (!mounted) return;

    if (user != null) {
      if (widget.startScheduleId != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ReminderScreen(
              scheduleId: widget.startScheduleId!,
              retryCount: widget.startRetryCount,
            ),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigationPage()),
        );
      }
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.teal,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'กำลังตรวจสอบข้อมูล...',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

// ========================================
// Main Navigation Page
// ========================================

class MainNavigationPage extends StatefulWidget {
  final int initialIndex; //เพิ่มตัวแปรรับค่า index เริ่มต้น
  final int? targetScheduleId;
  //แก้ Constructor ให้รับค่า (ถ้าไม่ส่งมา ให้เริ่มที่ 0=หน้าบ้าน)
  const MainNavigationPage({
    super.key,
    this.initialIndex = 0,
    this.targetScheduleId,
  });

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage>
    with WidgetsBindingObserver {
  final SyncService _syncService = SyncService();
  int? _currentTargetId;
  //int _currentIndex = 0;
  late int _currentIndex;
  Key _homeScreenKey = UniqueKey();
  Key _medInfoKey = UniqueKey();
  UserModel? _currentUser; // เก็บข้อมูล User ไว้แสดงผล

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _currentTargetId = widget.targetScheduleId;
    WidgetsBinding.instance.addObserver(this);
    _loadUser(); // โหลดข้อมูล User

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _initializeSync();
      }
    });
  }

  void _consumeTargetId() {
    if (_currentTargetId != null) {
      setState(() {
        _currentTargetId = null; // ล้างค่าทิ้ง ครั้งหน้า Home จะไม่เลื่อนแล้ว
      });
    }
  }

  // โหลดข้อมูล User จาก SQLite (จะได้ข้อมูลล่าสุดที่แก้ใน ProfilePage)
  Future<void> _loadUser() async {
    final user = await AuthService.instance.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _initializeSync() {
    try {
      final userId = AppSession.instance.getUserId();
      if (userId == null) return;
      _syncService.initReactiveSync(
        userId,
        onSyncStart: _onSyncStart,
        onSyncEnd: _onSyncEnd,
      );
    } catch (e) {
      print('❌ Error initializing sync: $e');
    }
  }

  void _onSyncStart() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('กำลังอัปเดตข้อมูล...'),
        backgroundColor: Colors.blueGrey,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onSyncEnd() {
    if (!mounted) return;
    setState(() {
      _homeScreenKey = UniqueKey();
      _medInfoKey = UniqueKey();
    });
    // โหลด User ใหม่เผื่อมีการเปลี่ยนแปลงจาก Cloud
    _loadUser();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('อัปเดตข้อมูลเสร็จสิ้น'),
        backgroundColor: Colors.teal,
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _getGreeting() {
    try {
      final DateFormat thaiDay = DateFormat.EEEE('th');
      return 'สวัสดี${thaiDay.format(DateTime.now())}';
    } catch (_) {
      return 'สวัสดี';
    }
  }

  // Helper Widget สำหรับแสดงรูป Profile
  Widget _buildProfileAvatar() {
    final pic = _currentUser?.pic;

    if (pic != null && pic.isNotEmpty) {
      // ถ้าเป็น URL (จาก Google เดิม)
      if (pic.startsWith('http')) {
        return CircleAvatar(
          radius: 24,
          backgroundImage: NetworkImage(pic),
          backgroundColor: Colors.white,
        );
      }
      // ถ้าเป็น Asset (เลือกจากในแอป)
      else if (pic.startsWith('assets/')) {
        return CircleAvatar(
          radius: 24,
          backgroundImage: AssetImage(pic),
          backgroundColor: Colors.white,
          onBackgroundImageError: (_, __) => const Icon(Icons.person),
        );
      }
    }
    // ถ้าไม่มีรูป ใช้ Icon แทน
    return const CircleAvatar(
      radius: 24,
      backgroundColor: Colors.white,
      child: Icon(Icons.person, color: Colors.teal),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ใช้ข้อมูลจาก _currentUser ที่โหลดมาจาก SQLite แทน AppSession
    final userName = _currentUser?.name ?? 'ผู้ใช้';

    final List<Widget> pages = [
      HomeScreen(
        key: _homeScreenKey,
        highlightScheduleId: _currentTargetId, // ใช้ตัวแปร state
        onConsumeId: _consumeTargetId, // ส่งฟังก์ชันลบค่า
      ),
      const AppointScreen(),
      MedInfoScreen(key: _medInfoKey),
      SettingScreen(onProfileUpdated: _loadUser),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal,
        toolbarHeight: 80,
        // แก้ไข Title เป็น Row เพื่อใส่รูปคู่กับข้อความ
        title: Row(
          children: [
            _buildProfileAvatar(),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                ),
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: IconButton(
              icon: const Icon(
                Icons.notifications,
                size: 32,
                color: Colors.white,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        notchMargin: 12,
        child: SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, "หน้าหลัก", 0),
              _buildNavItem(Icons.event, "นัดหมาย", 1),
              _buildAddButton(),
              _buildNavItem(Icons.medication, "ยา", 2),
              _buildNavItem(Icons.settings, "ตั้งค่า", 3),
            ],
          ),
        ),
      ),
      body: pages[_currentIndex],
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final bool isSelected = _currentIndex == index;
    return InkWell(
      onTap: () {
        setState(() => _currentIndex = index);
        // ถ้ากดแท็บตั้งค่า (index 3) แล้วกลับมา อาจมีการเปลี่ยนรูป ให้โหลดใหม่
        if (index == 0 || index == 3) _loadUser();
      },
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: isSelected ? Colors.teal : Colors.grey),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: isSelected ? Colors.teal : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddMedScreen()),
        );
        if (result == true && mounted) {
          setState(() {
            _homeScreenKey = UniqueKey();
            _medInfoKey = UniqueKey();
          });
        }
      },
      child: Container(
        width: 65,
        height: 55,
        decoration: const BoxDecoration(
          color: Colors.teal,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              spreadRadius: 2,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 35),
      ),
    );
  }
}
