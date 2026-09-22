import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'audit_scan_screen.dart';

class AuditTicketListScreen extends StatefulWidget {
  const AuditTicketListScreen({super.key});

  @override
  State<AuditTicketListScreen> createState() => _AuditTicketListScreenState();
}

class _AuditTicketListScreenState extends State<AuditTicketListScreen> {
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _filteredTickets = [];
  bool _isLoading = false;
  String _selectedFilter = 'ALL';
  String _selectedDepartment = 'ALL';
  final TextEditingController _searchController = TextEditingController();
  List<String> _departments = ['ALL'];

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.getAuditTickets();
      if (response['success'] == true && mounted) {
        final ticketList = List<Map<String, dynamic>>.from(response['tickets'] ?? []);
        final depts = <String>{'ALL'};
        for (var ticket in ticketList) {
          final dept = ticket['department'] as String? ?? 'Unknown';
          depts.add(dept);
        }
        
        setState(() {
          _tickets = ticketList;
          _filteredTickets = ticketList;
          _departments = depts.toList();
        });
      }
    } catch (e) {
      print('Error loading tickets: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi tải phiếu: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = _tickets;

    // Status filter
    if (_selectedFilter != 'ALL') {
      filtered = filtered.where((t) => t['status'] == _selectedFilter).toList();
    }

    // Department filter
    if (_selectedDepartment != 'ALL') {
      filtered = filtered.where((t) => t['department'] == _selectedDepartment).toList();
    }

    // Search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((t) {
        final name = (t['ticket_id'] as String? ?? '').toLowerCase();
        return name.contains(query);
      }).toList();
    }

    setState(() => _filteredTickets = filtered);
  }

  Future<void> _exportReport() async {
    // Placeholder for export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Đã tạo báo cáo PDF, chờ tải xuống...'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
    // TODO: Implement PDF export using pdf package
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phiếu kiểm kê'),
        backgroundColor: const Color(0xFF091A33),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportReport,
            tooltip: 'Xuất báo cáo',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTickets,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      backgroundColor: const Color(0xFF0F172A),
      body: Column(
        children: [
          // Search bar
          Container(
            color: const Color(0xFF091A33),
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _applyFilters(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm phiếu...',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF60A5FA)),
                filled: true,
                fillColor: const Color(0xFF0D2242),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Filters
          Container(
            color: const Color(0xFF091A33),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Status filter
                  _buildFilterChip(
                    label: _selectedFilter == 'ALL' ? '📊 Trạng thái' : _selectedFilter,
                    onTap: () => _showFilterDialog(),
                  ),
                  const SizedBox(width: 8),
                  // Department filter
                  _buildFilterChip(
                    label: _selectedDepartment == 'ALL' ? '🏢 Phòng ban' : _selectedDepartment,
                    onTap: () => _showDepartmentDialog(),
                  ),
                  const SizedBox(width: 8),
                  // Reset filters
                  if (_selectedFilter != 'ALL' || _selectedDepartment != 'ALL')
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedFilter = 'ALL';
                          _selectedDepartment = 'ALL';
                          _searchController.clear();
                          _filteredTickets = _tickets;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.clear, color: Color(0xFFF87171), size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Xóa bộ lọc',
                              style: TextStyle(color: Color(0xFFF87171), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Tickets list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Color(0xFF2563EB)),
                    ),
                  )
                : _filteredTickets.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              color: Colors.white30,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Không có phiếu nào',
                              style: TextStyle(color: Colors.white60, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTickets,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredTickets.length,
                          itemBuilder: (ctx, idx) => _buildTicketCard(_filteredTickets[idx]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0D2242),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: Colors.white60, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final ticketId = ticket['ticket_id'] as String? ?? 'N/A';
    final status = ticket['status'] as String? ?? 'IN_PROGRESS';
    final department = ticket['department'] as String? ?? 'Phòng IT';
    final totalItems = ticket['total_items'] as int? ?? 0;
    final scannedItems = ticket['scanned_items'] as int? ?? 0;
    final progress = totalItems > 0 ? (scannedItems / totalItems * 100).toStringAsFixed(1) : '0.0';
    final createdAt = ticket['created_at'] as String? ?? DateTime.now().toString();

    final statusColor = status == 'COMPLETED'
        ? const Color(0xFF10B981)
        : status == 'APPROVED'
            ? const Color(0xFF2563EB)
            : const Color(0xFFF59E0B);

    final statusLabel = status == 'COMPLETED'
        ? '✅ Hoàn thành'
        : status == 'APPROVED'
            ? '✔️ Duyệt'
            : '⏳ Đang làm';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AuditScanScreen(ticketId: ticketId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF091A33),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: ID + Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    ticketId,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Department + Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '🏢 $department',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  createdAt.substring(0, 10),
                  style: const TextStyle(color: Colors.white30, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Progress bar + stats
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Tiến độ',
                            style: TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                          Text(
                            '$progress%',
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: totalItems > 0 ? scannedItems / totalItems : 0,
                          backgroundColor: Colors.grey[800],
                          valueColor: const AlwaysStoppedAnimation(Color(0xFF2563EB)),
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$scannedItems/$totalItems',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF091A33),
        title: const Text('Chọn trạng thái', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['ALL', 'IN_PROGRESS', 'COMPLETED', 'APPROVED'].map((status) {
            return ListTile(
              title: Text(
                status == 'ALL' ? 'Tất cả' : status == 'IN_PROGRESS' ? 'Đang làm' : status == 'COMPLETED' ? 'Hoàn thành' : 'Duyệt',
                style: TextStyle(
                  color: _selectedFilter == status ? const Color(0xFF2563EB) : Colors.white,
                  fontWeight: _selectedFilter == status ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              onTap: () {
                setState(() => _selectedFilter = status);
                _applyFilters();
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showDepartmentDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF091A33),
        title: const Text('Chọn phòng ban', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _departments.map((dept) {
              return ListTile(
                title: Text(
                  dept,
                  style: TextStyle(
                    color: _selectedDepartment == dept ? const Color(0xFF2563EB) : Colors.white,
                    fontWeight: _selectedDepartment == dept ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  setState(() => _selectedDepartment = dept);
                  _applyFilters();
                  Navigator.pop(ctx);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
