import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';

class InstantTicketScanScreen extends StatefulWidget {
  const InstantTicketScanScreen({super.key});

  @override
  State<InstantTicketScanScreen> createState() => _InstantTicketScanScreenState();
}

class _InstantTicketScanScreenState extends State<InstantTicketScanScreen> {
  late MobileScannerController _scannerController;
  final List<String> _scannedAssets = [];
  bool _isProcessing = false;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || _isPaused) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final qrCodes = barcodes.where((b) => b.type == BarcodeType.qr).toList();
    if (qrCodes.isEmpty) return;

    final String? code = qrCodes.first.rawValue;
    if (code == null || code.trim().isEmpty) return;

    // Check for duplicate
    if (_scannedAssets.contains(code)) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Đã quét mã này rồi!'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _scannedAssets.add(code);
    });

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Đã quét: $code (${_scannedAssets.length} item)'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isProcessing = false);
    });
  }

  void _removeAsset(String asset) {
    setState(() => _scannedAssets.removeWhere((a) => a == asset));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('↩️ Xóa: $asset'),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _submitTicket() async {
    if (_scannedAssets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Vui lòng quét ít nhất 1 tài sản'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF091A33),
        title: const Text('Xác nhận tạo phiếu', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bạn muốn tạo phiếu kiểm kê nhanh với ${_scannedAssets.length} tài sản?',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D2242),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Danh sách tài sản:',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 150,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _scannedAssets.asMap().entries.map((e) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '${e.key + 1}. ${e.value}',
                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () async {
              Navigator.pop(ctx);
              await _createInstantTicket();
            },
            child: const Text('Tạo phiếu', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _createInstantTicket() async {
    _scannerController.stop();

    try {
      final response = await ApiService.createInstantTicket(_scannedAssets);

      if (response['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Tạo phiếu thành công: ${response['ticket_id']}'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => _scannedAssets.clear());
            _scannerController.start();
          }
        });
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
      _scannerController.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kiểm kê nhanh'),
        backgroundColor: const Color(0xFF091A33),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause, color: Colors.white),
            onPressed: () => setState(() => _isPaused = !_isPaused),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF0F172A),
      body: Column(
        children: [
          // Camera view
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                ),
                // Overlay
                if (_isPaused)
                  Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    child: const Center(
                      child: Text(
                        'QUÉT ĐÃ TẠMTẠM DỪNG',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Preview list
          Expanded(
            flex: 1,
            child: Container(
              color: const Color(0xFF091A33),
              child: Column(
                children: [
                  // Counter
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Danh sách quét (${_scannedAssets.length})',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        if (_scannedAssets.isNotEmpty)
                          GestureDetector(
                            onTap: () => setState(() => _scannedAssets.clear()),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Xóa tất cả',
                                style: TextStyle(color: Color(0xFFF87171), fontSize: 11),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Items list
                  Expanded(
                    child: _scannedAssets.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox_outlined, color: Colors.white30, size: 48),
                                SizedBox(height: 12),
                                Text(
                                  'Chưa quét tài sản nào',
                                  style: TextStyle(color: Colors.white60, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: _scannedAssets.length,
                            itemBuilder: (ctx, idx) => Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D2242),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '${idx + 1}.',
                                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _scannedAssets[idx],
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _removeAsset(_scannedAssets[idx]),
                                    child: const Icon(Icons.close, color: Colors.white30, size: 18),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  // Action buttons
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle, color: Colors.white),
                        label: const Text('Tạo phiếu', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _submitTicket,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }
}
