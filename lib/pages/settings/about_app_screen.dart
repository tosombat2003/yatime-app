import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'เกี่ยวกับแอป',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.teal,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // === 1. ส่วนหัว (Logo & Version) ===
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                //color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.maxWidth * 0.5;
                  final assetPath = 'assets/icon/logo.png';
                  return SizedBox(
                    width: size,
                    height: size,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.teal.shade100,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        backgroundColor: Colors.grey[200],
                        backgroundImage: AssetImage(assetPath),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'YaTime',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: const Text(
                'Version 1.0.0 (Beta)',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.teal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 30),

            // === 2. คำอธิบายแอป ===
            _buildInfoCard(
              context,
              title: 'เกี่ยวกับ YaTime',
              icon: Icons.info_outline,
              content: const Text(
                'YaTime คือแอปพลิเคชันผู้ช่วยส่วนตัวที่ถูกออกแบบมาเพื่อช่วยดูแลตารางการทานยาและนัดหมายแพทย์ '
                'เหมาะสำหรับผู้สูงอายุและผู้ดูแล เพื่อให้มั่นใจว่าจะไม่พลาดทุกมื้อยาสำคัญและทุกนัดหมาย',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
            ),

            const SizedBox(height: 16),

            // === 3. ฟีเจอร์หลัก ===
            _buildInfoCard(
              context,
              title: 'ฟีเจอร์หลัก',
              icon: Icons.stars_rounded,
              content: Column(
                children: [
                  _buildFeatureItem('แจ้งเตือนทานยาตรงเวลา แม่นยำ'),
                  _buildFeatureItem('ระบบ Snooze เตือนซ้ำเมื่อยังไม่ทาน'),
                  _buildFeatureItem('บันทึกประวัติการทานยา (Adherence)'),
                  _buildFeatureItem('แจ้งเตือนนัดหมายแพทย์ล่วงหน้า'),
                  _buildFeatureItem(
                    'ใช้งานได้แม้ไม่มีอินเทอร์เน็ต (Offline First)',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // === 4. ทีมพัฒนา & ติดต่อ ===
            _buildInfoCard(
              context,
              title: 'พัฒนาโดย',
              icon: Icons.code_rounded,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'นักศึกษาสาขาวิทยาการคอมพิวเตอร์\nมหาวิทยาลัยศิลปากร',
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'ติดต่อเรา',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  _buildContactRow(
                    context,
                    Icons.email_rounded,
                    'support@yatime.app',
                  ),
                  //_buildContactRow(context, Icons.facebook, 'YaTime Official'),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Footer
            const Text(
              '© 2026 YaTime Project. All Rights Reserved.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Widget: การ์ดข้อมูล
  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, // ตอนนี้ใช้ context ได้แล้ว!
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.teal),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  // Widget: รายการฟีเจอร์ (Bullet)
  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  // Widget: แถวติดต่อ (กดแล้ว Copy ได้)
  Widget _buildContactRow(BuildContext context, IconData icon, String text) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('คัดลอก "$text" แล้ว'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey[700], size: 22),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.blueAccent,
                decoration: TextDecoration.underline,
              ),
            ),
            const Spacer(),
            const Icon(Icons.copy, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
