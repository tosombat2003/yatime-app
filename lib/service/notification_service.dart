import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; 

import '../pages/reminder_screen.dart';
import '../main.dart'; 

import 'package:ya_time/database_local/dao/notification_dao.dart';
import 'package:ya_time/database_local/models/notification_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  final NotificationDao _notificationDao = NotificationDao();

  Future<void> init() async {
    tz_data.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        if (details.payload != null) {
          String payload = details.payload!;
          
          if (payload.startsWith('appoint|')) {
             navigatorKey.currentState?.pushAndRemoveUntil(
               MaterialPageRoute(
                 builder: (context) => const MainNavigationPage(initialIndex: 1)
               ),
               (route) => false,
             );
          }
          else if (payload.startsWith('missed|')) {
             final parts = payload.split('|');
             final sId = int.tryParse(parts[1]);

             navigatorKey.currentState?.pushAndRemoveUntil(
               MaterialPageRoute(
                 builder: (context) => MainNavigationPage(initialIndex: 0, targetScheduleId: sId)
               ),
               (route) => false,
             );
          }
          else {
            int sId;
            int retry = 0;
            if (payload.contains('|')) {
              final parts = payload.split('|');
              sId = int.tryParse(parts[0]) ?? 0;
              if (parts.length > 1) retry = int.tryParse(parts[1]) ?? 0;
            } else {
              sId = int.tryParse(payload) ?? 0;
            }

            if (sId != 0) {
              navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (context) => ReminderScreen(scheduleId: sId, retryCount: retry),
                ),
              );
            }
          }
        }
      },
    );

    const AndroidNotificationChannel urgentChannel = AndroidNotificationChannel(
      'ya_time_urgent_channel',
      'Medication Alarm',
      description: 'แจ้งเตือนกินยา (เต็มจอ)',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    const AndroidNotificationChannel generalChannel = AndroidNotificationChannel(
      'ya_time_general_channel',
      'General Notifications',
      description: 'แจ้งเตือนนัดหมายและอื่นๆ',
      importance: Importance.high, 
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(urgentChannel);

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(generalChannel);

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
    bool saveToHistory = false,
    String type = 'general', 
  }) async {
    
    //อ่านค่าการตั้งค่าก่อนสร้างการแจ้งเตือน
    final prefs = await SharedPreferences.getInstance();
    final bool soundEnabled = prefs.getBool('noti_sound') ?? true;
    final bool vibrateEnabled = prefs.getBool('noti_vibrate') ?? true;

    String channelId = 'ya_time_general_channel';
    String channelName = 'General Notifications';
    bool useFullScreen = false;
    Priority notiPriority = Priority.high;

    if (type == 'medication' || type == 'snooze') {
      channelId = 'ya_time_urgent_channel';
      channelName = 'Medication Alarm';
      useFullScreen = true; 
      notiPriority = Priority.max;
    }

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: useFullScreen ? Importance.max : Importance.high,
          priority: notiPriority,
          fullScreenIntent: useFullScreen,
          category: useFullScreen ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
          audioAttributesUsage: AudioAttributesUsage.alarm, 
          // ปิด/เปิด ตามที่ผู้ใช้ตั้งค่า (มีผลกับป้าย Banner ที่เด้งลงมา)
          playSound: soundEnabled,
          enableVibration: vibrateEnabled,
        ),
      ),
      payload: payload ?? id.toString(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    if (saveToHistory) {
      try {
        final bool exists = await _notificationDao.isPayloadExist(payload ?? id.toString());
        
        if (!exists) {
          await _notificationDao.insertNotification(
            NotificationModel(
              title: title,
              body: body,
              payload: payload ?? id.toString(),
              date: scheduledTime.toIso8601String(),
              type: type,
            ),
          );
        } else {
          print("🔄 Notification already in history, skipping insert.");
        }
      } catch (e) {
        print('⚠️ Error saving notification to DB: $e');
      }
    }
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}