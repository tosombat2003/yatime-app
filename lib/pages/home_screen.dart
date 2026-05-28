import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:ya_time/database_local/repositories/medication_repository.dart';
import 'package:ya_time/data_models/medication_item.dart';
import 'package:ya_time/service/sync_service.dart';
import 'package:ya_time/service/connectivity_service.dart';
import 'package:ya_time/app_session.dart';
//Widgets
import 'widgets/home_calendar.dart';
import 'widgets/daily_medication_list.dart';

class HomeScreen extends StatefulWidget {
  final int? highlightScheduleId;
  final VoidCallback? onConsumeId;
  const HomeScreen({super.key, this.highlightScheduleId,this.onConsumeId,});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  final CalendarFormat _calendarFormat = CalendarFormat.week;

  final MedicationRepository _medicationRepo = MedicationRepository();
  Map<String, List<MedicationItem>> _medicationsByTime = {};
  bool _isLoading = false;
  bool _isInitialized = false;

  final Map<String, GlobalKey> _sectionKeys = {}; //เก็บ key แต่ละเวลา
  int? _pendingId;

  @override
  void initState() {
    super.initState();
    _pendingId = widget.highlightScheduleId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  // --- Logic การโหลดข้อมูล ---
  Future<void> _initializeData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await _medicationRepo.autoMarkAsMissed();
      // เพิ่ม Timeout เพื่อป้องกันการค้าง
      await Future.any([
        _fetchMedicationRecords(_selectedDay),
        Future.delayed(const Duration(seconds: 15)),
      ]);
    } catch (e) {
      print('❌ Error init data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialized = true;
        });
      }
    }
  }

  Future<void> _fetchMedicationRecords(DateTime selectedDay) async {
    if (!mounted) return;
    try {
      final medications = await _medicationRepo.getMedicationsByDate(selectedDay);
      if (mounted) {
        setState(() {
          _medicationsByTime = medications;
          
          _sectionKeys.clear();
          for (var time in medications.keys) {
            _sectionKeys[time] = GlobalKey();
          }
        });
        if (_pendingId != null) {
          final int idToScroll = _pendingId!;
          _pendingId = null; // ลบใน Local state

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToTarget(idToScroll);
            widget.onConsumeId?.call(); 
          });
        }
      }
    } catch (e) {
      print("❌ Fetch Error: $e");
      if (mounted) setState(() => _medicationsByTime = {});
    }
  }
  void _scrollToTarget(int targetId) {
    String? targetTime;

    // วนหาว่า ID นี้ อยู่ในเวลาไหน?
    _medicationsByTime.forEach((time, items) {
      if (items.any((item) => item.schedule.schedId == targetId)) {
        targetTime = time;
      }
    });

    // ถ้าเจอเวลา และมี Key อยู่ -> สั่ง Scroll เลย!
    if (targetTime != null && _sectionKeys.containsKey(targetTime)) {
      final key = _sectionKeys[targetTime]!;
      if (key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 600), // ความเร็วการเลื่อน
          curve: Curves.easeInOut, // รูปแบบการเลื่อน (นุ่มนวล)
          alignment:
              0.1, // ให้เลื่อนมาอยู่เกือบบนสุดของจอ (0.0=บนสุด, 0.5=กลางจอ)
        );
        print("🚀 Scrolling to $targetTime");
      }
    }
  }

  Future<void> _onRefresh() async {
    final hasNet = await ConnectivityService().hasInternet();
    if (!hasNet) {
      if (mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่มีการเชื่อมต่ออินเทอร์เน็ต')),
        );
      return;
      }
    }

    final userId = AppSession.instance.getUserId();
    if (userId != null) {
      await SyncService().syncAll(userId);
      if (mounted) await _fetchMedicationRecords(_selectedDay);
    }
  }

  // --- Logic การจัดการยา (Action) ---
  Future<void> _handleMedicineAction(MedicationItem item, String action) async {
    try {
      switch (action) {
        case 'ontime':
          await _markAsTaken(item);
          break;
        // case 'attime':
        //   await _showTimePickerDialog(item);
        //   break;
        case 'skip':
          await _markAsSkipped(item);
          break;
        case 'undo':
          await _undoMedicationStatus(item);
          break;
      }
    } catch (e) {
      if (mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markAsTaken(MedicationItem item, {String? takenTime}) async {
    await _medicationRepo.markAsTaken(
      item.schedule.schedId!,
      takenTime: takenTime,
    );
    await _fetchMedicationRecords(_selectedDay);
    if (mounted){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('บันทึกการกินยาสำเร็จ'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _markAsSkipped(MedicationItem item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการข้ามยา'),
        content: Text(
          'คุณต้องการข้ามยา "${item.medication.medName}" ใช่หรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ข้ามยา', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _medicationRepo.markAsSkipped(item.schedule.schedId!);
      await _fetchMedicationRecords(_selectedDay);
    }
  }

  Future<void> _undoMedicationStatus(MedicationItem item) async {
    await _medicationRepo.markAsPending(item.schedule.schedId!);
    await _fetchMedicationRecords(_selectedDay);
    if (mounted){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ยกเลิกสถานะเรียบร้อย'),
          backgroundColor: Colors.indigo,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  // Future<void> _showTimePickerDialog(MedicationItem item) async {
  //   final TimeOfDay? selectedTime = await showTimePicker(
  //     context: context,
  //     initialTime: TimeOfDay.now(),
  //   );
  //   if (selectedTime != null) {
  //     final now = DateTime.now();
  //     final takenDateTime = DateTime(
  //       now.year,
  //       now.month,
  //       now.day,
  //       selectedTime.hour,
  //       selectedTime.minute,
  //     );
  //     await _markAsTaken(item, takenTime: takenDateTime.toIso8601String());
  //   }
  // }

  Future<void> _handleTakeAll(List<MedicationItem> items) async {
    final pendingCount = _medicationRepo.getPendingCount(items);
    if (pendingCount == 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.teal[400], size: 32),
            const SizedBox(width: 12),
            const Text(
              'ยืนยันการกินยา',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'คุณต้องการบันทึกว่า "กินแล้ว" ทั้งหมด $pendingCount รายการใช่หรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _medicationRepo.markAllAsTaken(items);
      await _fetchMedicationRecords(_selectedDay);
      if (mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกทั้งหมดสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.teal)),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 1. Calendar Widget
            HomeCalendar(
              focusedDay: _focusedDay,
              selectedDay: _selectedDay,
              calendarFormat: _calendarFormat,
              onDaySelected: (selected, focused) {
                if (!isSameDay(_selectedDay, selected)) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                  _fetchMedicationRecords(selected);
                }
              },
              onPageChanged: (focused) => _focusedDay = focused,
            ),

            // 2. Medication List Widget
            Expanded(
              child: DailyMedicationList(
                isLoading: _isLoading,
                medicationsByTime: _medicationsByTime,
                onRefresh: _onRefresh,
                onAction: _handleMedicineAction,
                onTakeAll: _handleTakeAll,
                sectionKeys: _sectionKeys,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
