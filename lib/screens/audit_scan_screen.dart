import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';

class AuditScanScreen extends StatefulWidget {
  final String ticketId;
  const AuditScanScreen({super.key, required this.ticketId});

  @override
  State<AuditScanScreen> createState() => _AuditScanScreenState();
}

class _AuditScanScreenState extends State<AuditScanScreen> {
  late MobileScannerController _scannerController;
  bool _isProcessing = false;
  int _totalItems = 0;
  int _scannedItems = 0;
  int _matchedItems = 0;
  int _unexpectedItems = 0;
  final List<String> _scanHistory = [];
  List<Map<String, dynamic>> _ticketItems = [];
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    _loadTicketItems();
  }

  Future<void> _loadTicketItems() async {
    try {
      final response = await ApiService.getTicketItems(widget.ticketId);
      if (response['success'] == true && mounted) {
        final items = List<Map<String, dynamic>>.from(response['items'] ?? []);
        setState(() {
          _ticketItems = items;
          _totalItems = items.length;
        });
      }
    } catch (e) {
      print('Error loading ticket items: $e');
    }
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || _isPaused) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final qrCodes = barcodes.where((b) => b.type == BarcodeType.qr).toList();
    if (qrCodes.isEmpty) return;

    final String? code = qrCodes.first.rawValue;
    if (code == null || code.trim().isEmpty) return;

    // Check for duplicate scan
    if (_scanHistory.contains(code)) {
      _playSound('error');
      _showMessage('⚠️ Đã quét mã này rồi!', Colors.orange, vibrationPattern: [100, 50, 100]);
      return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      final response = await ApiService.scanAssetTag(
        ticketId: widget.ticketId,
        assetTag: code,
        scannedBy: 'mobile_app',
      );

      if (response['success'] == true) {
        final status = response['status'] ?? 'MATCHED';
        
        _scanHistory.add(code);
        setState(() {
          _scannedItems++;
          if (status == 'MATCHED') {
            _matchedItems++;
            _playSound('success');
            _showMessage('✅ Khớp: $code', const Color(0xFF10B981), vibrationPattern: [100]);
          } else if (status == 'UNEXPECTED') {
            _unexpectedItems++;
            _playSound('warning');
            _showMessage('⚠️ Thừa: $code (Không có trong phiếu)', Colors.orange, vibrationPattern: [100, 50, 100]);
          }
        });

        // Save to local history
        await DatabaseService.instance.addScanHistory(widget.ticketId, code, status);
      } else {
        _playSound('error');
        _showMessage('❌ Lỗi: ${response['message'] ?? 'Không tìm thấy tài sản'}', const Color(0xFFEF4444), vibrationPattern: [100, 100, 100]);
      }
    } catch (e) {
      _playSound('error');
      _showMessage('❌ Lỗi kết nối: $e', const Color(0xFFEF4444));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _playSound(String type) {
    // Placeholder for sound playing
    // Could use audioplayers package
  }

  void _showMessage(String message, Color bgColor, {List<int>? vibrationPattern}) {
    if (vibrationPattern != null) {
      HapticFeedback.vibrate();
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _undoLastScan() async {
    if (_scanHistory.isEmpty) {
      _showMessage('ℹ️ Không có lần quét nào để hoàn tác', Colors.blue);
      return;
    }

    final lastCode = _scanHistory.removeLast();
    setState(() => _scannedItems--);
    _showMessage('↩️ Đã hoàn tác: $lastCode', Colors.blue);
  }

  Future<void> _submitTicket() async {
    final missingItems = _totalItems - _scannedItems;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF091A33),
        title: const Text('Xác nhận chốt phiếu', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConfirmStat('Tổng cộng', '$_totalItems tài sản'),
            _buildConfirmStat('Đã quét', '$_scannedItems tài sản'),
            _buildConfirmStat('Khớp', '$_matchedItems tài sản', const Color(0xFF10B981)),
            _buildConfirmStat('Thừa', '$_unexpectedItems tài sản', Colors.orange),
            _buildConfirmStat('Thiếu', '$missingItems tài sản', const Color(0xFFEF4444)),
            const SizedBox(height: 12),
            const Text(
              'Bạn có chắc muốn chốt phiếu này?',
              style: TextStyle(color: Colors.white70, fontSize: 12),
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
              await _submitToServer();
            },
            child: const Text('Chốt phiếu', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitToServer() async {
    try {
      _scannerController.stop();
      
      final response = await ApiService.approveTicket(widget.ticketId);
      
      if (response['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Phiếu đã được chốt thành công!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
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
    final missingItems = _totalItems - _scannedItems;
    final progress = _totalItems > 0 ? (_scannedItems / _totalItems * 100).toStringAsFixed(1) : '0.0';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét kiểm kê'),
        backgroundColor: const Color(0xFF091A33),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause, color: Colors.white),
            onPressed: () => setState(() => _isPaused = !_isPaused),
            tooltip: _isPaused ? 'Tiếp tục' : 'Tạm dừng',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showScanSummary(),
            tooltip: 'Chi tiết',
          ),
        ],
      ),
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Camera view
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // Overlay UI
          Column(
            children: [
              // Top: Counter display
              Container(
                color: Colors.black.withValues(alpha: 0.3),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      'Phiếu: ${widget.ticketId}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Large counter
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            Text(
                              '$_scannedItems',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'Đã quét',
                              style: TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Column(
                          children: [
                            Text(
                              '$_totalItems',
                              style: const TextStyle(
                                color: Colors.white30,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'Tổng cộng',
                              style: TextStyle(color: Colors.white30, fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _totalItems > 0 ? _scannedItems / _totalItems : 0,
                        backgroundColor: Colors.grey[800],
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF2563EB)),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$progress% hoàn thành',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),

              // Middle: Camera scanning area (with frame)
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Scanning frame overlay
                    CustomPaint(
                      size: Size.infinite,
                      painter: ScanFramePainter(),
                    ),
                    // Pause indicator
                    if (_isPaused)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pause_circle_outline, color: Colors.white, size: 48),
                            SizedBox(height: 12),
                            Text(
                              'QUÉT ĐÃ TẠMTẠM DỪNG',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Bottom: Stats and controls
              Container(
                color: Colors.black.withValues(alpha: 0.4),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Stats row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatBadge('✅ Khớp', '$_matchedItems', const Color(0xFF10B981)),
                        _buildStatBadge('⚠️ Thừa', '$_unexpectedItems', Colors.orange),
                        _buildStatBadge('❌ Thiếu', '$missingItems', const Color(0xFFEF4444)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.undo, color: Colors.white60),
                            label: const Text('Hoàn tác', style: TextStyle(color: Colors.white60)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _undoLastScan,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle, color: Colors.white),
                            label: const Text('Chốt phiếu', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _submitTicket,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmStat(String label, String value, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showScanSummary() {
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
              'Lịch sử quét',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _scanHistory.length,
                itemBuilder: (ctx, idx) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Text(
                        '${idx + 1}.',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _scanHistory[idx],
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }
}

// Custom painter for scan frame
class ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const frameSize = 260.0;
    final offsetX = (size.width - frameSize) / 2;
    final offsetY = (size.height - frameSize) / 2;

    // Draw dimmed background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );

    // Clear the scanning area
    canvas.drawRect(
      Rect.fromLTWH(offsetX, offsetY, frameSize, frameSize),
      Paint()..blendMode = BlendMode.clear,
    );

    // Draw frame border (Neon Blue)
    canvas.drawRect(
      Rect.fromLTWH(offsetX, offsetY, frameSize, frameSize),
      Paint()
        ..color = const Color(0xFF2563EB)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );

    // Draw corner brackets
    const cornerLength = 24.0;
    final paint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(Offset(offsetX, offsetY), Offset(offsetX + cornerLength, offsetY), paint);
    canvas.drawLine(Offset(offsetX, offsetY), Offset(offsetX, offsetY + cornerLength), paint);

    // Top-right
    canvas.drawLine(Offset(offsetX + frameSize, offsetY), Offset(offsetX + frameSize - cornerLength, offsetY), paint);
    canvas.drawLine(Offset(offsetX + frameSize, offsetY), Offset(offsetX + frameSize, offsetY + cornerLength), paint);

    // Bottom-left
    canvas.drawLine(Offset(offsetX, offsetY + frameSize), Offset(offsetX + cornerLength, offsetY + frameSize), paint);
    canvas.drawLine(Offset(offsetX, offsetY + frameSize), Offset(offsetX, offsetY + frameSize - cornerLength), paint);

    // Bottom-right
    canvas.drawLine(Offset(offsetX + frameSize, offsetY + frameSize), Offset(offsetX + frameSize - cornerLength, offsetY + frameSize), paint);
    canvas.drawLine(Offset(offsetX + frameSize, offsetY + frameSize), Offset(offsetX + frameSize, offsetY + frameSize - cornerLength), paint);
  }

  @override
  bool shouldRepaint(ScanFramePainter oldDelegate) => false;
}
