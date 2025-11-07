import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_inventory_management/db/app_database.dart';
import 'package:hotel_inventory_management/services/sync_service.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';

/// Utility class for testing sync functionality
class SyncTestUtils {
  static const _uuid = Uuid();

  /// Generate test product data
  static ProductsCompanion generateTestProduct({
    String? uuid,
    String? name,
    double? currentStock,
    String? sourceDevice,
    bool isSynced = false,
  }) {
    return ProductsCompanion(
      uuid: Value(uuid ?? _uuid.v4()),
      name: Value(name ?? 'Test Product ${DateTime.now().millisecondsSinceEpoch}'),
      category: const Value('Test Category'),
      unit: const Value('kg'),
      unitConversion: const Value(1.0),
      gstPercent: const Value(18.0),
      purchaseRate: const Value(100.0),
      sellingRate: const Value(150.0),
      openingStock: const Value(0.0),
      currentStock: Value(currentStock ?? 50.0),
      reorderLevel: const Value(10.0),
      batchTracking: const Value(false),
      barcode: const Value.absent(),
      expiryDate: const Value.absent(),
      lastModified: Value(DateTime.now()),
      isSynced: Value(isSynced),
      sourceDevice: Value(sourceDevice ?? 'test-device'),
      isActive: const Value(true),
    );
  }

  /// Generate test supplier data
  static SuppliersCompanion generateTestSupplier({
    String? uuid,
    String? name,
    String? sourceDevice,
    bool isSynced = false,
  }) {
    return SuppliersCompanion(
      uuid: Value(uuid ?? _uuid.v4()),
      name: Value(name ?? 'Test Supplier ${DateTime.now().millisecondsSinceEpoch}'),
      contact: const Value('1234567890'),
      gstin: const Value('29ABCDE1234F1Z5'),
      address: const Value('Test Address'),
      balance: const Value(0.0),
      lastModified: Value(DateTime.now()),
      isSynced: Value(isSynced),
      sourceDevice: Value(sourceDevice ?? 'test-device'),
      isActive: const Value(true),
    );
  }

  /// Generate test purchase data
  static PurchasesCompanion generateTestPurchase({
    String? uuid,
    String? supplierId,
    String? sourceDevice,
    bool isSynced = false,
  }) {
    return PurchasesCompanion(
      uuid: Value(uuid ?? _uuid.v4()),
      supplierId: Value(supplierId ?? _uuid.v4()),
      invoiceNo: Value('INV-${DateTime.now().millisecondsSinceEpoch}'),
      purchaseDate: Value(DateTime.now()),
      totalAmount: const Value(1000.0),
      paymentMode: const Value('Cash'),
      batchNo: const Value.absent(),
      receivedBy: const Value('Test User'),
      status: const Value('Pending'),
      remarks: const Value.absent(),
      lastModified: Value(DateTime.now()),
      isSynced: Value(isSynced),
      sourceDevice: Value(sourceDevice ?? 'test-device'),
    );
  }

  /// Generate test issue voucher data
  static IssueVouchersCompanion generateTestIssue({
    String? uuid,
    String? sourceDevice,
    bool isSynced = false,
  }) {
    return IssueVouchersCompanion(
      uuid: Value(uuid ?? _uuid.v4()),
      department: const Value('Test Department'),
      issuedBy: const Value('Test User'),
      receivedBy: const Value('Test Receiver'),
      issueDate: Value(DateTime.now()),
      approvalStatus: const Value('Pending'),
      remarks: const Value.absent(),
      lastModified: Value(DateTime.now()),
      isSynced: Value(isSynced),
      sourceDevice: Value(sourceDevice ?? 'test-device'),
    );
  }

  /// Create multiple unsynced records for testing
  static Future<List<String>> createUnsyncedProducts(
    AppDatabase database,
    int count, {
    String? sourceDevice,
  }) async {
    final uuids = <String>[];

    for (int i = 0; i < count; i++) {
      final product = generateTestProduct(
        name: 'Unsynced Product $i',
        isSynced: false,
        sourceDevice: sourceDevice,
      );

      await database.productDao.createProduct(product);
      uuids.add(product.uuid.value);
    }

    return uuids;
  }

  /// Create a conflict scenario
  static Future<void> createConflictScenario(
    AppDatabase database,
    String recordId,
  ) async {
    // Create a conflict log entry
    await database.syncDao.addConflict(
      tableName: 'stock_items',
      recordId: recordId,
      clientData: jsonEncode({
        'uuid': recordId,
        'name': 'Device Version',
        'currentStock': 50.0,
        'lastModified': DateTime.now().toIso8601String(),
      }),
      serverData: jsonEncode({
        'uuid': recordId,
        'name': 'Server Version',
        'currentStock': 45.0,
        'lastModified': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
      }),
    );
  }

  /// Verify sync flag is set correctly
  static Future<bool> verifySyncFlag(
    AppDatabase database,
    String productUuid,
    bool expectedValue,
  ) async {
    final product = await database.productDao.getProductById(productUuid);
    return product?.isSynced == expectedValue;
  }

  /// Get unsynced records count
  static Future<int> getUnsyncedCount(AppDatabase database) async {
    final products = await database.productDao.getUnsyncedProducts();
    final suppliers = await database.supplierDao.getUnsyncedSuppliers();
    final purchases = await database.purchaseDao.getUnsyncedPurchases();
    final issues = await database.issueDao.getUnsyncedIssues();

    return products.length + suppliers.length + purchases.length + issues.length;
  }

  /// Clear all test data
  static Future<void> clearTestData(AppDatabase database) async {
    // Delete all test products (where name contains "Test")
    final allProducts = await database.productDao.getAllProducts();
    for (final product in allProducts) {
      if (product.name.contains('Test')) {
        await database.productDao.deleteProduct(product.uuid);
      }
    }

    // Delete all test suppliers
    final allSuppliers = await database.supplierDao.getAllSuppliers();
    for (final supplier in allSuppliers) {
      if (supplier.name.contains('Test')) {
        await database.supplierDao.deleteSupplier(supplier.uuid);
      }
    }

    // Clear sync queue
    await database.syncDao.clearSyncQueue();

    // Delete old resolved conflicts
    await database.syncDao.deleteOldResolvedConflicts(0);
  }

  /// Mock server response for testing
  static Map<String, dynamic> mockServerPullResponse({
    List<Map<String, dynamic>>? products,
    List<Map<String, dynamic>>? suppliers,
  }) {
    return {
      'success': true,
      'data': {
        'stock_items': products ?? [],
        'suppliers': suppliers ?? [],
        'purchases': [],
        'purchase_items': [],
        'issues': [],
        'issue_items': [],
      },
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Mock server push response
  static Map<String, dynamic> mockServerPushResponse({
    List<Map<String, dynamic>>? conflicts,
  }) {
    return {
      'success': true,
      'conflicts': conflicts ?? [],
      'synced_count': 10,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Simulate network delay
  static Future<void> simulateNetworkDelay([int milliseconds = 100]) async {
    await Future.delayed(Duration(milliseconds: milliseconds));
  }

  /// Validate sync service state
  static void validateSyncServiceState(SyncService syncService) {
    expect(syncService, isNotNull, reason: 'SyncService should be initialized');
    // Add more validations as needed
  }

  /// Print sync statistics (for debugging)
  static Future<void> printSyncStats(AppDatabase database) async {
    final products = await database.productDao.getUnsyncedProducts();
    final suppliers = await database.supplierDao.getUnsyncedSuppliers();
    final purchases = await database.purchaseDao.getUnsyncedPurchases();
    final issues = await database.issueDao.getUnsyncedIssues();
    final conflicts = await database.syncDao.getUnresolvedConflicts();
    final queue = await database.syncDao.getPendingSyncItems();

    print('=== Sync Statistics ===');
    print('Unsynced Products: ${products.length}');
    print('Unsynced Suppliers: ${suppliers.length}');
    print('Unsynced Purchases: ${purchases.length}');
    print('Unsynced Issues: ${issues.length}');
    print('Unresolved Conflicts: ${conflicts.length}');
    print('Pending Queue Items: ${queue.length}');
    print('======================');
  }
}

/// Test scenarios for sync functionality
class SyncTestScenarios {
  /// Scenario 1: Basic sync flow
  static Future<void> testBasicSync(AppDatabase database) async {
    print('\n📝 Testing Basic Sync Flow...');

    // 1. Create unsynced products
    final uuids = await SyncTestUtils.createUnsyncedProducts(database, 5);
    print('✓ Created 5 unsynced products');

    // 2. Verify they are unsynced
    for (final uuid in uuids) {
      final isSynced = await SyncTestUtils.verifySyncFlag(database, uuid, false);
      expect(isSynced, isTrue, reason: 'Product should be unsynced');
    }
    print('✓ Verified products are unsynced');

    // 3. Mark as synced
    for (final uuid in uuids) {
      await database.productDao.markProductAsSynced(uuid);
    }
    print('✓ Marked products as synced');

    // 4. Verify they are now synced
    for (final uuid in uuids) {
      final isSynced = await SyncTestUtils.verifySyncFlag(database, uuid, true);
      expect(isSynced, isTrue, reason: 'Product should be synced');
    }
    print('✓ Verified products are synced');

    print('✅ Basic Sync Flow Test PASSED\n');
  }

  /// Scenario 2: Conflict detection
  static Future<void> testConflictDetection(AppDatabase database) async {
    print('\n📝 Testing Conflict Detection...');

    // 1. Create a product
    final product = SyncTestUtils.generateTestProduct();
    await database.productDao.createProduct(product);
    print('✓ Created test product');

    // 2. Create a conflict scenario
    await SyncTestUtils.createConflictScenario(database, product.uuid.value);
    print('✓ Created conflict scenario');

    // 3. Verify conflict was logged
    final conflicts = await database.syncDao.getUnresolvedConflicts();
    expect(conflicts.length, greaterThan(0), reason: 'Should have at least one conflict');
    print('✓ Conflict logged: ${conflicts.length} conflicts found');

    // 4. Resolve conflict
    await database.syncDao.resolveConflict(
      conflictId: conflicts.first.id,
      resolution: 'use_server',
      resolvedBy: 'test',
    );
    print('✓ Resolved conflict');

    // 5. Verify conflict is resolved
    final unresolvedConflicts = await database.syncDao.getUnresolvedConflicts();
    expect(
      unresolvedConflicts.length,
      equals(conflicts.length - 1),
      reason: 'Should have one less unresolved conflict',
    );
    print('✓ Verified conflict resolution');

    print('✅ Conflict Detection Test PASSED\n');
  }

  /// Scenario 3: Sync queue management
  static Future<void> testSyncQueue(AppDatabase database) async {
    print('\n📝 Testing Sync Queue...');

    // 1. Add items to sync queue
    await database.syncDao.addToSyncQueue(
      tableName: 'stock_items',
      recordId: 'test-record-1',
      operation: 'INSERT',
      data: jsonEncode({'name': 'Test Product'}),
    );
    await database.syncDao.addToSyncQueue(
      tableName: 'suppliers',
      recordId: 'test-record-2',
      operation: 'UPDATE',
      data: jsonEncode({'name': 'Test Supplier'}),
    );
    print('✓ Added 2 items to sync queue');

    // 2. Verify queue count
    final queueCount = await database.syncDao.getSyncQueueCount();
    expect(queueCount, greaterThanOrEqualTo(2), reason: 'Should have at least 2 queued items');
    print('✓ Verified queue count: $queueCount items');

    // 3. Get pending items
    final pendingItems = await database.syncDao.getPendingSyncItems();
    expect(pendingItems.length, greaterThanOrEqualTo(2), reason: 'Should have at least 2 pending items');
    print('✓ Retrieved ${pendingItems.length} pending items');

    // 4. Clear queue
    await database.syncDao.clearSyncQueue();
    final clearedCount = await database.syncDao.getSyncQueueCount();
    expect(clearedCount, equals(0), reason: 'Queue should be empty');
    print('✓ Cleared sync queue');

    print('✅ Sync Queue Test PASSED\n');
  }

  /// Run all test scenarios
  static Future<void> runAllTests(AppDatabase database) async {
    print('\n' + '=' * 50);
    print('🧪 RUNNING ALL SYNC TEST SCENARIOS');
    print('=' * 50);

    try {
      await testBasicSync(database);
      await testConflictDetection(database);
      await testSyncQueue(database);

      print('\n' + '=' * 50);
      print('✅ ALL TESTS PASSED SUCCESSFULLY');
      print('=' * 50 + '\n');
    } catch (e, stackTrace) {
      print('\n' + '=' * 50);
      print('❌ TEST FAILED');
      print('=' * 50);
      print('Error: $e');
      print('Stack Trace: $stackTrace');
      print('\n');
      rethrow;
    } finally {
      // Cleanup
      await SyncTestUtils.clearTestData(database);
      print('🧹 Cleaned up test data\n');
    }
  }
}
