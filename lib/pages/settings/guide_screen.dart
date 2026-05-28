import 'package:flutter/material.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('คู่มือการใช้งาน', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor:Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.teal,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildGuideItem(
            'วิธีเพิ่มยาใหม่',
            '1. กดปุ่ม + สีเขียวด้านล่าง\n2. กรอกชื่อยา ประเภท และขนาด\n3. เลือกช่วงเวลาที่ต้องทาน\n4. กดบันทึก',
            Icons.add_circle_outline,
          ),
          _buildGuideItem(
            'เมื่อถึงเวลากินยา',
            'เมื่อมีการแจ้งเตือนเด้งขึ้นมา:\n- กด "กินแล้ว" เพื่อบันทึก\n- กด "ข้าม" หากไม่ต้องการทานมื้อนี้\n- กด "เลื่อน" เพื่อให้เตือนอีกครั้งใน 5 นาที',
            Icons.notifications_active_outlined,
          ),
          _buildGuideItem(
            'ดูประวัติการกินยา',
            'ไปที่หน้า "ยา" (แท็บที่ 3) แล้วเลือกแท็บ "ยาที่เคยใช้" เพื่อดูประวัติยาที่กินหมดแล้ว หรือยาที่หยุดกิน',
            Icons.history,
          ),
          _buildGuideItem(
            'การนัดหมายแพทย์',
            '1. ไปที่หน้า "นัดหมาย" (แท็บที่ 2)\n2. ดูวันนัดหมายที่ใกล้ถึง\n3. เมื่อถึงวัดนัดหมาย ปุ่มไปหาหมอแล้วจึงกดได้ \n4. แอปจะเตือนล่วงหน้า 1 วัน และ 3 ชั่วโมง',
            Icons.calendar_month_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildGuideItem(String title, String content, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.teal[50],
          child: Icon(icon, color: Colors.teal),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Container(width: 2, height: 60, color: Colors.teal[100], margin: const EdgeInsets.only(right: 12)),
                Expanded(
                  child: Text(
                    content,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}