import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:ya_time/app_session.dart';
import 'package:ya_time/database_local/dao/appointments_dao.dart';
import 'package:ya_time/database_local/models/appointments_model.dart';
import 'package:ya_time/service/sync_service.dart';
import 'package:ya_time/service/connectivity_service.dart';
import 'package:ya_time/database_remote/db_firestore_helper.dart';
import 'package:ya_time/service/notification_service.dart';

class AppointScreen extends StatefulWidget {
  const AppointScreen({super.key});

  @override
  State<AppointScreen> createState() => _AppointScreenState();
}

class _AppointScreenState extends State<AppointScreen> {
  final AppointmentDao _appointmentDao = AppointmentDao();
  final FirebaseHelper _firebaseHelper = FirebaseHelper();
  final ConnectivityService _connectivity = ConnectivityService();
  final FlutterTts _tts = FlutterTts();

  List<AppointmentModel> _upcomingAppointments = [];
  List<AppointmentModel> _historyAppointments = [];
  AppointmentModel? _nextAppointment;

  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = AppSession.instance.getUserId();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    if (_userId == null) return;
    if (mounted) setState(() => _isLoading = true);

    try {
      final allAppoints = await _appointmentDao.getAppointmentsByUserId(_userId!);
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      List<AppointmentModel> upcoming = [];
      List<AppointmentModel> history = [];

      for (var appt in allAppoints) {
        final apptDate = DateTime.parse(appt.appointmentDate);
        bool isPastDate = apptDate.isBefore(todayStart);

        if (appt.status == 'completed' || appt.status == 'missed' || isPastDate) {
          history.add(appt);
        } else {
          upcoming.add(appt);
        }
      }

      history.sort((a, b) {
        final dateA = DateTime.parse('${a.appointmentDate} ${a.appointmentTime}');
        final dateB = DateTime.parse('${b.appointmentDate} ${b.appointmentTime}');
        return dateB.compareTo(dateA);
      });

      upcoming.sort((a, b) {
        final dateA = DateTime.parse('${a.appointmentDate} ${a.appointmentTime}');
        final dateB = DateTime.parse('${b.appointmentDate} ${b.appointmentTime}');
        return dateA.compareTo(dateB);
      });

      AppointmentModel? next;
      if (upcoming.isNotEmpty) {
        next = upcoming.first;
      }

      if (mounted) {
        setState(() {
          _upcomingAppointments = upcoming;
          _historyAppointments = history;
          _nextAppointment = next;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onRefresh() async {
    final hasNet = await _connectivity.hasInternet();
    if (!hasNet) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่มีการเชื่อมต่ออินเทอร์เน็ต')),
        );
      }
      return;
    }

    if (_userId != null) {
      await SyncService().syncAll(_userId!);
      await _loadAppointments();
    }
  }

  Future<void> _updateAppointmentStatus(AppointmentModel appt, String newStatus) async {
    if (!_isTodayOrPast(appt.appointmentDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยังไม่ถึงวันนัดหมายครับ')),
      );
      return;
    }

    String title = newStatus == 'completed' ? 'ไปพบแพทย์เรียบร้อย?' : 'ไม่ได้ไปตามนัด?';
    String content = newStatus == 'completed' 
        ? 'คุณได้ไปพบแพทย์ตามนัดหมายนี้เรียบร้อยแล้วใช่หรือไม่?' 
        : 'คุณไม่ได้ไปพบแพทย์ตามนัดนี้ (ขาดนัด) ใช่หรือไม่?';
    Color btnColor = newStatus == 'completed' ? Colors.teal : Colors.red;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: TextStyle(color: btnColor, fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: btnColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final int baseId = appt.appointmentId.hashCode.abs();
    final notiService = NotificationService();
    await notiService.cancelNotification(baseId + 1);
    await notiService.cancelNotification(baseId + 2);
    await notiService.cancelNotification(baseId + 3);

    await _appointmentDao.updateAppointmentStatus(
      id: appt.appointmentId,
      newStatus: newStatus,
    );

    await _loadAppointments();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus == 'completed' ? 'บันทึกประวัติการเข้าพบแพทย์แล้ว' : 'บันทึกว่าขาดนัดแล้ว'),
          backgroundColor: newStatus == 'completed' ? Colors.green : Colors.orange,
        ),
      );
    }

    _trySyncStatusToCloud(appt.appointmentId);
  }

  Future<void> _trySyncStatusToCloud(String apptId) async {
    try {
      final hasNet = await _connectivity.hasInternet();
      if (!hasNet) return;

      final updatedAppt = await _appointmentDao.getAppointmentById(apptId);
      if (updatedAppt != null && _userId != null) {
        await _firebaseHelper.uploadAppointment(_userId!, updatedAppt);
        await _appointmentDao.markAsSynced(apptId, _userId!);
      }
    } catch (_) {}
  }

  bool _isTodayOrPast(String dateStr) {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final apptDate = DateTime.parse(dateStr);
      final apptDateOnly = DateTime(apptDate.year, apptDate.month, apptDate.day);

      return !apptDateOnly.isAfter(today);
    } catch (_) {
      return false;
    }
  }

  String _calculateDaysLeft(String dateStr) {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final appointDate = DateTime.parse(dateStr);
      final appointDateOnly = DateTime(appointDate.year, appointDate.month, appointDate.day);

      final diff = appointDateOnly.difference(today).inDays;

      if (diff < 0) return "ผ่านมาแล้ว";
      if (diff == 0) return "วันนี้";
      if (diff == 1) return "พรุ่งนี้";
      return "อีก $diff วัน";
    } catch (_) {
      return "-";
    }
  }

  String _formatThaiDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat("d MMMM yyyy", 'th_TH').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  void _speakAppointment(AppointmentModel appt) {
    String text = 'นัดหมายกับ ${appt.doctorName ?? "แพทย์"}, ';
    text += 'วันที่ ${_formatThaiDate(appt.appointmentDate)}, ';
    text += 'เวลา ${appt.appointmentTime} นาฬิกา';
    text += appt.department != null ? ', สถานที่ ${appt.department}' : '';
    text += appt.location != null ? ' ${appt.location}' : '';
    text += appt.appointmentType != null ? ', ประเภท ${appt.appointmentType}' : '';
    text += appt.advice != null ? '. คำแนะนำ: ${appt.advice}' : '';
    _tts.setLanguage('th-TH');
    _tts.speak(text);
  }

  // ฟังก์ชันแสดงรายละเอียดนัดหมาย (Bottom Sheet)
  void _showAppointmentDetails(AppointmentModel appt, bool isDark) {
    String statusText = "รอยืนยัน (เลยกำหนด)";
    Color statusColor = Colors.orange;

    if (appt.status == 'completed') {
      statusText = "พบแพทย์แล้ว";
      statusColor = Colors.green;
    } else if (appt.status == 'missed') {
      statusText = "ไม่ได้เข้าพบแพทย์ (ขาดนัด)";
      statusColor = Colors.red;
    } else if (!_isTodayOrPast(appt.appointmentDate)) {
      statusText = "รอนัดหมาย";
      statusColor = Colors.teal;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ขีดสีเทาด้านบนสุด
              Container(
                width: 50, height: 5,
                decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 20),
              Text(
                "รายละเอียดนัดหมาย",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 16),

              // สถานะ
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor),
                ),
                child: Center(
                  child: Text(
                    "สถานะ: $statusText",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ข้อมูลนัดหมาย
              _buildDetailRow(Icons.calendar_month, "วันที่:", _formatThaiDate(appt.appointmentDate), isDark),
              _buildDetailRow(Icons.access_time, "เวลา:", "${appt.appointmentTime} น.", isDark),
              const Divider(height: 30),
              _buildDetailRow(Icons.person, "แพทย์:", appt.doctorName ?? "-", isDark),
              _buildDetailRow(Icons.local_hospital, "แผนก:", appt.department ?? "-", isDark),
              _buildDetailRow(Icons.location_on, "สถานที่:", appt.location ?? "-", isDark),
              _buildDetailRow(Icons.assignment, "ประเภท:", appt.appointmentType ?? "-", isDark),
              
              if (appt.advice != null && appt.advice!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.orange.shade900.withOpacity(0.2) : Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("คำแนะนำจากแพทย์:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(appt.advice!, style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("ปิด", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Widget ช่วยสร้างบรรทัดข้อมูลใน Bottom Sheet
  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.teal, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14)),
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: const TabBar(
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: Colors.teal,
                      borderRadius: BorderRadius.all(Radius.circular(10.0)),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.teal,
                    tabs: [
                      Tab(child: Text('นัดหมายเร็วๆ นี้', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                      Tab(child: Text('ประวัติการนัดหมาย', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                    : TabBarView(
                        children: [
                          RefreshIndicator(
                            onRefresh: _onRefresh,
                            color: Colors.teal,
                            child: _upcomingAppointments.isEmpty
                                ? _buildNoAppointmentView("ไม่มีนัดหมายเร็วๆ นี้", Icons.event_available, isDark)
                                : ListView(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    children: [
                                      if (_nextAppointment != null)
                                        _buildNextAppointmentCard(_nextAppointment!, isDark),

                                      if (_upcomingAppointments.length > 1) ...[
                                        const SizedBox(height: 20),
                                        Text("รายการนัดหมายอื่นๆ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey)),
                                        const SizedBox(height: 10),
                                        ..._upcomingAppointments.skip(1).map((appt) => _buildHistoryCard(appt, isHistory: false, isDark: isDark)),
                                      ],
                                    ],
                                  ),
                          ),

                          RefreshIndicator(
                            onRefresh: _onRefresh,
                            color: Colors.teal,
                            child: _historyAppointments.isEmpty
                                ? _buildNoAppointmentView("ไม่มีประวัติการนัดหมาย", Icons.history, isDark)
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    itemCount: _historyAppointments.length,
                                    itemBuilder: (context, index) {
                                      return _buildHistoryCard(_historyAppointments[index], isHistory: true, isDark: isDark);
                                    },
                                  ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoAppointmentView(String message, IconData icon, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: isDark ? Colors.grey[700] : Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 18, color: isDark ? Colors.grey[500] : Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildNextAppointmentCard(AppointmentModel appt, bool isDark) {
    final bool canComplete = _isTodayOrPast(appt.appointmentDate);

    return Card(
      elevation: 4,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(20)),
                  child: const Row(
                    children: [
                      Icon(Icons.star, color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text("นัดหมายครั้งต่อไป", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(0.5),
                  decoration: BoxDecoration(color: isDark ? Colors.teal.shade900 : Colors.teal.shade50, shape: BoxShape.circle),
                  child: IconButton(
                    icon: Icon(Icons.volume_up, size: 28, color: isDark ? Colors.tealAccent : Colors.teal),
                    onPressed: () => _speakAppointment(appt),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _calculateDaysLeft(appt.appointmentDate),
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.teal),
            ),
            Text(
              "${_formatThaiDate(appt.appointmentDate)} เวลา ${appt.appointmentTime} น.",
              style: TextStyle(fontSize: 20, color: isDark ? Colors.white : Colors.black87),
            ),
            const Divider(height: 30),
            _buildInfoRow(Icons.person, "แพทย์", appt.doctorName ?? "-", isDark),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.location_on, "สถานที่", "${appt.department ?? ''} ${appt.location ?? ''}", isDark),
            if (appt.appointmentType != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(Icons.assignment, "ประเภท", appt.appointmentType!, isDark),
            ],
            if (appt.advice != null && appt.advice!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color.fromARGB(255, 230, 165, 0).withOpacity(0.3) : Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("คำแนะนำ:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    const SizedBox(height: 4),
                    Text(appt.advice!, style: TextStyle(fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            if (canComplete)
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: () => _updateAppointmentStatus(appt, 'missed'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red.shade300, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text("ขาดนัด", style: TextStyle(fontSize: 18, color: Colors.red.shade400, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _updateAppointmentStatus(appt, 'completed'),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text("ไปพบแพทย์แล้ว", style: TextStyle(fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.calendar_month),
                  label: const Text("ยังไม่ถึงวันนัด", style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    disabledBackgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                    disabledForegroundColor: Colors.grey[500],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(AppointmentModel appt, {required bool isHistory, required bool isDark}) {
    String statusText = "รอยืนยัน";
    Color statusColor = Colors.orange;
    IconData statusIcon = Icons.help_outline;

    if (appt.status == 'completed') {
      statusText = "เสร็จสิ้น";
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (appt.status == 'missed') {
      statusText = "ขาดนัด";
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    } else if (isHistory) {
      statusText = "เลยกำหนด";
      statusColor = Colors.orange;
      statusIcon = Icons.warning_amber_rounded;
    }

    // เปลี่ยน Card ให้แตะได้ (หุ้มด้วย InkWell หรือใส่ onTap ใน ListTile)
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showAppointmentDetails(appt, isDark), // เรียก Bottom Sheet
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: isHistory 
                ? (isDark ? Colors.grey[800] : Colors.grey[200]) 
                : (isDark ? Colors.teal[900] : Colors.teal[100]),
            child: Icon(isHistory ? statusIcon : Icons.event, color: isHistory ? statusColor : Colors.teal),
          ),
          title: Text(
            appt.doctorName ?? "ไม่ระบุแพทย์",
            style: TextStyle(fontWeight: FontWeight.bold, color: isHistory ? (isDark ? Colors.grey[400] : Colors.grey[700]) : Theme.of(context).textTheme.bodyLarge?.color),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text("${_formatThaiDate(appt.appointmentDate)} | ${appt.appointmentTime} น.", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[800])),
              if (appt.location != null)
                Text(appt.location!, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[600] : Colors.grey[600])),
            ],
          ),
          trailing: isHistory
              ? Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 16))
              : Icon(Icons.chevron_right, color: isDark ? Colors.grey[600] : Colors.grey),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: isDark ? Colors.grey[500] : Colors.grey[600], size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 14)),
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }
}