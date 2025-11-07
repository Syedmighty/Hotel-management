import 'package:drift/drift.dart';
import '../app_database.dart';
import 'product_dao.dart';

part 'physical_count_dao.g.dart';

@DriftAccessor(tables: [PhysicalCounts, PhysicalCountLineItems])
class PhysicalCountDao extends DatabaseAccessor<AppDatabase>
    with _$PhysicalCountDaoMixin {
  PhysicalCountDao(AppDatabase db) : super(db);

  final ProductDao _productDao = ProductDao(AppDatabase());

  // Create physical count with line items (transaction-based)
  Future<String> createPhysicalCountWithItems({
    required String countNo,
    required DateTime countDate,
    required String countedBy,
    required List<PhysicalCountLineItemsCompanion> lineItems,
    String? remarks,
  }) async {
    return await transaction(() async {
      // Insert physical count record
      final countId = await into(physicalCounts).insert(
        PhysicalCountsCompanion.insert(
          countNo: countNo,
          countDate: countDate,
          countedBy: countedBy,
          status: const Value('Pending'),
          remarks: Value(remarks),
          createdAt: DateTime.now(),
          lastModified: DateTime.now(),
        ),
      );

      // Get the generated UUID
      final count = await (select(physicalCounts)
            ..where((pc) => pc.id.equals(countId)))
          .getSingle();

      // Insert line items with the count UUID
      for (final item in lineItems) {
        await into(physicalCountLineItems).insert(
          item.copyWith(countId: Value(count.uuid)),
        );
      }

      return count.uuid;
    });
  }

  // Get physical count by ID
  Future<PhysicalCount?> getPhysicalCountById(String countId) async {
    return await (select(physicalCounts)
          ..where((pc) => pc.uuid.equals(countId)))
        .getSingleOrNull();
  }

  // Get all physical counts
  Future<List<PhysicalCount>> getAllPhysicalCounts() async {
    return await (select(physicalCounts)
          ..orderBy([
            (pc) => OrderingTerm.desc(pc.countDate),
            (pc) => OrderingTerm.desc(pc.createdAt),
          ]))
        .get();
  }

  // Watch all physical counts (stream)
  Stream<List<PhysicalCount>> watchAllPhysicalCounts() {
    return (select(physicalCounts)
          ..orderBy([
            (pc) => OrderingTerm.desc(pc.countDate),
            (pc) => OrderingTerm.desc(pc.createdAt),
          ]))
        .watch();
  }

  // Get pending physical counts
  Future<List<PhysicalCount>> getPendingPhysicalCounts() async {
    return await (select(physicalCounts)
          ..where((pc) => pc.status.equals('Pending'))
          ..orderBy([
            (pc) => OrderingTerm.desc(pc.countDate),
          ]))
        .get();
  }

  // Watch pending physical counts (stream)
  Stream<List<PhysicalCount>> watchPendingPhysicalCounts() {
    return (select(physicalCounts)
          ..where((pc) => pc.status.equals('Pending'))
          ..orderBy([
            (pc) => OrderingTerm.desc(pc.countDate),
          ]))
        .watch();
  }

  // Get physical counts by status
  Future<List<PhysicalCount>> getPhysicalCountsByStatus(String status) async {
    return await (select(physicalCounts)
          ..where((pc) => pc.status.equals(status))
          ..orderBy([
            (pc) => OrderingTerm.desc(pc.countDate),
          ]))
        .get();
  }

  // Search physical counts
  Future<List<PhysicalCount>> searchPhysicalCounts(String query) async {
    final lowerQuery = query.toLowerCase();
    return await (select(physicalCounts)
          ..where((pc) =>
              pc.countNo.lower().like('%$lowerQuery%') |
              pc.countedBy.lower().like('%$lowerQuery%'))
          ..orderBy([
            (pc) => OrderingTerm.desc(pc.countDate),
          ]))
        .get();
  }

  // Get line items for a physical count
  Future<List<PhysicalCountLineItem>> getPhysicalCountLineItems(
      String countId) async {
    return await (select(physicalCountLineItems)
          ..where((pcli) => pcli.countId.equals(countId))
          ..orderBy([
            (pcli) => OrderingTerm.asc(pcli.id),
          ]))
        .get();
  }

  // Watch line items for a physical count (stream)
  Stream<List<PhysicalCountLineItem>> watchPhysicalCountLineItems(
      String countId) {
    return (select(physicalCountLineItems)
          ..where((pcli) => pcli.countId.equals(countId))
          ..orderBy([
            (pcli) => OrderingTerm.asc(pcli.id),
          ]))
        .watch();
  }

  // Calculate variances for line items with current stock
  Future<List<PhysicalCountLineItemWithVariance>>
      getLineItemsWithVariance(String countId) async {
    final lineItems = await getPhysicalCountLineItems(countId);
    final List<PhysicalCountLineItemWithVariance> itemsWithVariance = [];

    for (final lineItem in lineItems) {
      final product = await _productDao.getProductById(lineItem.productId);
      if (product != null) {
        final variance = lineItem.countedQuantity - product.currentStock;
        final varianceValue = variance * product.purchaseRate;

        itemsWithVariance.add(PhysicalCountLineItemWithVariance(
          lineItem: lineItem,
          product: product,
          systemStock: product.currentStock,
          variance: variance,
          varianceValue: varianceValue,
        ));
      }
    }

    return itemsWithVariance;
  }

  // Update physical count
  Future<bool> updatePhysicalCount({
    required String countId,
    String? countNo,
    DateTime? countDate,
    String? countedBy,
    String? status,
    String? remarks,
  }) async {
    final companionData = PhysicalCountsCompanion(
      countNo: countNo != null ? Value(countNo) : const Value.absent(),
      countDate: countDate != null ? Value(countDate) : const Value.absent(),
      countedBy: countedBy != null ? Value(countedBy) : const Value.absent(),
      status: status != null ? Value(status) : const Value.absent(),
      remarks: remarks != null ? Value(remarks) : const Value.absent(),
      lastModified: Value(DateTime.now()),
      isSynced: const Value(false),
    );

    final rowsAffected = await (update(physicalCounts)
          ..where((pc) => pc.uuid.equals(countId)))
        .write(companionData);

    return rowsAffected > 0;
  }

  // Update physical count with line items (transaction-based)
  Future<bool> updatePhysicalCountWithItems({
    required String countId,
    required String countNo,
    required DateTime countDate,
    required String countedBy,
    required List<PhysicalCountLineItemsCompanion> lineItems,
    String? remarks,
  }) async {
    return await transaction(() async {
      // Update physical count
      final updated = await updatePhysicalCount(
        countId: countId,
        countNo: countNo,
        countDate: countDate,
        countedBy: countedBy,
        remarks: remarks,
      );

      if (!updated) return false;

      // Delete existing line items
      await (delete(physicalCountLineItems)
            ..where((pcli) => pcli.countId.equals(countId)))
          .go();

      // Insert new line items
      for (final item in lineItems) {
        await into(physicalCountLineItems).insert(
          item.copyWith(countId: Value(countId)),
        );
      }

      return true;
    });
  }

  // Approve physical count and adjust stock based on variances
  Future<void> approvePhysicalCount(String countId) async {
    await transaction(() async {
      final count = await getPhysicalCountById(countId);
      if (count == null) {
        throw Exception('Physical count not found');
      }

      if (count.status == 'Approved') {
        throw Exception('Physical count already approved');
      }

      final lineItems = await getPhysicalCountLineItems(countId);

      // Adjust stock for each line item based on variance
      for (final item in lineItems) {
        final product = await _productDao.getProductById(item.productId);
        if (product == null) {
          throw Exception('Product ${item.productId} not found');
        }

        final variance = item.countedQuantity - product.currentStock;

        if (variance != 0) {
          // Update product stock to counted quantity
          await _productDao.updateProduct(
            productId: item.productId,
            currentStock: item.countedQuantity,
          );

          // Create stock adjustment record for audit trail
          await into(stockAdjustments).insert(
            StockAdjustmentsCompanion.insert(
              productId: item.productId,
              adjustmentDate: count.countDate,
              adjustmentType: variance > 0 ? 'Increase' : 'Decrease',
              quantity: variance.abs(),
              reason: item.varianceReason ?? 'Physical count adjustment',
              remarks: Value('Physical count: ${count.countNo}'),
              approvedBy: Value(count.countedBy),
              createdAt: DateTime.now(),
              lastModified: DateTime.now(),
            ),
          );
        }
      }

      // Update physical count status to Approved
      await (update(physicalCounts)..where((pc) => pc.uuid.equals(countId)))
          .write(PhysicalCountsCompanion(
        status: const Value('Approved'),
        lastModified: Value(DateTime.now()),
        isSynced: const Value(false),
      ));
    });
  }

  // Delete physical count (only if pending)
  Future<bool> deletePhysicalCount(String countId) async {
    return await transaction(() async {
      final count = await getPhysicalCountById(countId);
      if (count == null) return false;

      if (count.status == 'Approved') {
        throw Exception('Cannot delete approved physical count');
      }

      // Delete line items first
      await (delete(physicalCountLineItems)
            ..where((pcli) => pcli.countId.equals(countId)))
          .go();

      // Delete physical count
      final rowsAffected = await (delete(physicalCounts)
            ..where((pc) => pc.uuid.equals(countId)))
          .go();

      return rowsAffected > 0;
    });
  }

  // Get variance summary
  Future<PhysicalCountVarianceSummary> getVarianceSummary(
      String countId) async {
    final itemsWithVariance = await getLineItemsWithVariance(countId);

    double totalPositiveVariance = 0.0;
    double totalNegativeVariance = 0.0;
    int itemsWithIncrease = 0;
    int itemsWithDecrease = 0;
    int itemsWithNoVariance = 0;

    for (final item in itemsWithVariance) {
      if (item.variance > 0) {
        totalPositiveVariance += item.varianceValue;
        itemsWithIncrease++;
      } else if (item.variance < 0) {
        totalNegativeVariance += item.varianceValue.abs();
        itemsWithDecrease++;
      } else {
        itemsWithNoVariance++;
      }
    }

    return PhysicalCountVarianceSummary(
      totalItems: itemsWithVariance.length,
      itemsWithIncrease: itemsWithIncrease,
      itemsWithDecrease: itemsWithDecrease,
      itemsWithNoVariance: itemsWithNoVariance,
      totalPositiveVariance: totalPositiveVariance,
      totalNegativeVariance: totalNegativeVariance,
      netVariance: totalPositiveVariance - totalNegativeVariance,
    );
  }

  // Get physical counts by date range
  Future<List<PhysicalCount>> getPhysicalCountsByDateRange(
      DateTime startDate, DateTime endDate) async {
    return await (select(physicalCounts)
          ..where((pc) =>
              pc.countDate.isBiggerOrEqualValue(startDate) &
              pc.countDate.isSmallerOrEqualValue(endDate))
          ..orderBy([
            (pc) => OrderingTerm.desc(pc.countDate),
          ]))
        .get();
  }

  // Get next count number (auto-increment helper)
  Future<String> getNextCountNo() async {
    final lastCount = await (select(physicalCounts)
          ..orderBy([
            (pc) => OrderingTerm.desc(pc.createdAt),
          ])
          ..limit(1))
        .getSingleOrNull();

    if (lastCount == null) {
      return 'CNT-0001';
    }

    // Extract number from last count number (e.g., CNT-0001 -> 1)
    final lastNo = lastCount.countNo;
    final match = RegExp(r'\d+$').firstMatch(lastNo);
    if (match != null) {
      final num = int.parse(match.group(0)!);
      return 'CNT-${(num + 1).toString().padLeft(4, '0')}';
    }

    return 'CNT-0001';
  }

  // Get products for physical count (all active products with current stock)
  Future<List<ProductForCount>> getProductsForCount() async {
    final products = await (select(this.products)
          ..where((p) => p.isActive.equals(true))
          ..orderBy([
            (p) => OrderingTerm.asc(p.category),
            (p) => OrderingTerm.asc(p.name),
          ]))
        .get();

    return products
        .map((p) => ProductForCount(
              product: p,
              systemStock: p.currentStock,
            ))
        .toList();
  }
}

// Data models for physical count
class PhysicalCountLineItemWithVariance {
  final PhysicalCountLineItem lineItem;
  final Product product;
  final double systemStock;
  final double variance;
  final double varianceValue;

  PhysicalCountLineItemWithVariance({
    required this.lineItem,
    required this.product,
    required this.systemStock,
    required this.variance,
    required this.varianceValue,
  });
}

class PhysicalCountVarianceSummary {
  final int totalItems;
  final int itemsWithIncrease;
  final int itemsWithDecrease;
  final int itemsWithNoVariance;
  final double totalPositiveVariance;
  final double totalNegativeVariance;
  final double netVariance;

  PhysicalCountVarianceSummary({
    required this.totalItems,
    required this.itemsWithIncrease,
    required this.itemsWithDecrease,
    required this.itemsWithNoVariance,
    required this.totalPositiveVariance,
    required this.totalNegativeVariance,
    required this.netVariance,
  });
}

class ProductForCount {
  final Product product;
  final double systemStock;

  ProductForCount({
    required this.product,
    required this.systemStock,
  });
}
