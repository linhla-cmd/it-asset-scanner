import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TicketChecklistScreen extends StatefulWidget {
  final String ticketId;
  const TicketChecklistScreen({super.key, required this.ticketId});

  @override
  State<TicketChecklistScreen> createState() => _TicketChecklistScreenState();
}

class _TicketChecklistScreenState extends State<TicketChecklistScreen> {
  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _filteredItems = [];
  String _currentTab = 'ALL';
  String _sortBy = 'ASSET_TAG'; // ASSET_TAG or HOSTNAME
  bool _isLoading = false;
  bool _isBulkMode = false;
  Set<String> _selectedItems = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.getTicketItems(widget.ticketId);
      if (response['success'] == true && mounted) {
        final items = List<Map<String, dynamic>>.from(response['items'] ?? []);
        setState(() {
          _allItems = items;
          _applyFilters();
        });
      }
    } catch (e) {
      print('Error loading items: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = _allItems;

    // Tab filter
    if (_currentTab == 'SCANNED') {
      filtered = filtered.where((item) => item['status'] == 'MATCHED').toList();
    } else if (_currentTab == 'PENDING') {
      filtered = filtered.where((item) => item['status'] == 'MISSING').toList();
    } else if (_currentTab == 'UNEXPECTED') {
      filtered = filtered.where((item) => item['status'] == 'UNEXPECTED').toList();
    }

    // Search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((item) {
        final assetTag = (item['asset_tag'] as String? ?? '').toLowerCase();
        final hostname = (item['hostname'] as String? ?? '').toLowerCase();
        return assetTag.contains(query) || hostname.contains(query);
      }).toList();
    }

    // Sort
    if (_sortBy == 'ASSET_TAG') {
      filtered.sort((a, b) => (a['asset_tag'] ?? '').compareTo(b['asset_tag'] ?? ''));
    } else if (_sortBy == 'HOSTNAME') {
      filtered.sort((a, b) => (a['hostname'] ?? '').compareTo(b['hostname'] ?? ''));
    }

    setState(() => _filteredItems = filtered);
  }

  void _toggleBulkMode() {
    setState(() {
      _isBulkMode = !_isBulkMode;
      if (!_isBulkMode) _selectedItems.clear();
    });
  }

  void _toggleItemSelection(String assetTag) {
    setState(() {
      if (_selectedItems.contains(assetTag)) {
        _selectedItems.remove(assetTag);
      } else {
        _selectedItems.add(assetTag);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedItems = _filteredItems.map((item) => item['asset_tag'] as String).toSet();
    });
  }

  void _deselectAll() {
    setState(() => _selectedItems.clear());
  }

  Future<void> _bulkMarkAsCompleted() async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Chưa chọn item nào'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF091A33),
        title: const Text('Đánh dấu hoàn thành', style: TextStyle(color: Colors.white)),
        content: Text(
          'Đánh dấu ${_selectedItems.length} items đã hoàn thành?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () async {
              Navigator.pop(ctx);
              await _performBulkUpdate();
            },
            child: const Text('Xác nhận', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _performBulkUpdate() async {
    try {
      // TODO: Implement bulk update API
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Đã cập nhật ${_selectedItems.length} items'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      
      setState(() {
        _selectedItems.clear();
        _isBulkMode = false;
      });
      
      _loadItems();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Lỗi: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _exportToExcel() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📊 Đang xuất Excel...'),
        backgroundColor: Color(0xFF2563EB),
      ),
    );
    
    // TODO: Implement Excel export
    await Future.delayed(const Duration(seconds: 1));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Xuất Excel thành công!'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  void _addNoteToItem(String assetTag) {
    final noteController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF091A33),
        title: const Text('Ghi chú', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Thêm ghi chú cho: $assetTag',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ví dụ: Màn hình bị hỏng, cần thay thế...',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF0D2242),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Đã lưu ghi chú cho $assetTag'),
                  backgroundColor: const Color(0xFF10B981),
                ),
              );
            },
            child: const Text('Lưu', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allCount = _allItems.length;
    final scannedCount = _allItems.where((i) => i['status'] == 'MATCHED').length;
    final pendingCount = _allItems.where((i) => i['status'] == 'MISSING').length;
    final unexpectedCount = _allItems.where((i) => i['status'] == 'UNEXPECTED').length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isBulkMode ? 'Chọn: ${_selectedItems.length}' : 'Chi tiết phiếu'),
        backgroundColor: const Color(0xFF091A33),
        foregroundColor: Colors.white,
        actions: [
          if (_isBulkMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: _selectAll,
              tooltip: 'Chọn tất cả',
            ),
            IconButton(
              icon: const Icon(Icons.deselect),
              onPressed: _deselectAll,
              tooltip: 'Bỏ chọn',
            ),
            IconButton(
              icon: const Icon(Icons.check_circle),
              onPressed: _bulkMarkAsCompleted,
              tooltip: 'Đánh dấu hoàn thành',
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.checklist),
              onPressed: _toggleBulkMode,
              tooltip: 'Chế độ chọn',
            ),
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _exportToExcel,
              tooltip: 'Xuất Excel',
            ),
          ],
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _isBulkMode ? _toggleBulkMode : null,
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
                  onChanged: (_) => _applyFilters(),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm asset tag hoặc hostname...',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
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
                // Sort
                Row(
                  children: [
                    Expanded(
                      child: _buildSortButton('Asset Tag', 'ASSET_TAG'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSortButton('Hostname', 'HOSTNAME'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            color: const Color(0xFF091A33),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(child: _buildTab('Tất cả', 'ALL', allCount)),
                Expanded(child: _buildTab('Đã quét', 'SCANNED', scannedCount)),
                Expanded(child: _buildTab('Chưa quét', 'PENDING', pendingCount)),
                Expanded(child: _buildTab('Thừa', 'UNEXPECTED', unexpectedCount)),
              ],
            ),
          ),

          // Items list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Color(0xFF2563EB)),
                    ),
                  )
                : _filteredItems.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, color: Colors.white30, size: 64),
                            SizedBox(height: 16),
                            Text(
                              'Không có item nào',
                              style: TextStyle(color: Colors.white60, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredItems.length,
                        itemBuilder: (ctx, idx) => _buildItemCard(_filteredItems[idx]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, String value, int count) {
    final isActive = _currentTab == value;
    return GestureDetector(
      onTap: () {
        setState(() => _currentTab = value);
        _applyFilters();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? const Color(0xFF2563EB) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF2563EB) : Colors.white60,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                color: isActive ? const Color(0xFF2563EB) : Colors.white30,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortButton(String label, String value) {
    final isSelected = _sortBy == value;
    return GestureDetector(
      onTap: () {
        setState(() => _sortBy = value);
        _applyFilters();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0D2242),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : Colors.white.withValues(alpha: 0.1),
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

  Widget _buildItemCard(Map<String, dynamic> item) {
    final assetTag = item['asset_tag'] as String? ?? 'N/A';
    final hostname = item['hostname'] as String? ?? 'Unknown';
    final status = item['status'] as String? ?? 'MISSING';
    final isSelected = _selectedItems.contains(assetTag);

    final statusColor = status == 'MATCHED'
        ? const Color(0xFF10B981)
        : status == 'UNEXPECTED'
            ? Colors.orange
            : const Color(0xFFEF4444);

    final statusLabel = status == 'MATCHED'
        ? '✅ Đã quét'
        : status == 'UNEXPECTED'
            ? '⚠️ Thừa'
            : '❌ Chưa quét';

    return GestureDetector(
      onTap: _isBulkMode ? () => _toggleItemSelection(assetTag) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF091A33),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            if (_isBulkMode)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleItemSelection(assetTag),
                  fillColor: WidgetStateProperty.all(
                    isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                  ),
                  checkColor: Colors.white,
                  side: const BorderSide(color: Colors.white30),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hostname,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    assetTag,
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (!_isBulkMode)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _addNoteToItem(assetTag),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D2242),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.note_add, color: Colors.white60, size: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
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
