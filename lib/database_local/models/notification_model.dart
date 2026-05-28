class NotificationModel {
  final int? id;
  final String title;
  final String body;
  final String? payload;
  final String date; // วันเวลาที่แจ้งเตือน
  final int isRead;  // 0=ยังไม่อ่าน, 1=อ่านแล้ว
  final String type; // 'medication', 'appointment', etc.

  NotificationModel({
    this.id,
    required this.title,
    required this.body,
    this.payload,
    required this.date,
    this.isRead = 0,
    this.type = 'general',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'payload': payload,
      'date': date,
      'is_read': isRead,
      'type': type,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'],
      title: map['title'],
      body: map['body'],
      payload: map['payload'],
      date: map['date'],
      isRead: map['is_read'],
      type: map['type'],
    );
  }
}