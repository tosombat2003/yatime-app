import 'package:flutter/material.dart';
import 'package:ya_time/auth/auth_service.dart';
import 'package:ya_time/database_local/models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  String? _selectedAvatar;
  bool _isLoading = true;
  UserModel? _currentUser;

  // รายการ Avatar ที่มีในแอป
  final List<String> _avatars = [
    'assets/avatar/1.png', 'assets/avatar/2.png', 'assets/avatar/3.png',
    'assets/avatar/4.png', 'assets/avatar/5.png', 'assets/avatar/6.png',
    'assets/avatar/7.png', 'assets/avatar/8.png', 'assets/avatar/9.png',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = await AuthService.instance.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
        _nameController.text = user?.name ?? '';
        _selectedAvatar = user?.pic;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_currentUser == null) return;

    setState(() => _isLoading = true);
    try {
      await AuthService.instance.updateUserProfile(
        name: _nameController.text.trim(),
        picUrl: _selectedAvatar,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกข้อมูลเรียบร้อย')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ฟังก์ชันแสดงหน้าต่างเลือกรูป (Bottom Sheet)
  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 400, // กำหนดความสูงของหน้าต่างเลือกรูป
          child: Column(
            children: [
              const Text(
                'เลือกรูปประจำตัว',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, // แถวละ 3 รูป
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _avatars.length + 1, // +1 สำหรับปุ่ม "ไม่มีรูป"
                  itemBuilder: (context, index) {
                    // ปุ่มแรก: เลือก "ไม่มีรูป"
                    if (index == 0) {
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedAvatar = null);
                          Navigator.pop(context);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            shape: BoxShape.circle,
                            border: _selectedAvatar == null
                                ? Border.all(color: Colors.teal, width: 4)
                                : null,
                          ),
                          child: const Icon(Icons.person_off, color: Colors.teal, size: 30),
                        ),
                      );
                    }

                    // ปุ่มถัดไป: รูป Avatar
                    final assetPath = _avatars[index - 1];
                    final isSelected = _selectedAvatar == assetPath;

                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedAvatar = assetPath);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.teal, width: 4)
                              : null,
                        ),
                        child: CircleAvatar(
                          backgroundImage: AssetImage(assetPath),
                          backgroundColor: Colors.grey[200],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper Widget: แสดงรูปปัจจุบัน
  ImageProvider? _getImageProvider(String? pic) {
    if (pic == null || pic.isEmpty) return null;
    if (pic.startsWith('http')) {
      return NetworkImage(pic);
    } else {
      return AssetImage(pic);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.teal)));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('แก้ไขข้อมูลส่วนตัว'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveProfile,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // --- ส่วนแสดงรูปโปรไฟล์ปัจจุบัน + ปุ่มแก้ไข ---
            Center(
              child: Stack(
                children: [
                  // รูปโปรไฟล์ใหญ่
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.teal, width: 3),
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.teal[50],
                      backgroundImage: _getImageProvider(_selectedAvatar),
                      child: _selectedAvatar == null
                          ? const Icon(Icons.person, size: 60, color: Colors.teal)
                          : null,
                    ),
                  ),
                  
                  // ปุ่มกล้องถ่ายรูป (แก้ไข)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _showAvatarPicker, // กดแล้วเรียกหน้าต่างเลือกรูป
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.teal,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          //Icons.camera_alt,
                          Icons.edit,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),
            const Text(
              'แตะที่ไอคอนดินสอเพื่อเปลี่ยนรูป',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),

            const SizedBox(height: 40),

            // ฟอร์มแก้ไขชื่อ
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'ชื่อที่แสดง',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit),
              ),
            ),
            
            const SizedBox(height: 12),
            Text(
              'Username : ${_currentUser?.username ?? _currentUser?.email ?? "-"}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}