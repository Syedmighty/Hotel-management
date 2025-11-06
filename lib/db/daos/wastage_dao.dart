import 'package:drift/drift.dart';
import '../app_database.dart';
import 'product_dao.dart';
import 'supplier_dao.dart';

part 'wastage_dao.g.dart';

@DriftAccessor(tables: [WastageReturns, WastageLineItems])
class WastageDao extends DatabaseAccessor<AppDatabase>
    with _$WastageDaoMixin {
  WastageDao(AppDatabase db) : super(db);

  final ProductDao _productDao = ProductDao(AppDatabase());
  final SupplierDao _supplierDao = SupplierDao(AppDatabase());

  // Create wastage/return with line items (transaction-based)
  Future<String> createWastageWithItems({
    required String wastageNo,
    required DateTime wastageDate,
    required String type, // 'Wastage' or 'Return'
    String? supplierId,
    required double totalAmount,
    required List<WastageLineItemsCompanion> lineItems,
    String? remarks,
  }) async {
    return await transaction(() async {
      // Validate: If type is Return, supplierId must be provided
      if (type == 'Return' && (supplierId == null || supplierId.isEmpty)) {
        throw Exception('Supplier is required for Return type');
      }

      // Insert wastage/return record
      final wastageId = await into(wastageReturns).insert(
        WastageReturnsCompanion.insert(
          wastageNo: wastageNo,
          wastageDate: wastageDate,
          type: type,
          supplierId: Value(supplierId),
          totalAmount: totalAmount,
          status: const Value('Pending'),
          remarks: Value(remarks),
          createdAt: DateTime.now(),
          lastModified: DateTime.now(),
        ),
      );

      // Get the generated UUID
      final wastage = await (select(wastageReturns)
            ..where((wr) => wr.id.equals(wastageId)))
          .getSingle();

      // Insert line items with the wastage UUID
      for (final item in lineItems) {
        await into(wastageLineItems).insert(
          item.copyWith(wastageId: Value(wastage.uuid)),
        );
      }

      return wastage.uuid;
    });
  }

  // Get wastage/return by ID
  Future<WastageReturn?> getWastageById(String wastageId) async {
    return await (select(wastageReturns)
          ..where((wr) => wr.uuid.equals(wastageId)))
        .getSingleOrNull();
  }

  // Get all wastage/returns
  Future<List<WastageReturn>> getAllWastages() async {
    return await (select(wastageReturns)
          ..orderBy([
            (wr) => OrderingTerm.desc(wr.wastageDate),
            (wr) => OrderingTerm.desc(wr.createdAt),
          ]))
        .get();
  }

  // Watch all wastage/returns (stream)
  Stream<List<WastageReturn>> watchAllWastages() {
    return (select(wastageReturns)
          ..orderBy([
            (wr) => OrderingTerm.desc(wr.wastageDate),
            (wr) => OrderingTerm.desc(wr.createdAt),
          ]))
        .watch();
  }

  // Get pending wastage/returns
  Future<List<WastageReturn>> getPendingWastages() async {
    return await (select(wastageReturns)
          ..where((wr) => wr.status.equals('Pending'))
          ..orderBy([
            (wr) => OrderingTerm.desc(wr.wastageDate),
          ]))
        .get();
  }

  // Watch pending wastage/returns (stream)
  Stream<List<WastageReturn>> watchPendingWastages() {
    return (select(wastageReturns)
          ..where((wr) => wr.status.equals('Pending'))
          ..orderBy([
            (wr) => OrderingTerm.desc(wr.wastageDate),
          ]))
        .watch();
  }

  // Get wastage/returns by type
  Future<List<WastageReturn>> getWastagesByType(String type) async {
    return await (select(wastageReturns)
          ..where((wr) => wr.type.equals(type))
          ..orderBy([
            (wr) => OrderingTerm.desc(wr.wastageDate),
          ]))
        .get();
  }

  // Get wastage/returns by status
  Future<List<WastageReturn>> getWastagesByStatus(String status) async {
    return await (select(wastageReturns)
          ..where((wr) => wr.status.equals(status))
          ..orderBy([
            (wr) => OrderingTerm.desc(wr.wastageDate),
          ]))
        .get();
  }

  // Search wastage/returns
  Future<List<WastageReturn>> searchWastages(String query) async {
    final lowerQuery = query.toLowerCase();
    return await (select(wastageReturns)
          ..where((wr) =>
              wr.wastageNo.lower().like('%$lowerQuery%') |
              wr.type.lower().like('%$lowerQuery%') |
              wr.remarks.lower().like('%$lowerQuery%'))
          ..orderBy([
            (wr) => OrderingTerm.desc(wr.wastageDate),
          ]))
        .get();
  }

  // Get line items for a wastage/return
  Future<List<WastageLineItem>> getWastageLineItems(String wastageId) async {
    return await (select(wastageLineItems)
          ..where((wli) => wli.wastageId.equals(wastageId))
          ..orderBy([
            (wli) => OrderingTerm.asc(wli.id),
          ]))
        .get();
  }

  // Watch line items for a wastage/return (stream)
  Stream<List<WastageLineItem>> watchWastageLineItems(String wastageId) {
    return (select(wastageLineItems)
          ..where((wli) => wli.wastageId.equals(wastageId))
          ..orderBy([
            (wli) => OrderingTerm.asc(wli.id),
          ]))
        .watch();
  }

  // Update wastage/return
  Future<bool> updateWastage({
    required String wastageId,
    String? wastageNo,
    DateTime? wastageDate,
    String? type,
    String? supplierId,
    double? totalAmount,
    String? status,
    String? remarks,
  }) async {
    final companionData = WastageReturnsCompanion(
      wastageNo: wastageNo != null ? Value(wastageNo) : const Value.absent(),
      wastageDate:
          wastageDate != null ? Value(wastageDate) : const Value.absent(),
      type: type != null ? Value(type) : const Value.absent(),
      supplierId:
          supplierId != null ? Value(supplierId) : const Value.absent(),
      totalAmount:
          totalAmount != null ? Value(totalAmount) : const Value.absent(),
      status: status != null ? Value(status) : const Value.absent(),
      remarks: remarks != null ? Value(remarks) : const Value.absent(),
      lastModified: Value(DateTime.now()),
      isSynced: const Value(false),
    );

    final rowsAffected = await (update(wastageReturns)
          ..where((wr) => wr.uuid.equals(wastageId)))
        .write(companionData);

    return rowsAffected > 0;
  }

  // Update wastage/return with line items (transaction-based)
  Future<bool> updateWastageWithItems({
    required String wastageId,
    required String wastageNo,
    required DateTime wastageDate,
    required String type,
    String? supplierId,
    required double totalAmount,
    required List<WastageLineItemsCompanion> lineItems,
    String? remarks,
  }) async {
    return await transaction(() async {
      // Validate: If type is Return, supplierId must be provided
      if (type == 'Return' && (supplierId == null || supplierId.isEmpty)) {
        throw Exception('Supplier is required for Return type');
      }

      // Update wastage/return
      final updated = await updateWastage(
        wastageId: wastageId,
        wastageNo: wastageNo,
        wastageDate: wastageDate,
        type: type,
        supplierId: supplierId,
        totalAmount: totalAmount,
        remarks: remarks,
      );

      if (!updated) return false;

      // Delete existing line items
      await (delete(wastageLineItems)
            ..where((wli) => wli.wastageId.equals(wastageId)))
          .go();

      // Insert new line items
      for (final item in lineItems) {
        await into(wastageLineItems).insert(
          item.copyWith(wastageId: Value(wastageId)),
        );
      }

      return true;
    });
  }

  // Approve wastage/return (adjust stock and supplier balance if return)
  Future<void> approveWastage(String wastageId) async {
    await transaction(() async {
      final wastage = await getWastageById(wastageId);
      if (wastage == null) {
        throw Exception('Wastage/Return record not found');
      }

      if (wastage.status == 'Approved') {
        throw Exception('Wastage/Return already approved');
      }

      final lineItems = await getWastageLineItems(wastageId);

      // Check stock availability for all items
      for (final item in lineItems) {
        final product = await _productDao.getProductById(item.productId);
        if (product == null) {
          throw Exception('Product ${item.productId} not found');
        }
        if (product.currentStock < item.quantity) {
          throw Exception(
              'Insufficient stock for ${product.name}. Available: ${product.currentStock}, Required: ${item.quantity}');
        }
      }

      // Deduct stock for each line item (both Wastage and Return reduce stock)
      for (final item in lineItems) {
        await _productDao.decreaseStock(item.productId, item.quantity);
      }

      // If type is Return, update supplier balance (credit supplier)
      if (wastage.type == 'Return' && wastage.supplierId != null) {
        // Subtract from supplier balance (we're returning goods, they owe us less)
        await _supplierDao.subtractFromBalance(
            wastage.supplierId!, wastage.totalAmount);
      }

      // Update wastage status to Approved
      await (update(wastageReturns)..where((wr) => wr.uuid.equals(wastageId)))
          .write(WastageReturnsCompanion(
        status: const Value('Approved'),
        lastModified: Value(DateTime.now()),
        isSynced: const Value(false),
      ));
    });
  }

  // Delete wastage/return (only if pending)
  Future<bool> deleteWastage(String wastageId) async {
    return await transaction(() async {
      final wastage = await getWastageById(wastageId);
      if (wastage == null) return false;

      if (wastage.status == 'Approved') {
        throw Exception('Cannot delete approved wastage/return');
      }

      // Delete line items first
      await (delete(wastageLineItems)
            ..where((wli) => wli.wastageId.equals(wastageId)))
          .go();

      // Delete wastage/return
      final rowsAffected = await (delete(wastageReturns)
            ..where((wr) => wr.uuid.equals(wastageId)))
          .go();

      return rowsAffected > 0;
    });
  }

  // Get total wastage value by date range
  Future<double> getTotalWastageValueByDateRange(
      DateTime startDate, DateTime endDate) async {
    final query = selectOnly(wastageReturns)
      ..addColumns([wastageReturns.totalAmount.sum()])
      ..where(wastageReturns.wastageDate.isBiggerOrEqualValue(startDate) &
          wastageReturns.wastageDate.isSmallerOrEqualValue(endDate) &
          wastageReturns.type.equals('Wastage') &
          wastageReturns.status.equals('Approved'));

    final result = await query.getSingle();
    return result.read(wastageReturns.totalAmount.sum()) ?? 0.0;
  }

  // Get total return value by date range
  Future<double> getTotalReturnValueByDateRange(
      DateTime startDate, DateTime endDate) async {
    final query = selectOnly(wastageReturns)
      ..addColumns([wastageReturns.totalAmount.sum()])
      ..where(wastageReturns.wastageDate.isBiggerOrEqualValue(startDate) &
          wastageReturns.wastageDate.isSmallerOrEqualValue(endDate) &
          wastageReturns.type.equals('Return') &
          wastageReturns.status.equals('Approved'));

    final result = await query.getSingle();
    return result.read(wastageReturns.totalAmount.sum()) ?? 0.0;
  }

  // Get wastage/returns by date range
  Future<List<WastageReturn>> getWastagesByDateRange(
      DateTime startDate, DateTime endDate) async {
    return await (select(wastageReturns)
          ..where((wr) =>
              wr.wastageDate.isBiggerOrEqualValue(startDate) &
              wr.wastageDate.isSmallerOrEqualValue(endDate))
          ..orderBy([
            (wr) => OrderingTerm.desc(wr.wastageDate),
          ]))
        .get();
  }

  // Get wastages by supplier (for returns)
  Future<List<WastageReturn>> getWastagesBySupplier(String supplierId) async {
    return await (select(wastageReturns)
          ..where((wr) =>
              wr.supplierId.equals(supplierId) & wr.type.equals('Return'))
          ..orderBy([
            (wr) => OrderingTerm.desc(wr.wastageDate),
          ]))
        .get();
  }

  // Get most wasted products (top N)
  Future<List<Map<String, dynamic>>> getMostWastedProducts(
      {int limit = 10}) async {
    // Join with wastage_returns to filter by type='Wastage'
    final query = selectOnly(wastageLineItems)
      ..join([
        innerJoin(wastageReturns,
            wastageReturns.uuid.equalsExp(wastageLineItems.wastageId))
      ])
      ..addColumns([
        wastageLineItems.productId,
        wastageLineItems.quantity.sum(),
      ])
      ..where(wastageReturns.type.equals('Wastage') &
          wastageReturns.status.equals('Approved'))
      ..groupBy([wastageLineItems.productId])
      ..orderBy([OrderingTerm.desc(wastageLineItems.quantity.sum())])
      ..limit(limit);

    final results = await query.get();
    return results.map((row) {
      return {
        'productId': row.read(wastageLineItems.productId),
        'totalQuantity': row.read(wastageLineItems.quantity.sum()) ?? 0.0,
      };
    }).toList();
  }

  // Get wastage by reason (aggregated)
  Future<List<Map<String, dynamic>>> getWastageByReason() async {
    final query = selectOnly(wastageLineItems)
      ..join([
        innerJoin(wastageReturns,
            wastageReturns.uuid.equalsExp(wastageLineItems.wastageId))
      ])
      ..addColumns([
        wastageLineItems.reason,
        wastageLineItems.quantity.sum(),
      ])
      ..where(wastageReturns.type.equals('Wastage') &
          wastageReturns.status.equals('Approved'))
      ..groupBy([wastageLineItems.reason])
      ..orderBy([OrderingTerm.desc(wastageLineItems.quantity.sum())]);

    final results = await query.get();
    return results.map((row) {
      return {
        'reason': row.read(wastageLineItems.reason),
        'totalQuantity': row.read(wastageLineItems.quantity.sum()) ?? 0.0,
      };
    }).toList();
  }

  // Get next wastage number (auto-increment helper)
  Future<String> getNextWastageNo(String type) async {
    final prefix = type == 'Wastage' ? 'WST' : 'RET';

    final lastWastage = await (select(wastageReturns)
          ..where((wr) => wr.type.equals(type))
          ..orderBy([
            (wr) => OrderingTerm.desc(wr.createdAt),
          ])
          ..limit(1))
        .getSingleOrNull();

    if (lastWastage == null) {
      return '$prefix-0001';
    }

    // Extract number from last wastage number (e.g., WST-0001 -> 1)
    final lastNo = lastWastage.wastageNo;
    final match = RegExp(r'\d+$').firstMatch(lastNo);
    if (match != null) {
      final num = int.parse(match.group(0)!);
      return '$prefix-${(num + 1).toString().padLeft(4, '0')}';
    }

    return '$prefix-0001';
  }
}
