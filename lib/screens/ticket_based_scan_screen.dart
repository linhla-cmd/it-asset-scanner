import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import 'ticket_checklist_screen.dart';

class TicketBasedScanScreen extends StatefulWidget {
  final String ticketId;
  const TicketBasedScanScreen({super.key, required this.ticketId});

  @override
  State<TicketBasedScanScreen> createState() => _TicketBasedScanScreenState();
}

class _TicketBasedScanScreenState extends State<TicketBasedScanScreen> {
  late MobileScannerController _scannerController;
  bool _isProcessing = false;
  bool _isPaused = false;
  bool _isTorchOn = false;
  
  int _totalItems = 0;
  int _scannedItems = 0;
  int _matchedItems = 0;
  int _unexpectedItems = 0;
  int _missingItems = 0;
  
  final List<Map<String, dynamic>> _scannedList = [];
  final List<String> _scanHistory = [];

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    _loadTicketStats();
  }

  Future<void> _loadTicketStats() async {
    try {
      final response = await ApiService.getTicketItems(widget.ticketId);
      if (response['success'] == true && mounted) {
        final items = List<Map<String, dynamic>>.from(response['items'] ?? []);
        setState(() {
          _totalItems = items.length;
          _missingItems = items.length;
        });
      }
    } catch (e) {
      print('Error loading ticket stats: $e');
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

    // Check duplicate
    if (_scanHistory.contains(code)) {
      _playErrorSound();
      _showFloatingMessage('⚠️ Đã quét: $code', Colors.orange, vibrationCount: 2);
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
        final deviceInfo = response['device'] ?? {};
        final hostname = deviceInfo['hostname'] ?? 'Unknown';

        _scanHistory.add(code);
        
        setState(() {
          _scannedItems++;
          _missingItems = _totalItems - _scannedItems;

          if (status == 'MATCHED') {
            _matchedItems++;
            _scannedList.add({
              'code': code,
              'hostname': hostname,
              'status': 'MATCHED',
              'timestamp': DateTime.now(),
            });
            _playSuccessSound();
            _showFloatingMessage('✅ $hostname', const Color(0xFF10B981), vibrationCount: 1);
          } else if (status == 'UNEXPECTED') {
            _unexpectedItems++;
            _scannedList.add({
              'code': code,
              'hostname': hostname,
              'status': 'UNEXPECTED',
              'timestamp': DateTime.now(),
            });
            _playWarningSound();
            _showFloatingMessage('⚠️ THỪA: $hostname', Colors.orange, vibrationCount: 2);
          }
        });

        await DatabaseService.instance.addScanHistory(widget.ticketId, code, status);
      }
    } catch (e) {
      _playErrorSound();
      _showFloatingMessage('❌ Lỗi: $e', const Color(0xFFEF4444), vibrationCount: 3);
    } finally {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _isProcessing = false);
      });
    }
  }

  void _playSuccessSound() {
    // Placeholder for success sound (use audioplayers package)
    HapticFeedback.heavyImpact();
  }

  void _playWarningSound() {
    HapticFeedback.mediumImpact();
  }

  void _playErrorSound() {
    HapticFeedback.lightImpact();
  }

  void _showFloatingMessage(String message, Color color, {int vibrationCount = 1}) {
    for (int i = 0; i < vibrationCount; i++) {
      HapticFeedback.vibrate();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _toggleTorch() async {
    setState(() => _isTorchOn = !_isTorchOn);
    await _scannerController.toggleTorch();
  }

  Future<void> _undoLastScan() async {
    if (_scanHistory.isEmpty) {
      _showFloatingMessage('ℹ️ Không có lần quét nào', Colors.blue);
      return;
    }

    final lastCode = _scanHistory.removeLast();
    final lastItem = _scannedList.isNotEmpty ? _scannedList.removeLast() : null;

    if (lastItem != null) {
      if (lastItem['status'] == 'MATCHED') {
        _matchedItems--;
      } else if (lastItem['status'] == 'UNEXPECTED') {
        _unexpectedItems--;
      }
    }

    setState(() {
      _scannedItems--;
      _missingItems = _totalItems - _scannedItems;
    });

    _showFloatingMessage('↩️ Hoàn tác: $lastCode', Colors.blue);
  }

  void _showScannedList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF091A33),
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Danh sách quét',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close, color: Colors.white60),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _scannedList.length,
                itemBuilder: (ctx, idx) {
                  final item = _scannedList[idx];
                  final isMatched = item['status'] == 'MATCHED';
                  final color = isMatched ? const Color(0xFF10B981) : Colors.orange;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D2242),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isMatched ? Icons.check_circle : Icons.warning,
                          color: color,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['hostname'] ?? 'Unknown',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item['code'] ?? '',
                                style: const TextStyle(color: Colors.white60, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          isMatched ? 'Khớp' : 'Thừa',
                          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
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
    );
  }

  Future<void> _submitTicket() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF091A33),
        title: const Text('Xác nhận chốt phiếu', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConfirmStat('Tổng cộng', '$_totalItems'),
            _buildConfirmStat('Đã quét', '$_scannedItems'),
            _buildConfirmStat('Khớp', '$_matchedItems', const Color(0xFF10B981)),
            _buildConfirmStat('Thừa', '$_unexpectedItems', Colors.orange),
            _buildConfirmStat('Thiếu', '$_missingItems', const Color(0xFFEF4444)),
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
              await _performSubmit();
            },
            child: const Text('Chốt phiếu', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _performSubmit() async {
    _scannerController.stop();
    try {
      final response = await ApiService.approveTicket(widget.ticketId);
      if (response['success'] == true && mounted) {
        _showFloatingMessage('✅ Phiếu đã chốt thành công!', const Color(0xFF10B981));
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      _showFloatingMessage('❌ Lỗi: $e', const Color(0xFFEF4444));
      _scannerController.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalItems > 0 ? (_scannedItems / _totalItems * 100).toStringAsFixed(1) : '0.0';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét phiếu'),
        backgroundColor: const Color(0xFF091A33),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flashlight_on : Icons.flashlight_off, color: Colors.white),
            onPressed: _toggleTorch,
            tooltip: 'Đèn flash',
          ),
          IconButton(
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause, color: Colors.white),
            onPressed: () => setState(() => _isPaused = !_isPaused),
            tooltip: _isPaused ? 'Tiếp tục' : 'Tạm dừng',
          ),
        ],
      ),
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Camera
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // Overlay UI
          Column(
            children: [
              // Top: Large counter
              Container(
                color: Colors.black.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Column(
                  children: [
                    Text(
                      '$_scannedItems',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'của ',
                          style: TextStyle(color: Colors.white60, fontSize: 16),
                        ),
                        Text(
                          '$_totalItems',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),

              // Middle: Camera area
              Expanded(child: Container()),

              // Bottom: Stats & Controls
              Container(
                color: Colors.black.withValues(alpha: 0.6),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Stats row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatBadge('✅ Khớp', '$_matchedItems', const Color(0xFF10B981)),
                        _buildStatBadge('⚠️ Thừa', '$_unexpectedItems', Colors.orange),
                        _buildStatBadge('❌ Thiếu', '$_missingItems', const Color(0xFFEF4444)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Buttons row 1
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.undo, color: Colors.white60, size: 18),
                            label: const Text('Hoàn tác', style: TextStyle(color: Colors.white60, fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: _undoLastScan,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.list, color: Colors.white, size: 18),
                            label: const Text('Danh sách', style: TextStyle(color: Colors.white, fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D2242),
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: _showScannedList,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Buttons row 2
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.details, color: Colors.white60, size: 18),
                            label: const Text('Chi tiết', style: TextStyle(color: Colors.white60, fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TicketChecklistScreen(ticketId: widget.ticketId),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
                            label: const Text('Chốt phiếu', style: TextStyle(color: Colors.white, fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(vertical: 10),
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

          // Pause overlay
          if (_isPaused)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pause_circle_outline, color: Colors.white, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'QUÉT ĐÃ TẠMTẠM DỪNG',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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

  Widget _buildStatBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
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

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }
}
