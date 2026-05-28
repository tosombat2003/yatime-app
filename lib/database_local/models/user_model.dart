class UserModel {
  final String userId;
  final String email;
  final String? username;
  final String? name;
  final String? pic;
  final String provider;
  
  final bool isEmailVerified;
  final String? lastLoginAt;
  
  final String? createdAt;
  final String? lastModified;
  
  final bool isActive;
  final bool isSynced;
  final String? syncAt;

  UserModel({
    required this.userId,
    required this.email,
    this.username,
    this.name,
    this.pic,
    this.provider = 'google',
    this.isEmailVerified = false,
    this.lastLoginAt,
    this.createdAt,
    this.lastModified,
    this.isActive = true,
    this.isSynced = false,
    this.syncAt,
  });

  // แปลงเป็น Map สำหรับบันทึกลง Database
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'email': email,
      'username': username,
      'name': name,
      'pic': pic,
      'provider': provider,
      'is_email_verified': isEmailVerified ? 1 : 0,
      'last_login_at': lastLoginAt,
      'created_at': createdAt,
      'last_modified': lastModified,
      'is_active': isActive ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
      'sync_at': syncAt,
    };
  }

  // สร้าง UserModel จาก Map (อ่านจาก Database)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      userId: map['user_id'] as String,
      email: map['email'] as String,
      username: map['username'] as String?,
      name: map['name'] as String?,
      pic: map['pic'] as String?,
      provider: map['provider'] as String? ?? 'google',
      isEmailVerified: (map['is_email_verified'] as int?) == 1,
      lastLoginAt: map['last_login_at'] as String?,
      createdAt: map['created_at'] as String?,
      lastModified: map['last_modified'] as String?,
      isActive: (map['is_active'] as int?) == 1,
      isSynced: (map['is_synced'] as int?) == 1,
      syncAt: map['sync_at'] as String?,
    );
  }

  // Factory สำหรับสร้าง UserModel จาก Firebase User (สะดวกสำหรับ Google Sign-In)
  factory UserModel.fromFirebaseUser({
    required String uid,
    required String email,
    String? displayName,
    String? photoURL,
    bool emailVerified = false,
  }) {
    // ✅ เพิ่มบรรทัดนี้: ตัดเอาคำหน้า @ มาเป็น username
    String derivedUsername = email.split('@').first; 

    return UserModel(
      userId: uid,
      email: email,
      username: derivedUsername, // ✅ ส่งค่าเข้าไปตรงนี้
      name: displayName,
      pic: photoURL,
      provider: 'google',
      isEmailVerified: emailVerified,
      lastLoginAt: DateTime.now().toIso8601String(),
      createdAt: DateTime.now().toIso8601String(),
      lastModified: DateTime.now().toIso8601String(),
    );
  }

  // สร้าง copy พร้อมแก้ไขบางฟิลด์
  UserModel copyWith({
    String? userId,
    String? email,
    String? username,
    String? name,
    String? pic,
    String? provider,
    bool? isEmailVerified,
    String? lastLoginAt,
    String? createdAt,
    String? lastModified,
    bool? isActive,
    bool? isSynced,
    String? syncAt,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      username: username ?? this.username,
      name: name ?? this.name,
      pic: pic ?? this.pic,
      provider: provider ?? this.provider,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
      isActive: isActive ?? this.isActive,
      isSynced: isSynced ?? this.isSynced,
      syncAt: syncAt ?? this.syncAt,
    );
  }

  @override
  String toString() {
    return 'UserModel(userId: $userId, email: $email, name: $name, provider: $provider)';
  }
}