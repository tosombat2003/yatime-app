import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart'; // เช็ค Path ให้ตรงกับที่คุณสร้าง

class DisplaySettingScreen extends StatelessWidget {
  const DisplaySettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ดึงสถานะปัจจุบันของ Theme
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // แปลง ThemeMode กลับเป็น String เพื่อใช้เช็คเงื่อนไขในการ์ด
    String selectedThemeStr = 'system';
    if (themeProvider.themeMode == ThemeMode.light) selectedThemeStr = 'light';
    if (themeProvider.themeMode == ThemeMode.dark) selectedThemeStr = 'dark';

    return Scaffold(
      appBar: AppBar(
        title: const Text('การแสดงผล', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor:Theme.of(context).scaffoldBackgroundColor,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          _buildThemeOption(context, 'ตามระบบ', 'system', Icons.settings_brightness, isDark, selectedThemeStr),
          _buildThemeOption(context, 'โหมดสว่าง', 'light', Icons.wb_sunny_rounded, isDark, selectedThemeStr),
          _buildThemeOption(context, 'โหมดมืด', 'dark', Icons.dark_mode_rounded, isDark, selectedThemeStr),
        ],
      ),
    );
  }

  Widget _buildThemeOption(BuildContext context, String title, String value, IconData icon, bool isDark, String currentSelected) {
    final isSelected = currentSelected == value;
    
    return Card(
      color: isDark ? Theme.of(context).cardColor : Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected 
          ? const BorderSide(color: Colors.teal, width: 2) 
          : BorderSide(color: isDark ? Colors.grey[800]! : Colors.transparent),
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? Colors.teal : Colors.grey),

        title: Text(title, style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 20,
        )),
        trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.teal) : null,
        onTap: () {
          // สั่งอัปเดต Theme ผ่าน Provider ทันที!
          context.read<ThemeProvider>().setTheme(value);
        },
      ),
    );
  }
}