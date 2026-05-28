import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:ya_time/data_models/medication_item.dart';
import 'package:intl/intl.dart';
import 'package:ya_time/service/deletemed_service.dart';
import 'package:ya_time/service/editmed_service.dart';
import 'package:ya_time/service/resumemed_service.dart';
import 'package:ya_time/app_session.dart';

class MedicationDetailScreen extends StatefulWidget {
  final MedicationItem medicationItem;
  final int daysLeft;
  final bool isExpired;

  const MedicationDetailScreen({
    super.key,
    required this.medicationItem,
    required this.daysLeft,
    this.isExpired = false,
  });

  @override
  State<MedicationDetailScreen> createState() => _MedicationDetailScreenState();
}

class _MedicationDetailScreenState extends State<MedicationDetailScreen> {
  // Controllers สำหรับยา Custom
  late TextEditingController _medNameController;
  late TextEditingController _genericNameController;
  late TextEditingController _dosageController;
  late TextEditingController _doseAmountController;
  late TextEditingController _instructionsController;
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;

  bool _isEditing = false;
  bool _isSaving = false;
  bool _isDeleting = false;

  List<TimeOfDay> _times = [];

  @override
  void initState() {
    super.initState();
    _initControllers();
    _initTimesFromString(widget.medicationItem.prescription.timeToNotify);
  }

  void _initControllers() {
    final med = widget.medicationItem.medication;
    final presc = widget.medicationItem.prescription;

    _medNameController = TextEditingController(text: med.medName);
    _genericNameController = TextEditingController(
      text: med.medGenericName ?? '',
    );
    _dosageController = TextEditingController(text: med.dosageStrength ?? '');
    _doseAmountController = TextEditingController(text: presc.doseAmount ?? '');
    _instructionsController = TextEditingController(
      text: presc.instructions ?? '',
    );
    _startDateController = TextEditingController(text: presc.startDate ?? '');
    _endDateController = TextEditingController(text: presc.endDate ?? '');
  }

  void _initTimesFromString(String? timeString) {
    if (timeString == null || timeString.isEmpty) return;

    _times = timeString.split(',').map((t) {
      final parts = t.trim().split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }).toList();
  }

  @override
  void dispose() {
    _medNameController.dispose();
    _genericNameController.dispose();
    _dosageController.dispose();
    _doseAmountController.dispose();
    _instructionsController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  bool get _isCustomMedicine => widget.medicationItem.medication.isCustom == 1;

  String _formatDate(DateTime date) {
    try {
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _saveChanges() async {
    if (_times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากำหนดเวลาแจ้งเตือนอย่างน้อย 1 เวลา'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final editService = EditMedicationService();
      final med = widget.medicationItem.medication;
      final presc = widget.medicationItem.prescription;

      final startDate = _startDateController.text.trim().isEmpty
          ? presc.startDate
          : _startDateController.text.trim();

      final endDate = _endDateController.text.trim().isEmpty
          ? presc.endDate
          : _endDateController.text.trim();

      if (startDate == null ||
          startDate.isEmpty ||
          endDate == null ||
          endDate.isEmpty) {
        throw Exception('กรุณากำหนดวันเริ่มต้นและวันสิ้นสุด');
      }

      await editService.editMedication(
        userId: AppSession.instance.getUserId() ?? 'unknown',
        prescriptionId: presc.prescriptionId,
        medId: med.medId,
        medName: _medNameController.text.trim().isEmpty
            ? med.medName
            : _medNameController.text.trim(),
        genericName: _genericNameController.text.trim().isEmpty
            ? med.medGenericName
            : _genericNameController.text.trim(),
        dosageStrength: _dosageController.text.trim().isEmpty
            ? med.dosageStrength
            : _dosageController.text.trim(),
        type: med.type,
        doseAmount: _doseAmountController.text.trim().isEmpty
            ? presc.doseAmount
            : _doseAmountController.text.trim(),
        instructions: _instructionsController.text.trim().isEmpty
            ? presc.instructions
            : _instructionsController.text.trim(),
        startDate: startDate,
        endDate: endDate,
        timeToNotify: _buildTimeString(),
        rescheduleFromToday: false,
      );

      if (!mounted) return;

      setState(() {
        _isSaving = false;
        _isEditing = false;
      });

      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // แก้ไข: แบ่งตัวเลือกลบเป็น 2 แบบ (ลบทิ้งถาวร vs หยุดใช้)
  Future<void> _showDeleteOptionsDialog(
    BuildContext context,
    MedicationItem item,
  ) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ต้องการจัดการยานี้อย่างไร?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // ตัวเลือกที่ 1: หยุดการใช้งาน (ย้ายไปประวัติ)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.archive, color: Colors.orange.shade800),
                ),
                title: const Text(
                  'แพทย์สั่งหยุดยา / เลิกทานแล้ว',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'ยาจะไม่แจ้งเตือนอีก แต่จะถูกเก็บไว้ใน "ยาที่เคยใช้"',
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _handleStopMedication(item);
                },
              ),
              const Divider(height: 30),

              // ตัวเลือกที่ 2: ลบทิ้งถาวร (กรอกผิด)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.delete_forever, color: Colors.red.shade800),
                ),
                title: const Text(
                  'ลบทิ้งถาวร (กรอกข้อมูลผิด)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                subtitle: const Text('ลบข้อมูลนี้ออกจากระบบทั้งหมด'),
                onTap: () async {
                  Navigator.pop(context);
                  await _handlePermanentDelete(item);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // Logic สำหรับ "แพทย์สั่งหยุดยา" (ย้ายไป History)
  Future<void> _handleStopMedication(MedicationItem item) async {
    setState(() => _isDeleting = true);
    try {
      final editService = EditMedicationService();

      // ตั้งค่า endDate เป็นเมื่อวาน เพื่อให้ถือว่ายาหมดอายุแล้ว
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayStr = yesterday.toIso8601String().substring(0, 10);

      await editService.editMedication(
        userId: AppSession.instance.getUserId() ?? 'unknown',
        prescriptionId: item.prescription.prescriptionId,
        medId: item.medication.medId,
        endDate: yesterdayStr, // เปลี่ยนแค่วันสิ้นสุด
        rescheduleFromToday: true, // เพื่อให้มันลบ Schedule ล่วงหน้าทิ้ง
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("ย้ายไปที่รายการ 'ยาที่เคยใช้' แล้ว"),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ เกิดข้อผิดพลาด: $e")));
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  // Logic สำหรับ "ลบทิ้งถาวร" (โค้ดเดิมของคุณ)
  Future<void> _handlePermanentDelete(MedicationItem item) async {
    // โชว์ Dialog ยืนยันอีกครั้งกันพลาด
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบข้อมูลถาวร?', style: TextStyle(color: Colors.red)),
        content: const Text('ข้อมูลจะถูกลบและไม่สามารถกู้คืนได้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบเลย', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isDeleting = true);
      try {
        await DeleteMedicationService().deleteMedication(
          AppSession.instance.getUserId() ?? 'unknown',
          item.prescription.prescriptionId,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("ลบข้อมูลสำเร็จ")));
        Navigator.pop(context, true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("❌ ลบไม่สำเร็จ: $e")));
        }
      } finally {
        if (mounted) setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    DateTime initialDate = DateTime.now();

    if (controller.text.isNotEmpty) {
      try {
        initialDate = DateFormat('yyyy-MM-dd').parse(controller.text);
      } catch (e) {
        initialDate = DateTime.now();
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 5),
    );

    if (picked != null) {
      setState(() {
        try {
          controller.text = DateFormat('yyyy-MM-dd').format(picked);
        } catch (e) {
          controller.text =
              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
        }
      });
    }
  }

  Future<void> _editTime(int index) async {
    final currentTime = _times[index];

    final picked = await showTimePicker(
      context: context,
      initialTime: currentTime,
    );

    if (picked != null) {
      setState(() {
        _times[index] = picked;
      });
    }
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );

    if (picked != null) {
      setState(() {
        _times.add(picked);
        _times.sort(
          (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
        );
      });
    }
  }

  void _showResumeBottomSheet(BuildContext context, dynamic item) {
    int durationDays = 7;
    DateTime selectedStartDate = DateTime.now();

    // 1. เช็คก่อนเลยว่ายานี้ "นับเป็นชิ้นๆ ได้ไหม?" (ถ้าน้ำจะไม่ให้นับ)
    final bool canCalculateQty = item.medication.type != 'น้ำ';

    // ถ้าคำนวณไม่ได้ (เป็นยาน้ำ) ให้บังคับกรอกเป็นวันเสมอ
    bool isInputByDays = true;
    TextEditingController totalQtyController = TextEditingController();

    int mealsPerDay = 1;
    if (item.prescription.timeToNotify != null &&
        item.prescription.timeToNotify.isNotEmpty) {
      mealsPerDay = item.prescription.timeToNotify.split(',').length;
    }

    double dosePerMeal = 1.0;
    if (item.prescription.doseAmount != null) {
      String doseStr = item.prescription.doseAmount!.replaceAll(
        RegExp(r'[^0-9.]'),
        '',
      );
      dosePerMeal = double.tryParse(doseStr) ?? 1.0;
    }

    String unit = item.medication.type == 'น้ำ'
        ? 'ช้อนชา'
        : item.medication.type == 'ผง'
        ? 'ซอง'
        : item.medication.type == 'ฉีด'
        ? 'เข็ม'
        : 'เม็ด';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void calculateDays() {
              int totalQty = int.tryParse(totalQtyController.text) ?? 0;
              if (totalQty > 0 && dosePerMeal > 0 && mealsPerDay > 0) {
                setModalState(() {
                  durationDays = (totalQty / (dosePerMeal * mealsPerDay))
                      .ceil();
                });
              }
            }

            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'ตั้งค่าการเริ่มทานยาใหม่',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // 2. ถ้าเป็นยาน้ำ จะไม่โชว์แถบสลับนี้เลย!
                  if (canCalculateQty)
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setModalState(() => isInputByDays = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isInputByDays
                                      ? Colors.teal
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "ระบุจำนวนวัน",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isInputByDays
                                        ? Colors.white
                                        : (isDark
                                              ? Colors.grey[400]
                                              : Colors.black54),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() {
                                isInputByDays = false;
                                totalQtyController.clear();
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: !isInputByDays
                                      ? Colors.teal
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "ระบุจำนวนยา",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: !isInputByDays
                                        ? Colors.white
                                        : (isDark
                                              ? Colors.grey[400]
                                              : Colors.black54),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (canCalculateQty) const SizedBox(height: 20),

                  //  3. ถ้าเป็นยาน้ำ จะข้ามมาโชว์ตัวปรับ "จำนวนวัน" ทันที
                  if (isInputByDays)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        "ทานต่อเนื่อง (วัน)",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.teal,
                              size: 30,
                            ),
                            onPressed: () => setModalState(
                              () => durationDays > 1 ? durationDays-- : null,
                            ),
                          ),
                          Text(
                            '$durationDays',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle_outline,
                              color: Colors.teal,
                              size: 30,
                            ),
                            onPressed: () =>
                                setModalState(() => durationDays++),
                          ),
                        ],
                      ),
                    )
                  else
                    TextField(
                      controller: totalQtyController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 20),
                      decoration: InputDecoration(
                        labelText: 'จำนวนยาทั้งหมดที่ซื้อมา',
                        labelStyle: const TextStyle(fontSize: 18),
                        suffixText: unit,
                        suffixStyle: const TextStyle(fontSize: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(
                          Icons.medical_information,
                          color: Colors.teal,
                        ),
                      ),
                      onChanged: (val) => calculateDays(),
                    ),

                  const SizedBox(height: 20),

                  // สรุปข้อมูล
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.teal.shade900.withOpacity(0.3)
                          : Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          color: Colors.teal,
                          size: 30,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'รวมต้องทาน: $durationDays วัน',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'ยาจะหมดวันที่: ${_formatDate(selectedStartDate.add(Duration(days: durationDays - 1)))}',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        if (!isInputByDays && totalQtyController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('กรุณากรอกจำนวนยา')),
                          );
                          return;
                        }

                        final newEndDate = selectedStartDate.add(
                          Duration(days: durationDays - 1),
                        );

                        await ResumeMedicationService().resumeMedication(
                          userId: AppSession.instance.getUserId() ?? 'unknown',
                          prescriptionId: item.prescription.prescriptionId,
                          medId: item.medication.medId,
                          startDate: selectedStartDate,
                          endDate: newEndDate,
                        );

                       if (context.mounted) {
                          Navigator.pop(context); 
                          Navigator.pop(context, 'resume_success');
                        }
                      },
                      child: const Text(
                        'ยืนยัน',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.medicationItem;

    return Scaffold(
      appBar: AppBar(
        title: const Text('รายละเอียดยา'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          if (!widget.isExpired)
            IconButton(
              icon: Icon(_isEditing ? Icons.close : Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = !_isEditing;
                  if (!_isEditing) {
                    _initControllers();
                  }
                });
              },
            ),
        ],
      ),
      body: (_isSaving || _isDeleting)
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(height: 16),
                  Text('กำลังบันทึกข้อมูล...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.medical_services,
                        size: 48,
                        color: Colors.teal,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _isEditing && _isCustomMedicine
                            ? TextField(
                                controller: _medNameController,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'ชื่อยา',
                                  border: OutlineInputBorder(),
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.medication.medName,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (item.medication.medGenericName != null)
                                    Text(
                                      item.medication.medGenericName!,
                                      style: TextStyle(
                                        fontSize: 18,
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.grey[400]
                                            : Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.volume_up, size: 32),
                        color: Colors.blueGrey,
                        onPressed: () {
                          FlutterTts().speak(
                            'ยาที่ต้องทานคือ ${item.medication.medName}, จำนวน ${item.prescription.doseAmount}, ${item.prescription.instructions} เวลาแจ้งเตือน ${item.prescription.timeToNotify}, เริ่มต้นวันที่ ${item.prescription.startDate}, สิ้นสุดวันที่ ${item.prescription.endDate}',
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  _buildInfoCard(
                    title: 'ข้อมูลทั่วไป',
                    children: [
                      if (_isCustomMedicine && _isEditing)
                        _buildEditField('ชื่อสามัญ', _genericNameController),

                      if (_isCustomMedicine && _isEditing)
                        _buildEditField('ขนาดยา', _dosageController)
                      else
                        _buildInfoRow(
                          'ขนาดยา',
                          item.medication.dosageStrength ?? 'ไม่ระบุ',
                        ),

                      if (_isCustomMedicine && _isEditing)
                        _buildEditField(
                          'ปริมาณที่ต้องทาน',
                          _doseAmountController,
                        )
                      else
                        _buildInfoRow(
                          'ปริมาณที่ต้องทาน',
                          item.prescription.doseAmount ?? 'ไม่ระบุ',
                        ),

                      if (_isCustomMedicine && _isEditing)
                        _buildEditField('คำแนะนำ', _instructionsController)
                      else
                        _buildInfoRow(
                          'คำแนะนำ',
                          item.prescription.instructions ?? 'ไม่ระบุ',
                        ),

                      if (_isEditing)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'เวลาแจ้งเตือน',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),

                            ..._times.asMap().entries.map((entry) {
                              final index = entry.key;
                              final time = entry.value;

                              return ListTile(
                                leading: const Icon(
                                  Icons.access_time,
                                  color: Colors.teal,
                                ),
                                title: Text(
                                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _editTime(index),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => setState(
                                        () => _times.removeAt(index),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),

                            Center(
                              child: TextButton.icon(
                                onPressed: _addTime,
                                icon: const Icon(
                                  Icons.add_circle,
                                  color: Colors.teal,
                                  size: 30,
                                ),
                                label: const Text(
                                  'เพิ่มเวลาแจ้งเตือน',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.teal,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        _buildInfoRow(
                          'เวลาแจ้งเตือน',
                          item.prescription.timeToNotify ?? 'ไม่ระบุ',
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _buildInfoCard(
                    title: 'ระยะเวลาการใช้',
                    children: [
                      if (_isCustomMedicine && _isEditing)
                        _buildPickerField(
                          label: 'เริ่มต้น',
                          controller: _startDateController,
                          icon: Icons.calendar_today,
                          onTap: () => _pickDate(_startDateController),
                        )
                      else
                        _buildInfoRow(
                          'เริ่มต้น',
                          (item.prescription.startDate?.split('T').first) ??
                              'ไม่ระบุ',
                        ),

                      if (_isCustomMedicine && _isEditing)
                        _buildPickerField(
                          label: 'สิ้นสุด',
                          controller: _endDateController,
                          icon: Icons.calendar_today,
                          onTap: () => _pickDate(_endDateController),
                        )
                      else
                        _buildInfoRow(
                          'สิ้นสุด',
                          (item.prescription.endDate?.split('T').first) ??
                              'ไม่ระบุ',
                        ),

                      _buildInfoRow(
                        'เหลืออีก',
                        '${widget.daysLeft} วัน',
                        highlight: widget.daysLeft < 7,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _buildInfoCard(
                    title: 'ประเภท',
                    children: [
                      _buildInfoRow(
                        'แหล่งที่มา',
                        _isCustomMedicine ? 'เพิ่มเอง' : 'จากโรงพยาบาล',
                        highlight: _isCustomMedicine,
                      ),
                    ],
                  ),

                  // ปุ่มลบ/ยกเลิก (เปลี่ยนมาเรียก _showDeleteOptionsDialog)
                  if (!_isEditing && !widget.isExpired)
                    if (item.medication.isCustom == 1)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _showDeleteOptionsDialog(context, item),
                          icon: const Icon(Icons.delete_sweep),
                          label: const Text(
                            'จัดการยา',
                            style: TextStyle(fontSize: 20),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade400,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                  const SizedBox(height: 24),

                  if (widget.isExpired && _isCustomMedicine)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          _showResumeBottomSheet(context, item);
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text(
                          'ใช้ยานี้อีกครั้ง',
                          style: TextStyle(fontSize: 20),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                  if (_isEditing)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'บันทึกการเปลี่ยนแปลง',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool highlight = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: highlight
                    ? Colors.orange
                    : (isDark ? Colors.white : Colors.black87),
                fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildPickerField({
    required String label,
    required TextEditingController controller,
    required VoidCallback onTap,
    IconData icon = Icons.edit,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        readOnly: true,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  String _buildTimeString() {
    return _times
        .map(
          (t) =>
              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
        )
        .join(', ');
  }
}
