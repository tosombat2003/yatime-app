import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum MedicineCardFor { detailView, actionView }

class MedicineCard extends StatelessWidget {
  final Function(String)? onAction;
  final int? scheduleId;
  final DateTime? scheduledDateTime;

  final String name;
  final String genericName;
  final String dosage;
  final String amount;
  final String instructions;
  final String time;
  final String? medicineType; 
  final bool isActive;
  final MedicineCardFor type;
  final String status;
  final int? daysLeft;

  const MedicineCard({
    super.key,
    this.onAction,
    this.scheduleId,
    this.scheduledDateTime,
    required this.name,
    required this.genericName,
    required this.dosage,
    required this.amount,
    required this.instructions,
    required this.time,
    this.medicineType, 
    required this.isActive,
    this.type = MedicineCardFor.detailView,
    this.status = 'pending',
    this.daysLeft,
  });

  bool _canTakeMedicine() {
    DateTime now = DateTime.now();
    if (scheduledDateTime == null) return true;
    Duration diff = scheduledDateTime!.difference(now);
    return diff.inMinutes <= 30;
  }

  IconData _getIconByType() {
    // เช็คว่า medicineType มีคำว่าอะไรบ้าง
    final t = (medicineType ?? '').trim();
    if (t == 'น้ำ') return Icons.local_drink;
    if (t == 'ผง') return Icons.grain;
    if (t == 'ฉีด') return Icons.vaccines;
    
    // Default คือ ยาเม็ด
    return Icons.medication; 
  }

  Color _cardColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark; 
    
    if (status == 'taken') return isDark ? Colors.green.shade900 : const Color(0xFFE8F5E9);
    if (status == 'skipped') return isDark ? const Color.fromARGB(255, 182, 78, 23) : const Color(0xFFFFF3E0);
    return Theme.of(context).cardColor;
  }

  Color _borderColor() {
    if (status == 'taken') return Colors.green.shade600;
    if (status == 'skipped') return Colors.orange.shade600;
    return Colors.teal.shade200; 
  }

  @override
  Widget build(BuildContext context) {
    final bool isActionView = type == MedicineCardFor.actionView;
    final bool canTake = _canTakeMedicine();
    final bool isPending = status == 'pending';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final TextStyle nameStyle = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      decoration: !isPending ? TextDecoration.lineThrough : null,
    );

    final TextStyle detailStyle = const TextStyle(
      fontSize: 20,
      height: 1.4,
    );

    return Card(
      color: _cardColor(context),
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: _borderColor(), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- ส่วนที่ 1: ไอคอนยาด้านซ้าย (แสดงตามประเภท) ---
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isActive 
                        ? (isDark ? Colors.teal.shade900 : Colors.teal.shade50) 
                        : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    // ล็อกให้เป็นรูปยาตามประเภทเสมอ
                    _getIconByType(),
                    size: 36,
                    //เปลี่ยนสีตามสถานะ (กินแล้ว=เขียว, ข้าม=ส้ม, รอกิน=Teal)
                    color: status == 'taken' 
                        ? Colors.green 
                        : (status == 'skipped' ? Colors.orange : Colors.teal),
                  ),
                ),
                
                const SizedBox(width: 16),

                // --- ส่วนที่ 2: เนื้อหา ---
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(name, style: nameStyle),
                          ),
                          InkWell(
                            onTap: () {
                              FlutterTts().speak('$name จำนวน $amount $instructions');
                            },
                            borderRadius: BorderRadius.circular(50),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.volume_up, size: 28, color: Colors.teal),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      _buildBigInfoRow(Icons.description, instructions, detailStyle),
                      const SizedBox(height: 6),
                      _buildBigInfoRow(Icons.numbers, amount, detailStyle),
                      
                      if (!isActionView) ...[
                        Text(genericName, style: TextStyle(fontSize: 16, color: Colors.grey[600], fontStyle: FontStyle.italic)),
                      ]
                    ],
                  ),
                ),
              ],
            ),

            // --- ส่วนที่ 3: ปุ่ม Action (คงเดิม) ---
            if (isActionView) ...[
              const SizedBox(height: 16),
              const Divider(thickness: 1),
              const SizedBox(height: 12),

              if (isPending)
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildButton(
                        color: Colors.orange[50]!,
                        borderColor: Colors.orange.shade200,
                        shadowColor: Colors.orange.withValues(alpha: 0.1),
                        onTap: () => onAction?.call('skip'),
                        icon: Icons.close_rounded,
                        iconColor: Colors.deepOrange[700]!,
                        text: "ข้าม",
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildButton(
                        color: canTake ? Colors.teal[50]! : Colors.grey[200]!,
                        borderColor: canTake ? Colors.teal.shade300 : Colors.grey.shade400,
                        shadowColor: canTake ? Colors.teal.withValues(alpha: 0.1) : Colors.transparent,
                        onTap: canTake ? () => onAction?.call('ontime') : null,
                        icon: Icons.check_rounded,
                        iconColor: canTake ? Colors.teal[800]! : Colors.grey,
                        text: "กินแล้ว",
                      ),
                    ),
                    // if (canTake)
                    //   Padding(
                    //     padding: const EdgeInsets.only(left: 10.0),
                    //     child: Container(
                    //       height: 60, width: 50,
                    //       decoration: BoxDecoration(
                    //         color: Colors.white,
                    //         borderRadius: BorderRadius.circular(15),
                    //         border: Border.all(color: Colors.teal.shade200, width: 2),
                    //       ),
                    //       child: IconButton(
                    //         icon: const Icon(Icons.more_vert, size: 28),
                    //         color: Colors.teal,
                    //         onPressed: () => onAction?.call('attime'),
                    //       ),
                    //     ),
                    //   ),
                  ],
                )
              else 
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          status == 'taken' ? Icons.check_circle : Icons.cancel,
                          color: status == 'taken' ? Colors.green : Colors.orange,
                          size: 26,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          status == 'taken' ? "เรียบร้อยแล้ว" : "ข้ามแล้ว",
                          style: TextStyle(
                            fontSize: 20, 
                            fontWeight: FontWeight.bold, 
                            color: status == 'taken' ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () => onAction?.call('undo'),
                      icon: const Icon(Icons.refresh, size: 28),
                      label: const Text("ย้อนกลับ", style: TextStyle(fontSize: 20)),
                      style: TextButton.styleFrom(foregroundColor: Colors.teal),
                    )
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBigInfoRow(IconData icon, String text, TextStyle style) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 24, color: Colors.grey.shade700),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }

  Widget _buildButton({
    required Color color, required Color borderColor, required Color shadowColor,
    required VoidCallback? onTap, required IconData icon, required Color iconColor, required String text,
  }) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: onTap != null ? [BoxShadow(color: shadowColor, blurRadius: 4, offset: const Offset(0, 2))] : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(width: 4),
              Text(text, style: TextStyle(fontSize: 20, color: iconColor, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}