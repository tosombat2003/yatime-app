import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingScreen extends StatefulWidget {
  const NotificationSettingScreen({super.key});

  @override
  State<NotificationSettingScreen> createState() => _NotificationSettingScreenState();
}

class _NotificationSettingScreenState extends State<NotificationSettingScreen> {
  bool _soundEnabled = true;
  bool _voiceEnabled = true; 
  bool _vibrationEnabled = true;
  bool _snoozeEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _soundEnabled = prefs.getBool('noti_sound') ?? true;
        _voiceEnabled = prefs.getBool('noti_voice') ?? true; // โหลดค่า TTS
        _vibrationEnabled = prefs.getBool('noti_vibrate') ?? true;
        _snoozeEnabled = prefs.getBool('noti_snooze') ?? true;
      });
    }
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    // เช็คโหมดมืดสำหรับปรับสีบางจุดให้สวยงาม
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('ตั้งค่าการแจ้งเตือน', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        //backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        //foregroundColor: Colors.teal,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildInfoCard(isDark),
          const SizedBox(height: 20),
          
          // โชว์แจ้งเตือนถ้าปิดทั้งเสียงและสั่น
          if (!_soundEnabled && !_vibrationEnabled && !_voiceEnabled)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'คำเตือน: คุณปิดการแจ้งเตือนทุกรูปแบบ อาจทำให้พลาดการทานยาได้',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor, 
              borderRadius: BorderRadius.circular(16)
            ),
            child: Column(
              children: [
                _buildSwitchTile(
                  'เสียงกระดิ่งเตือน',
                  'ดังเมื่อถึงเวลาทานยา',
                  Icons.notifications_active_rounded,
                  _soundEnabled,
                  (val) {
                    setState(() => _soundEnabled = val);
                    _saveSetting('noti_sound', val);
                  },
                ),
                const Divider(height: 1, indent: 60),
                
                // เมนูใหม่: เสียงพูด (TTS)
                _buildSwitchTile(
                  'เสียงอ่านชื่อยา',
                  'ระบบจะพูดชื่อยาและจำนวนที่ต้องทาน',
                  Icons.record_voice_over_rounded,
                  _voiceEnabled,
                  (val) {
                    setState(() => _voiceEnabled = val);
                    _saveSetting('noti_voice', val);
                  },
                ),
                const Divider(height: 1, indent: 60),

                _buildSwitchTile(
                  'ระบบสั่น',
                  'สั่นโทรศัพท์เมื่อถึงเวลา',
                  Icons.vibration_rounded,
                  _vibrationEnabled,
                  (val) {
                    setState(() => _vibrationEnabled = val);
                    _saveSetting('noti_vibrate', val);
                  },
                ),
                const Divider(height: 1, indent: 60),

                _buildSwitchTile(
                  'อนุญาตให้เลื่อน (Snooze)',
                  'แสดงปุ่ม "เตือนอีกครั้ง" ใน 5 นาที',
                  Icons.snooze_rounded,
                  _snoozeEnabled,
                  (val) {
                    setState(() => _snoozeEnabled = val);
                    _saveSetting('noti_snooze', val);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.orange.shade900.withOpacity(0.2) : Colors.orange[50], 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: isDark ? Colors.orange.shade800 : Colors.orange[200]!)
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: isDark ? Colors.orangeAccent : Colors.orange[800]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'การตั้งค่านี้จะมีผลเฉพาะในแอป YaTime เท่านั้น',
              style: TextStyle(color: isDark ? Colors.orange.shade200 : Colors.orange[900], fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, IconData icon, bool value, Function(bool) onChanged) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.teal,
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.teal.shade900 : Colors.teal[50], 
          borderRadius: BorderRadius.circular(10)
        ),
        child: Icon(icon, color: isDark ? Colors.tealAccent : Colors.teal),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(
        subtitle, 
        style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600])
      ),
    );
  }
}