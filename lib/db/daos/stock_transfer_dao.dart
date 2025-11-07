import 'package:drift/drift.dart';
import '../app_database.dart';
import 'product_dao.dart';

part 'stock_transfer_dao.g.dart';

@DriftAccessor(tables: [StockTransfers, StockTransferLineItems])
class StockTransferDao extends DatabaseAccessor<AppDatabase>
    with _$StockTransferDaoMixin {
  StockTransferDao(AppDatabase db) : super(db);

  final ProductDao _productDao = ProductDao(AppDatabase());

  // Create stock transfer with line items (transaction-based)
  Future<String> createStockTransferWithItems({
    required String transferNo,
    required DateTime transferDate,
    required String fromLocation,
    required String toLocation,
    required String requestedBy,
    required double totalAmount,
    required List<StockTransferLineItemsCompanion> lineItems,
    String? remarks,
  }) async {
    return await transaction(() async {
      // Validate: fromLocation and toLocation must be different
      if (fromLocation == toLocation) {
        throw Exception('Source and destination locations must be different');
      }

      // Insert stock transfer record
      final transferId = await into(stockTransfers).insert(
        StockTransfersCompanion.insert(
          transferNo: transferNo,
          transferDate: transferDate,
          fromLocation: fromLocation,
          toLocation: toLocation,
          requestedBy: requestedBy,
          totalAmount: totalAmount,
          status: const Value('Pending'),
          remarks: Value(remarks),
          createdAt: DateTime.now(),
          lastModified: DateTime.now(),
        ),
      );

      // Get the generated UUID
      final transfer = await (select(stockTransfers)
            ..where((st) => st.id.equals(transferId)))
          .getSingle();

      // Insert line items with the transfer UUID
      for (final item in lineItems) {
        await into(stockTransferLineItems).insert(
          item.copyWith(transferId: Value(transfer.uuid)),
        );
      }

      return transfer.uuid;
    });
  }

  // Get stock transfer by ID
  Future<StockTransfer?> getStockTransferById(String transferId) async {
    return await (select(stockTransfers)
          ..where((st) => st.uuid.equals(transferId)))
        .getSingleOrNull();
  }

  // Get all stock transfers
  Future<List<StockTransfer>> getAllStockTransfers() async {
    return await (select(stockTransfers)
          ..orderBy([
            (st) => OrderingTerm.desc(st.transferDate),
            (st) => OrderingTerm.desc(st.createdAt),
          ]))
        .get();
  }

  // Watch all stock transfers (stream)
  Stream<List<StockTransfer>> watchAllStockTransfers() {
    return (select(stockTransfers)
          ..orderBy([
            (st) => OrderingTerm.desc(st.transferDate),
            (st) => OrderingTerm.desc(st.createdAt),
          ]))
        .watch();
  }

  // Get pending stock transfers
  Future<List<StockTransfer>> getPendingStockTransfers() async {
    return await (select(stockTransfers)
          ..where((st) => st.status.equals('Pending'))
          ..orderBy([
            (st) => OrderingTerm.desc(st.transferDate),
          ]))
        .get();
  }

  // Watch pending stock transfers (stream)
  Stream<List<StockTransfer>> watchPendingStockTransfers() {
    return (select(stockTransfers)
          ..where((st) => st.status.equals('Pending'))
          ..orderBy([
            (st) => OrderingTerm.desc(st.transferDate),
          ]))
        .watch();
  }

  // Get stock transfers by status
  Future<List<StockTransfer>> getStockTransfersByStatus(String status) async {
    return await (select(stockTransfers)
          ..where((st) => st.status.equals(status))
          ..orderBy([
            (st) => OrderingTerm.desc(st.transferDate),
          ]))
        .get();
  }

  // Get stock transfers by location (from or to)
  Future<List<StockTransfer>> getStockTransfersByLocation(
      String location) async {
    return await (select(stockTransfers)
          ..where((st) =>
              st.fromLocation.equals(location) | st.toLocation.equals(location))
          ..orderBy([
            (st) => OrderingTerm.desc(st.transferDate),
          ]))
        .get();
  }

  // Search stock transfers
  Future<List<StockTransfer>> searchStockTransfers(String query) async {
    final lowerQuery = query.toLowerCase();
    return await (select(stockTransfers)
          ..where((st) =>
              st.transferNo.lower().like('%$lowerQuery%') |
              st.fromLocation.lower().like('%$lowerQuery%') |
              st.toLocation.lower().like('%$lowerQuery%') |
              st.requestedBy.lower().like('%$lowerQuery%'))
          ..orderBy([
            (st) => OrderingTerm.desc(st.transferDate),
          ]))
        .get();
  }

  // Get line items for a stock transfer
  Future<List<StockTransferLineItem>> getStockTransferLineItems(
      String transferId) async {
    return await (select(stockTransferLineItems)
          ..where((stli) => stli.transferId.equals(transferId))
          ..orderBy([
            (stli) => OrderingTerm.asc(stli.id),
          ]))
        .get();
  }

  // Watch line items for a stock transfer (stream)
  Stream<List<StockTransferLineItem>> watchStockTransferLineItems(
      String transferId) {
    return (select(stockTransferLineItems)
          ..where((stli) => stli.transferId.equals(transferId))
          ..orderBy([
            (stli) => OrderingTerm.asc(stli.id),
          ]))
        .watch();
  }

  // Update stock transfer
  Future<bool> updateStockTransfer({
    required String transferId,
    String? transferNo,
    DateTime? transferDate,
    String? fromLocation,
    String? toLocation,
    String? requestedBy,
    double? totalAmount,
    String? status,
    String? remarks,
  }) async {
    // Validate: fromLocation and toLocation must be different
    if (fromLocation != null &&
        toLocation != null &&
        fromLocation == toLocation) {
      throw Exception('Source and destination locations must be different');
    }

    final companionData = StockTransfersCompanion(
      transferNo:
          transferNo != null ? Value(transferNo) : const Value.absent(),
      transferDate:
          transferDate != null ? Value(transferDate) : const Value.absent(),
      fromLocation:
          fromLocation != null ? Value(fromLocation) : const Value.absent(),
      toLocation:
          toLocation != null ? Value(toLocation) : const Value.absent(),
      requestedBy:
          requestedBy != null ? Value(requestedBy) : const Value.absent(),
      totalAmount:
          totalAmount != null ? Value(totalAmount) : const Value.absent(),
      status: status != null ? Value(status) : const Value.absent(),
      remarks: remarks != null ? Value(remarks) : const Value.absent(),
      lastModified: Value(DateTime.now()),
      isSynced: const Value(false),
    );

    final rowsAffected = await (update(stockTransfers)
          ..where((st) => st.uuid.equals(transferId)))
        .write(companionData);

    return rowsAffected > 0;
  }

  // Update stock transfer with line items (transaction-based)
  Future<bool> updateStockTransferWithItems({
    required String transferId,
    required String transferNo,
    required DateTime transferDate,
    required String fromLocation,
    required String toLocation,
    required String requestedBy,
    required double totalAmount,
    required List<StockTransferLineItemsCompanion> lineItems,
    String? remarks,
  }) async {
    return await transaction(() async {
      // Validate: fromLocation and toLocation must be different
      if (fromLocation == toLocation) {
        throw Exception('Source and destination locations must be different');
      }

      // Update stock transfer
      final updated = await updateStockTransfer(
        transferId: transferId,
        transferNo: transferNo,
        transferDate: transferDate,
        fromLocation: fromLocation,
        toLocation: toLocation,
        requestedBy: requestedBy,
        totalAmount: totalAmount,
        remarks: remarks,
      );

      if (!updated) return false;

      // Delete existing line items
      await (delete(stockTransferLineItems)
            ..where((stli) => stli.transferId.equals(transferId)))
          .go();

      // Insert new line items
      for (final item in lineItems) {
        await into(stockTransferLineItems).insert(
          item.copyWith(transferId: Value(transferId)),
        );
      }

      return true;
    });
  }

  // Approve stock transfer (NOTE: In a real multi-location system, this would
  // update location-specific stock. For now, we just track the transfer)
  Future<void> approveStockTransfer(String transferId) async {
    await transaction(() async {
      final transfer = await getStockTransferById(transferId);
      if (transfer == null) {
        throw Exception('Stock transfer not found');
      }

      if (transfer.status == 'Approved') {
        throw Exception('Stock transfer already approved');
      }

      final lineItems = await getStockTransferLineItems(transferId);

      // Check stock availability in source location
      // Note: In current implementation, we track overall stock, not per-location
      // This would need extension for true multi-location inventory
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

      // Create stock adjustment records for audit trail
      // In a full multi-location system, this would:
      // 1. Decrease stock in fromLocation
      // 2. Increase stock in toLocation
      // For now, we just create audit records
      for (final item in lineItems) {
        // Create outward adjustment from source
        await into(stockAdjustments).insert(
          StockAdjustmentsCompanion.insert(
            productId: item.productId,
            adjustmentDate: transfer.transferDate,
            adjustmentType: 'Decrease',
            quantity: item.quantity,
            reason: 'Transfer Out',
            remarks: Value(
                'Transfer ${transfer.transferNo}: ${transfer.fromLocation} → ${transfer.toLocation}'),
            approvedBy: Value(transfer.requestedBy),
            createdAt: DateTime.now(),
            lastModified: DateTime.now(),
          ),
        );

        // Create inward adjustment to destination
        await into(stockAdjustments).insert(
          StockAdjustmentsCompanion.insert(
            productId: item.productId,
            adjustmentDate: transfer.transferDate,
            adjustmentType: 'Increase',
            quantity: item.quantity,
            reason: 'Transfer In',
            remarks: Value(
                'Transfer ${transfer.transferNo}: ${transfer.fromLocation} → ${transfer.toLocation}'),
            approvedBy: Value(transfer.requestedBy),
            createdAt: DateTime.now(),
            lastModified: DateTime.now(),
          ),
        );
      }

      // Update stock transfer status to Approved
      await (update(stockTransfers)
            ..where((st) => st.uuid.equals(transferId)))
          .write(StockTransfersCompanion(
        status: const Value('Approved'),
        lastModified: Value(DateTime.now()),
        isSynced: const Value(false),
      ));
    });
  }

  // Delete stock transfer (only if pending)
  Future<bool> deleteStockTransfer(String transferId) async {
    return await transaction(() async {
      final transfer = await getStockTransferById(transferId);
      if (transfer == null) return false;

      if (transfer.status == 'Approved') {
        throw Exception('Cannot delete approved stock transfer');
      }

      // Delete line items first
      await (delete(stockTransferLineItems)
            ..where((stli) => stli.transferId.equals(transferId)))
          .go();

      // Delete stock transfer
      final rowsAffected = await (delete(stockTransfers)
            ..where((st) => st.uuid.equals(transferId)))
          .go();

      return rowsAffected > 0;
    });
  }

  // Get total transfer value by date range
  Future<double> getTotalTransferValueByDateRange(
      DateTime startDate, DateTime endDate) async {
    final query = selectOnly(stockTransfers)
      ..addColumns([stockTransfers.totalAmount.sum()])
      ..where(stockTransfers.transferDate.isBiggerOrEqualValue(startDate) &
          stockTransfers.transferDate.isSmallerOrEqualValue(endDate) &
          stockTransfers.status.equals('Approved'));

    final result = await query.getSingle();
    return result.read(stockTransfers.totalAmount.sum()) ?? 0.0;
  }

  // Get stock transfers by date range
  Future<List<StockTransfer>> getStockTransfersByDateRange(
      DateTime startDate, DateTime endDate) async {
    return await (select(stockTransfers)
          ..where((st) =>
              st.transferDate.isBiggerOrEqualValue(startDate) &
              st.transferDate.isSmallerOrEqualValue(endDate))
          ..orderBy([
            (st) => OrderingTerm.desc(st.transferDate),
          ]))
        .get();
  }

  // Get transfer statistics by location
  Future<List<LocationTransferStats>> getLocationTransferStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final Map<String, LocationTransferStats> statsMap = {};

    // Get all transfers in date range
    final transfers = await (startDate != null && endDate != null
        ? getStockTransfersByDateRange(startDate, endDate)
        : getAllStockTransfers());

    final approvedTransfers =
        transfers.where((t) => t.status == 'Approved').toList();

    for (final transfer in approvedTransfers) {
      // Track outgoing transfers
      if (!statsMap.containsKey(transfer.fromLocation)) {
        statsMap[transfer.fromLocation] = LocationTransferStats(
          location: transfer.fromLocation,
          outgoingTransfers: 0,
          incomingTransfers: 0,
          outgoingValue: 0.0,
          incomingValue: 0.0,
        );
      }
      statsMap[transfer.fromLocation]!.outgoingTransfers++;
      statsMap[transfer.fromLocation]!.outgoingValue += transfer.totalAmount;

      // Track incoming transfers
      if (!statsMap.containsKey(transfer.toLocation)) {
        statsMap[transfer.toLocation] = LocationTransferStats(
          location: transfer.toLocation,
          outgoingTransfers: 0,
          incomingTransfers: 0,
          outgoingValue: 0.0,
          incomingValue: 0.0,
        );
      }
      statsMap[transfer.toLocation]!.incomingTransfers++;
      statsMap[transfer.toLocation]!.incomingValue += transfer.totalAmount;
    }

    return statsMap.values.toList();
  }

  // Get most transferred products
  Future<List<Map<String, dynamic>>> getMostTransferredProducts(
      {int limit = 10}) async {
    final query = selectOnly(stockTransferLineItems)
      ..join([
        innerJoin(stockTransfers,
            stockTransfers.uuid.equalsExp(stockTransferLineItems.transferId))
      ])
      ..addColumns([
        stockTransferLineItems.productId,
        stockTransferLineItems.quantity.sum(),
      ])
      ..where(stockTransfers.status.equals('Approved'))
      ..groupBy([stockTransferLineItems.productId])
      ..orderBy([OrderingTerm.desc(stockTransferLineItems.quantity.sum())])
      ..limit(limit);

    final results = await query.get();
    return results.map((row) {
      return {
        'productId': row.read(stockTransferLineItems.productId),
        'totalQuantity': row.read(stockTransferLineItems.quantity.sum()) ?? 0.0,
      };
    }).toList();
  }

  // Get next transfer number (auto-increment helper)
  Future<String> getNextTransferNo() async {
    final lastTransfer = await (select(stockTransfers)
          ..orderBy([
            (st) => OrderingTerm.desc(st.createdAt),
          ])
          ..limit(1))
        .getSingleOrNull();

    if (lastTransfer == null) {
      return 'TRF-0001';
    }

    // Extract number from last transfer number (e.g., TRF-0001 -> 1)
    final lastNo = lastTransfer.transferNo;
    final match = RegExp(r'\d+$').firstMatch(lastNo);
    if (match != null) {
      final num = int.parse(match.group(0)!);
      return 'TRF-${(num + 1).toString().padLeft(4, '0')}';
    }

    return 'TRF-0001';
  }
}

// Data models for stock transfer
class LocationTransferStats {
  final String location;
  int outgoingTransfers;
  int incomingTransfers;
  double outgoingValue;
  double incomingValue;

  LocationTransferStats({
    required this.location,
    required this.outgoingTransfers,
    required this.incomingTransfers,
    required this.outgoingValue,
    required this.incomingValue,
  });

  double get netTransferValue => incomingValue - outgoingValue;
}
