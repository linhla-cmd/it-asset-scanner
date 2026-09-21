import 'package:flutter/material.dart';
import '../services/api_service.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _userInfo = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final result = await ApiService.getUserProfile();
    setState(() {
      _isLoading = false;
      if (result['success']) {
        _userInfo = result['user'] ?? {};
      }
    });
  }

  String _getRoleName(String? role) {
    switch (role) {
      case 'Admin':
        return 'Quản trị viên';
      case 'ITStaff':
        return 'Nhân viên IT';
      case 'Auditor':
        return 'Kiểm kê viên';
      case 'Operator':
        return 'Vận hành';
      case 'Viewer':
        return 'Xem';
      default:
        return role ?? 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071326),
      appBar: AppBar(
        backgroundColor: const Color(0xFF091A33),
        title: const Text('Thông tin người dùng',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Avatar
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 48),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _userInfo['full_name'] ?? _userInfo['username'] ?? 'N/A',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getRoleName(_userInfo['role']),
                      style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Info cards
                  _buildInfoCard(Icons.person_outline, 'Tên đăng nhập', _userInfo['username'] ?? 'N/A'),
                  _buildInfoCard(Icons.badge_outlined, 'Họ và tên', _userInfo['full_name'] ?? 'Chưa cập nhật'),
                  _buildInfoCard(Icons.admin_panel_settings_outlined, 'Vai trò', _getRoleName(_userInfo['role'])),
                  _buildInfoCard(
                    Icons.circle,
                    'Trạng thái',
                    _userInfo['is_active'] == 1 ? 'Đang hoạt động' : 'Bị khóa',
                    valueColor: _userInfo['is_active'] == 1 ? Colors.green : Colors.red,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value, {Color? valueColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF091A33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF38BDF8), size: 22),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                      color: valueColor ?? Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
