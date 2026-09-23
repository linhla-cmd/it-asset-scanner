import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  static SyncService get instance => _instance;

  SyncService._internal();

  // Sync intervals (in minutes)
  static const int _syncInterval = 15; // 15 minutes
  static const int _syncRetryInterval = 5; // 5 minutes

  // Last sync timestamps
  DateTime? _lastFullSync;
  DateTime? _lastPartialSync;

  // Connectivity status
  bool _isOnline = false;

  // Sync status
  bool _isSyncing = false;
  int _syncProgress = 0;
  int _syncTotal = 0;

  // Initialize sync service
  Future<void> initialize() async {
    await _checkConnectivity();
    await _loadLastSyncTimestamps();
    _startSyncTimer();
  }

  // Check connectivity
  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    _isOnline = connectivityResult != ConnectivityResult.none;
  }

  // Load last sync timestamps
  Future<void> _loadLastSyncTimestamps() async {
    final prefs = await SharedPreferences.getInstance();
    final fullSync = prefs.getString('last_full_sync');
    final partialSync = prefs.getString('last_partial_sync');

    if (fullSync != null) _lastFullSync = DateTime.parse(fullSync);
    if (partialSync != null) _lastPartialSync = DateTime.parse(partialSync);
  }

  // Save last sync timestamps
  Future<void> _saveLastSyncTimestamps() async {
    final prefs = await SharedPreferences.getInstance();
    if (_lastFullSync != null) {
      await prefs.setString('last_full_sync', _lastFullSync!.toIso8601String());
    }
    if (_lastPartialSync != null) {
      await prefs.setString('last_partial_sync', _lastPartialSync!.toIso8601String());
    }
  }

  // Start sync timer
  void _startSyncTimer() {
    // Check connectivity every minute
    Connectivity().onConnectivityChanged.listen((result) async {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;

      if (_isOnline && !wasOnline) {
        // Just came online - perform sync
        await _performSync();
      }
    });

    // Schedule periodic sync
    Future.delayed(const Duration(minutes: _syncInterval), () async {
      if (_isOnline) {
        await _performSync();
      }
      _startSyncTimer();
    });
  }

  // Perform sync operation
  Future<void> _performSync() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _syncProgress = 0;
    _syncTotal = 0;

    try {
      // 1. Sync tickets
      await _syncTickets();

      // 2. Sync scan history
      await _syncScanHistory();

      // 3. Sync device inventory
      await _syncDeviceInventory();

      // Update last sync timestamp
      _lastFullSync = DateTime.now();
      await _saveLastSyncTimestamps();
    } catch (e) {
      // print('Sync error: $e');
      // Schedule retry
      Future.delayed(const Duration(minutes: _syncRetryInterval), _performSync);
    } finally {
      _isSyncing = false;
    }
  }

  // Sync tickets
  Future<void> _syncTickets() async {
    final db = await DatabaseService.instance.database;

    // Get all offline tickets
    final offlineTickets = await db.query(
      'tickets_offline',
      where: 'status = ?',
      whereArgs: ['IN_PROGRESS'],
    );

    _syncTotal += offlineTickets.length;

    for (final ticket in offlineTickets) {
      try {
        // Upload ticket to server
        final response = await ApiService.uploadTicket(
          ticket['ticket_id'] as String,
          ticket['items'] as String,
        );

        if (response['success'] == true) {
          // Mark as synced
          await db.update(
            'tickets_offline',
            {'status': 'SYNCED'},
            where: 'ticket_id = ?',
            whereArgs: [ticket['ticket_id']],
          );
        }
      } catch (e) {
        // print('Failed to sync ticket ${ticket['ticket_id']}: $e');
      }

      _syncProgress++;
    }
  }

  // Sync scan history
  Future<void> _syncScanHistory() async {
    final db = await DatabaseService.instance.database;

    // Get unsynced scan history
    final unsyncedScans = await db.query(
      'scan_history',
      where: 'synced_at IS NULL',
    );

    _syncTotal += unsyncedScans.length;

    for (final scan in unsyncedScans) {
      try {
        // Upload scan to server
        final response = await ApiService.uploadScan(
          scan['asset_tag'] as String,
          scan['scanned_at'] as String,
        );

        if (response['success'] == true) {
          // Mark as synced
          await db.update(
            'scan_history',
            {'synced_at': DateTime.now().toIso8601String()},
            where: 'id = ?',
            whereArgs: [scan['id']],
          );
        }
      } catch (e) {
        // print('Failed to sync scan ${scan['asset_tag']}: $e');
      }

      _syncProgress++;
    }
  }

  // Sync device inventory
  Future<void> _syncDeviceInventory() async {
    final db = await DatabaseService.instance.database;

    // Get unsynced devices
    final unsyncedDevices = await db.query(
      'devices',
      where: 'synced_at IS NULL',
    );

    _syncTotal += unsyncedDevices.length;

    for (final device in unsyncedDevices) {
      try {
        // Upload device to server
        final response = await ApiService.uploadDevice(
          device['asset_tag'] as String,
          device['hostname'] as String,
          device['scanned_at'] as String,
        );

        if (response['success'] == true) {
          // Mark as synced
          await db.update(
            'devices',
            {'synced_at': DateTime.now().toIso8601String()},
            where: 'asset_tag = ?',
            whereArgs: [device['asset_tag']],
          );
        }
      } catch (e) {
        // print('Failed to sync device ${device['asset_tag']}: $e');
      }

      _syncProgress++;
    }
  }

  // Get sync status
  Map<String, dynamic> getSyncStatus() {
    return {
      'isOnline': _isOnline,
      'isSyncing': _isSyncing,
      'progress': _syncProgress,
      'total': _syncTotal,
      'lastFullSync': _lastFullSync?.toIso8601String(),
      'lastPartialSync': _lastPartialSync?.toIso8601String(),
    };
  }

  // Force sync
  Future<void> forceSync() async {
    if (_isOnline) {
      await _performSync();
    }
  }
}
