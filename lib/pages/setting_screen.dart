import 'package:flutter/material.dart';
import 'package:ya_time/auth/auth_service.dart';
import 'package:ya_time/service/connectivity_service.dart';
import 'package:ya_time/database_local/models/user_model.dart';
import 'login_screen.dart';

// Import หน้าต่างๆ
import 'settings/profile_screen.dart';
import 'settings/noti_setting.dart';
import 'settings/display_setting.dart';
import 'settings/about_app_screen.dart';
import 'settings/report_screen.dart';
import 'settings/guide_screen.dart';

class SettingScreen extends StatefulWidget {
  final VoidCallback? onProfileUpdated;
  const SettingScreen({super.key, this.onProfileUpdated});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.instance.getCurrentUser();
    if (mounted) setState(() => _currentUser = user);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // === โปรไฟล์การ์ด ===
          _buildProfileCard(),
          const SizedBox(height: 26),

          // === หมวดทั่วไป ===
          _buildSectionHeader('ทั่วไป'),
          _buildSettingCard([
            _buildTile(
              icon: Icons.notifications_active_outlined,
              title: 'การแจ้งเตือน',
              color: Colors.orange,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationSettingScreen())),
            ),
            _buildDivider(),
            _buildTile(
              icon: Icons.palette_outlined,
              title: 'การแสดงผล',
              color: Colors.purple,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DisplaySettingScreen())),
            ),
          ]),

          const SizedBox(height: 30),

          // === หมวดช่วยเหลือ ===
          _buildSectionHeader('ช่วยเหลือ & อื่นๆ'),
          _buildSettingCard([
            _buildTile(
              icon: Icons.menu_book_rounded,
              title: 'คู่มือการใช้งาน',
              color: Colors.blue,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GuideScreen())),
            ),
            _buildDivider(),
            _buildTile(
              icon: Icons.support_agent_rounded,
              title: 'แจ้งปัญหาการใช้งาน',
              color: Colors.greenAccent,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportScreen())),
            ),
            _buildDivider(),
            _buildTile(
              icon: Icons.info_outline_rounded,
              title: 'เกี่ยวกับแอป',
              color: Colors.grey,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutAppScreen())),
            ),
          ]),

          const SizedBox(height: 40),

          // === ปุ่มออกจากระบบ (แบบเรียบง่าย แต่ Logic ครบ) ===
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor, 
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 2))],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1), 
                  borderRadius: BorderRadius.circular(15)
                ),
                child: const Icon(Icons.logout_rounded, color: Colors.red, size: 32),
              ),
              title: const Text(
                'ออกจากระบบ', 
                style: TextStyle(
                  color: Colors.red, 
                  fontSize: 22, // ตัวหนังสือใหญ่ชัดเจน
                  fontWeight: FontWeight.bold
                )
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.red, size: 32),
              onTap: () => _handleLogout(context),
            ),
          ),
          
          const SizedBox(height: 30),
          const Center(child: Text('Version 1.0.0', style: TextStyle(color: Colors.grey, fontSize: 18))),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.teal,
        borderRadius: BorderRadius.circular(24), // มนมากขึ้น
        boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
            _loadUser();
            widget.onProfileUpdated?.call();
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24), // Padding ใหญ่ขึ้น
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: CircleAvatar(
                    radius: 32, 
                    backgroundColor: Colors.teal[50],
                    backgroundImage: _currentUser?.pic != null 
                        ? (_currentUser!.pic!.startsWith('http') ? NetworkImage(_currentUser!.pic!) : AssetImage(_currentUser!.pic!) as ImageProvider)
                        : null,
                    child: _currentUser?.pic == null ? const Icon(Icons.person, size: 45, color: Colors.teal) : null,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentUser?.name ?? 'ผู้ใช้งาน',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white), // ชื่อใหญ่มาก
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _currentUser?.email ?? '',
                        style: TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.9)), // อีเมลใหญ่อ่านง่าย
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.edit, color: Colors.white, size: 30),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 12),
      child: Text(
        title, 
        style: const TextStyle(
          fontSize: 24, 
          fontWeight: FontWeight.bold, 
          // 3.เอา color: Colors.black87 ระบบจะรู้เองว่าต้องใช้สีขาวหรือดำ
        )
      ), 
    );
  }

Widget _buildSettingCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        // 2. ดึงสีกล่องการ์ดจาก Theme (สว่าง=ขาว, มืด=เทาเข้ม)
        color: Theme.of(context).cardColor, 
        borderRadius: BorderRadius.circular(20)
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTile({required IconData icon, required String title, required Color color, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), // พื้นที่กดใหญ่ขึ้น
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, color: color, size: 34), // ไอคอนใหญ่
      ),
      title: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)), // ตัวหนังสือเมนูใหญ่
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 32),
      onTap: onTap,
    );
  }

  Widget _buildDivider() => const Divider(height: 1, indent: 90, thickness: 1); // เส้นแบ่งชัดเจน

  // --- Logic ออกจากระบบ ---
  Future<void> _handleLogout(BuildContext context) async {
    final authService = AuthService.instance;
    final connectivity = ConnectivityService();
    final hasNet = await connectivity.hasInternet();

    if (hasNet) {
      _performLogout(context);
    } else {
      final hasPendingData = await authService.hasUnsyncedData();
      if (hasPendingData && context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('⚠️ เตือน: ข้อมูลอาจสูญหาย', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            content: const Text('คุณกำลังออฟไลน์และมีข้อมูลที่ยังไม่ได้บันทึกขึ้นระบบ\nหากออกจากระบบตอนนี้ ข้อมูลใหม่จะหายไปถาวร', style: TextStyle(fontSize: 20)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก', style: TextStyle(fontSize: 20))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                onPressed: () { Navigator.pop(ctx); _performLogout(context); },
                child: const Text('ยืนยันออก', style: TextStyle(color: Colors.white , fontSize: 20)),
              ),
            ],
          ),
        );
      } else {
        _performLogout(context);
      }
    }
  }

  Future<void> _performLogout(BuildContext context) async {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));
    try {
      await AuthService.instance.signOut();
      if (context.mounted) {
        Navigator.pop(context);
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
    }
  }
}