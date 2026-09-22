import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic> _userInfo = {};
  Map<String, dynamic> _userStats = {
    'total_scans': 0,
    'completed_tickets': 0,
    'total_assets_scanned': 0,
    'average_scan_time': '0',
  };
  List<Map<String, dynamic>> _activityLog = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadUserStats();
    _loadActivityLog();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.getUserProfile();
      if (response['success'] == true && mounted) {
        setState(() => _userInfo = response['user'] ?? {});
      }
    } catch (e) {
      print('Error loading profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserStats() async {
    try {
      final db = await DatabaseService.instance.database;
      
      // Count total scans
      final scanHistory = await db.query('scan_history');
      final totalScans = scanHistory.length;
      
      // Count completed tickets (example)
      const completedTickets = 0; // TODO: Implement ticket counting
      
      setState(() {
        _userStats = {
          'total_scans': totalScans,
          'completed_tickets': completedTickets,
          'total_assets_scanned': totalScans,
          'average_scan_time': '2.5s',
        };
      });
    } catch (e) {
      print('Error loading stats: $e');
    }
  }

  Future<void> _loadActivityLog() async {
    try {
      final db = await DatabaseService.instance.database;
      final logs = await db.query(
        'scan_history',
        orderBy: 'scanned_at DESC',
        limit: 10,
      );
      
      setState(() {
        _activityLog = logs.map((log) {
          return {
            'action': 'Quét tài sản',
            'detail': log['asset_tag'] ?? 'Unknown',
            'timestamp': log['scanned_at'] ?? DateTime.now().toString(),
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading activity log: $e');
    }
  }

  Future<void> _uploadAvatar() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📷 Chức năng upload avatar đang phát triển...'),
        backgroundColor: Color(0xFF2563EB),
      ),
    );
    // TODO: Implement image picker and upload
  }

  Future<void> _showSettings() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF091A33),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cài đặt',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSettingItem(
              icon: Icons.volume_up,
              label: 'Âm thanh quét',
              trailing: Switch(
                value: true,
                onChanged: (val) {},
                activeThumbColor: const Color(0xFF2563EB),
              ),
            ),
            _buildSettingItem(
              icon: Icons.vibration,
              label: 'Rung khi quét',
              trailing: Switch(
                value: true,
                onChanged: (val) {},
                activeThumbColor: const Color(0xFF2563EB),
              ),
            ),
            _buildSettingItem(
              icon: Icons.notifications,
              label: 'Thông báo',
              trailing: Switch(
                value: true,
                onChanged: (val) {},
                activeThumbColor: const Color(0xFF2563EB),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final username = _userInfo['username'] ?? 'admin';
    final email = _userInfo['email'] ?? 'admin@company.com';
    final role = _userInfo['role'] ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ'),
        backgroundColor: const Color(0xFF091A33),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
            tooltip: 'Cài đặt',
          ),
        ],
      ),
      backgroundColor: const Color(0xFF0F172A),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFF2563EB)),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Profile header
                  Container(
                    color: const Color(0xFF091A33),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Avatar
                        Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF2563EB), width: 3),
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Color(0xFF60A5FA),
                                size: 50,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _uploadAvatar,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: const TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            role,
                            style: const TextStyle(
                              color: Color(0xFF60A5FA),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Stats cards
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'THỐNG KÊ',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Tổng số lần quét',
                                '${_userStats['total_scans']}',
                                Icons.qr_code_scanner,
                                const Color(0xFF2563EB),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                'Phiếu hoàn thành',
                                '${_userStats['completed_tickets']}',
                                Icons.check_circle,
                                const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Tài sản quét',
                                '${_userStats['total_assets_scanned']}',
                                Icons.devices,
                                const Color(0xFFF59E0B),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                'Thời gian TB',
                                _userStats['average_scan_time'] ?? '0s',
                                Icons.speed,
                                const Color(0xFF8B5CF6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Activity log
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'HOẠT ĐỘNG GẦN ĐÂY',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('📋 Xem tất cả hoạt động'),
                                    backgroundColor: Color(0xFF2563EB),
                                  ),
                                );
                              },
                              child: const Text(
                                'Xem tất cả',
                                style: TextStyle(
                                  color: Color(0xFF60A5FA),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF091A33),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: _activityLog.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(Icons.history, color: Colors.white30, size: 48),
                                        SizedBox(height: 12),
                                        Text(
                                          'Chưa có hoạt động nào',
                                          style: TextStyle(color: Colors.white60, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _activityLog.length,
                                  itemBuilder: (ctx, idx) {
                                    final log = _activityLog[idx];
                                    final isLast = idx == _activityLog.length - 1;
                                    
                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: isLast
                                            ? null
                                            : Border(
                                                bottom: BorderSide(
                                                  color: Colors.white.withValues(alpha: 0.08),
                                                ),
                                              ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.qr_code_scanner,
                                              color: Color(0xFF60A5FA),
                                              size: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  log['action'] ?? 'Hoạt động',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  log['detail'] ?? '',
                                                  style: const TextStyle(
                                                    color: Colors.white60,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            _formatTimestamp(log['timestamp'] ?? ''),
                                            style: const TextStyle(
                                              color: Colors.white30,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF091A33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String label,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white60, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Vừa xong';
      if (diff.inMinutes < 60) return '${diff.inMinutes}p trước';
      if (diff.inHours < 24) return '${diff.inHours}h trước';
      return '${diff.inDays}d trước';
    } catch (e) {
      return 'N/A';
    }
  }
}
