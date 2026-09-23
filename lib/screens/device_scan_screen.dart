import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';

class AssetInfo {
  final String assetCode;
  final String machineName;
  final String currentUser;
  final String ipAddress;
  final String processor;
  final String ram;

  AssetInfo({
    required this.assetCode,
    required this.machineName,
    required this.currentUser,
    required this.ipAddress,
    required this.processor,
    required this.ram,
  });

  factory AssetInfo.fromJson(Map<String, dynamic> json) {
    return AssetInfo(
      assetCode: json['asset_code'] ?? json['asset_tag'] ?? json['tag'] ?? 'N/A',
      machineName: json['machine_name'] ?? json['hostname'] ?? json['name'] ?? 'N/A',
      currentUser: json['current_user'] ?? json['user'] ?? json['username'] ?? 'Chưa gán',
      ipAddress: json['ip_address'] ?? json['ip'] ?? '0.0.0.0',
      processor: json['processor'] ?? json['cpu'] ?? 'N/A',
      ram: json['ram'] ?? json['memory'] ?? 'N/A',
    );
  }
}

class DeviceScanScreen extends StatefulWidget {
  final String? initialTag;
  const DeviceScanScreen({super.key, this.initialTag});

  @override
  State<DeviceScanScreen> createState() => _DeviceScanScreenState();
}

class _DeviceScanScreenState extends State<DeviceScanScreen> {
  late MobileScannerController _scannerController;
  bool _isFlashOn = false;
  bool _isLoading = false;
  bool _hasCameraPermission = false;
  bool _isScanningActive = true;

  AssetInfo? _currentAsset;
  String? _errorMessage;

  final TextEditingController _manualInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    _checkCameraPermission();
    if (widget.initialTag != null && widget.initialTag!.isNotEmpty) {
      _manualInputController.text = widget.initialTag!;
      _fetchAssetInfo(widget.initialTag!);
    }
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.request();
    if (mounted) {
      setState(() {
        _hasCameraPermission = status.isGranted;
      });
    }
  }

  Future<void> _toggleFlash() async {
    try {
      await _scannerController.toggleTorch();
      if (mounted) {
        setState(() => _isFlashOn = !_isFlashOn);
      }
    } catch (_) {}
  }

  void _onDetect(BarcodeCapture capture) async {
    if (!_isScanningActive || _isLoading) return;

    final barcode = capture.barcodes.firstOrNull;
    final rawCode = barcode?.rawValue?.trim();
    if (rawCode == null || rawCode.isEmpty) return;

    setState(() {
      _isScanningActive = false;
    });

    HapticFeedback.mediumImpact();
    await _fetchAssetInfo(rawCode);
  }

  String _cleanAssetCode(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('{') && cleaned.endsWith('}')) {
      try {
        final map = jsonDecode(cleaned);
        if (map is Map) {
          return map['tag'] ?? map['asset_tag'] ?? map['asset_code'] ?? map['id'] ?? cleaned;
        }
      } catch (_) {}
    }
    if (cleaned.contains('-')) {
      final parts = cleaned.split('-');
      if (parts.isNotEmpty && parts.first.length >= 4) {
        return parts.first.trim();
      }
    }
    return cleaned;
  }

  Future<void> _fetchAssetInfo(String rawCode) async {
    final cleanCode = _cleanAssetCode(rawCode);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _queryAssetData(cleanCode);
      if (!mounted) return;

      if (result != null) {
        setState(() {
          _currentAsset = result;
          _errorMessage = null;
          _isLoading = false;
        });
      } else {
        setState(() {
          _currentAsset = null;
          _errorMessage = 'Không tìm thấy tài sản trên hệ thống!\nMã quét: $cleanCode';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _currentAsset = null;
        _errorMessage = 'Lỗi truy vấn dữ liệu: $e';
        _isLoading = false;
      });
    }
  }

  Future<AssetInfo?> _queryAssetData(String code) async {
    try {
      final apiResponse = await ApiService.getDeviceDetail(code);
      if (apiResponse['success'] == true && apiResponse['device'] != null) {
        return AssetInfo.fromJson(apiResponse['device']);
      }
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 600));

    final mockDatabase = <String, AssetInfo>{
      'TS-2026-001': AssetInfo(
        assetCode: 'TS-2026-001',
        machineName: 'IT-DESKTOP-01',
        currentUser: 'Nguyễn Văn A (IT Support)',
        ipAddress: '192.168.1.125',
        processor: 'Intel Core i7-13700 (16 Cores)',
        ram: '32 GB DDR5 5600MHz',
      ),
      'MTS00192': AssetInfo(
        assetCode: 'MTS00192',
        machineName: 'KT-LAPTOP-LENOVO',
        currentUser: 'Trần Thị B (Kế toán trưởng)',
        ipAddress: '192.168.1.88',
        processor: 'AMD Ryzen 7 7840U',
        ram: '16 GB LPDDR5',
      ),
      '242200486': AssetInfo(
        assetCode: '242200486',
        machineName: 'LENOVO 83K6-PC',
        currentUser: 'Linh Nguyen (Admin)',
        ipAddress: '192.168.1.200',
        processor: 'Intel Core i5-12450H',
        ram: '16 GB DDR4',
      ),
    };

    if (mockDatabase.containsKey(code)) {
      return mockDatabase[code];
    }

    for (final entry in mockDatabase.entries) {
      if (code.contains(entry.key) || entry.key.contains(code)) {
        return entry.value;
      }
    }

    // Không tìm thấy trong mock database → trả null
    return null;
  }

  void _resumeScanning() {
    setState(() {
      _currentAsset = null;
      _errorMessage = null;
      _isScanningActive = true;
      _manualInputController.clear();
    });
  }

  void _showUpdateIpDialog(BuildContext context) {
    final ipController = TextEditingController(text: _currentAsset?.ipAddress ?? '');
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A2847),
          title: const Text(
            'Cập nhật Địa chỉ IP',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tên máy: ${_currentAsset?.machineName}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ipController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Nhập địa chỉ IP (VD: 192.168.1.100)...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF0F1729),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF0284C7)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              if (isLoading)
                const SizedBox(
                  height: 40,
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF0284C7)),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final newIp = ipController.text.trim();
                      if (newIp.isEmpty) return;
                      setDialogState(() => isLoading = true);
                      final result = await ApiService.updateDeviceIp(
                        assetTag: _currentAsset!.assetCode,
                        ipAddress: newIp,
                      );
                      if (!mounted) return;
                      setDialogState(() => isLoading = false);
                      if (result['success'] == true) {
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã cập nhật IP thành công!'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                        setState(() {
                          _currentAsset = AssetInfo(
                            assetCode: _currentAsset!.assetCode,
                            machineName: _currentAsset!.machineName,
                            currentUser: _currentAsset!.currentUser,
                            ipAddress: newIp,
                            processor: _currentAsset!.processor,
                            ram: _currentAsset!.ram,
                          );
                        });
                      } else {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result['message'] ?? 'Không cập nhật được IP'),
                            backgroundColor: const Color(0xFFEF4444),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                disabledBackgroundColor: Colors.grey[600],
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateUserDialog(BuildContext context) {
    final userController = TextEditingController(text: _currentAsset?.currentUser ?? '');
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A2847),
          title: const Text(
            'Cập nhật người sử dụng',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Mã tài sản: ${_currentAsset?.assetCode}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: userController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Nhập tên người sử dụng...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF0F1729),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2563EB)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              if (isLoading)
                const SizedBox(
                  height: 40,
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setDialogState(() => isLoading = true);
                      final result = await ApiService.updateDeviceUser(
                        assetTag: _currentAsset!.assetCode,
                        assetUser: userController.text.trim(),
                      );
                      if (!mounted) return;
                      setDialogState(() => isLoading = false);
                      if (result['success'] == true) {
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã cập nhật người sử dụng thành công!'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                        setState(() {
                          _currentAsset = AssetInfo(
                            assetCode: _currentAsset!.assetCode,
                            machineName: _currentAsset!.machineName,
                            currentUser: userController.text.trim(),
                            ipAddress: _currentAsset!.ipAddress,
                            processor: _currentAsset!.processor,
                            ram: _currentAsset!.ram,
                          );
                        });
                      } else {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result['message'] ?? 'Không cập nhật được'),
                            backgroundColor: const Color(0xFFEF4444),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                disabledBackgroundColor: Colors.grey[600],
              ),
              child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1729),
      appBar: AppBar(
        title: const Text(
          'Scan Test - Tài sản cố định',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF091A33),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleFlash,
            tooltip: 'Bật/tắt Flash',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resumeScanning,
            tooltip: 'Quét lại',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isScanningActive && _currentAsset == null && !_isLoading)
              Container(
                height: 230,
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2563EB), width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_hasCameraPermission)
                        MobileScanner(
                          controller: _scannerController,
                          onDetect: _onDetect,
                          fit: BoxFit.cover,
                        )
                      else
                        Center(
                          child: ElevatedButton(
                            onPressed: _checkCameraPermission,
                            child: const Text('Cấp quyền Camera'),
                          ),
                        ),
                      Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.lightBlueAccent, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Hướng camera vào mã QR',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manualInputController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Nhập mã tài sản (VD: 242200486)...',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF1A2847),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          _fetchAssetInfo(val.trim());
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final val = _manualInputController.text.trim();
                      if (val.isNotEmpty) {
                        _fetchAssetInfo(val);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Tìm', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF2563EB)),
                      SizedBox(height: 16),
                      Text(
                        'Đang truy vấn database...',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            if (!_isLoading && _errorMessage != null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 54),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _resumeScanning,
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Quét mã khác'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (!_isLoading && _currentAsset != null)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      _buildAssetCard(_currentAsset!),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () => _showUpdateUserDialog(context),
                        icon: const Icon(Icons.person_add_alt_1, size: 18),
                        label: const Text('Cập nhật người sử dụng'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          minimumSize: const Size(double.infinity, 46),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showUpdateIpDialog(context),
                              icon: const Icon(Icons.edit_location_alt, size: 18),
                              label: const Text('Cập nhật IP'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0284C7),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Tạo ticket báo hỏng cho tài sản: ${_currentAsset!.assetCode}'),
                                    backgroundColor: const Color(0xFFDC2626),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.report_problem, size: 18),
                              label: const Text('Báo hỏng'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _resumeScanning,
                        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                        label: const Text('Quét tiếp tài sản khác', style: TextStyle(color: Colors.white)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 46),
                          side: const BorderSide(color: Color(0xFF2563EB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetCard(AssetInfo asset) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2847),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MÃ TÀI SẢN',
                style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  asset.assetCode,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
          const SizedBox(height: 14),
          _buildDetailRow('Tên máy (Hostname)', asset.machineName, Icons.computer, Colors.cyanAccent),
          const SizedBox(height: 12),
          _buildDetailRow('Người sử dụng', asset.currentUser, Icons.person, Colors.amberAccent),
          const SizedBox(height: 12),
          _buildDetailRow('Địa chỉ IP', asset.ipAddress, Icons.wifi, Colors.greenAccent),
          const SizedBox(height: 12),
          _buildDetailRow('Bộ vi xử lý (CPU)', asset.processor, Icons.memory, Colors.orangeAccent),
          const SizedBox(height: 12),
          _buildDetailRow('Dung lượng RAM', asset.ram, Icons.storage, Colors.purpleAccent),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _manualInputController.dispose();
    super.dispose();
  }
}
