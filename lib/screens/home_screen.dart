import 'package:flutter/material.dart';
import 'device_scan_screen.dart';
import 'ticket_list_screen.dart';
import 'instant_ticket_scan_screen.dart';
import 'change_password_screen.dart';
import 'user_profile_screen.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _username = 'admin';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final creds = await ApiService.getRememberCredentials();
    if (creds['username'] != null && (creds['username'] as String).isNotEmpty) {
      setState(() {
        _username = creds['username'];
      });
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1729),
        title: const Text('Đăng xuất', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Bạn có chắc chắn muốn thoát khỏi tài khoản?', style: TextStyle(color: Color(0xFFA0AEC0))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFFA0AEC0))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Thoát'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService.logout();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1729),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. LOGO + TITLE
              _buildHeader(),
              const SizedBox(height: 20),

              // 2. USER GREETING BAR
              _buildUserGreetingBar(),
              const SizedBox(height: 16),

              // 3. SECTION 1: HỆ THỐNG
              _buildSectionCard(
                title: 'Hệ thống',
                children: [
                  _buildIconGridRow(
                    items: [
                      _GridItem(
                        icon: Icons.article_outlined,
                        label: 'Dashboard\nQuản trị',
                        onTap: () => _showNotice('Dashboard Quản trị'),
                      ),
                      _GridItem(
                        icon: Icons.lock_outlined,
                        label: 'Đổi mật\nkhẩu',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                        ),
                      ),
                      _GridItem(
                        icon: Icons.person_outlined,
                        label: 'Thông tin\nngười dùng',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 4. SECTION 2: QUÉT MÃ QR CODE
              _buildSectionCard(
                title: 'Quét mã QR Code',
                badgeText: 'Live Camera',
                badgeColor: const Color(0xFF1E3A8A),
                children: [
                  _buildIconGridRow(
                    items: [
                      _GridItem(
                        icon: Icons.qr_code_2,
                        label: 'Scan Test\nQR Code',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DeviceScanScreen()),
                        ),
                      ),
                      _GridItem(
                        icon: Icons.search,
                        label: 'Tra cứu Tag\nthủ công',
                        onTap: _showManualLookupDialog,
                      ),
                      _GridItem(
                        icon: Icons.computer,
                        label: 'Danh sách\nthiết bị',
                        onTap: () => _showNotice('Danh sách thiết bị'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 5. SECTION 3: KIỂM KÊ THIẾT BỊ IT
              _buildSectionCard(
                title: 'Kiểm kê thiết bị IT',
                badgeText: '1 Đợt',
                badgeColor: const Color(0xFF0C4A6E),
                children: [
                  _buildIconGridRow(
                    items: [
                      _GridItem(
                        icon: Icons.assignment,
                        label: 'Phiếu kiểm\nkê IT',
                        badgeCount: 1,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TicketListScreen()),
                        ),
                      ),
                      _GridItem(
                        icon: Icons.add_box_outlined,
                        label: 'Tạo phiếu\nkiểm kê IT',
                        onTap: () => _showNotice('Tạo phiếu kiểm kê IT'),
                      ),
                      _GridItem(
                        icon: Icons.qr_code_scanner,
                        label: 'Quét thiết\nbị IT',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const InstantTicketScanScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/logo.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.smart_toy,
                color: Color(0xFF1E40AF),
                size: 40,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Windows Agent',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildUserGreetingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2847),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              color: Color(0xFF0F1729),
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Xin chào,',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFFA0AEC0),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _username,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _handleLogout,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F1729),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 0,
            ),
            child: const Text(
              'Thoát',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    String? badgeText,
    Color? badgeColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2847),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: badgeColor ?? const Color(0xFF1E3A8A),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7DD3FC),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildIconGridRow({required List<_GridItem> items}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Expanded(
              child: _buildIconButton(item),
            ),
          )
          .toList(),
    );
  }

  Widget _buildIconButton(_GridItem item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    item.icon,
                    color: const Color(0xFF0F1729),
                    size: 32,
                  ),
                ),
                if (item.badgeCount != null && item.badgeCount! > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                      child: Text(
                        '${item.badgeCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: Center(
                child: Text(
                  item.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotice(String featureName) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Tính năng "$featureName" đang được tối ưu.',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: const Color(0xFF1E40AF),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showManualLookupDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1729),
        title: const Text(
          'Tra cứu Tag thủ công',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Nhập Tag, Hostname hoặc IP...',
            hintStyle: const TextStyle(color: Color(0xFF64748B)),
            filled: true,
            fillColor: const Color(0xFF1A2847),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFFA0AEC0))),
          ),
          ElevatedButton(
            onPressed: () {
              final query = controller.text.trim();
              if (query.isNotEmpty) {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeviceScanScreen(initialTag: query),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: const Text('Tra cứu'),
          ),
        ],
      ),
    );
  }
}

class _GridItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badgeCount;

  _GridItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount,
  });
}
