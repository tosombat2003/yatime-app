import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import '../database_local/repositories/medication_repository.dart';
import '../data_models/medication_item.dart';
import 'package:ya_time/service/notification_service.dart';
import 'package:flutter/services.dart';

class ReminderScreen extends StatefulWidget {
  final int scheduleId;
  final int retryCount;

  const ReminderScreen({super.key, required this.scheduleId, this.retryCount = 0});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final MedicationRepository _repository = MedicationRepository();

  List<MedicationItem> displayItems = [];
  bool isLoading = true;

  late Timer _timer;
  Timer? _ttsTimer;
  Timer? _autoStopTimer;
  String currentTime = _getFormattedTime();

  bool _soundEnabled = true;
  bool _voiceEnabled = true;
  bool _vibrationEnabled = true;
  bool _snoozeEnabled = true;

  // 1. เพิ่มตัวแปรควบคุมเสียงพูด เพื่อไม่ให้พูดซ้อนกัน
  bool _keepSpeaking = true; 

  static String _getFormattedTime() {
    try {
      return DateFormat('HH:mm').format(DateTime.now());
    } catch (e) {
      return DateTime.now().toString().split('.')[0].split(' ')[1];
    }
  }

  @override
  void initState() {
    super.initState();
    _initReminderSystem();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => currentTime = _getFormattedTime());
    });
  }

  Future<void> _initReminderSystem() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _soundEnabled = prefs.getBool('noti_sound') ?? true;
      _voiceEnabled = prefs.getBool('noti_voice') ?? true;
      _vibrationEnabled = prefs.getBool('noti_vibrate') ?? true;
      _snoozeEnabled = prefs.getBool('noti_snooze') ?? true;

      final allToday = await _repository.getMedicationsByDate(DateTime.now());
      displayItems = [];
      allToday.forEach((time, items) {
        if (items.any((item) => item.schedule.schedId == widget.scheduleId)) {
          displayItems = items;
        }
      });

      if (mounted) setState(() => isLoading = false);

      if (displayItems.isNotEmpty) {
        if (_soundEnabled) await _playAlarmSound();
        if (_voiceEnabled) await _speakMedicationNames();
        if (_vibrationEnabled) await _startVibration();

        // Auto Snooze 3 นาที
        _autoStopTimer = Timer(const Duration(minutes: 3), () {
          if (_snoozeEnabled) {
            _handleAutoSnooze();
          } else {
            if (mounted) _stopAllAudio();
          }
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _startVibration() async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(pattern: [500, 1000, 500, 1000], repeat: 1);
    }
  }

  void _handleAutoSnooze() {
    if (!mounted) return;
    print("⏰ Auto Snooze Triggered");
    _stopAllAudio();
    _snooze(isAuto: true); // แยกเคส Auto เพื่อไม่ให้หยุดเสียงซ้ำซ้อน
  }

  // 2. สั่งหยุดทุกอย่าง รวมถึงปิดการวนลูปของเสียงพูดด้วย
  void _stopAllAudio() {
    print("🛑 Stopping all audio & vibration");
    _keepSpeaking = false; // ปิดโหมดพูด
    _ttsTimer?.cancel();
    _audioPlayer.stop();
    _tts.stop();
    Vibration.cancel();
  }

  IconData _getIconByType(String? medicineType) {
    final t = (medicineType ?? '').trim();
    if (t == 'น้ำ') return Icons.local_drink;
    if (t == 'ผง') return Icons.grain;
    if (t == 'ฉีด') return Icons.vaccines;
    return Icons.medication;
  }

  Future<void> _snooze({bool isAuto = false}) async {
    if (!isAuto) _stopAllAudio(); 

    if (!_snoozeEnabled) return;

    if (widget.retryCount >= 2) {
      print("🚫 ครบ 3 รอบแล้ว เลิกเตือน");
      if (mounted) SystemNavigator.pop();
      return;
    }

    List<String> names = displayItems.map((e) => e.medication.medName).toList();
    String medListText = names.join(" และ ");
    DateTime snoozeTime = DateTime.now().add(const Duration(minutes: 5));
    int nextRetry = widget.retryCount + 1;

    if (displayItems.isNotEmpty) {
      await NotificationService().scheduleNotification(
          id: widget.scheduleId + 5000 + nextRetry,
          title: "เตือนซ้ำ (รอบที่ $nextRetry): ได้เวลาทานยาแล้ว",
          body: "รายการยา: $medListText",
          scheduledTime: snoozeTime,
          payload: "${widget.scheduleId}|$nextRetry",
          saveToHistory: false,
          type: 'snooze');
    }
    if (mounted) SystemNavigator.pop();
  }

  //3. แก้ไขฟังก์ชันการพูดให้รอพูดจบก่อน แล้วค่อยเริ่มใหม่
  Future<void> _speakMedicationNames() async {
    if (displayItems.isEmpty) return;
    
    _keepSpeaking = true; // เปิดโหมดพูดเมื่อฟังก์ชันเริ่มทำงาน

    // 1. บอกจำนวนยาก่อน
    String message = "ได้เวลาทานยา ${displayItems.length} รายการแล้วค่ะ. ";

    // 2. ถ้ามียาแค่ 1 ตัว ก็พูดปกติ
    if (displayItems.length == 1) {
      final e = displayItems.first;
      message += "${e.medication.medName}, จำนวน ${e.prescription.doseAmount}, ${e.prescription.instructions}ค่ะ";
    } 
    // 3. ถ้ามียาหลายตัว ให้เว้นจังหวะให้เป็นธรรมชาติขึ้น
    else {
      message += "ได้แก่. "; // เพิ่มจุดเพื่อให้บอทเว้นจังหวะหายใจ
      
      for (int i = 0; i < displayItems.length; i++) {
        final e = displayItems[i];
        
        // ถ้าเป็นตัวสุดท้าย ให้ใส่คำว่า "และ"
        if (i == displayItems.length - 1) {
          message += "และ ${e.medication.medName}, จำนวน ${e.prescription.doseAmount}, ${e.prescription.instructions}ค่ะ";
        } else {
          // ตัวอื่นๆ เว้นด้วย comma เพื่อให้พูดช้าลง
          message += "${e.medication.medName}, จำนวน ${e.prescription.doseAmount}, ${e.prescription.instructions}. ";
        }
      }
    }

    if (mounted) {
      await _tts.setLanguage("th-TH");
      await _tts.setSpeechRate(0.45); // ความเร็วระดับกำลังดี

      // 4. ตั้งค่าให้รอพูดจบ แล้วนับ 10 วิ ค่อยพูดใหม่ (แทนการใช้ Timer เดิม)
      _tts.setCompletionHandler(() async {
        // ถ้าผู้ใช้กดกินยาไปแล้ว หรือกดออกไปแล้ว ให้หยุดทำงาน
        if (!_keepSpeaking || !mounted) return;

        // หน่วงเวลา 10 วินาที
        await Future.delayed(const Duration(seconds: 10));
        
        // เช็คอีกรอบก่อนจะเริ่มพูดประโยคใหม่
        if (_keepSpeaking && mounted) {
          _tts.speak(message);
        }
      });

      // สั่งให้เริ่มพูดครั้งแรก
      _tts.speak(message);
    }
  }

  Future<void> _playAlarmSound() async {
    await _audioPlayer.setAudioContext(AudioContext(
      android: const AudioContextAndroid(
        isSpeakerphoneOn: true,
        stayAwake: true,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.alarm, 
        audioFocus: AndroidAudioFocus.gainTransientExclusive,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {AVAudioSessionOptions.duckOthers},
      ),
    ));

    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.setVolume(1.0);
    await _audioPlayer.play(AssetSource('sounds/alarm_bg1.mp3'));
  }

  @override
  void dispose() {
    _autoStopTimer?.cancel();
    _ttsTimer?.cancel();
    _timer.cancel();
    _stopAllAudio();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.teal.shade800,
        body: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal.shade600, Colors.teal.shade900], 
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // --- 1. ส่วนบน ---
                Column(
                  children: [
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_active_outlined, size: 60, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      currentTime,
                      style: const TextStyle(fontSize: 80, color: Colors.white, fontWeight: FontWeight.w900, height: 1),
                    ),
                    const SizedBox(height: 10),
                    const Text('ถึงเวลาทานยา', style: TextStyle(fontSize: 28, color: Colors.white70, fontWeight: FontWeight.bold)),
                  ],
                ),

                // --- 2. ส่วนกลาง (รองรับการเลื่อนเมื่อมียาหลายตัว) ---
                Flexible(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 20), 
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
                    child: ListView.builder(
                      shrinkWrap: true, 
                      itemCount: displayItems.length,
                      itemBuilder: (context, index) {
                        final item = displayItems[index]; 
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.teal[50], borderRadius: BorderRadius.circular(15)),
                                child: Icon(_getIconByType(item.medication.type), size: 36, color: Colors.teal),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      item.medication.medName,
                                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
                                    ),
                                    Text(
                                      "${item.prescription.doseAmount} | ${item.prescription.instructions}",
                                      style: const TextStyle(fontSize: 24, color: Colors.black87),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // --- 3. ส่วนล่าง ---
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 75,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          _stopAllAudio();
                          
                          for (var item in displayItems) {
                            if (item.schedule.schedId != null) {
                              await _repository.markAsTaken(item.schedule.schedId!);
                            }
                          }
                          if (mounted) SystemNavigator.pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white, 
                          foregroundColor: Colors.teal.shade800, 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 5,
                        ),
                        icon: const Icon(Icons.check_circle, size: 36),
                        label: const Text('กินเรียบร้อย', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: _snoozeEnabled ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
                      children: [
                        if (_snoozeEnabled)
                          TextButton.icon(
                            onPressed: () => _snooze(), 
                            icon: const Icon(Icons.snooze, color: Colors.white70),
                            label: const Text('เลื่อน 5 นาที', style: TextStyle(fontSize: 18, color: Colors.white)),
                          ),
                        TextButton.icon(
                          onPressed: () async {
                            _stopAllAudio();

                            for (var item in displayItems) {
                              if (item.schedule.schedId != null) {
                                await _repository.markAsSkipped(item.schedule.schedId!);
                              }
                            }
                            if (mounted) SystemNavigator.pop();
                          },
                          icon: Icon(Icons.close, color: Colors.orange.shade200),
                          label: Text('ข้ามมื้อนี้', style: TextStyle(fontSize: 18, color: Colors.orange.shade200, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}