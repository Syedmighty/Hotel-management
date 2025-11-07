import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:udp/udp.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../db/app_database.dart';
import 'error_service.dart';

/// Server information discovered via UDP
class ServerInfo {
  final String serverIP;
  final int port;
  final String name;
  final String version;
  final DateTime timestamp;

  ServerInfo({
    required this.serverIP,
    required this.port,
    required this.name,
    required this.version,
    required this.timestamp,
  });

  factory ServerInfo.fromJson(Map<String, dynamic> json) {
    return ServerInfo(
      serverIP: json['serverIP'] as String,
      port: json['port'] as int,
      name: json['name'] as String,
      version: json['version'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  String get baseUrl => 'http://$serverIP:$port';
}

/// Sync status
enum SyncStatus {
  idle,
  discovering,
  connected,
  syncing,
  conflict,
  error,
}

/// Service for multi-device synchronization
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  // Constants
  static const int discoveryPort = 9999;
  static const Duration discoveryTimeout = Duration(seconds: 10);
  static const Duration syncInterval = Duration(minutes: 2);
  static const int maxRecordsPerSync = 200;

  // State
  ServerInfo? _serverInfo;
  String? _deviceUuid;
  String? _deviceName;
  Timer? _syncTimer;
  Timer? _discoveryTimer;
  UDP? _udpReceiver;
  SyncStatus _status = SyncStatus.idle;
  DateTime? _lastSyncTime;
  bool _isDiscovering = false;

  // Getters
  ServerInfo? get serverInfo => _serverInfo;
  SyncStatus get status => _status;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isConnected => _serverInfo != null;
  bool get isDiscovering => _isDiscovering;

  // Stream controllers
  final _statusController = StreamController<SyncStatus>.broadcast();
  final _serverInfoController = StreamController<ServerInfo?>.broadcast();

  Stream<SyncStatus> get statusStream => _statusController.stream;
  Stream<ServerInfo?> get serverInfoStream => _serverInfoController.stream;

  /// Initialize the sync service
  Future<void> initialize(AppDatabase database) async {
    try {
      ErrorService().logInfo('Initializing SyncService');

      // Get or create device UUID
      await _initializeDeviceInfo();

      // Start UDP discovery
      await startDiscovery();

      // Start periodic sync (every 2 minutes)
      _syncTimer?.cancel();
      _syncTimer = Timer.periodic(syncInterval, (_) async {
        if (isConnected) {
          await syncAll(database);
        }
      });

      ErrorService().logInfo('SyncService initialized successfully', data: {
        'deviceUuid': _deviceUuid,
        'deviceName': _deviceName,
      });
    } catch (e, stackTrace) {
      ErrorService().logError(
        e,
        stackTrace: stackTrace,
        context: 'SyncService Initialization',
      );
    }
  }

  /// Initialize device information
  Future<void> _initializeDeviceInfo() async {
    final prefs = await SharedPreferences.getInstance();

    // Get or create device UUID
    _deviceUuid = prefs.getString('device_uuid');
    if (_deviceUuid == null) {
      _deviceUuid = const Uuid().v4();
      await prefs.setString('device_uuid', _deviceUuid!);
    }

    // Get device name
    _deviceName = await _getDeviceName();
    await prefs.setString('device_name', _deviceName!);
  }

  /// Get device name based on platform
  Future<String> _getDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return '${iosInfo.name} (${iosInfo.model})';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        return windowsInfo.computerName;
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        return macInfo.computerName;
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        return linuxInfo.name;
      }
    } catch (e) {
      ErrorService().logWarning('Error getting device name: $e');
    }

    return 'Unknown Device';
  }

  /// Start UDP discovery to find the server
  Future<void> startDiscovery() async {
    if (_isDiscovering) {
      ErrorService().logWarning('Discovery already in progress');
      return;
    }

    try {
      _isDiscovering = true;
      _updateStatus(SyncStatus.discovering);

      ErrorService().logInfo('Starting UDP discovery on port $discoveryPort');

      // Create UDP receiver
      _udpReceiver = await UDP.bind(Endpoint.any(port: Port(discoveryPort)));

      // Listen for broadcasts
      _udpReceiver!.asStream().listen((datagram) {
        if (datagram != null) {
          try {
            final message = String.fromCharCodes(datagram.data);
            final json = jsonDecode(message) as Map<String, dynamic>;

            final server = ServerInfo.fromJson(json);
            _onServerDiscovered(server);
          } catch (e) {
            ErrorService().logDebug('Invalid UDP message: $e');
          }
        }
      });

      ErrorService().logInfo('UDP discovery started successfully');

      // Set a timeout for discovery
      Future.delayed(discoveryTimeout, () {
        if (_serverInfo == null && _isDiscovering) {
          ErrorService().logWarning('Server discovery timeout');
          _updateStatus(SyncStatus.idle);
        }
      });
    } catch (e, stackTrace) {
      _isDiscovering = false;
      ErrorService().logError(
        e,
        stackTrace: stackTrace,
        context: 'UDP Discovery Start',
      );
      _updateStatus(SyncStatus.error);
    }
  }

  /// Stop UDP discovery
  Future<void> stopDiscovery() async {
    _isDiscovering = false;
    await _udpReceiver?.close();
    _udpReceiver = null;
    ErrorService().logInfo('UDP discovery stopped');
  }

  /// Handle server discovery
  void _onServerDiscovered(ServerInfo server) {
    if (_serverInfo?.serverIP != server.serverIP ||
        _serverInfo?.port != server.port) {
      ErrorService().logInfo('Server discovered', data: {
        'serverIP': server.serverIP,
        'port': server.port,
        'name': server.name,
      });

      _serverInfo = server;
      _serverInfoController.add(server);
      _updateStatus(SyncStatus.connected);

      // Register device with server
      _registerDevice();
    }
  }

  /// Register this device with the server
  Future<void> _registerDevice() async {
    if (_serverInfo == null || _deviceUuid == null) return;

    try {
      final url = '${_serverInfo!.baseUrl}/devices/register';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uuid': _deviceUuid,
          'name': _deviceName,
          'role': 'client',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        ErrorService().logInfo('Device registered successfully', data: data);
      } else {
        throw Exception('Registration failed: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      ErrorService().logError(
        e,
        stackTrace: stackTrace,
        context: 'Device Registration',
      );
    }
  }

  /// Sync all data with the server
  Future<bool> syncAll(AppDatabase database) async {
    if (_serverInfo == null) {
      ErrorService().logWarning('Cannot sync: Server not discovered');
      return false;
    }

    if (_status == SyncStatus.syncing) {
      ErrorService().logWarning('Sync already in progress');
      return false;
    }

    try {
      _updateStatus(SyncStatus.syncing);
      ErrorService().logInfo('Starting full sync');

      // Step 1: Push local changes
      final pushSuccess = await _pushLocalChanges(database);
      if (!pushSuccess) {
        ErrorService().logWarning('Push failed, aborting sync');
        _updateStatus(SyncStatus.error);
        return false;
      }

      // Step 2: Pull server changes
      final pullSuccess = await _pullServerChanges(database);
      if (!pullSuccess) {
        ErrorService().logWarning('Pull failed');
        _updateStatus(SyncStatus.error);
        return false;
      }

      _lastSyncTime = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_time', _lastSyncTime!.toIso8601String());

      _updateStatus(SyncStatus.connected);
      ErrorService().logInfo('Sync completed successfully');
      return true;
    } catch (e, stackTrace) {
      ErrorService().logError(
        e,
        stackTrace: stackTrace,
        context: 'Sync All',
      );
      _updateStatus(SyncStatus.error);
      return false;
    }
  }

  /// Push local changes to server
  Future<bool> _pushLocalChanges(AppDatabase database) async {
    try {
      ErrorService().logInfo('Pushing local changes to server');

      // Get all tables to sync
      final tables = [
        'stock_items',
        'suppliers',
        'purchases',
        'purchase_items',
        'issues',
        'issue_items',
      ];

      final data = <String, List<Map<String, dynamic>>>{};

      // Collect unsynced records from each table
      for (final tableName in tables) {
        try {
          final records = await _getUnsyncedRecords(database, tableName);
          if (records.isNotEmpty) {
            data[tableName] = records;
            ErrorService().logDebug('Found ${records.length} unsynced records in $tableName');
          }
        } catch (e) {
          ErrorService().logError(e, context: 'Collecting unsynced records from $tableName');
        }
      }

      if (data.isEmpty) {
        ErrorService().logInfo('No local changes to push');
        return true;
      }

      // Push to server
      final url = '${_serverInfo!.baseUrl}/sync/push';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'deviceUuid': _deviceUuid,
          'data': data,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        final processed = result['processed'] as Map<String, dynamic>;
        final conflicts = result['conflicts'] as List<dynamic>? ?? [];

        ErrorService().logInfo('Push completed', data: processed);

        if (conflicts.isNotEmpty) {
          ErrorService().logWarning('${conflicts.length} conflicts detected');
          _updateStatus(SyncStatus.conflict);
          // Store conflicts for user resolution
          await _storeConflicts(database, conflicts);
        }

        // Mark pushed records as synced
        await _markRecordsAsSynced(database, data);

        return true;
      } else {
        throw Exception('Push failed: ${response.statusCode} ${response.body}');
      }
    } catch (e, stackTrace) {
      ErrorService().logError(
        e,
        stackTrace: stackTrace,
        context: 'Push Local Changes',
      );
      return false;
    }
  }

  /// Pull server changes
  Future<bool> _pullServerChanges(AppDatabase database) async {
    try {
      ErrorService().logInfo('Pulling server changes');

      // Get last sync time
      final prefs = await SharedPreferences.getInstance();
      final lastSyncStr = prefs.getString('last_sync_time');
      final since = lastSyncStr != null
          ? DateTime.parse(lastSyncStr).toIso8601String()
          : DateTime(2020, 1, 1).toIso8601String();

      // Request updated records
      final url = '${_serverInfo!.baseUrl}/sync/pull';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'deviceUuid': _deviceUuid,
          'tables': [
            'stock_items',
            'suppliers',
            'purchases',
            'purchase_items',
            'issues',
            'issue_items',
          ],
          'since': since,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        final data = result['data'] as Map<String, dynamic>;
        final totalRecords = result['totalRecords'] as int;

        ErrorService().logInfo('Received $totalRecords records from server');

        // Apply server changes to local database
        await _applyServerChanges(database, data);

        return true;
      } else {
        throw Exception('Pull failed: ${response.statusCode} ${response.body}');
      }
    } catch (e, stackTrace) {
      ErrorService().logError(
        e,
        stackTrace: stackTrace,
        context: 'Pull Server Changes',
      );
      return false;
    }
  }

  /// Get unsynced records from a table
  Future<List<Map<String, dynamic>>> _getUnsyncedRecords(
    AppDatabase database,
    String tableName,
  ) async {
    try {
      switch (tableName) {
        case 'stock_items':
          // Access ProductDao from the database instance
          final products = await database.productDao.getUnsyncedProducts();
          return products.map((p) => p.toJson()).toList();

        case 'suppliers':
          final suppliers = await database.supplierDao.getUnsyncedSuppliers();
          return suppliers.map((s) => s.toJson()).toList();

        case 'purchases':
          final purchases = await database.purchaseDao.getUnsyncedPurchases();
          return purchases.map((p) => p.toJson()).toList();

        case 'purchase_items':
          // Get all purchase line items for unsynced purchases
          final purchases = await database.purchaseDao.getUnsyncedPurchases();
          final List<Map<String, dynamic>> allLineItems = [];
          for (final purchase in purchases) {
            final lineItems = await database.purchaseDao.getPurchaseLineItems(purchase.uuid);
            allLineItems.addAll(lineItems.map((li) => li.toJson()));
          }
          return allLineItems;

        case 'issues':
          final issues = await database.issueDao.getUnsyncedIssues();
          return issues.map((i) => i.toJson()).toList();

        case 'issue_items':
          // Get all issue line items for unsynced issues
          final issues = await database.issueDao.getUnsyncedIssues();
          final List<Map<String, dynamic>> allLineItems = [];
          for (final issue in issues) {
            final lineItems = await database.issueDao.getIssueLineItems(issue.uuid);
            allLineItems.addAll(lineItems.map((li) => li.toJson()));
          }
          return allLineItems;

        default:
          ErrorService().logWarning('Unknown table for sync: $tableName');
          return [];
      }
    } catch (e, stackTrace) {
      ErrorService().logError(e, stackTrace: stackTrace, context: 'Getting unsynced records from $tableName');
      return [];
    }
  }

  /// Apply server changes to local database
  Future<void> _applyServerChanges(
    AppDatabase database,
    Map<String, dynamic> data,
  ) async {
    try {
      for (final entry in data.entries) {
        final tableName = entry.key;
        final records = entry.value as List<dynamic>;

        ErrorService().logDebug('Applying ${records.length} records to $tableName');

        switch (tableName) {
          case 'stock_items':
            for (final record in records) {
              final productData = record as Map<String, dynamic>;
              final product = ProductsCompanion(
                uuid: Value(productData['uuid']),
                name: Value(productData['name']),
                category: Value(productData['category']),
                unit: Value(productData['unit']),
                unitConversion: Value(productData['unitConversion'] ?? 1.0),
                gstPercent: Value(productData['gstPercent'] ?? 0.0),
                purchaseRate: Value(productData['purchaseRate']),
                sellingRate: Value(productData['sellingRate']),
                openingStock: Value(productData['openingStock'] ?? 0.0),
                currentStock: Value(productData['currentStock'] ?? 0.0),
                reorderLevel: Value(productData['reorderLevel'] ?? 0.0),
                batchTracking: Value(productData['batchTracking'] ?? false),
                barcode: Value(productData['barcode']),
                expiryDate: productData['expiryDate'] != null
                    ? Value(DateTime.parse(productData['expiryDate']))
                    : const Value.absent(),
                lastModified: Value(DateTime.parse(productData['lastModified'])),
                isSynced: const Value(true),
                sourceDevice: Value(productData['sourceDevice']),
                isActive: Value(productData['isActive'] ?? true),
              );
              await database.productDao.upsertProductFromServer(product);
            }
            break;

          case 'suppliers':
            for (final record in records) {
              final supplierData = record as Map<String, dynamic>;
              final supplier = SuppliersCompanion(
                uuid: Value(supplierData['uuid']),
                name: Value(supplierData['name']),
                contact: Value(supplierData['contact']),
                gstin: Value(supplierData['gstin']),
                address: Value(supplierData['address']),
                balance: Value(supplierData['balance'] ?? 0.0),
                lastModified: Value(DateTime.parse(supplierData['lastModified'])),
                isSynced: const Value(true),
                sourceDevice: Value(supplierData['sourceDevice']),
                isActive: Value(supplierData['isActive'] ?? true),
              );
              await database.supplierDao.upsertSupplierFromServer(supplier);
            }
            break;

          case 'purchases':
            for (final record in records) {
              final purchaseData = record as Map<String, dynamic>;
              final purchase = PurchasesCompanion(
                uuid: Value(purchaseData['uuid']),
                supplierId: Value(purchaseData['supplierId']),
                invoiceNo: Value(purchaseData['invoiceNo']),
                purchaseDate: Value(DateTime.parse(purchaseData['purchaseDate'])),
                totalAmount: Value(purchaseData['totalAmount']),
                paymentMode: Value(purchaseData['paymentMode']),
                batchNo: Value(purchaseData['batchNo']),
                receivedBy: Value(purchaseData['receivedBy']),
                status: Value(purchaseData['status'] ?? 'Pending'),
                remarks: Value(purchaseData['remarks']),
                lastModified: Value(DateTime.parse(purchaseData['lastModified'])),
                isSynced: const Value(true),
                sourceDevice: Value(purchaseData['sourceDevice']),
              );
              await database.purchaseDao.upsertPurchaseFromServer(purchase);
            }
            break;

          case 'purchase_items':
            for (final record in records) {
              final lineItemData = record as Map<String, dynamic>;
              final lineItem = PurchaseLineItemsCompanion(
                id: lineItemData['id'] != null ? Value(lineItemData['id']) : const Value.absent(),
                purchaseId: Value(lineItemData['purchaseId']),
                productId: Value(lineItemData['productId']),
                quantity: Value(lineItemData['quantity']),
                rate: Value(lineItemData['rate']),
                gstPercent: Value(lineItemData['gstPercent']),
                batchNo: Value(lineItemData['batchNo']),
                expiryDate: lineItemData['expiryDate'] != null
                    ? Value(DateTime.parse(lineItemData['expiryDate']))
                    : const Value.absent(),
                amount: Value(lineItemData['amount']),
                gstAmount: Value(lineItemData['gstAmount']),
                totalAmount: Value(lineItemData['totalAmount']),
                lastModified: Value(DateTime.parse(lineItemData['lastModified'])),
              );
              await database.purchaseDao.upsertPurchaseLineItemFromServer(lineItem);
            }
            break;

          case 'issues':
            for (final record in records) {
              final issueData = record as Map<String, dynamic>;
              final issue = IssueVouchersCompanion(
                uuid: Value(issueData['uuid']),
                department: Value(issueData['department']),
                issuedBy: Value(issueData['issuedBy']),
                receivedBy: Value(issueData['receivedBy']),
                issueDate: Value(DateTime.parse(issueData['issueDate'])),
                approvalStatus: Value(issueData['approvalStatus'] ?? 'Pending'),
                remarks: Value(issueData['remarks']),
                lastModified: Value(DateTime.parse(issueData['lastModified'])),
                isSynced: const Value(true),
                sourceDevice: Value(issueData['sourceDevice']),
              );
              await database.issueDao.upsertIssueFromServer(issue);
            }
            break;

          case 'issue_items':
            for (final record in records) {
              final lineItemData = record as Map<String, dynamic>;
              final lineItem = IssueLineItemsCompanion(
                id: lineItemData['id'] != null ? Value(lineItemData['id']) : const Value.absent(),
                issueId: Value(lineItemData['issueId']),
                productId: Value(lineItemData['productId']),
                quantity: Value(lineItemData['quantity']),
                rate: Value(lineItemData['rate']),
                amount: Value(lineItemData['amount']),
                batchNo: Value(lineItemData['batchNo']),
                lastModified: Value(DateTime.parse(lineItemData['lastModified'])),
              );
              await database.issueDao.upsertIssueLineItemFromServer(lineItem);
            }
            break;

          default:
            ErrorService().logWarning('Unknown table for sync: $tableName');
        }
      }
    } catch (e, stackTrace) {
      ErrorService().logError(e, stackTrace: stackTrace, context: 'Applying server changes');
    }
  }

  /// Mark records as synced
  Future<void> _markRecordsAsSynced(
    AppDatabase database,
    Map<String, List<Map<String, dynamic>>> data,
  ) async {
    try {
      for (final entry in data.entries) {
        final tableName = entry.key;
        final records = entry.value;
        ErrorService().logDebug('Marking ${records.length} records as synced in $tableName');

        final uuids = records.map((r) => r['uuid'] as String).toList();

        switch (tableName) {
          case 'stock_items':
            await database.productDao.markProductsAsSynced(uuids);
            break;

          case 'suppliers':
            await database.supplierDao.markSuppliersAsSynced(uuids);
            break;

          case 'purchases':
            await database.purchaseDao.markPurchasesAsSynced(uuids);
            break;

          case 'issues':
            await database.issueDao.markIssuesAsSynced(uuids);
            break;

          default:
            ErrorService().logWarning('Unknown table for marking synced: $tableName');
        }
      }
    } catch (e, stackTrace) {
      ErrorService().logError(e, stackTrace: stackTrace, context: 'Marking records as synced');
    }
  }

  /// Store conflicts for user resolution
  Future<void> _storeConflicts(
    AppDatabase database,
    List<dynamic> conflicts,
  ) async {
    try {
      ErrorService().logInfo('Storing ${conflicts.length} conflicts');

      for (final conflict in conflicts) {
        final conflictData = conflict as Map<String, dynamic>;
        await database.syncDao.addConflict(
          tableName: conflictData['table'],
          recordId: conflictData['uuid'],
          clientData: jsonEncode(conflictData['deviceData'] ?? {}),
          serverData: jsonEncode(conflictData['serverData'] ?? {}),
        );
      }
    } catch (e, stackTrace) {
      ErrorService().logError(e, stackTrace: stackTrace, context: 'Storing conflicts');
    }
  }

  /// Update sync status
  void _updateStatus(SyncStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(newStatus);
    }
  }

  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _discoveryTimer?.cancel();
    stopDiscovery();
    _statusController.close();
    _serverInfoController.close();
  }
}
