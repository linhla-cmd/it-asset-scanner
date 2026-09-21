import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';

class DeviceScanScreen extends StatefulWidget {
  final String? initialTag;
  const DeviceScanScreen({super.key, this.initialTag});

  @override
  State<DeviceScanScreen> createState() => _DeviceScanScreenState();
}

class _DeviceScanScreenState extends State<DeviceScanScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;
  bool _isTorchOn = false;
  bool _cameraPermissionGranted = false;
  bool _checkingPermission = true;

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
    if (widget.initialTag != null && widget.initialTag!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _lookupTag(widget.initialTag!);
      });
    }
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      setState(() {
        _cameraPermissionGranted = true;
        _checkingPermission = false;
      });
    } else {
      final result = await Permission.camera.request();
      setState(() {
        _cameraPermissionGranted = result.isGranted;
        _checkingPermission = false;
      });
      if (!result.isGranted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cần cấp quyền Camera để quét mã QR. Vui lòng vào Cài đặt > Ứng dụng > Asset Agent > Quyền > Camera.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _lookupTag(String code) async {
    setState(() {
      _isProcessing = true;
    });

    _scannerController.stop();
    HapticFeedback.mediumImpact();

    final res = await ApiService.getDeviceInfo(code);

    if (mounted) {
      if (res['success'] == true) {
        _showDeviceDetailsBottomSheet(res['device']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    res['message'] ?? 'Mã QR "$code" không tồn tại trên hệ thống!',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
        _scannerController.start();
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.trim().isEmpty) return;

    await _lookupTag(code);
  }

  void _showActionNotice(String actionName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã gửi yêu cầu "$actionName" lên hệ thống.'),
        backgroundColor: const Color(0xFF2563EB),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showDeviceDetailsBottomSheet(Map<String, dynamic> device) {
    final hostname = device['hostname'] ?? 'Thiết bị IT';
    final assetTag = device['asset_tag'] ?? device['device_id'] ?? 'N/A';
    final department = device['department'] ?? 'Phòng IT / Kỹ thuật';
    final user = device['asset_user'] ?? (device['current_user']?['username']) ?? 'Chưa gán';
    final ipv4 = device['ipv4'] ?? '—';
    final osName = device['os']?['name'] ?? 'Windows';
    final isOnline = device['is_online'] == true || device['status'] == 'online';
    final model = device['model'] ?? 'Máy tính trạm Workstation';
    final lastSeen = device['last_seen'] != null
        ? DateTime.fromMillisecondsSinceEpoch(device['last_seen']).toString().substring(0, 16)
        : 'Vừa xong';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF071326),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // BottomSheet Scrollable Body
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Basic Info Header Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF091A33),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.4)),
                              ),
                              child: const Icon(
                                Icons.computer_rounded,
                                color: Color(0xFF60A5FA),
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          hostname,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isOnline
                                              ? const Color(0xFF10B981).withOpacity(0.2)
                                              : const Color(0xFFEF4444).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          isOnline ? 'ONLINE' : 'OFFLINE',
                                          style: TextStyle(
                                            color: isOnline ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Asset ID: $assetTag',
                                    style: const TextStyle(
                                      color: Color(0xFF60A5FA),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Loại: $model',
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 2. Accordion Card: Trạng thái & Vị trí
                      _buildGroupAccordion(
                        title: 'Trạng thái & Vị trí',
                        icon: Icons.location_on_outlined,
                        initiallyExpanded: true,
                        children: [
                          _buildDetailItem('Trạng thái hoạt động', isOnline ? 'Đang hoạt động (Online)' : 'Ngoại tuyến (Offline)'),
                          _buildDetailItem('Vị trí / Phòng ban', department),
                          _buildDetailItem('Người sử dụng trực tiếp', user),
                          _buildDetailItem('Địa chỉ IP mạng', ipv4),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 3. Accordion Card: Thông tin kỹ thuật
                      _buildGroupAccordion(
                        title: 'Thông tin kỹ thuật',
                        icon: Icons.memory_outlined,
                        children: [
                          _buildDetailItem('Mã Serial Number', device['device_id'] ?? 'SN-9821873912'),
                          _buildDetailItem('Hệ điều hành', osName),
                          _buildDetailItem('Thời hạn bảo hành', 'Còn 12 tháng (Hạn 2027-09)'),
                          _buildDetailItem('Chu kỳ bảo dưỡng', 'Định kỳ 6 tháng/lần'),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 4. Accordion Card: Thông tin tài chính
                      _buildGroupAccordion(
                        title: 'Thông tin tài chính',
                        icon: Icons.payments_outlined,
                        children: [
                          _buildDetailItem('Ngày bàn giao trang bị', '2025-01-15'),
                          _buildDetailItem('Nhà cung cấp', 'Chính hãng Dell Vietnam'),
                          _buildDetailItem('Tỷ lệ khấu hao', '15% / năm'),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 5. Accordion Card: Lịch sử hoạt động
                      _buildGroupAccordion(
                        title: 'Lịch sử hoạt động',
                        icon: Icons.history_outlined,
                        children: [
                          _buildDetailItem('Lần quét gần nhất', lastSeen),
                          _buildDetailItem('Lịch sử bàn giao', 'Gán quyền cho $user từ 2025-01-15'),
                          _buildDetailItem('Lịch sử bảo trì', 'Kiểm tra phần mềm hệ thống hoàn tất'),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 6. Action CTA Buttons (Các hành động theo kèm)
                      const Text(
                        'HÀNH ĐỘNG NHANH (CTA)',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.build_circle_outlined, size: 18),
                              label: const Text('Báo hỏng', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showActionNotice('Báo hỏng / Yêu cầu sửa chữa');
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                              label: const Text('Bàn giao', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF59E0B),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showActionNotice('Cập nhật vị trí / Bàn giao');
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              label: const Text('Kiểm kê', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showActionNotice('Đã xác nhận kiểm kê tài sản');
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Continue Scanning Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('QUÉT TIẾP THIẾT BỊ KHÁC'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withOpacity(0.2)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      _scannerController.start();
      setState(() {
        _isProcessing = false;
      });
    });
  }

  Widget _buildGroupAccordion({
    required String title,
    required IconData icon,
    bool initiallyExpanded = false,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF091A33),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Theme(
        data: ThemeData.dark().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Icon(icon, color: const Color(0xFF60A5FA), size: 20),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          children: children,
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
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

  @override
  Widget build(BuildContext context) {
    if (_checkingPermission) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: const Color(0xFF071326),
          elevation: 0,
          title: const Text(
            'Quét mã QR Tra cứu Tài sản',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF2563EB)),
              SizedBox(height: 16),
              Text(
                'Đang kiểm tra quyền Camera...',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (!_cameraPermissionGranted) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: const Color(0xFF071326),
          elevation: 0,
          title: const Text(
            'Quét mã QR Tra cứu Tài sản',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt_outlined, color: Colors.redAccent, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Chưa có quyền Camera',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Vui lòng cấp quyền Camera trong Cài đặt > Ứng dụng > Asset Agent > Quyền',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _checkCameraPermission,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF071326),
        elevation: 0,
        title: const Text(
          'Quét mã QR Tra cứu Tài sản',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: _isTorchOn ? Colors.yellowAccent : Colors.white70,
            ),
            onPressed: () {
              setState(() {
                _isTorchOn = !_isTorchOn;
              });
              _scannerController.toggleTorch();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // Darkened background with central scan frame
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.5),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Neon Border for Scan Frame
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF2563EB), width: 3),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),

          // Guidance notice on top
          Positioned(
            top: 24,
            left: 20,
            right: 20,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF091A33).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner, color: Color(0xFF60A5FA), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Hướng camera vào mã QR dán trên tài sản',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
