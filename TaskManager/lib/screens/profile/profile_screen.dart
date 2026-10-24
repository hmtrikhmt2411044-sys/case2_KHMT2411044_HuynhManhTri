import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final user = await AuthService.getProfile();
    if (!mounted) return;
    setState(() {
      _user = user;
      _isLoading = false;
    });
  }

  // 1. Hộp thoại Cập nhật thông tin cá nhân
  void _showEditProfileDialog() {
    if (_user == null) return;
    final nameController = TextEditingController(text: _user!.fullName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cập Nhật Thông Tin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Họ và tên',
                prefixIcon: Icon(Icons.person),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isEmpty) return;

              Navigator.pop(ctx);
              final result = await AuthService.updateProfile(fullName: newName);
              if (!mounted) return;

              if (result['success'] == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message']),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadProfile();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message']),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  // 2. Hộp thoại Đổi mật khẩu
  void _showChangePasswordDialog() {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi Mật Khẩu'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentPassController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu hiện tại',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (val) =>
                    (val == null || val.isEmpty) ? 'Vui lòng nhập mật khẩu cũ' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newPassController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu mới',
                  prefixIcon: Icon(Icons.lock_reset),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Vui lòng nhập mật khẩu mới';
                  if (val.length < 6) return 'Mật khẩu mới phải từ 6 ký tự';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmPassController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Xác nhận mật khẩu mới',
                  prefixIcon: Icon(Icons.check_circle_outline),
                ),
                validator: (val) {
                  if (val != newPassController.text) return 'Mật khẩu xác nhận không khớp';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              Navigator.pop(ctx);
              final result = await AuthService.changePassword(
                currentPassword: currentPassController.text,
                newPassword: newPassController.text,
              );
              if (!mounted) return;

              if (result['success'] == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message']),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message']),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Đổi Mật Khẩu'),
          ),
        ],
      ),
    );
  }

  // 3. Đăng xuất
  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác Nhận Đăng Xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi hệ thống?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Đăng Xuất', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông Tin Cá Nhân'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  // Avatar
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blueAccent.shade100,
                    child: Text(
                      _user?.fullName.isNotEmpty == true
                          ? _user!.fullName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _user?.fullName ?? 'Người dùng',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _user?.email ?? '',
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 30),

                  // Menu danh sách hành động
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                          title: const Text('Chỉnh sửa thông tin'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _showEditProfileDialog,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.lock_outline, color: Colors.orangeAccent),
                          title: const Text('Đổi mật khẩu'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _showChangePasswordDialog,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.logout, color: Colors.redAccent),
                          title: const Text(
                            'Đăng xuất',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _handleLogout,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
