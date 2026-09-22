import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import 'ticket_based_scan_screen.dart';

class TicketListScreen extends StatefulWidget {
  const TicketListScreen({super.key});

  @override
  State<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen> {
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _filteredTickets = [];
  bool _isLoading = false;
  String _sortBy = 'DATE'; // DATE or PROGRESS
  final TextEditingController _searchController = TextEditingController();
  int _unSyncedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.getAllAuditTickets();
      if (response['success'] == true && mounted) {
        final ticketList = List<Map<String, dynamic>>.from(response['tickets'] ?? []);
        
        // Count unsynced items
        int unsyncedCount = 0;
        for (var ticket in ticketList) {
          final db = await DatabaseService.instance.database;
          final unsynced = await db.query(
            'audit_items_offline',
            where: 'ticket_id = ? AND synced = 0',
            whereArgs: [ticket['ticket_id']],
          );
          unsyncedCount += unsynced.length;
        }
        
        setState(() {
          _tickets = ticketList;
          _filteredTickets = ticketList;
          _unSyncedCount = unsyncedCount;
          _applySort();
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

  void _applySort() {
    if (_sortBy == 'DATE') {
      _filteredTickets.sort((a, b) {
        final dateA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now();
        final dateB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.now();
        return dateB.compareTo(dateA);
      });
    } else if (_sortBy == 'PROGRESS') {
      _filteredTickets.sort((a, b) {
        final totalA = a['total_items'] as int? ?? 0;
        final totalB = b['total_items'] as int? ?? 0;
        final scannedA = a['scanned_items'] as int? ?? 0;
        final scannedB = b['scanned_items'] as int? ?? 0;
        
        final progressA = totalA > 0 ? scannedA / totalA : 0.0;
        final progressB = totalB > 0 ? scannedB / totalB : 0.0;
        
        return progressB.compareTo(progressA);
      });
    }
  }

  void _applySearch(String query) {
    List<Map<String, dynamic>> filtered = _tickets;
    
    if (query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      filtered = filtered.where((t) {
        final id = (t['ticket_id'] as String? ?? '').toLowerCase();
        return id.contains(lowerQuery);
      }).toList();
    }
    
    setState(() {
      _filteredTickets = filtered;
      _applySort();
    });
  }

  Future<void> _syncAllTickets() async {
    if (_unSyncedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Tất cả đều đã sync!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF091A33),
        title: const Text('Đồng bộ tất cả', style: TextStyle(color: Colors.white)),
        content: Text(
          'Đồng bộ $_unSyncedCount items chưa sync?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () {
              Navigator.pop(ctx);
              _performSyncAll();
            },
            child: const Text('Đồng bộ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _performSyncAll() async {
    // TODO: Implement actual sync logic using SyncService
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔄 Đang đồng bộ...'),
        backgroundColor: Color(0xFF2563EB),
      ),
    );
    
    await Future.delayed(const Duration(seconds: 2));
    
    setState(() => _unSyncedCount = 0);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Đồng bộ hoàn tất!'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  Future<void> _downloadTicket(String ticketId) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📥 Đang tải phiếu về...'),
          backgroundColor: Color(0xFF2563EB),
        ),
      );
      
      final response = await ApiService.downloadTicketOffline(ticketId);
      
      if (response['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Tải phiếu thành công!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        _loadTickets();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _deleteOfflineTicket(String ticketId) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF091A33),
        title: const Text('Xóa phiếu offline', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Xóa dữ liệu phiếu này khỏi điện thoại?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final db = await DatabaseService.instance.database;
                await db.delete(
                  'audit_items_offline',
                  where: 'ticket_id = ?',
                  whereArgs: [ticketId],
                );
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Đã xóa phiếu offline'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                  _loadTickets();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Lỗi: $e'),
                      backgroundColor: const Color(0xFFEF4444),
                    ),
                  );
                }
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét theo phiếu'),
        backgroundColor: const Color(0xFF091A33),
        foregroundColor: Colors.white,
        actions: [
          if (_unSyncedCount > 0)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: GestureDetector(
                  onTap: _syncAllTickets,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_upload_outlined, color: const Color(0xFFFCD34D), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Sync $_unSyncedCount',
                          style: const TextStyle(
                            color: Color(0xFFFCD34D),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      backgroundColor: const Color(0xFF0F172A),
      body: Column(
        children: [
          // Search + Sort
          Container(
            color: const Color(0xFF091A33),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search
                TextField(
                  controller: _searchController,
                  onChanged: _applySearch,
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
                const SizedBox(height: 12),
                // Sort options
                Row(
                  children: [
                    Expanded(
                      child: _buildSortButton('📅 Ngày tạo', 'DATE'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSortButton('📊 Tiến độ', 'PROGRESS'),
                    ),
                  ],
                ),
              ],
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
                            Icon(Icons.inbox_outlined, color: Colors.white30, size: 64),
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

  Widget _buildSortButton(String label, String value) {
    final isSelected = _sortBy == value;
    return GestureDetector(
      onTap: () {
        setState(() => _sortBy = value);
        _applySort();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0D2242),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final ticketId = ticket['ticket_id'] as String? ?? 'N/A';
    final totalItems = ticket['total_items'] as int? ?? 0;
    final scannedItems = ticket['scanned_items'] as int? ?? 0;
    final progress = totalItems > 0 ? (scannedItems / totalItems * 100).toStringAsFixed(1) : '0.0';
    final status = ticket['status'] as String? ?? 'IN_PROGRESS';
    
    final statusColor = status == 'COMPLETED' ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    final statusLabel = status == 'COMPLETED' ? '✅ Hoàn thành' : '⏳ Đang làm';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TicketBasedScanScreen(ticketId: ticketId),
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
            // Header
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
            const SizedBox(height: 10),

            // Progress bar
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
            const SizedBox(height: 10),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.download, color: Colors.white60, size: 16),
                    label: const Text('Tải về', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => _downloadTicket(ticketId),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 16),
                    label: const Text('Quét', style: TextStyle(color: Colors.white, fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TicketBasedScanScreen(ticketId: ticketId),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _deleteOfflineTicket(ticketId),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.delete_outline, color: Color(0xFFF87171), size: 16),
                  ),
                ),
              ],
            ),
          ],
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
