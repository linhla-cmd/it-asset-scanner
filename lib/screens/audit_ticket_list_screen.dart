import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'audit_scan_screen.dart';

class AuditTicketListScreen extends StatefulWidget {
  const AuditTicketListScreen({super.key});

  @override
  State<AuditTicketListScreen> createState() => _AuditTicketListScreenState();
}

class _AuditTicketListScreenState extends State<AuditTicketListScreen> {
  List<dynamic> _tickets = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tickets = await ApiService.getApprovedAuditTickets();
      setState(() {
        _tickets = tickets;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Lỗi tải danh sách phiếu kiểm kê';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadTickets,
        color: const Color(0xFF38BDF8),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadTickets,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                          child: const Text('Tải lại'),
                        ),
                      ],
                    ),
                  )
                : _tickets.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.white24),
                            const SizedBox(height: 16),
                            const Text(
                              'Không có phiếu kiểm kê nào được duyệt (APPROVED)',
                              style: TextStyle(color: Colors.white54, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              icon: const Icon(Icons.refresh, color: Color(0xFF38BDF8)),
                              label: const Text('Làm mới', style: TextStyle(color: Color(0xFF38BDF8))),
                              onPressed: _loadTickets,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _tickets.length,
                        itemBuilder: (context, index) {
                          final ticket = _tickets[index];
                          final ticketId = ticket['ticket_id'] ?? 'N/A';
                          final name = ticket['title'] ?? ticket['name'] ?? 'Phiếu kiểm kê $ticketId';
                          final totalItems = ticket['total_items'] ?? ticket['items_count'] ?? 0;
                          final scannedItems = ticket['scanned_items'] ?? ticket['scanned_count'] ?? 0;
                          final progress = totalItems > 0 ? (scannedItems / totalItems) : 0.0;

                          return Card(
                            color: const Color(0xFF1E293B),
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFF334155)),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AuditScanScreen(
                                      ticketId: ticketId,
                                      ticketTitle: name,
                                    ),
                                  ),
                                ).then((_) => _loadTickets());
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.greenAccent),
                                          ),
                                          child: const Text(
                                            'ĐÃ DUYỆT',
                                            style: TextStyle(
                                              color: Colors.greenAccent,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          ticketId,
                                          style: const TextStyle(
                                            color: Color(0xFF38BDF8),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Tiến độ quét: $scannedItems/$totalItems thiết bị',
                                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                                        ),
                                        Text(
                                          '${(progress * 100).toInt()}%',
                                          style: const TextStyle(
                                            color: Color(0xFF38BDF8),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: progress.toDouble(),
                                        backgroundColor: const Color(0xFF334155),
                                        color: const Color(0xFF38BDF8),
                                        minHeight: 6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
