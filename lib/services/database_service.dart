import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('it_asset_scanner.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Bảng lưu phiếu kiểm kê theo phòng (Ticket-based)
    await db.execute('''
      CREATE TABLE audit_tickets_offline (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ticket_id TEXT UNIQUE NOT NULL,
        title TEXT NOT NULL,
        department TEXT,
        total_items INTEGER DEFAULT 0,
        status TEXT DEFAULT 'IN_PROGRESS',
        created_at TEXT NOT NULL,
        downloaded_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        synced_at TEXT
      )
    ''');

    // Bảng lưu chi tiết items của phiếu
    await db.execute('''
      CREATE TABLE audit_items_offline (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ticket_id TEXT NOT NULL,
        asset_tag TEXT NOT NULL,
        hostname TEXT,
        expected_department TEXT,
        actual_status TEXT DEFAULT 'PENDING',
        scanned_at TEXT,
        scanned_by TEXT,
        synced INTEGER DEFAULT 0,
        synced_at TEXT,
        UNIQUE(ticket_id, asset_tag),
        FOREIGN KEY(ticket_id) REFERENCES audit_tickets_offline(ticket_id)
      )
    ''');

    // Bảng lưu phiếu kiểm kê nhanh (instant - draft) offline
    await db.execute('''
      CREATE TABLE instant_ticket_drafts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        draft_id TEXT UNIQUE NOT NULL,
        title TEXT NOT NULL,
        department TEXT DEFAULT 'Tất cả',
        scanned_devices TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        server_ticket_id TEXT,
        synced_at TEXT
      )
    ''');

    // Bảng lưu các thiết bị đã quét (cache local)
    await db.execute('''
      CREATE TABLE scanned_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        draft_id TEXT NOT NULL,
        asset_tag TEXT NOT NULL,
        hostname TEXT,
        department TEXT,
        scanned_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        FOREIGN KEY(draft_id) REFERENCES instant_ticket_drafts(draft_id)
      )
    ''');

    // Bảng lưu trạng thái sync
    await db.execute('''
      CREATE TABLE sync_status (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        draft_id TEXT UNIQUE NOT NULL,
        last_sync_attempt TEXT,
        sync_status TEXT,
        error_message TEXT,
        retry_count INTEGER DEFAULT 0,
        last_error_at TEXT
      )
    ''');

    // Bảng lưu lịch sử quét (Scan History)
    await db.execute('''
      CREATE TABLE scan_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ticket_id TEXT,
        asset_tag TEXT NOT NULL,
        scan_result TEXT NOT NULL,
        scanned_at TEXT NOT NULL,
        scanned_by TEXT,
        notes TEXT
      )
    ''');

    // Bảng lưu cài đặt người dùng (User Settings)
    await db.execute('''
      CREATE TABLE user_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT UNIQUE NOT NULL,
        value TEXT,
        updated_at TEXT
      )
    ''');

    // Bảng thống kê (Statistics)
    await db.execute('''
      CREATE TABLE statistics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stat_type TEXT NOT NULL,
        value TEXT NOT NULL,
        recorded_at TEXT NOT NULL,
        UNIQUE(stat_type, recorded_at)
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Upgrade to version 2: add ticket-based tables
      await db.execute('''
        CREATE TABLE IF NOT EXISTS audit_tickets_offline (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ticket_id TEXT UNIQUE NOT NULL,
          title TEXT NOT NULL,
          department TEXT,
          total_items INTEGER DEFAULT 0,
          status TEXT DEFAULT 'IN_PROGRESS',
          created_at TEXT NOT NULL,
          downloaded_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS audit_items_offline (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ticket_id TEXT NOT NULL,
          asset_tag TEXT NOT NULL,
          hostname TEXT,
          expected_department TEXT,
          actual_status TEXT DEFAULT 'PENDING',
          scanned_at TEXT,
          scanned_by TEXT,
          UNIQUE(ticket_id, asset_tag),
          FOREIGN KEY(ticket_id) REFERENCES audit_tickets_offline(ticket_id)
        )
      ''');
    }

    if (oldVersion < 3) {
      // Upgrade to version 3: add tracking columns and new tables
      try {
        await db.execute('ALTER TABLE audit_tickets_offline ADD COLUMN synced_at TEXT');
      } catch (e) {
        // print('[DatabaseService] Column synced_at already exists');
      }

      try {
        await db.execute('ALTER TABLE audit_items_offline ADD COLUMN synced INTEGER DEFAULT 0');
      } catch (e) {
        // print('[DatabaseService] Column synced already exists in audit_items_offline');
      }

      try {
        await db.execute('ALTER TABLE audit_items_offline ADD COLUMN synced_at TEXT');
      } catch (e) {
        // print('[DatabaseService] Column synced_at already exists in audit_items_offline');
      }

      try {
        await db.execute('ALTER TABLE instant_ticket_drafts ADD COLUMN synced_at TEXT');
      } catch (e) {
        // print('[DatabaseService] Column synced_at already exists in instant_ticket_drafts');
      }

      try {
        await db.execute('ALTER TABLE scanned_history ADD COLUMN synced INTEGER DEFAULT 0');
      } catch (e) {
        // print('[DatabaseService] Column synced already exists in scanned_history');
      }

      try {
        await db.execute('ALTER TABLE sync_status ADD COLUMN last_error_at TEXT');
      } catch (e) {
        // print('[DatabaseService] Column last_error_at already exists');
      }

      // Create new tables
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS scan_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ticket_id TEXT,
            asset_tag TEXT NOT NULL,
            scan_result TEXT NOT NULL,
            scanned_at TEXT NOT NULL,
            scanned_by TEXT,
            notes TEXT
          )
        ''');
      } catch (e) {
        // print('[DatabaseService] scan_history table already exists');
      }

      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS user_settings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            key TEXT UNIQUE NOT NULL,
            value TEXT,
            updated_at TEXT
          )
        ''');
      } catch (e) {
        // print('[DatabaseService] user_settings table already exists');
      }

      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS statistics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            stat_type TEXT NOT NULL,
            value TEXT NOT NULL,
            recorded_at TEXT NOT NULL,
            UNIQUE(stat_type, recorded_at)
          )
        ''');
      } catch (e) {
        // print('[DatabaseService] statistics table already exists');
      }
    }
  }

  // Thêm scan vào lịch sử
  Future<void> addScanHistory(String ticketId, String assetTag, String status) async {
    final db = await database;
    await db.insert(
      'scan_history',
      {
        'ticket_id': ticketId,
        'asset_tag': assetTag,
        'scan_result': status,
        'scanned_at': DateTime.now().toIso8601String(),
        'scanned_by': 'mobile_app',
        'notes': null,
      },
    );
  }

  // Lấy lịch sử quét
  Future<List<Map<String, dynamic>>> getScanHistory({
    String? ticketId,
    int limit = 100,
  }) async {
    final db = await database;
    String query = 'SELECT * FROM scan_history';
    List<dynamic> args = [];

    if (ticketId != null) {
      query += ' WHERE ticket_id = ?';
      args.add(ticketId);
    }

    query += ' ORDER BY scanned_at DESC LIMIT ?';
    args.add(limit);

    return await db.rawQuery(query, args);
  }

  // Cài đặt người dùng
  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'user_settings',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final result = await db.query(
      'user_settings',
      where: 'key = ?',
      whereArgs: [key],
    );

    if (result.isNotEmpty) {
      return result.first['value'] as String?;
    }
    return null;
  }

  // Thêm thống kê
  Future<void> recordStatistic(String statType, String value) async {
    final db = await database;
    await db.insert(
      'statistics',
      {
        'stat_type': statType,
        'value': value,
        'recorded_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // Lấy thống kê
  Future<List<Map<String, dynamic>>> getStatistics({
    String? statType,
    int days = 30,
  }) async {
    final db = await database;
    final startDate = DateTime.now().subtract(Duration(days: days)).toIso8601String();

    String query = 'SELECT * FROM statistics WHERE recorded_at >= ?';
    List<dynamic> args = [startDate];

    if (statType != null) {
      query += ' AND stat_type = ?';
      args.add(statType);
    }

    query += ' ORDER BY recorded_at DESC';

    return await db.rawQuery(query, args);
  }

  // Đóng database
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
    }
  }
}
