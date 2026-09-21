import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';

class AuditScanScreen extends StatefulWidget {
  final String ticketId;
  final String ticketTitle;

  const AuditScanScreen({
    super.key,
    required this.ticketId,
    required this.ticketTitle,
  });

  @override
  State<AuditScanScreen> createState() => _AuditScanScreenState();
}

class _AuditScanScreenState extends State<AuditScanScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;
  Map<String, dynamic>? _ticketDetail;
  List<dynamic> _items = [];
  int _scannedCount = 0;
  int _totalCount = 0;
  String _scannedBy = 'admin';

  @override
  void initState() {
    super.initState();
    _loadTicketDetails();
  }

  Future<void> _loadTicketDetails() async {
    final detail = await ApiService.getAuditTicketDetail(widget.ticketId);
    if (detail != null && mounted) {
      setState(() {
        _ticketDetail = detail;
        _items = detail['items'] ?? [];
        _totalCount = _items.length;
        _scannedCount = _items.where((i) => i['status'] == 'SCANNED').length;
      });
    }
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? assetTag = barcodes.first.rawValue;
    if (assetTag == null || assetTag.trim().isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    _scannerController.stop();

    // Call API to submit scan
    final res = await ApiService.scanAssetTag(
      ticketId: widget.ticketId,
      assetTag: assetTag.trim(),
      scannedBy: _scannedBy,
    );

    if (mounted) {
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.greenAccent),
                const SizedBox(width: 8),
                Text('Đã quét thành công: $assetTag'),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            duration: const Duration(seconds: 2),
          ),
        );
        await _loadTicketDetails();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent),
                const SizedBox(width: 8),
                Expanded(child: Text(res['message'] ?? 'Lỗi quét Asset Tag')),
              ],
            ),
            backgroundColor: Colors.red.withOpacity(0.9),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      await Future.delayed(const Duration(milliseconds: 1200));
      _scannerController.start();
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalCount > 0 ? (_scannedCount / _totalCount) : 0.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.ticketTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Mã phiếu: ${widget.ticketId}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF38BDF8)),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Upper Section: Mobile Scanner
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                ),
                // Aim Overlay
                Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isProcessing ? Colors.orangeAccent : const Color(0xFF38BDF8),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _isProcessing
                        ? const Center(
                            child: CircularProgressIndicator(color: Colors.orangeAccent),
                          )
                        : null,
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Đưa mã QR Asset Tag vào khung ngắm',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Progress & Header Banner
          Container(
            color: const Color(0xFF1E293B),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tiến độ: $_scannedCount/$_totalCount thiết bị',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF38BDF8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.toDouble(),
                    backgroundColor: const Color(0xFF334155),
                    color: const Color(0xFF38BDF8),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),

          // Lower Section: Item Checklist
          Expanded(
            flex: 4,
            child: Container(
              color: const Color(0xFF0F172A),
              child: _items.isEmpty
                  ? const Center(
                      child: Text('Đang tải danh sách thiết bị...', style: TextStyle(color: Colors.white54)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E293B), height: 1),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final isScanned = item['status'] == 'SCANNED';
                        final assetTag = item['asset_tag'] ?? 'N/A';
                        final hostname = item['hostname'] ?? item['device_name'] ?? 'Thiết bị ${index + 1}';

                        return ListTile(
                          dense: true,
                          leading: Icon(
                            isScanned ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: isScanned ? Colors.greenAccent : Colors.white38,
                            size: 22,
                          ),
                          title: Text(
                            hostname,
                            style: TextStyle(
                              color: isScanned ? Colors.white : Colors.white70,
                              fontWeight: isScanned ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            'Tag: $assetTag',
                            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isScanned ? Colors.green.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isScanned ? 'ĐÃ QUÉT' : 'CHƯA QUÉT',
                              style: TextStyle(
                                color: isScanned ? Colors.greenAccent : Colors.white38,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
