import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'database_service.dart';

class InstantTicketService {
  static const String baseUrl = 'http://100.86.164.103:3000/api';
  
  /// Tạo phiếu kiểm kê nhanh trên server
  static Future<Map<String, dynamic>> createInstantTicket({
    required String title,
    required List<String> scannedDevices,
    String department = 'Tất cả',
    String notes = '',
    String createdBy = 'Mobile User',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/audit/tickets'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': title,
          'department': department,
          'notes': notes,
          'created_by': createdBy,
        }),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Lỗi tạo phiếu: ${response.body}');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối: $e');
    }
  }

  /// Quét QR - gọi API quét cho phiếu
  static Future<Map<String, dynamic>> scanQR({
    required String ticketId,
    required String assetTag,
    String scannedBy = 'Mobile User',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/audit/tickets/$ticketId/scan'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'asset_tag': assetTag,
          'scanned_by': scannedBy,
        }),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Lỗi quét QR: ${response.body}');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối: $e');
    }
  }

  /// Duyệt phiếu (hoàn tất kiểm kê)
  static Future<Map<String, dynamic>> approveTicket({
    required String ticketId,
    String notes = '',
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/audit/tickets/$ticketId/approve'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'notes': notes,
        }),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Lỗi duyệt phiếu: ${response.body}');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối: $e');
    }
  }

  /// Lưu phiếu draft vào SQLite (cho offline mode)
  static Future<void> saveDraftTicket({
    required String draftId,
    required String title,
    required List<String> scannedDevices,
    String department = 'Tất cả',
    String notes = '',
  }) async {
    try {
      final db = await DatabaseService.instance.database;
      
      await db.insert(
        'instant_ticket_drafts',
        {
          'draft_id': draftId,
          'title': title,
          'department': department,
          'scanned_devices': jsonEncode(scannedDevices),
          'notes': notes,
          'created_at': DateTime.now().toIso8601String(),
          'synced': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Lỗi lưu draft: $e');
    }
  }

  /// Lấy danh sách draft chưa sync
  static Future<List<Map<String, dynamic>>> getUnsyncedDrafts() async {
    try {
      final db = await DatabaseService.instance.database;
      return await db.query(
        'instant_ticket_drafts',
        where: 'synced = ?',
        whereArgs: [0],
      );
    } catch (e) {
      print('Lỗi lấy draft: $e');
      return [];
    }
  }

  /// Sync draft lên server
  static Future<bool> syncDraft(Map<String, dynamic> draft) async {
    try {
      final scannedDevices = jsonDecode(draft['scanned_devices'] as String) as List;
      
      final result = await createInstantTicket(
        title: draft['title'],
        scannedDevices: scannedDevices.cast<String>(),
        department: draft['department'] ?? 'Tất cả',
        notes: draft['notes'] ?? '',
      );

      if (result['success'] == true || result['ticket_id'] != null) {
        // Đánh dấu là đã sync
        final db = await DatabaseService.instance.database;
        await db.update(
          'instant_ticket_drafts',
          {'synced': 1},
          where: 'draft_id = ?',
          whereArgs: [draft['draft_id']],
        );
        return true;
      }
      return false;
    } catch (e) {
      print('Lỗi sync draft: $e');
      return false;
    }
  }

  /// Auto-sync khi có kết nối mạng
  static Future<void> autoSync() async {
    try {
      final unsyncedDrafts = await getUnsyncedDrafts();
      
      for (var draft in unsyncedDrafts) {
        await syncDraft(draft);
      }
    } catch (e) {
      print('Lỗi auto-sync: $e');
    }
  }
}
