import 'package:flutter/material.dart';
import 'device_scan_screen.dart';
import 'audit_ticket_list_screen.dart';
import 'audit_scan_screen.dart';
import 'instant_ticket_scan_screen.dart';
import 'ticket_list_screen.dart';
import 'change_password_screen.dart';
import 'user_profile_screen.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../services/database_service.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _username = 'admin';
  bool _isOnline = true;
  Map<String, dynamic> _stats = {
    'total_tickets': 0,
    'in_progress': 0,
    'completed': 0,
    'total_assets': 0,
    'scanned_assets': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadStats();
  }

  Future<void> _loadUserInfo() async {
    final token = await ApiService.getToken();
    if (token != null) {
      final result = await ApiService.getUserProfile();
      if (result['success'] == true && mounted) {
        setState(() {
          _username = result['user']?['username'] ?? 'admin';
        });
      }
    }
  }

  Future<void> _loadStats() async {
    final stats = await ApiService.getAuditStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _isOnline = true; // Default online, can add connectivity check later
      });
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Windows Agent'),
        backgroundColor: const Color(0xFF091A33),
        foregroundColor: Colors.white,
        actions: [
          // Status indicator
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isOnline ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isOnline ? Icons.cloud_done : Icons.cloud_off,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isOnline ? 'Online' : 'Offline',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          PopupMenuButton(
            color: const Color(0xFF091A33),
            itemBuilder: (ctx) => [
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.person, color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Hồ sơ',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                  );
                },
              ),
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.lock, color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Đổi mật khẩu',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                  );
                },
              ),
              PopupMenuItem(
                onTap: _logout,
                child: const Row(
                  children: [
                    Icon(Icons.logout, color: Color(0xFFEF4444), size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Đăng xuất',
                      style: TextStyle(color: Color(0xFFEF4444)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: const Color(0xFF0F172A),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadUserInfo();
          _loadStats();
        },
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. HEADER: Chào mừng người dùng
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Xin chào, $_username 👋',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hôm nay là ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. DASHBOARD STATS
                _buildStatsGrid(),
                const SizedBox(height: 24),

                // 3. SECTION 1: QUẢN LÝ THIẾT BỊ (3 tính năng / 1 hàng)
                _buildSectionCard(
                  title: 'Quản lý thiết bị',
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildGridButton(
                            icon: Icons.qr_code_scanner,
                            label: 'Quét thiết bị\nnhanh',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const DeviceScanScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: _buildGridButton(
                            icon: Icons.devices,
                            label: 'Danh sách\nthiết bị',
                            onTap: () => _showNotice('Danh sách thiết bị'),
                          ),
                        ),
                        Expanded(
                          child: _buildGridButton(
                            icon: Icons.info_outlined,
                            label: 'Thông tin\nthiết bị',
                            onTap: () => _showNotice('Thông tin thiết bị'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 4. SECTION 2: KẾT NỐI MẠNG (3 tính năng / 1 hàng)
                _buildSectionCard(
                  title: 'Kết nối mạng',
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildGridButton(
                            icon: Icons.router,
                            label: 'Quét địa chỉ\nIP',
                            onTap: () => _showNotice('Quét địa chỉ IP'),
                          ),
                        ),
                        Expanded(
                          child: _buildGridButton(
                            icon: Icons.language,
                            label: 'Cấu hình\nmạng',
                            onTap: () => _showNotice('Cấu hình mạng'),
                          ),
                        ),
                        Expanded(
                          child: _buildGridButton(
                            icon: Icons.speed,
                            label: 'Tốc độ\nmạng',
                            onTap: () => _showNotice('Tốc độ mạng'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 5. SECTION 3: KIỂM KÊ TÀI SẢN (3 tính năng / 1 hàng)
                _buildSectionCard(
                  title: 'Kiểm kê tài sản',
                  badgeText: '${_stats['in_progress']} đợt',
                  badgeColor: const Color(0xFF0C4A6E),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildGridButton(
                            icon: Icons.assignment_outlined,
                            label: 'Phiếu\nkiểm kê',
                            badgeCount: _stats['in_progress'] as int? ?? 0,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AuditTicketListScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: _buildGridButton(
                            icon: Icons.flash_on_outlined,
                            label: 'Kiểm kê\nnhanh',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const InstantTicketScanScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: _buildGridButton(
                            icon: Icons.assignment_turned_in_outlined,
                            label: 'Quét theo\nphiếu',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const TicketListScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 6. SECTION 4: BÁO CÁO VÀ THỐNG KÊ (3 tính năng / 1 hàng)
                _buildSectionCard(
                  title: 'Báo cáo & thống kê',
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildGridButton(
                            icon: Icons.bar_chart,
                            label: 'Báo cáo\ntổng quan',
                            onTap: () => _showNotice('Báo cáo tổng quan'),
                          ),
                        ),
                        Expanded(
                          child: _buildGridButton(
                            icon: Icons.pie_chart,
                            label: 'Biểu đồ\nthống kê',
                            onTap: () => _showNotice('Biểu đồ thống kê'),
                          ),
                        ),
                        Expanded(
                          child: _buildGridButton(
                            icon: Icons.download,
                            label: 'Xuất\nbáo cáo',
                            onTap: () => _showNotice('Xuất báo cáo'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 7. SECTION 5: CÀI ĐẶT (3 tính năng / 1 hàng)
                _buildSectionCard(
                  title: 'Cài đặt',
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildGridButton(
                            icon: Icons.settings,
                            label: 'Cài đặt\nchung',
                            onTap: () => _showNotice('Cài đặt chung'),
                          ),
                        ),
                        Expanded(
                          child: _buildGridButton(
                            icon: Icons.notifications,
                            label: 'Thông báo',
                            onTap: () => _showNotice('Cài đặt thông báo'),
                          ),
                        ),
                        Expanded(
                          child: _buildGridButton(
                            icon: Icons.info,
                            label: 'Về ứng\ndụng',
                            onTap: () => _showNotice('Về ứng dụng'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Dashboard Stats Grid
  Widget _buildStatsGrid() {
    final totalScanned = _stats['scanned_assets'] as int? ?? 0;
    final totalAssets = _stats['total_assets'] as int? ?? 0;
    final scanProgress = totalAssets > 0 ? (totalScanned / totalAssets * 100).toStringAsFixed(1) : '0.0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF091A33),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard('Phiếu', '${_stats['total_tickets']}', Colors.blue),
              _buildStatCard('Đang làm', '${_stats['in_progress']}', Colors.orange),
              _buildStatCard('Hoàn thành', '${_stats['completed']}', Colors.green),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tiến độ quét',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: totalAssets > 0 ? totalScanned / totalAssets : 0,
                        backgroundColor: Colors.grey[800],
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF2563EB)),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '$scanProgress%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$totalScanned/$totalAssets tài sản',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              Text(
                'Cập nhật lúc ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.white30, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Stat Card
  Widget _buildStatCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }

  // Section Card
  Widget _buildSectionCard({
    required String title,
    String? badgeText,
    Color? badgeColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF091A33),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (badgeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (badgeColor ?? Colors.blue).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: badgeColor ?? Colors.blue),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        color: badgeColor ?? Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Divider
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  // Grid Button
  Widget _buildGridButton({
    required IconData icon,
    required String label,
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D2242),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, color: const Color(0xFF2563EB), size: 28),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  void _showNotice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$message - Coming Soon!'),
        backgroundColor: const Color(0xFF2563EB),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
