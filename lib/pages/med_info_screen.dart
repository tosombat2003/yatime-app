import 'package:flutter/material.dart';
import 'package:ya_time/database_local/repositories/medication_repository.dart';
import 'package:ya_time/data_models/medication_item.dart';
import 'package:ya_time/app_session.dart';
import 'full_med_info.dart';
import 'package:ya_time/service/sync_service.dart';
import 'package:ya_time/service/connectivity_service.dart';


class MedInfoScreen extends StatefulWidget {
  const MedInfoScreen({super.key});

  @override
  State<MedInfoScreen> createState() => _MedInfoScreenState();
}

class _MedInfoScreenState extends State<MedInfoScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _switchToCurrentTab() {
    _tabController.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                child: TabBar(
                  controller: _tabController, 
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: const BoxDecoration(
                    color: Colors.teal,
                    borderRadius: BorderRadius.all(Radius.circular(10.0)),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.teal,
                  tabs: const [
                    Tab(
                      child: Text(
                        'ยาปัจจุบัน',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Tab(
                      child: Text(
                        'ยาที่เคยใช้',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController, 
                children: [
                  const CurrentMed(),
                  UsedMed(onItemResumed: _switchToCurrentTab), 
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= ยาปัจจุบัน =================
class CurrentMed extends StatefulWidget {
  const CurrentMed({super.key});
  @override
  State<CurrentMed> createState() => _CurrentMedState();
}

class _CurrentMedState extends State<CurrentMed> {
  final MedicationRepository _medicationRepo = MedicationRepository();
  List<MedicationItem> _medications = [];
  bool _isLoading = false;
  late String _userId;

  @override
  void initState() {
    super.initState();
    _userId = AppSession().getUserId()!;
    _loadCurrentMedications();
  }

  Future<void> _loadCurrentMedications() async {
    setState(() => _isLoading = true);
    try {
      final items = await _medicationRepo.getCurrentMedications(_userId);
      setState(() {
        _medications = items;
        _isLoading = false;
      });
    } catch (error) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $error'), backgroundColor: Colors.red),
        );
      }
    }
  }

  int _calculateDaysLeft(MedicationItem item) {
    if (item.prescription.endDate == null) return -1;
    try {
      final end = DateTime.parse(item.prescription.endDate!);
      final now = DateTime.now();
      final endOnly = DateTime(end.year, end.month, end.day);
      final todayOnly = DateTime(now.year, now.month, now.day);
      return endOnly.difference(todayOnly).inDays;
    } catch (_) {
      return -1;
    }
  }

 Future<void> _onRefresh() async {
    final hasNet = await ConnectivityService().hasInternet();
    final syncService = SyncService();
    if (hasNet) {
      final userId = AppSession.instance.getUserId();
      if (userId != null) await syncService.syncAll(userId);
      
      await _loadCurrentMedications(); 
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ไม่มีการเชื่อมต่ออินเทอร์เน็ต')));
    }
  }
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.teal));
    if (_medications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medical_services_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('ไม่มียาปัจจุบัน', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: Colors.teal,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _medications.length,
        itemBuilder: (context, index) {
          final item = _medications[index];
          final daysLeft = _calculateDaysLeft(item);
          return MedicineCompactCard(
            medicationItem: item,
            daysLeft: daysLeft,
            isActive: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MedicationDetailScreen(medicationItem: item, daysLeft: daysLeft)),
              ).then((needRefresh) {
                if (needRefresh == true) _loadCurrentMedications();
              });
            },
          );
        },
      ),
    );
  }
}

// ================= ยาที่เคยใช้ =================
class UsedMed extends StatefulWidget {
  final VoidCallback? onItemResumed; 
  
  const UsedMed({super.key, this.onItemResumed});

  @override
  State<UsedMed> createState() => _UsedMedState();
}

class _UsedMedState extends State<UsedMed> {
  final MedicationRepository _medicationRepo = MedicationRepository();
  List<MedicationItem> _medications = [];
  bool _isLoading = false;
  late String _userId;

  @override
  void initState() {
    super.initState();
    _userId = AppSession().getUserId()!;
    _loadUsedMedications();
  }

  Future<void> _loadUsedMedications() async {
    setState(() => _isLoading = true);
    try {
      final items = await _medicationRepo.getUsedMedications(_userId);
      setState(() {
        _medications = items;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

Future<void> _onRefresh() async {
    final hasNet = await ConnectivityService().hasInternet();
    final syncService = SyncService();
    if (hasNet) {
      final userId = AppSession.instance.getUserId();
      if (userId != null) await syncService.syncAll(userId);

      await _loadUsedMedications();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ไม่มีการเชื่อมต่ออินเทอร์เน็ต')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.teal));
    if (_medications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medical_services_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('ไม่มียาที่เคยใช้', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: Colors.teal,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _medications.length,
        itemBuilder: (context, index) {
          final item = _medications[index];
          return MedicineCompactCard(
            medicationItem: item,
            daysLeft: -1, 
            isActive: false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MedicationDetailScreen(
                    medicationItem: item,
                    daysLeft: 0,
                    isExpired: true,
                  ),
                ),
              ).then((result) {
                if (result == 'resume_success') {
                  widget.onItemResumed?.call(); // สั่งหน้าแม่สลับแท็บ
                } else if (result == true) {
                  _loadUsedMedications(); // ถ้าแค่ลบ/แก้ประวัติธรรมดา ก็รีเฟรชหน้าเดิม
                }
              });
            },
          );
        },
      ),
    );
  }
}

// ================= Card =================
// ================= การ์ดยาแบบย่อ (สำหรับหน้ารวมยา) =================
class MedicineCompactCard extends StatelessWidget {
  final MedicationItem medicationItem;
  final int daysLeft;
  final bool isActive; // true = ยาปัจจุบัน (Teal), false = ยาที่เคยใช้ (Grey)
  final VoidCallback onTap;

  const MedicineCompactCard({
    super.key,
    required this.medicationItem,
    required this.daysLeft,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isActive 
          ? (isDark ? Colors.teal.shade900 : Colors.teal.shade50) 
          : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: isActive ? Colors.teal.shade200 : Colors.grey.shade400,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              // --- 1. ไอคอนประเภทยา ---
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getIconByType(medicationItem.medication.type),
                  size: 30,
                  color: isActive ? Colors.teal : Colors.grey[600],
                ),
              ),
              const SizedBox(width: 16),

              // --- 2. ข้อมูลยา ---
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ชื่อยา
                    Text(
                      medicationItem.medication.medName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        //color: isActive ? Colors.black87 : Colors.black54,
                      ),
                    ),
                    if (medicationItem.medication.medGenericName != null &&
                        medicationItem.medication.medGenericName!.isNotEmpty)
                      Text(
                        medicationItem.medication.medGenericName!,
                        style: TextStyle(
                          fontSize: 18,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    const SizedBox(height: 4),
                    // รายละเอียดการทาน
                    Text(
                      '${medicationItem.prescription.instructions ?? ""} | ${medicationItem.prescription.doseAmount ?? ""}',
                      style: const TextStyle(fontSize: 18),
                    ),
                    
                    // แสดงวันคงเหลือ (ถ้ามี)
                    if (isActive && daysLeft >= 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          daysLeft == 0 ? 'วันนี้วันสุดท้าย' : 'เหลืออีก $daysLeft วัน',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: daysLeft < 7 ? Colors.orange[800] : Colors.teal[700],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // --- 3. ปุ่มลูกศรบอกว่ากดได้ ---
              Icon(
                Icons.chevron_right,
                size: 32,
                color: isActive ? Colors.teal : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper เลือกไอคอน
  IconData _getIconByType(String? type) {
    final t = (type ?? '').trim();
    if (t == 'น้ำ') return Icons.local_drink;
    if (t == 'ผง') return Icons.grain;
    if (t == 'ฉีด') return Icons.vaccines;
    return Icons.medication;
  }
}