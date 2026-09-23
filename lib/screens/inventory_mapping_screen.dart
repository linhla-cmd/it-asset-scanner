import 'package:flutter/material.dart';
import '../services/api_service.dart';

class InventoryMappingScreen extends StatefulWidget {
  const InventoryMappingScreen({super.key});

  @override
  State<InventoryMappingScreen> createState() => _InventoryMappingScreenState();
}

class _InventoryMappingScreenState extends State<InventoryMappingScreen> {
  List<Map<String, dynamic>> _orders = [];
  String? _selectedOrderId;
  List<Map<String, dynamic>> _orderItems = [];
  int _totalItems = 0;
  int _scannedItems = 0;
  bool _isLoading = false;
  bool _isLoadingItems = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.getAuditTickets();
      if (response['success'] == true && mounted) {
        final tickets = List<Map<String, dynamic>>.from(response['tickets'] ?? []);
        setState(() {
          _orders = tickets;
        });
      }
    } catch (e) {
      // print('Error loading orders: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadOrderItems(String orderId) async {
    setState(() {
      _selectedOrderId = orderId;
      _isLoadingItems = true;
    });
    try {
      final response = await ApiService.getTicketItems(orderId);
      if (response['success'] == true && mounted) {
        final items = List<Map<String, dynamic>>.from(response['items'] ?? []);
        final scanned = items.where((i) => i['status'] == 'MATCHED').length;
        setState(() {
          _orderItems = items;
          _totalItems = items.length;
          _scannedItems = scanned;
        });
      }
    } catch (e) {
      // print('Error loading order items: $e');
    } finally {
      if (mounted) setState(() => _isLoadingItems = false);
    }
  }

  void _startScanning() {
    if (_selectedOrderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn đơn hàng trước')),
      );
      return;
    }
    // TODO: Navigate to scanning screen with _selectedOrderId
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => TicketBasedScanScreen(ticketId: _selectedOrderId!),
    //   ),
    // );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1729),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mapping Kiểm Kê',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Dropdown Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2563EB), width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chọn đơn hàng',
                    style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  _isLoading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : DropdownButton<String>(
                          value: _selectedOrderId,
                          isExpanded: true,
                          hint: const Text('Chọn đơn hàng...'),
                          items: _orders.map<DropdownMenuItem<String>>((order) {
                            final orderId = (order['ticket_id'] ?? order['id'] ?? '').toString();
                            final orderCode = (order['po_code'] ?? orderId).toString();
                            final itemCount = (order['item_count'] ?? 0).toString();
                            return DropdownMenuItem<String>(
                              value: orderId,
                              child: Text(
                                'PO: $orderCode - ($itemCount)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              _loadOrderItems(value);
                            }
                          },
                        ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Start Scanning Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startScanning,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BCD4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_scanner, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Bắt đầu quét',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // KPI Stats
            if (_selectedOrderId != null && !_isLoadingItems)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Icon(Icons.inventory_2, color: Color(0xFF8B7355), size: 24),
                        const SizedBox(height: 4),
                        Text(
                          'Tổng số: $_totalItems',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const Text('Thiết bị', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    Container(width: 1, height: 50, color: Colors.grey[300]),
                    Column(
                      children: [
                        const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 24),
                        const SizedBox(height: 4),
                        Text(
                          'Số scan: $_scannedItems',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const Text('Đã quét', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Items List
            if (_selectedOrderId != null && !_isLoadingItems)
              _isLoadingItems
                  ? const Center(child: CircularProgressIndicator())
                  : _orderItems.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(20),
                          alignment: Alignment.center,
                          child: const Text('Không có thiết bị trong đơn hàng này'),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _orderItems.length,
                          itemBuilder: (context, index) {
                            final item = _orderItems[index];
                            final assetTag = item['asset_tag'] ?? 'N/A';
                            final hostname = item['hostname'] ?? 'Unknown';
                            final model = item['model'] ?? 'N/A';
                            final ipAddress = item['ip_address'] ?? 'N/A';
                            final status = item['status'] ?? 'UNKNOWN';
                            final department = item['department'] ?? 'N/A';

                            Color statusColor = Colors.grey;
                            String statusLabel = 'Chưa quét';
                            if (status == 'MATCHED') {
                              statusColor = Colors.green;
                              statusLabel = 'Đã quét';
                            } else if (status == 'UNEXPECTED') {
                              statusColor = Colors.orange;
                              statusLabel = 'Không mong muốn';
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Asset Tag & Status
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              assetTag,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              hostname,
                                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Device Details Grid
                                  GridView.count(
                                    crossAxisCount: 2,
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                    childAspectRatio: 3,
                                    children: [
                                      _buildDetailItem('💻', 'Model', model),
                                      _buildDetailItem('🌐', 'IP', ipAddress),
                                      _buildDetailItem('🏢', 'Dept', department),
                                      _buildDetailItem('📍', 'Status', statusLabel),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$icon $label',
            style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
