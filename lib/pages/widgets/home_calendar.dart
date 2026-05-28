import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class HomeCalendar extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final CalendarFormat calendarFormat;
  final Function(DateTime, DateTime) onDaySelected;
  final Function(DateTime) onPageChanged;

  const HomeCalendar({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.calendarFormat,
    required this.onDaySelected,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.all(12.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).cardColor, // ให้สีการ์ดเปลี่ยนตาม Theme
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: TableCalendar(
          locale: 'th_TH',
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: focusedDay,
          calendarFormat: calendarFormat,

          selectedDayPredicate: (day) => isSameDay(selectedDay, day),
          onDaySelected: onDaySelected,
          onPageChanged: onPageChanged,

          daysOfWeekHeight: 32,
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(fontSize: 16, color: isDark ? Colors.grey[300] : Colors.black87),
            weekendStyle: TextStyle(fontSize: 16, color: isDark ? Colors.red[300] : Colors.red),
          ),

          // ================= HEADER =================
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.tealAccent : Colors.teal[800], 
            ),
            leftChevronIcon: Icon(Icons.chevron_left, color: isDark ? Colors.tealAccent : Colors.teal),
            rightChevronIcon: Icon(Icons.chevron_right, color: isDark ? Colors.tealAccent : Colors.teal),
          ),

          // ================= CALENDAR STYLE =================
          calendarStyle: CalendarStyle(
            cellMargin: const EdgeInsets.all(4.0),
            cellPadding: const EdgeInsets.all(2.0),

            
            defaultTextStyle: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87, 
            ),
            
            weekendTextStyle: TextStyle(
              fontSize: 14, 
              color: isDark ? Colors.redAccent : Colors.red,
            ),

            // วันที่เลือก
            selectedDecoration: const BoxDecoration(
              color: Colors.teal,
              shape: BoxShape.circle,
            ),

            // วันนี้
            todayDecoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.4),
              shape: BoxShape.circle,
            ),

            // ตัวเลขในวงกลม
            selectedTextStyle: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            todayTextStyle: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}