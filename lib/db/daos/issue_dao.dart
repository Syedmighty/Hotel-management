import 'package:drift/drift.dart';
import '../app_database.dart';
import 'product_dao.dart';

part 'issue_dao.g.dart';

@DriftAccessor(tables: [IssueVouchers, IssueLineItems])
class IssueDao extends DatabaseAccessor<AppDatabase> with _$IssueDaoMixin {
  IssueDao(AppDatabase db) : super(db);

  final ProductDao _productDao = ProductDao(AppDatabase());

  // Create issue voucher with line items (transaction-based)
  Future<String> createIssueWithItems({
    required String issueNo,
    required DateTime issueDate,
    required String issuedTo,
    required String requestedBy,
    required String purpose,
    required double totalAmount,
    required List<IssueLineItemsCompanion> lineItems,
    String? remarks,
  }) async {
    return await transaction(() async {
      // Insert issue voucher
      final issueId = await into(issueVouchers).insert(
        IssueVouchersCompanion.insert(
          issueNo: issueNo,
          issueDate: issueDate,
          issuedTo: issuedTo,
          requestedBy: requestedBy,
          purpose: purpose,
          totalAmount: totalAmount,
          status: const Value('Pending'),
          remarks: Value(remarks),
          createdAt: DateTime.now(),
          lastModified: DateTime.now(),
        ),
      );

      // Get the generated UUID
      final issue = await (select(issueVouchers)
            ..where((iv) => iv.id.equals(issueId)))
          .getSingle();

      // Insert line items with the issue UUID
      for (final item in lineItems) {
        await into(issueLineItems).insert(
          item.copyWith(issueId: Value(issue.uuid)),
        );
      }

      return issue.uuid;
    });
  }

  // Get issue voucher by ID
  Future<IssueVoucher?> getIssueById(String issueId) async {
    return await (select(issueVouchers)
          ..where((iv) => iv.uuid.equals(issueId)))
        .getSingleOrNull();
  }

  // Get all issue vouchers
  Future<List<IssueVoucher>> getAllIssues() async {
    return await (select(issueVouchers)
          ..orderBy([
            (iv) => OrderingTerm.desc(iv.issueDate),
            (iv) => OrderingTerm.desc(iv.createdAt),
          ]))
        .get();
  }

  // Watch all issue vouchers (stream)
  Stream<List<IssueVoucher>> watchAllIssues() {
    return (select(issueVouchers)
          ..orderBy([
            (iv) => OrderingTerm.desc(iv.issueDate),
            (iv) => OrderingTerm.desc(iv.createdAt),
          ]))
        .watch();
  }

  // Get pending issue vouchers
  Future<List<IssueVoucher>> getPendingIssues() async {
    return await (select(issueVouchers)
          ..where((iv) => iv.status.equals('Pending'))
          ..orderBy([
            (iv) => OrderingTerm.desc(iv.issueDate),
          ]))
        .get();
  }

  // Watch pending issue vouchers (stream)
  Stream<List<IssueVoucher>> watchPendingIssues() {
    return (select(issueVouchers)
          ..where((iv) => iv.status.equals('Pending'))
          ..orderBy([
            (iv) => OrderingTerm.desc(iv.issueDate),
          ]))
        .watch();
  }

  // Get issue vouchers by status
  Future<List<IssueVoucher>> getIssuesByStatus(String status) async {
    return await (select(issueVouchers)
          ..where((iv) => iv.status.equals(status))
          ..orderBy([
            (iv) => OrderingTerm.desc(iv.issueDate),
          ]))
        .get();
  }

  // Search issue vouchers
  Future<List<IssueVoucher>> searchIssues(String query) async {
    final lowerQuery = query.toLowerCase();
    return await (select(issueVouchers)
          ..where((iv) =>
              iv.issueNo.lower().like('%$lowerQuery%') |
              iv.issuedTo.lower().like('%$lowerQuery%') |
              iv.requestedBy.lower().like('%$lowerQuery%') |
              iv.purpose.lower().like('%$lowerQuery%'))
          ..orderBy([
            (iv) => OrderingTerm.desc(iv.issueDate),
          ]))
        .get();
  }

  // Get line items for an issue voucher
  Future<List<IssueLineItem>> getIssueLineItems(String issueId) async {
    return await (select(issueLineItems)
          ..where((ili) => ili.issueId.equals(issueId))
          ..orderBy([
            (ili) => OrderingTerm.asc(ili.id),
          ]))
        .get();
  }

  // Watch line items for an issue voucher (stream)
  Stream<List<IssueLineItem>> watchIssueLineItems(String issueId) {
    return (select(issueLineItems)
          ..where((ili) => ili.issueId.equals(issueId))
          ..orderBy([
            (ili) => OrderingTerm.asc(ili.id),
          ]))
        .watch();
  }

  // Update issue voucher
  Future<bool> updateIssue({
    required String issueId,
    String? issueNo,
    DateTime? issueDate,
    String? issuedTo,
    String? requestedBy,
    String? purpose,
    double? totalAmount,
    String? status,
    String? remarks,
  }) async {
    final companionData = IssueVouchersCompanion(
      issueNo: issueNo != null ? Value(issueNo) : const Value.absent(),
      issueDate: issueDate != null ? Value(issueDate) : const Value.absent(),
      issuedTo: issuedTo != null ? Value(issuedTo) : const Value.absent(),
      requestedBy:
          requestedBy != null ? Value(requestedBy) : const Value.absent(),
      purpose: purpose != null ? Value(purpose) : const Value.absent(),
      totalAmount:
          totalAmount != null ? Value(totalAmount) : const Value.absent(),
      status: status != null ? Value(status) : const Value.absent(),
      remarks: remarks != null ? Value(remarks) : const Value.absent(),
      lastModified: Value(DateTime.now()),
      isSynced: const Value(false),
    );

    final rowsAffected = await (update(issueVouchers)
          ..where((iv) => iv.uuid.equals(issueId)))
        .write(companionData);

    return rowsAffected > 0;
  }

  // Update issue voucher with line items (transaction-based)
  Future<bool> updateIssueWithItems({
    required String issueId,
    required String issueNo,
    required DateTime issueDate,
    required String issuedTo,
    required String requestedBy,
    required String purpose,
    required double totalAmount,
    required List<IssueLineItemsCompanion> lineItems,
    String? remarks,
  }) async {
    return await transaction(() async {
      // Update issue voucher
      final updated = await updateIssue(
        issueId: issueId,
        issueNo: issueNo,
        issueDate: issueDate,
        issuedTo: issuedTo,
        requestedBy: requestedBy,
        purpose: purpose,
        totalAmount: totalAmount,
        remarks: remarks,
      );

      if (!updated) return false;

      // Delete existing line items
      await (delete(issueLineItems)
            ..where((ili) => ili.issueId.equals(issueId)))
          .go();

      // Insert new line items
      for (final item in lineItems) {
        await into(issueLineItems).insert(
          item.copyWith(issueId: Value(issueId)),
        );
      }

      return true;
    });
  }

  // Approve issue voucher (deduct stock)
  Future<void> approveIssue(String issueId) async {
    await transaction(() async {
      final issue = await getIssueById(issueId);
      if (issue == null) {
        throw Exception('Issue voucher not found');
      }

      if (issue.status == 'Approved') {
        throw Exception('Issue voucher already approved');
      }

      final lineItems = await getIssueLineItems(issueId);

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

      // Deduct stock for each line item
      for (final item in lineItems) {
        await _productDao.decreaseStock(item.productId, item.quantity);
      }

      // Update issue status to Approved
      await (update(issueVouchers)..where((iv) => iv.uuid.equals(issueId)))
          .write(IssueVouchersCompanion(
        status: const Value('Approved'),
        lastModified: Value(DateTime.now()),
        isSynced: const Value(false),
      ));
    });
  }

  // Delete issue voucher (only if pending)
  Future<bool> deleteIssue(String issueId) async {
    return await transaction(() async {
      final issue = await getIssueById(issueId);
      if (issue == null) return false;

      if (issue.status == 'Approved') {
        throw Exception('Cannot delete approved issue voucher');
      }

      // Delete line items first
      await (delete(issueLineItems)
            ..where((ili) => ili.issueId.equals(issueId)))
          .go();

      // Delete issue voucher
      final rowsAffected = await (delete(issueVouchers)
            ..where((iv) => iv.uuid.equals(issueId)))
          .go();

      return rowsAffected > 0;
    });
  }

  // Get total issue value by date range
  Future<double> getTotalIssueValueByDateRange(
      DateTime startDate, DateTime endDate) async {
    final query = selectOnly(issueVouchers)
      ..addColumns([issueVouchers.totalAmount.sum()])
      ..where(issueVouchers.issueDate.isBiggerOrEqualValue(startDate) &
          issueVouchers.issueDate.isSmallerOrEqualValue(endDate) &
          issueVouchers.status.equals('Approved'));

    final result = await query.getSingle();
    return result.read(issueVouchers.totalAmount.sum()) ?? 0.0;
  }

  // Get issues by department/issued to
  Future<List<IssueVoucher>> getIssuesByDepartment(String department) async {
    return await (select(issueVouchers)
          ..where((iv) => iv.issuedTo.equals(department))
          ..orderBy([
            (iv) => OrderingTerm.desc(iv.issueDate),
          ]))
        .get();
  }

  // Get issues by date range
  Future<List<IssueVoucher>> getIssuesByDateRange(
      DateTime startDate, DateTime endDate) async {
    return await (select(issueVouchers)
          ..where((iv) =>
              iv.issueDate.isBiggerOrEqualValue(startDate) &
              iv.issueDate.isSmallerOrEqualValue(endDate))
          ..orderBy([
            (iv) => OrderingTerm.desc(iv.issueDate),
          ]))
        .get();
  }

  // Get most issued products (top N)
  Future<List<Map<String, dynamic>>> getMostIssuedProducts(
      {int limit = 10}) async {
    // This requires a join with products table and aggregation
    // For now, return a simple aggregation by productId
    final query = selectOnly(issueLineItems)
      ..addColumns([
        issueLineItems.productId,
        issueLineItems.quantity.sum(),
      ])
      ..groupBy([issueLineItems.productId])
      ..orderBy([OrderingTerm.desc(issueLineItems.quantity.sum())])
      ..limit(limit);

    final results = await query.get();
    return results.map((row) {
      return {
        'productId': row.read(issueLineItems.productId),
        'totalQuantity': row.read(issueLineItems.quantity.sum()) ?? 0.0,
      };
    }).toList();
  }

  // Get next issue number (auto-increment helper)
  Future<String> getNextIssueNo() async {
    final lastIssue = await (select(issueVouchers)
          ..orderBy([
            (iv) => OrderingTerm.desc(iv.createdAt),
          ])
          ..limit(1))
        .getSingleOrNull();

    if (lastIssue == null) {
      return 'ISS-0001';
    }

    // Extract number from last issue number (e.g., ISS-0001 -> 1)
    final lastNo = lastIssue.issueNo;
    final match = RegExp(r'\d+$').firstMatch(lastNo);
    if (match != null) {
      final num = int.parse(match.group(0)!);
      return 'ISS-${(num + 1).toString().padLeft(4, '0')}';
    }

    return 'ISS-0001';
  }

  // ============================================================================
  // SYNC METHODS
  // ============================================================================

  // Get all unsynced issue vouchers
  Future<List<IssueVoucher>> getUnsyncedIssues() {
    return (select(issueVouchers)..where((iv) => iv.isSynced.equals(false))).get();
  }

  // Get issue vouchers modified since a specific timestamp
  Future<List<IssueVoucher>> getIssuesSince(DateTime since) {
    return (select(issueVouchers)
          ..where((iv) => iv.lastModified.isBiggerOrEqualValue(since))
          ..orderBy([(iv) => OrderingTerm.asc(iv.lastModified)]))
        .get();
  }

  // Mark issue voucher as synced
  Future<int> markIssueAsSynced(String uuid) {
    return (update(issueVouchers)..where((iv) => iv.uuid.equals(uuid)))
        .write(IssueVouchersCompanion(
      isSynced: const Value(true),
    ));
  }

  // Mark multiple issue vouchers as synced
  Future<void> markIssuesAsSynced(List<String> uuids) async {
    for (final uuid in uuids) {
      await markIssueAsSynced(uuid);
    }
  }

  // Upsert issue voucher from server (insert or update)
  Future<int> upsertIssueFromServer(IssueVouchersCompanion issue) async {
    return into(issueVouchers).insertOnConflictUpdate(issue);
  }

  // Batch upsert issue vouchers from server
  Future<void> batchUpsertIssues(List<IssueVouchersCompanion> issueList) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(issueVouchers, issueList);
    });
  }

  // Get issue line items modified since a specific timestamp
  Future<List<IssueLineItem>> getIssueLineItemsSince(DateTime since) {
    return (select(issueLineItems)
          ..where((li) => li.lastModified.isBiggerOrEqualValue(since))
          ..orderBy([(li) => OrderingTerm.asc(li.lastModified)]))
        .get();
  }

  // Upsert issue line item from server
  Future<int> upsertIssueLineItemFromServer(IssueLineItemsCompanion lineItem) async {
    return into(issueLineItems).insertOnConflictUpdate(lineItem);
  }

  // Batch upsert issue line items from server
  Future<void> batchUpsertIssueLineItems(List<IssueLineItemsCompanion> lineItemList) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(issueLineItems, lineItemList);
    });
  }

  // Get issue voucher by UUID for sync conflict detection
  Future<IssueVoucher?> getIssueForSync(String uuid) {
    return (select(issueVouchers)..where((iv) => iv.uuid.equals(uuid))).getSingleOrNull();
  }
}
