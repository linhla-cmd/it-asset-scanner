import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'database_service.dart';

class TicketListService {
  static const String baseUrl = 'http://100.86.164.103:3000/api';

  /// Lấy danh sách phiếu kiểm kê từ server
  static Future<List<Map<String, dynamic>>> fetchTickets({String? status}) async {
    try {
      String url = '$baseUrl/audit/tickets';
      if (status != null) {
        url += '?status=$status';
      }

      final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tickets = (data['tickets'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        return tickets;
      } else {
        throw Exception('Lỗi lấy danh sách phiếu: ${response.body}');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối: $e');
    }
  }

  /// Lấy chi tiết phiếu + danh sách items
  static Future<Map<String, dynamic>> fetchTicketDetail(String ticketId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/audit/tickets/$ticketId'))
          .timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Lỗi lấy chi tiết phiếu: ${response.body}');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối: $e');
    }
  }

  /// Download phiếu + items vào SQLite (offline mode)
  static Future<void> downloadTicketOffline({
    required String ticketId,
    required Map<String, dynamic> ticketData,
    required List<dynamic> items,
  }) async {
    try {
      final db = await DatabaseService.instance.database;

      // Lưu phiếu
      await db.insert(
        'audit_tickets_offline',
        {
          'ticket_id': ticketId,
          'title': ticketData['title'],
          'department': ticketData['department'] ?? 'Tất cả',
          'total_items': ticketData['total_items'] ?? 0,
          'status': ticketData['status'] ?? 'IN_PROGRESS',
          'created_at': DateTime.now().toIso8601String(),
          'downloaded_at': DateTime.now().toIso8601String(),
          'synced': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Lưu items
      for (var item in items) {
        await db.insert(
          'audit_items_offline',
          {
            'ticket_id': ticketId,
            'asset_tag': (item['asset_tag'] ?? '').toString().toUpperCase(),
            'hostname': item['hostname'] ?? '',
            'expected_department': item['expected_department'] ?? '',
            'actual_status': item['actual_status'] ?? 'PENDING', // PENDING, MATCHED, MISSING, UNEXPECTED
            'scanned_at': null,
            'scanned_by': null,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      print('✅ Đã download phiếu $ticketId offline');
    } catch (e) {
      print('❌ Lỗi download offline: $e');
      throw e;
    }
  }

  /// Lấy danh sách phiếu offline
  static Future<List<Map<String, dynamic>>> getOfflineTickets() async {
    try {
      final db = await DatabaseService.instance.database;
      return await db.query('audit_tickets_offline', orderBy: 'downloaded_at DESC');
    } catch (e) {
      print('Lỗi lấy phiếu offline: $e');
      return [];
    }
  }

  /// Lấy danh sách items của phiếu offline
  static Future<List<Map<String, dynamic>>> getOfflineItems(String ticketId) async {
    try {
      final db = await DatabaseService.instance.database;
      return await db.query(
        'audit_items_offline',
        where: 'ticket_id = ?',
        whereArgs: [ticketId],
        orderBy: 'asset_tag ASC',
      );
    } catch (e) {
      print('Lỗi lấy items offline: $e');
      return [];
    }
  }

  /// Cập nhật trạng thái item sau quét (offline)
  static Future<void> updateItemStatusOffline({
    required String ticketId,
    required String assetTag,
    required String status, // MATCHED, UNEXPECTED, MISSING
    String? scannedBy,
  }) async {
    try {
      final db = await DatabaseService.instance.database;
      await db.update(
        'audit_items_offline',
        {
          'actual_status': status,
          'scanned_at': DateTime.now().toIso8601String(),
          'scanned_by': scannedBy ?? 'Mobile User',
        },
        where: 'ticket_id = ? AND asset_tag = ?',
        whereArgs: [ticketId, assetTag.toUpperCase()],
      );
    } catch (e) {
      print('Lỗi cập nhật item: $e');
    }
  }

  /// Thống kê tiến độ quét
  static Future<Map<String, int>> getTicketStats(String ticketId) async {
    try {
      final db = await DatabaseService.instance.database;

      final total = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM audit_items_offline WHERE ticket_id = ?',
        [ticketId],
      );

      final matched = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM audit_items_offline WHERE ticket_id = ? AND actual_status = "MATCHED"',
        [ticketId],
      );

      final unexpected = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM audit_items_offline WHERE ticket_id = ? AND actual_status = "UNEXPECTED"',
        [ticketId],
      );

      final missing = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM audit_items_offline WHERE ticket_id = ? AND actual_status = "MISSING"',
        [ticketId],
      );

      return {
        'total': (total[0]['cnt'] as int?) ?? 0,
        'matched': (matched[0]['cnt'] as int?) ?? 0,
        'unexpected': (unexpected[0]['cnt'] as int?) ?? 0,
        'missing': (missing[0]['cnt'] as int?) ?? 0,
      };
    } catch (e) {
      print('Lỗi thống kê: $e');
      return {'total': 0, 'matched': 0, 'unexpected': 0, 'missing': 0};
    }
  }

  /// Sync phiếu offline lên server
  static Future<bool> syncTicketOffline({
    required String ticketId,
    required Map<String, dynamic> ticketData,
  }) async {
    try {
      // Gọi API duyệt phiếu để hoàn tất
      final response = await http.put(
        Uri.parse('$baseUrl/audit/tickets/$ticketId/approve'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'notes': 'Synced from mobile'}),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        // Đánh dấu là đã sync
        final db = await DatabaseService.instance.database;
        await db.update(
          'audit_tickets_offline',
          {'synced': 1},
          where: 'ticket_id = ?',
          whereArgs: [ticketId],
        );
        print('✅ Đã sync phiếu $ticketId');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Lỗi sync: $e');
      return false;
    }
  }

  /// Auto-sync tất cả phiếu chưa sync
  static Future<void> autoSyncAllTickets() async {
    try {
      final db = await DatabaseService.instance.database;
      final unsyncedTickets = await db.query(
        'audit_tickets_offline',
        where: 'synced = ?',
        whereArgs: [0],
      );

      for (var ticket in unsyncedTickets) {
        await syncTicketOffline(
          ticketId: ticket['ticket_id'] as String,
          ticketData: ticket,
        );
      }
    } catch (e) {
      print('Lỗi auto-sync: $e');
    }
  }
}
