import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/database_service.dart';

class DeviceScanScreen extends StatefulWidget {
  final String? initialTag;
  const DeviceScanScreen({super.key, this.initialTag});

  @override
  State<DeviceScanScreen> createState() => _DeviceScanScreenState();
}

class _DeviceScanScreenState extends State<DeviceScanScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isScanning = false;
  bool _isFlashOn = false;
  bool _isBatchMode = false;
  int _batchCount = 0;
  final List<String> _batchResults = [];
  String? _lastScannedTag;
  bool _isLoading = false;
  bool _hasCameraPermission = false;
  final TextEditingController _manualInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
    if (widget.initialTag != null) {
      _manualInputController.text = widget.initialTag!;
    }
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() => _hasCameraPermission = status.isGranted);
  }

  Future<void> _toggleFlash() async {
    try {
      await _scannerController.toggleTorch();
      setState(() => _isFlashOn = !_isFlashOn);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Lỗi điều khiển đèn flash: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _toggleBatchMode() async {
    setState(() {
      _isBatchMode = !_isBatchMode;
      if (!_isBatchMode) {
        _batchCount = 0;
        _batchResults.clear();
      }
    });
  }

  void _onDetect(BarcodeCapture barcode) async {
    if (!_isScanning) return;

    final code = barcode.barcodes.firstOrNull?.rawValue;
    if (code == null || code == _lastScannedTag) return;

    setState(() {
      _lastScannedTag = code;
      _isScanning = false;
    });

    HapticFeedback.mediumImpact();

    if (_isBatchMode) {
      setState(() {
        _batchCount++;
        _batchResults.add(code);
      });
    } else {
      await _processSingleScan(code);
    }

    // Reset scanning after 1 second
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _isScanning = true);
    });
  }

  Future<void> _processSingleScan(String code) async {
    setState(() => _isLoading = true);

    try {
      // Check if device exists in database
      final db = await DatabaseService.instance.database;
      final existing = await db.query(
        'devices',
        where: 'asset_tag = ?',
        whereArgs: [code],
      );

      if (existing.isNotEmpty) {
        // Device exists - show info
        final device = existing.first;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Thiết bị: ${device['hostname']} (${device['asset_tag']})',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } else {
        // New device - add to database
        await db.insert('devices', {
          'asset_tag': code,
          'hostname': 'Unknown',
          'scanned_at': DateTime.now().toIso8601String(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Thêm thiết bị mới: $code'),
            backgroundColor: const Color(0xFF2563EB),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Lỗi xử lý quét: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _processBatchScan() async {
    if (_batchResults.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final db = await DatabaseService.instance.database;
      int newCount = 0;
      int existingCount = 0;

      for (final tag in _batchResults) {
        final existing = await db.query(
          'devices',
          where: 'asset_tag = ?',
          whereArgs: [tag],
        );

        if (existing.isNotEmpty) {
          existingCount++;
        } else {
          await db.insert('devices', {
            'asset_tag': tag,
            'hostname': 'Unknown',
            'scanned_at': DateTime.now().toIso8601String(),
          });
          newCount++;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Đã xử lý $_batchCount thiết bị: $newCount mới, $existingCount đã có',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );

      setState(() {
        _batchCount = 0;
        _batchResults.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Lỗi xử lý batch: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitManualInput() async {
    final tag = _manualInputController.text.trim();
    if (tag.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Vui lòng nhập mã thiết bị'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    await _processSingleScan(tag);
    _manualInputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét thiết bị'),
        backgroundColor: const Color(0xFF091A33),
        foregroundColor: Colors.white,
        actions: [
          if (_isBatchMode)
            IconButton(
              icon: const Icon(Icons.check_circle),
              onPressed: _processBatchScan,
              tooltip: 'Xác nhận batch',
            ),
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleFlash,
            tooltip: 'Đèn flash',
          ),
          IconButton(
            icon: Icon(_isBatchMode ? Icons.checklist : Icons.qr_code_scanner),
            onPressed: _toggleBatchMode,
            tooltip: _isBatchMode ? 'Chế độ đơn' : 'Chế độ batch',
          ),
        ],
      ),
      backgroundColor: const Color(0xFF0F172A),
      body: Column(
        children: [
          // Scanner area
          Expanded(
            child: Stack(
              children: [
                if (_hasCameraPermission)
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _onDetect,
                    fit: BoxFit.contain,
                  )
                else
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_alt, color: Colors.white30, size: 64),
                        const SizedBox(height: 16),
                        const Text(
                          'Cần quyền camera',
                          style: TextStyle(color: Colors.white60, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                          ),
                          onPressed: _checkCameraPermission,
                          child: const Text('Yêu cầu quyền'),
                        ),
                      ],
                    ),
                  ),

                // Scanner overlay
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF2563EB),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                // Batch counter
                if (_isBatchMode && _batchCount > 0)
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Quét: $_batchCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Manual input
          Container(
            color: const Color(0xFF091A33),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualInputController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Nhập mã thiết bị thủ công',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: const Color(0xFF0D2242),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: _submitManualInput,
                  child: const Text('Xác nhận'),
                ),
              ],
            ),
          ),

          // Loading indicator
          if (_isLoading)
            const LinearProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Color(0xFF2563EB)),
              backgroundColor: Colors.transparent,
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _manualInputController.dispose();
    super.dispose();
  }
}
