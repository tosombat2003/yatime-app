import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ya_time/database_local/dao/notification_dao.dart';
import 'package:ya_time/database_local/models/notification_model.dart';
import 'reminder_screen.dart';
import 'package:ya_time/main.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationDao _dao = NotificationDao();
  List<NotificationModel> _list = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _dao.getHistoryNotifications();
    if (mounted) {
      setState(() {
        _list = data;
        _isLoading = false;
      });
    }
  }

  //  ฟังก์ชันสำหรับแสดง Pop-up ยืนยันและล้างประวัติทั้งหมด
  Future<void> _confirmDeleteAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
            SizedBox(width: 10),
            Text('ยืนยันการล้างประวัติ', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('คุณต้องการลบประวัติการแจ้งเตือนทั้งหมดใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(fontSize: 18, color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบทิ้งทั้งหมด', style: TextStyle(color: Colors.white, fontSize: 18)),
          ),
        ],
      ),
    );

    if (confirm == true) {
     
      await _dao.deleteAllNotifications(); 
      _loadData(); // โหลดหน้าใหม่ให้ว่างเปล่า
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ล้างประวัติการแจ้งเตือนเรียบร้อยแล้ว')),
        );
      }
    }
  }

  Future<void> _onItemTap(NotificationModel item) async {
    // Mark as read
    if (item.isRead == 0 && item.id != null) {
      await _dao.markAsRead(item.id!);
      _loadData();
    }

    // Logic การเปลี่ยนหน้า
    if (item.type == 'appointment' || (item.payload?.startsWith('appoint|') ?? false)) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigationPage(initialIndex: 1)),
        (route) => false,
      );
    } else if (item.type == 'missed_med' || (item.payload?.startsWith('missed|') ?? false)) {
      int? sId;
      if (item.payload != null && item.payload!.contains('|')) {
        sId = int.tryParse(item.payload!.split('|')[1]);
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => MainNavigationPage(initialIndex: 0, targetScheduleId: sId),
        ),
        (route) => false,
      );
    } else if (item.payload != null) {
      // Logic ยาปกติ/Snooze
      int sId = 0;
      int retry = 0;
      if (item.payload!.contains('|')) {
        final parts = item.payload!.split('|');
        sId = int.tryParse(parts[0]) ?? 0;
        if (parts.length > 1) retry = int.tryParse(parts[1]) ?? 0;
      } else {
        sId = int.tryParse(item.payload!) ?? 0;
      }

      if (sId != 0) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ReminderScreen(scheduleId: sId, retryCount: retry)),
        );
      }
    }
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final now = DateTime.now();
      
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return "วันนี้ ${DateFormat('HH:mm').format(dt)}";
      } else if (dt.year == now.year && dt.month == now.month && dt.day == now.day - 1) {
        return "เมื่อวาน ${DateFormat('HH:mm').format(dt)}";
      }
      return DateFormat('d MMM HH:mm', 'th').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  // เลือกสีพื้นหลังไอคอนตามประเภท
  Color _getIconColor(String type) {
    if (type == 'appointment') return Colors.blue.shade100;
    if (type == 'missed_med') return Colors.orange.shade100;
    return Colors.teal.shade100;
  }

  Color _getIconContentColor(String type) {
    if (type == 'appointment') return Colors.blue.shade700;
    if (type == 'missed_med') return Colors.orange.shade700;
    return Colors.teal.shade700;
  }

  IconData _getIconByType(String type) {
    if (type == 'appointment') return Icons.calendar_month;
    if (type == 'missed_med') return Icons.warning_amber_rounded;
    return Icons.medication;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('การแจ้งเตือน', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // ตรวจสอบว่าถ้ามีรายการแจ้งเตือน ถึงจะแสดงปุ่ม 2 ปุ่มนี้
          if (_list.isNotEmpty) ...[
            TextButton.icon(
              icon: const Icon(Icons.done_all, size: 20, color: Colors.white),
              label: const Text("อ่านครบ", style: TextStyle(color: Colors.white)),
              onPressed: () async {
                await _dao.markAllAsRead();
                _loadData();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              tooltip: 'ล้างประวัติทั้งหมด',
              onPressed: _confirmDeleteAll, // เรียกใช้ฟังก์ชันด้านบน
            ),
            const SizedBox(width: 8), // ดันปุ่มไม่ให้ชิดขอบขวาเกินไป
          ]
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _list.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 100, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('ไม่มีการแจ้งเตือน', style: TextStyle(fontSize: 20, color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _list.length,
                  itemBuilder: (context, index) {
                    final item = _list[index];
                    final isUnread = item.isRead == 0;

                    return Dismissible(
                      key: Key(item.id.toString()),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red[400],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete_outline, color: Colors.white, size: 30),
                      ),
                      onDismissed: (direction) async {
                        if (item.id != null) await _dao.deleteNotification(item.id!);
                        setState(() {
                          _list.removeAt(index);
                        });
                      },
                      child: Card(
                        elevation: isUnread ? 4 : 1,
                        margin: const EdgeInsets.only(bottom: 12),
                        color: isUnread ? Theme.of(context).cardColor : Theme.of(context).scaffoldBackgroundColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: isUnread ? BorderSide(color: Colors.teal.shade100, width: 1.5) : BorderSide.none,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(15),
                          onTap: () => _onItemTap(item),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // --- ไอคอน ---
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: _getIconColor(item.type),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _getIconByType(item.type),
                                    color: _getIconContentColor(item.type),
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                
                                // --- เนื้อหา ---
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: isUnread ? Theme.of(context).textTheme.bodyLarge?.color : Colors.grey[700],
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isUnread)
                                            Container(
                                              width: 10, height: 10,
                                              decoration: const BoxDecoration(
                                                color: Colors.redAccent,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.body,
                                        style: TextStyle(fontSize: 18, color: Colors.grey[700], height: 1.4),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _formatDate(item.date),
                                        style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}