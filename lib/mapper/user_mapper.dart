import 'package:ya_time/database_local/models/user_model.dart';

class UserMapper {
  /// แปลง UserModel เป็น Map สำหรับ Firestore
  static Map<String, dynamic> toFirestore(UserModel user) {
    return {
      'user_id': user.userId,
      'email': user.email,
      'username': user.username,
      'name': user.name,
      'pic': user.pic,
      'provider': user.provider,
      'is_email_verified': user.isEmailVerified,
      'last_login_at': user.lastLoginAt,
      'created_at': user.createdAt,
      'last_modified': user.lastModified,
      'is_active': user.isActive,
    };
  }

  /// แปลง Firestore Document เป็น UserModel
  static UserModel fromFirestore(
    Map<String, dynamic> data,
    String documentId,
  ) {
    return UserModel(
      userId: documentId,
      email: data['email'] as String,
      username: data['username'] as String?,
      name: data['name'] as String?,
      pic: data['pic'] as String?,
      provider: data['provider'] as String? ?? 'google',
      isEmailVerified: data['is_email_verified'] as bool? ?? false,
      lastLoginAt: data['last_login_at'] as String?,
      createdAt: data['created_at'] as String?,
      lastModified: data['last_modified'] as String?,
      isActive: data['is_active'] as bool? ?? true,
      isSynced: true, // จาก Firestore = synced แล้ว
      syncAt: DateTime.now().toIso8601String(),
    );
  }
}