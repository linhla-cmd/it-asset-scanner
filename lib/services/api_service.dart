import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Mặc định sử dụng IP Tailscale của máy chủ
  static const String defaultBaseUrl = 'http://100.86.164.103:3000';
  static const int maxRetries = 3;
  static const int defaultTimeout = 15; // seconds

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('custom_base_url') ?? defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_base_url', url);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<void> saveAuth(String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
    await prefs.setString('user_info', jsonEncode(user));
  }

  // Quản lý Ghi nhớ mật khẩu (Remember Me)
  static Future<void> saveRememberCredentials(String username, String password, bool remember) async {
    final prefs = await SharedPreferences.getInstance();
    if (remember) {
      await prefs.setString('remember_username', username);
      await prefs.setString('remember_password', password);
      await prefs.setBool('remember_me', true);
    } else {
      await prefs.remove('remember_username');
      await prefs.remove('remember_password');
      await prefs.setBool('remember_me', false);
    }
  }

  static Future<Map<String, dynamic>> getRememberCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('remember_me') ?? false;
    final username = prefs.getString('remember_username') ?? '';
    final password = prefs.getString('remember_password') ?? '';
    return {
      'remember': remember,
      'username': username,
      'password': password,
    };
  }

  // Biometric & Remember Me helpers
  static Future<String?> getSavedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('remember_username');
  }

  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_enabled') ?? false;
  }

  static Future<void> saveCredentials(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('remember_username', username);
    await prefs.setString('remember_password', password);
    await prefs.setBool('biometric_enabled', true);
  }

  static Future<Map<String, dynamic>> getAuditTickets() async {
    return await getAllAuditTickets();
  }

  // Tra cứu thông tin thiết bị chi tiết theo mã tài sản (Asset Tag / Code)
  static Future<Map<String, dynamic>> getDeviceDetail(String assetCode) async {
    try {
      final baseUrl = await getBaseUrl();
      final url = Uri.parse('$baseUrl/api/assets/search').replace(queryParameters: {'q': assetCode});

      final response = await _retryRequest(() => http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
      ));

      if (response == null) {
        return {'success': false, 'message': 'Không thể kết nối máy chủ'};
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['success'] == true) {
          return {
            'success': true,
            'device': data['data'] ?? {},
          };
        }
      } else if (response.statusCode == 404) {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['message'] ?? 'Không tìm thấy tài sản'};
      }
      return {'success': false, 'message': 'Lỗi từ máy chủ (${response.statusCode})'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối API: $e'};
    }
  }

  static Future<Map<String, dynamic>> approveTicket(String ticketId) async {
    try {
      final baseUrl = await getBaseUrl();
      final token = await getToken();
      final url = Uri.parse('$baseUrl/api/audit/tickets/$ticketId/approve');

      final response = await _retryRequest(() => http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ));

      if (response == null) {
        return {'success': false, 'message': 'Không thể kết nối máy chủ'};
      }

      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {'success': false, 'message': 'Duyệt phiếu thất bại'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi: $e'};
    }
  }

  static Future<Map<String, dynamic>> createInstantTicket(List<String> assetTags) async {
    try {
      final baseUrl = await getBaseUrl();
      final token = await getToken();
      final url = Uri.parse('$baseUrl/api/audit/instant');

      final response = await _retryRequest(() => http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'asset_tags': assetTags}),
      ));

      if (response == null) {
        return {'success': false, 'message': 'Không thể kết nối máy chủ'};
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'ticket_id': data['ticket_id'], 'data': data};
      }
      return {'success': false, 'message': 'Tạo phiếu thất bại'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi: $e'};
    }
  }

  static Future<Map<String, dynamic>> downloadTicketOffline(String ticketId) async {
    try {
      final detail = await getAuditTicketDetail(ticketId);
      if (detail != null) {
        return {'success': true, 'ticket': detail};
      }
      return {'success': false, 'message': 'Không tải được phiếu'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi: $e'};
    }
  }

  // Ghi nhận lịch sử quét từ Mobile App
  static Future<Map<String, dynamic>> logScan({
    required String assetTag,
    String? scannedBy,
    String scanSource = 'MOBILE_SCAN',
    String? ipAddress,
    String? deviceInfo,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final url = Uri.parse('$baseUrl/api/scan/log');
      final response = await _retryRequest(() => http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'asset_tag': assetTag,
          'scanned_by': scannedBy,
          'scan_source': scanSource,
          'ip_address': ipAddress,
          'device_info': deviceInfo,
        }),
      ));
      if (response != null && response.statusCode == 200) {
        return {'success': true};
      }
      return {'success': false, 'message': 'Không ghi được log quét'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi: $e'};
    }
  }

  // Cập nhật địa chỉ IP thiết bị từ Mobile App (Yêu cầu quyền Admin)
  static Future<Map<String, dynamic>> updateDeviceIp({
    required String assetTag,
    required String ipAddress,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final token = await getToken();
      final url = Uri.parse('$baseUrl/api/devices/update-ip');
      final response = await _retryRequest(() => http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'asset_tag': assetTag,
          'ip_address': ipAddress,
        }),
      ));
      if (response == null) {
        return {'success': false, 'message': 'Không kết nối được máy chủ'};
      }
      if (response.statusCode == 403) {
        return {'success': false, 'message': 'Bạn không có quyền Admin để cập nhật IP'};
      }
      if (response.statusCode == 401) {
        return {'success': false, 'message': 'Chưa đăng nhập hoặc phiên hết hạn'};
      }
      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {'success': false, 'message': 'Lỗi cập nhật (${response.statusCode})'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi: $e'};
    }
  }

  // Cập nhật người sử dụng thiết bị từ Mobile App (Yêu cầu quyền Admin)
  static Future<Map<String, dynamic>> updateDeviceUser({
    required String assetTag,
    required String assetUser,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final token = await getToken();
      final url = Uri.parse('$baseUrl/api/devices/update-user');
      final response = await _retryRequest(() => http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'asset_tag': assetTag,
          'asset_user': assetUser,
        }),
      ));
      if (response == null) {
        return {'success': false, 'message': 'Không kết nối được máy chủ'};
      }
      if (response.statusCode == 403) {
        return {'success': false, 'message': 'Bạn không có quyền Admin để cập nhật'};
      }
      if (response.statusCode == 401) {
        return {'success': false, 'message': 'Chưa đăng nhập hoặc phiên hết hạn'};
      }
      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {'success': false, 'message': 'Lỗi cập nhật (${response.statusCode})'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi: $e'};
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('user_info');
  }

  // Retry wrapper with exponential backoff
  static Future<http.Response?> _retryRequest(
    Future<http.Response> Function() request, {
    int maxAttempts = maxRetries,
  }) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await request().timeout(const Duration(seconds: defaultTimeout));
      } catch (e) {
        if (attempt == maxAttempts) {
          // print('[ApiService] Lỗi sau $maxAttempts lần thử: $e');
          return null;
        }
        
        // Exponential backoff: 1s, 2s, 4s
        final delayMs = (1000 * (attempt)).toInt();
        // print('[ApiService] Lần thử $attempt thất bại, chờ ${delayMs}ms...');
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
    return null;
  }

  // 1a. Đăng nhập
  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final baseUrl = await getBaseUrl();
      final url = Uri.parse('$baseUrl/api/auth/login');

      final response = await _retryRequest(() => http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      ));

      if (response == null) {
        return {'success': false, 'message': 'Không thể kết nối máy chủ sau $maxRetries lần thử'};
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveAuth(data['token'] ?? data['accessToken'] ?? '', data['user'] ?? {'username': username});
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'message': error['error'] ?? 'Đăng nhập thất bại (${response.statusCode})'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi đăng nhập: $e'};
    }
  }

  // 1b. Lấy thông tin người dùng hiện tại
  static Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final baseUrl = await getBaseUrl();
      final token = await getToken();
      final url = Uri.parse('$baseUrl/api/auth/me');

      final response = await _retryRequest(() => http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer ***',
        },
      ));

      if (response == null) {
        return {'success': false, 'message': 'Không thể lấy thông tin người dùng'};
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'user': data['user']};
      }
      return {'success': false, 'message': 'Không thể lấy thông tin người dùng (${response.statusCode})'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  // 1c. Đổi mật khẩu
  static Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    try {
      final baseUrl = await getBaseUrl();
      final token = await getToken();
      final url = Uri.parse('$baseUrl/api/auth/change-password');

      final response = await _retryRequest(() => http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer ***',
        },
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      ));

      if (response == null) {
        return {'success': false, 'message': 'Không thể kết nối máy chủ'};
      }

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Đổi mật khẩu thành công'};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Đổi mật khẩu thất bại'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối máy chủ ($e)'};
    }
  }

  // 2. Tra cứu thông tin máy tính (Device Check & QR Lookup)
  static Future<Map<String, dynamic>> getDeviceInfo(String query) async {
    try {
      final baseUrl = await getBaseUrl();
      final token = await getToken();
      
      final lookupUrl = Uri.parse('$baseUrl/api/qr/lookup?tag=${Uri.encodeComponent(query)}');
      final lookupRes = await _retryRequest(() => http.get(
        lookupUrl,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer ***',
        },
      ));

      if (lookupRes != null && lookupRes.statusCode == 200) {
        final lookupData = jsonDecode(lookupRes.body);
        if (lookupData['found'] == true && lookupData['device'] != null) {
          return {'success': true, 'device': lookupData['device']};
        }
      }

      final url = Uri.parse('$baseUrl/api/devices');
      final response = await _retryRequest(() => http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer ***',
        },
      ));

      if (response == null) {
        return {'success': false, 'message': 'Lỗi kết nối tra cứu'};
      }

      if (response.statusCode == 200) {
        final List<dynamic> devices = jsonDecode(response.body);
        final cleanQuery = query.trim().toLowerCase();

        final matched = devices.firstWhere(
          (d) =>
              (d['device_id']?.toString().toLowerCase() == cleanQuery) ||
              (d['hostname']?.toString().toLowerCase() == cleanQuery) ||
              (d['asset_tag']?.toString().toLowerCase() == cleanQuery) ||
              (d['ipv4']?.toString() == cleanQuery),
          orElse: () => null,
        );

        if (matched != null) {
          return {'success': true, 'device': matched};
        }
        return {'success': false, 'message': 'Không tìm thấy thiết bị khớp với mã: $query'};
      }
      return {'success': false, 'message': 'Lỗi máy chủ (${response.statusCode})'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối tra cứu: $e'};
    }
  }

  // 3. Lấy toàn bộ danh sách phiếu kiểm kê
  static Future<Map<String, dynamic>> getAllAuditTickets() async {
    try {
      final baseUrl = await getBaseUrl();
      final token = await getToken();
      final url = Uri.parse('$baseUrl/api/audit/tickets');

      final response = await _retryRequest(() => http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer ***',
        },
      ));

      if (response == null) return {'success': false, 'tickets': []};

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'tickets': data['tickets'] ?? []};
      }
      return {'success': false, 'tickets': []};
    } catch (e) {
      // print('[ApiService] Lỗi getAllAuditTickets: $e');
      return {'success': false, 'tickets': []};
    }
  }

  // 3b. Alias cho getApprovedAuditTickets
  static Future<Map<String, dynamic>> getApprovedAuditTickets() async {
    return getAllAuditTickets();
  }

  // 4. Lấy chi tiết phiếu kiểm kê
  static Future<Map<String, dynamic>?> getAuditTicketDetail(dynamic ticketId) async {
    try {
      final baseUrl = await getBaseUrl();
      final token = await getToken();
      final url = Uri.parse('$baseUrl/api/audit/tickets/$ticketId');

      final response = await _retryRequest(() => http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer ***',
        },
      ));

      if (response == null) return null;

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      // print('[ApiService] Lỗi getAuditTicketDetail: $e');
      return null;
    }
  }

  // 5. Gửi mã quét kiểm kê Asset Tag
  static Future<Map<String, dynamic>> scanAssetTag({
    required dynamic ticketId,
    required String assetTag,
    required String scannedBy,
    String? note,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final token = await getToken();
      final url = Uri.parse('$baseUrl/api/audit/tickets/$ticketId/scan');

      final response = await _retryRequest(() => http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer ***',
        },
        body: jsonEncode({
          'asset_tag': assetTag,
          'scanned_by': scannedBy,
          'scan_note': note ?? 'Quét từ Mobile App Flutter',
        }),
      ));

      if (response == null) {
        return {'success': false, 'message': 'Không thể kết nối máy chủ'};
      }

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Quét thất bại'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối ghi nhận kiểm kê: $e'};
    }
  }

  // 6. Tạo đợt kiểm kê mới từ App
  static Future<Map<String, dynamic>> createAuditTicket({
    required String title,
    String department = 'Tất cả',
    String createdBy = 'Admin',
    String notes = '',
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final token = await getToken();
      final url = Uri.parse('$baseUrl/api/audit/tickets');

      final response = await _retryRequest(() => http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer ***',
        },
        body: jsonEncode({
          'title': title,
          'department': department,
          'created_by': createdBy,
          'notes': notes,
        }),
      ));

      if (response == null) {
        return {'success': false, 'message': 'Không thể kết nối máy chủ'};
      }

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Tạo phiếu thất bại'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối tạo phiếu: $e'};
    }
  }

  // 7. Lấy thống kê phiếu
  static Future<Map<String, dynamic>> getAuditStats() async {
    try {
      final baseUrl = await getBaseUrl();
      final token = await getToken();
      final url = Uri.parse('$baseUrl/api/audit/stats');

      final response = await _retryRequest(() => http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer ***',
        },
      ));

      if (response == null) {
        return {
          'total_tickets': 0,
          'in_progress': 0,
          'completed': 0,
          'total_assets': 0,
          'scanned_assets': 0,
        };
      }

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {
        'total_tickets': 0,
        'in_progress': 0,
        'completed': 0,
        'total_assets': 0,
        'scanned_assets': 0,
      };
    } catch (e) {
      // print('[ApiService] Lỗi getAuditStats: $e');
      return {
        'total_tickets': 0,
        'in_progress': 0,
        'completed': 0,
        'total_assets': 0,
        'scanned_assets': 0,
      };
    }
  }

  // 8. Lấy danh sách items của phiếu
  static Future<Map<String, dynamic>> getTicketItems(String ticketId) async {
    try {
      final detail = await getAuditTicketDetail(ticketId);
      if (detail != null) {
        return {
          'success': true,
          'items': detail['items'] ?? [],
        };
      }
      return {'success': false, 'items': []};
    } catch (e) {
      // print('[ApiService] Lỗi getTicketItems: $e');
      return {'success': false, 'items': []};
    }
  }

  // 9. Upload ticket offline
  static Future<Map<String, dynamic>> uploadTicket(String ticketId, String items) async {
    try {
      final baseUrl = await getBaseUrl();
      final token = await getToken();
      final url = Uri.parse('$baseUrl/api/audit/tickets/$ticketId/sync');

      final response = await _retryRequest(() => http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer ***',
        },
        body: jsonEncode({'items': items}),
      ));

      if (response == null) {
        return {'success': false, 'message': 'Không thể kết nối máy chủ'};
      }

      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {'success': false, 'message': 'Upload thất bại (${response.statusCode})'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi upload: $e'};
    }
  }

  // 10. Upload scan history
  static Future<Map<String, dynamic>> uploadScan(String assetTag, String scannedAt) async {
    try {
      final baseUrl = await getBaseUrl();
      final token = await getToken();
      final url = Uri.parse('$baseUrl/api/scans/upload');

      final response = await _retryRequest(() => http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer ***',
        },
        body: jsonEncode({
          'asset_tag': assetTag,
          'scanned_at': scannedAt,
        }),
      ));

      if (response == null) {
        return {'success': false};
      }

      return {'success': response.statusCode == 200};
    } catch (e) {
      return {'success': false};
    }
  }

  // 11. Upload device
  static Future<Map<String, dynamic>> uploadDevice(String assetTag, String hostname, String scannedAt) async {
    try {
      final baseUrl = await getBaseUrl();
      final token = await getToken();
      final url = Uri.parse('$baseUrl/api/devices/upload');

      final response = await _retryRequest(() => http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer ***',
        },
        body: jsonEncode({
          'asset_tag': assetTag,
          'hostname': hostname,
          'scanned_at': scannedAt,
        }),
      ));

      if (response == null) {
        return {'success': false};
      }

      return {'success': response.statusCode == 200};
    } catch (e) {
      return {'success': false};
    }
  }

  // ── IT Inventory Tickets API ──
  static Future<Map<String, dynamic>> getItInventoryTickets({String? status, String? department, String? search}) async {
    try {
      final baseUrl = await getBaseUrl();
      final token = await getToken();
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (department != null && department.isNotEmpty) queryParams['department'] = department;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final url = Uri.parse('$baseUrl/api/it-inventory/tickets').replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await _retryRequest(() => http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ));

      if (response == null) {
        return {'success': false, 'message': 'Không thể kết nối máy chủ'};
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'tickets': data['tickets'] ?? []};
      }
      return {'success': false, 'message': 'Lỗi từ máy chủ (${response.statusCode})'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi: $e'};
    }
  }

  static Future<Map<String, dynamic>> createItInventoryTicket({
    required String title,
    String? department,
    String? deviceType,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final token = await getToken();
      final url = Uri.parse('$baseUrl/api/it-inventory/tickets');

      final response = await _retryRequest(() => http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'title': title,
          if (department != null) 'department': department,
          if (deviceType != null) 'device_type': deviceType,
        }),
      ));

      if (response == null) {
        return {'success': false, 'message': 'Không thể kết nối máy chủ'};
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'ticketId': data['ticketId'],
          'ticketCode': data['ticketCode'],
          'totalItems': data['totalItems'],
          'message': data['message'],
        };
      }
      final errData = jsonDecode(response.body);
      return {'success': false, 'message': errData['error'] ?? 'Tạo phiếu thất bại'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi: $e'};
    }
  }

  static Future<Map<String, dynamic>> getItInventoryTicketDetail(String ticketId) async {
    try {
      final baseUrl = await getBaseUrl();
      final token = await getToken();
      final url = Uri.parse('$baseUrl/api/it-inventory/tickets/$ticketId');

      final response = await _retryRequest(() => http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ));

      if (response == null) {
        return {'success': false, 'message': 'Không thể kết nối máy chủ'};
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'ticket': data['ticket']};
      }
      return {'success': false, 'message': 'Không tìm thấy phiếu kiểm kê'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi: $e'};
    }
  }

  static Future<Map<String, dynamic>> scanItInventoryItem({
    required String ticketId,
    String? assetCode,
    String? serialNumber,
    String? qrPayload,
    int? itDeviceId,
    String? notes,
    String? scannedLocation,
    String? status,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final token = await getToken();
      final url = Uri.parse('$baseUrl/api/it-inventory/tickets/$ticketId/scan');

      final response = await _retryRequest(() => http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          if (assetCode != null) 'asset_code': assetCode,
          if (serialNumber != null) 'serial_number': serialNumber,
          if (qrPayload != null) 'qr_payload': qrPayload,
          if (itDeviceId != null) 'it_device_id': itDeviceId,
          if (notes != null) 'notes': notes,
          if (scannedLocation != null) 'scanned_location': scannedLocation,
          if (status != null) 'status': status,
        }),
      ));

      if (response == null) {
        return {'success': false, 'message': 'Không thể kết nối máy chủ'};
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }
      final errData = jsonDecode(response.body);
      return {'success': false, 'message': errData['message'] ?? 'Quét thất bại'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateItInventoryTicketStatus({
    required String ticketId,
    required String status,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final token = await getToken();
      final url = Uri.parse('$baseUrl/api/it-inventory/tickets/$ticketId/status');

      final response = await _retryRequest(() => http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': status}),
      ));

      if (response == null) {
        return {'success': false, 'message': 'Không thể kết nối máy chủ'};
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'message': data['message'], 'ticket': data['ticket']};
      }
      final errData = jsonDecode(response.body);
      return {'success': false, 'message': errData['error'] ?? 'Cập nhật thất bại'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi: $e'};
    }
  }
}
