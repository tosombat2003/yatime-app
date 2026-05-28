import 'package:flutter/material.dart';
import 'package:ya_time/service/addmed_service.dart';
import 'package:ya_time/app_session.dart';

class AddMedScreen extends StatefulWidget {
  const AddMedScreen({super.key});

  @override
  State<AddMedScreen> createState() => _AddMedScreenState();
}

enum MedicineType { pill, liquid, powder, injection }
enum MealTime { morning, noon, evening, night }

class _AddMedScreenState extends State<AddMedScreen> {
  MedicineType? selectedMedicineType;

  final Map<MealTime, TimeOfDay> defaultTimes = {
    MealTime.morning: const TimeOfDay(hour: 8, minute: 0),
    MealTime.noon: const TimeOfDay(hour: 12, minute: 0),
    MealTime.evening: const TimeOfDay(hour: 18, minute: 0),
    MealTime.night: const TimeOfDay(hour: 21, minute: 0),
  };

  Map<MealTime, TimeOfDay> selectedTimes = {};

  int _currentStep = 0;
  
  // Controllers
  final _nameController = TextEditingController();
  final _genericNameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _doseAmountController = TextEditingController(text: '1');
  final _typeController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _timesPerDayController = TextEditingController();
  final _durationDaysController = TextEditingController();
  
  // Controller สำหรับกรอกจำนวนยาทั้งหมด
  final _totalQtyController = TextEditingController(); 

  // ตัวแปรเช็คว่าจะกรอกแบบไหน (true=กรอกวัน, false=กรอกจำนวนยา)
  bool _isInputByDays = true; 

  String? _instruction; 
  final List<String> _timingOptions = ['ก่อนอาหาร', 'หลังอาหาร', 'พร้อมอาหาร'];

  String get _currentUnit {
    switch (selectedMedicineType) {
      case MedicineType.pill: return 'เม็ด';
      case MedicineType.liquid: return 'ช้อนชา'; 
      case MedicineType.powder: return 'ซอง';
      case MedicineType.injection: return 'เข็ม'; 
      default: return 'หน่วย';
    }
  }

  // เช็คว่ายาประเภทนี้รองรับการคำนวณจำนวนเม็ดไหม (ถ้าน้ำจะไม่ให้คำนวณ)
  bool get _canCalculateQty {
    return selectedMedicineType != null && selectedMedicineType != MedicineType.liquid;
  }

  void _calculateDurationFromQty() {
    if (_isInputByDays) return; 

    final int totalQty = int.tryParse(_totalQtyController.text) ?? 0;
    final double dosePerMeal = double.tryParse(_doseAmountController.text) ?? 1.0;
    final int mealsPerDay = selectedTimes.length;

    if (totalQty > 0 && dosePerMeal > 0 && mealsPerDay > 0) {
      final int days = (totalQty / (dosePerMeal * mealsPerDay)).ceil();
      if (_durationDaysController.text != days.toString()) {
         _durationDaysController.text = days.toString();
      }
    } else {
      _durationDaysController.clear();
    }
  }

  bool get isFormEmpty {
    return _nameController.text.isEmpty && selectedMedicineType == null;
  }

  Future<bool> _handlePopAttempt() async {
    if (isFormEmpty) return true;
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยกเลิกการเพิ่มยา?', style: TextStyle(fontSize: 22)),
        content: const Text('ข้อมูลที่กรอกไว้จะหายไปทั้งหมด', style: TextStyle(fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('แก้ไขต่อ', style: TextStyle(fontSize: 18, color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ทิ้งข้อมูล', style: TextStyle(fontSize: 18, color: Colors.white)),
          ),
        ],
      ),
    );
    return shouldExit ?? false;
  }

  void updateTimesText() {
    final sortedTimes = selectedTimes.entries.toList()
      ..sort((a, b) {
        final aMin = a.value.hour * 60 + a.value.minute;
        final bMin = b.value.hour * 60 + b.value.minute;
        return aMin.compareTo(bMin);
      });

    final formattedTimes = sortedTimes.map((e) {
      final t = e.value;
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }).toList();

    _timesPerDayController.text = formattedTimes.join(', ');
    
    if (!_isInputByDays) _calculateDurationFromQty();
  }

  bool _validateStep1() {
    if (_nameController.text.trim().isEmpty) {
      _showError('กรุณากรอกชื่อยา');
      return false;
    }
    if (selectedMedicineType == null) {
      _showError('กรุณาเลือกประเภทของยา');
      return false;
    }
    if (_doseAmountController.text.trim().isEmpty) {
      _doseAmountController.text = '1';
    }
    return true;
  }

  bool _validateStep2() {
    if (selectedTimes.isEmpty) {
      _showError('กรุณาเลือกเวลาที่ต้องกินยาอย่างน้อย 1 เวลา');
      return false;
    }
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onStepContinue() async {
    if (_currentStep == 0) {
      if (!_validateStep1()) return;
    } else if (_currentStep == 1) {
      if (!_validateStep2()) return;
    }

    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep += 1;
        // Fix: ถ้าเพิ่งขยับมาหน้า 2 แล้วเป็นยาน้ำ ให้บังคับสลับกลับเป็น "กรอกวัน" ทันที
        if (_currentStep == 1 && !_canCalculateQty) {
          _isInputByDays = true; 
        } else if (_currentStep == 1 && !_isInputByDays) {
          _calculateDurationFromQty();
        }
      });
    } else {
      await _submitForm();
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    }
  }

  Future<void> _submitForm() async {
    final service = AddMedicationService();
    final String finalDoseAmount = '${_doseAmountController.text} $_currentUnit';

    await service.addMedication(
      userId: AppSession.instance.getUserId() ?? 'unknown',
      medName: _nameController.text,
      genericName: _genericNameController.text,
      dosageStrength: _dosageController.text,
      doseAmount: finalDoseAmount,
      type: _typeController.text,
      instructions: _instructionsController.text,
      startDate: DateTime.now().toIso8601String().substring(0, 10),
      endDate: _durationDaysController.text.isNotEmpty
          ? DateTime.now()
                .add(Duration(days: int.parse(_durationDaysController.text)))
                .toIso8601String()
                .substring(0, 10)
          : null,
      timeToNotify: _timesPerDayController.text,
      times: _timesPerDayController.text.split(', '),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกเรียบร้อย', style: TextStyle(fontSize: 18)), backgroundColor: Colors.green,),
      );
      Navigator.pop(context, true);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    String? suffixText,
    Function(String)? onChanged, 
    bool readOnly = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onChanged: onChanged,
        style: TextStyle(fontSize: 20, color: isDark ? Colors.white70 : Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 20, color: isDark ? Colors.grey[400] : Colors.grey[700]),
          prefixIcon: icon != null ? Icon(icon, color: Colors.teal) : null,
          suffixText: suffixText,
          suffixStyle: TextStyle(fontSize: 18, color: isDark ? Colors.grey[500] : Colors.black54),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          filled: readOnly,
          fillColor: readOnly ? (isDark ? Colors.grey[800] : Colors.grey[200]) : null,
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ประเภทของยา *', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: MedicineType.values.map((type) {
            IconData icon;
            String label;
            switch (type) {
              case MedicineType.pill: icon = Icons.medication; label = 'เม็ด'; break;
              case MedicineType.liquid: icon = Icons.local_drink; label = 'น้ำ'; break;
              case MedicineType.powder: icon = Icons.grain; label = 'ผง'; break;
              case MedicineType.injection: icon = Icons.vaccines; label = 'ฉีด'; break;
            }
            final isSelected = selectedMedicineType == type;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  selectedMedicineType = type;
                  _typeController.text = label;
                }),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.teal[100] : (isDark ? Colors.grey[800] : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.teal : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(icon, color: isSelected ? Colors.teal : (isDark ? Colors.grey[400] : Colors.grey), size: 30),
                      const SizedBox(height: 4),
                      Text(label, style: TextStyle(
                        fontSize: 18, 
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.teal[800] : (isDark ? Colors.grey[300] : Colors.black87),
                      )),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMealTimingPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Wrap(
        spacing: 12, runSpacing: 12, alignment: WrapAlignment.center,
        children: _timingOptions.map((timing) {
          final isSelected = _instruction == timing;
          return ChoiceChip(
            label: Text(timing, style: TextStyle(
              fontSize: 18, 
              color: isSelected ? Colors.teal[900] : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            )),
            selected: isSelected,
            selectedColor: Colors.teal[100],
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: isSelected ? Colors.teal : (isDark ? Colors.grey[700]! : Colors.grey.shade300)),
            ),
            onSelected: (selected) {
              setState(() {
                _instruction = selected ? timing : null;
                _instructionsController.text = _instruction ?? "";
              });
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimeSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: MealTime.values.map((time) {
            final isSelected = selectedTimes.containsKey(time);
            IconData icon;
            String label;
            switch (time) {
              case MealTime.morning: icon = Icons.wb_sunny; label = 'เช้า'; break;
              case MealTime.noon: icon = Icons.light_mode; label = 'กลางวัน'; break;
              case MealTime.evening: icon = Icons.wb_twilight; label = 'เย็น'; break;
              case MealTime.night: icon = Icons.nights_stay; label = 'ก่อนนอน'; break;
            }
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      selectedTimes.remove(time);
                    } else {
                      selectedTimes[time] = defaultTimes[time]!;
                    }
                    updateTimesText();
                  });
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.teal[100] : (isDark ? Colors.grey[800] : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.teal : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(icon, color: isSelected ? Colors.teal : (isDark ? Colors.grey[400] : Colors.grey), size: 30),
                      const SizedBox(height: 4),
                      Text(label, style: TextStyle(
                        fontSize: 18,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.teal[800] : (isDark ? Colors.grey[300] : Colors.black87),
                      )),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        if (selectedTimes.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text('เวลาแจ้งเตือน (แตะเพื่อแก้ไข)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          ),
          const SizedBox(height: 12),
          Column(
            children: selectedTimes.entries.map((entry) {
              final time = entry.key;
              final timeOfDay = entry.value;
              String label;
              switch (time) {
                case MealTime.morning: label = 'มื้อเช้า'; break;
                case MealTime.noon: label = 'มื้อกลางวัน'; break;
                case MealTime.evening: label = 'มื้อเย็น'; break;
                case MealTime.night: label = 'ก่อนนอน'; break;
              }
              return Card(
                elevation: 0,
                color: isDark ? const Color(0xFF1F3F3F) : Colors.teal[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isDark ? Colors.teal[700]! : Colors.teal.shade200),
                ),
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: const Icon(Icons.access_time_filled, color: Colors.teal, size: 30),
                  title: Text(label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.teal[700]! : Colors.teal.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${timeOfDay.hour.toString().padLeft(2, '0')}:${timeOfDay.minute.toString().padLeft(2, '0')} น.',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.edit, size: 20, color: isDark ? Colors.grey[400] : Colors.grey),
                      ],
                    ),
                  ),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: timeOfDay,
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(primary: Colors.teal),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setState(() {
                        selectedTimes[time] = picked;
                        updateTimesText();
                      });
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Icon(Icons.touch_app, size: 40, color: isDark ? Colors.grey[500] : Colors.grey),
                const SizedBox(height: 8),
                Text('กดเลือกมื้อด้านบนเพื่อตั้งเวลา', style: TextStyle(fontSize: 18, color: isDark ? Colors.grey[400] : Colors.grey)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 16, color: isDark ? Colors.grey[400] : Colors.grey)),
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Step Content ---
  List<Step> get _steps {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      Step(
        title: Text('ข้อมูลยา', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        content: Column(
          children: [
            const SizedBox(height: 8),
            _buildTextField(controller: _nameController, label: 'ชื่อยา *', icon: Icons.local_pharmacy),
            _buildTextField(controller: _genericNameController, label: 'ชื่อสามัญ', icon: Icons.description),
            _buildTypeSelector(),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildTextField(
                    controller: _dosageController, 
                    label: 'ขนาด (เช่น 500 mg)', 
                    icon: Icons.scale
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _buildTextField(
                    controller: _doseAmountController,
                    label: 'จำนวนกิน',
                    keyboardType: TextInputType.number,
                    suffixText: selectedMedicineType != null ? _currentUnit : null, 
                  ),
                ),
              ],
            ),
          ],
        ),
        isActive: _currentStep >= 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: Text('เวลาทาน', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Text('ทานช่วงไหน?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black))),
            const SizedBox(height: 12),
            _buildMealTimingPicker(),
            const SizedBox(height: 24),
            Text('เลือกมื้อที่ต้องทาน *', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            const SizedBox(height: 12),
            _buildTimeSelector(),
            const SizedBox(height: 24),
            Text('ระยะเวลาการทานยา', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            const SizedBox(height: 12),
            
            // ซ่อน Toggle สลับรูปแบบ ถ้าเป็นยาน้ำ
            if (_canCalculateQty)
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _isInputByDays = true;
                          _durationDaysController.clear();
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isInputByDays ? Colors.teal : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text("ระบุวัน", style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold,
                            color: _isInputByDays ? Colors.white : (isDark ? Colors.grey[400] : Colors.black54)
                          )),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _isInputByDays = false;
                          _totalQtyController.clear();
                          _durationDaysController.clear();
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isInputByDays ? Colors.teal : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text("คำนวณจากยา", style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold,
                            color: !_isInputByDays ? Colors.white : (isDark ? Colors.grey[400] : Colors.black54)
                          )),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_canCalculateQty) const SizedBox(height: 16),

            // บังคับโชว์กรอกจำนวนวันทันทีถ้าเป็นยาน้ำ
            if (_isInputByDays || !_canCalculateQty) 
              _buildTextField(
                controller: _durationDaysController,
                label: 'จำนวนวันที่ทาน',
                icon: Icons.calendar_month,
                keyboardType: TextInputType.number,
              )
            else 
              Column(
                children: [
                  _buildTextField(
                    controller: _totalQtyController,
                    label: 'จำนวนยาทั้งหมดที่ได้มา',
                    suffixText: _currentUnit,
                    icon: Icons.shopping_bag,
                    keyboardType: TextInputType.number,
                    onChanged: (val) => _calculateDurationFromQty(), 
                  ),
                  _buildTextField(
                    controller: _durationDaysController,
                    label: 'คำนวณแล้วต้องทาน (วัน)',
                    icon: Icons.calculate,
                    readOnly: true,
                  ),
                ],
              ),
          ],
        ),
        isActive: _currentStep >= 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: Text('ยืนยัน', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        content: Card(
          color: isDark ? const Color(0xFF1F3F3F) : Colors.teal[50],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildSummaryRow(Icons.local_pharmacy, 'ชื่อยา', _nameController.text),
                if (_genericNameController.text.isNotEmpty)
                  _buildSummaryRow(Icons.description, 'ชื่อสามัญ', _genericNameController.text),
                _buildSummaryRow(
                  Icons.category, 
                  'ประเภท/ขนาด', 
                  '${_typeController.text} ${_dosageController.text.isNotEmpty ? "(${_dosageController.text})" : ""}'
                ),
                const SizedBox(height: 8),
                const Divider(color: Colors.teal, thickness: 1),
                const SizedBox(height: 8),
                _buildSummaryRow(
                  Icons.numbers, 
                  'ปริมาณที่กิน', 
                  'ครั้งละ ${_doseAmountController.text} $_currentUnit'
                ),
                _buildSummaryRow(
                  Icons.restaurant, 
                  'ช่วงเวลา', 
                  _instructionsController.text.isEmpty ? '-' : _instructionsController.text
                ),
                _buildSummaryRow(
                  Icons.access_time_filled, 
                  'เวลาแจ้งเตือน', 
                  _timesPerDayController.text
                ),
                _buildSummaryRow(
                  Icons.event_repeat, 
                  'ระยะเวลา', 
                  _durationDaysController.text.isEmpty ? 'ทานตลอดไป' : '${_durationDaysController.text} วัน'
                ),
                if (!_isInputByDays && _canCalculateQty && _totalQtyController.text.isNotEmpty)
                   Padding(
                     padding: const EdgeInsets.only(top: 4, left: 36),
                     child: Text("(คำนวณจากยาทั้งหมด ${_totalQtyController.text} $_currentUnit)", 
                       style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600], fontStyle: FontStyle.italic)),
                   ),
              ],
            ),
          ),
        ),
        isActive: _currentStep == 2,
        state: StepState.indexed,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handlePopAttempt();
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('เพิ่มยาใหม่', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.close, size: 30),
            onPressed: () async {
              final shouldPop = await _handlePopAttempt();
              if (shouldPop && mounted) Navigator.of(context).pop();
            },
          ),
        ),
        body: Theme(
          data: Theme.of(context).copyWith(
            colorScheme: (Theme.of(context).brightness == Brightness.dark)
                ? const ColorScheme.dark(primary: Colors.teal, secondary: Colors.tealAccent)
                : const ColorScheme.light(primary: Colors.teal),
            inputDecorationTheme: const InputDecorationTheme(
              labelStyle: TextStyle(fontSize: 18),
            ),
          ),
          child: Stepper(
            currentStep: _currentStep,
            type: StepperType.horizontal,
            steps: _steps,
            onStepTapped: (index) {
              if (index > _currentStep) return; 
              setState(() => _currentStep = index);
            },
            onStepContinue: _onStepContinue,
            onStepCancel: _onStepCancel,
            controlsBuilder: (context, details) {
              final isLast = _currentStep == _steps.length - 1;
              return Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: details.onStepCancel,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Colors.teal, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('ย้อนกลับ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: details.onStepContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                        ),
                        child: Text(isLast ? 'บันทึก' : 'ถัดไป', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}