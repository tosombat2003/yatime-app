// ไฟล์: lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadTheme(); // โหลดค่าที่เคยตั้งไว้ทันทีที่แอปเปิด
  }

  // ดึงค่าจาก SharedPreferences
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme') ?? 'system';
    
    if (savedTheme == 'light') {
      _themeMode = ThemeMode.light;
    } else if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners(); // แจ้งเตือนแอปให้วาด UI ใหม่
  }

  // เซ็ตค่าและบันทึกลง SharedPreferences
  Future<void> setTheme(String themeModeString) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', themeModeString);

    if (themeModeString == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (themeModeString == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners(); // สั่งให้แอปเปลี่ยนสีเดี๋ยวนี้!
  }
}