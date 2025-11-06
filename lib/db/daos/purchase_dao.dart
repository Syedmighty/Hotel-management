import 'package:drift/drift.dart';
import 'package:hotel_inventory_management/db/app_database.dart';
import 'package:hotel_inventory_management/db/daos/product_dao.dart';
import 'package:hotel_inventory_management/db/daos/supplier_dao.dart';

part 'purchase_dao.g.dart';

@DriftAccessor(tables: [Purchases, PurchaseLineItems, Products, Suppliers])
class PurchaseDao extends DatabaseAccessor<AppDatabase> with _$PurchaseDaoMixin {
  final ProductDao _productDao;
  final SupplierDao _supplierDao;

  PurchaseDao(AppDatabase db, this._productDao, this._supplierDao) : super(db);

  // Get all purchases
  Future<List<Purchase>> getAllPurchases() {
    return (select(purchases)..orderBy([(p) => OrderingTerm.desc(p.purchaseDate)])).get();
  }

  // Get purchase by UUID
  Future<Purchase?> getPurchaseById(String uuid) {
    return (select(purchases)..where((p) => p.uuid.equals(uuid))).getSingleOrNull();
  }

  // Get purchase line items for a purchase
  Future<List<PurchaseLineItem>> getPurchaseLineItems(String purchaseId) {
    return (select(purchaseLineItems)
          ..where((li) => li.purchaseId.equals(purchaseId))
          ..orderBy([(li) => OrderingTerm.asc(li.id)]))
        .get();
  }

  // Get purchase with line items
  Future<PurchaseWithItems?> getPurchaseWithItems(String uuid) async {
    final purchase = await getPurchaseById(uuid);
    if (purchase == null) return null;

    final lineItems = await getPurchaseLineItems(uuid);
    return PurchaseWithItems(purchase: purchase, lineItems: lineItems);
  }

  // Search purchases by invoice number or supplier
  Future<List<Purchase>> searchPurchases(String query) async {
    final searchQuery = '%$query%';

    // Get purchases matching invoice number
    final purchasesByInvoice = await (select(purchases)
          ..where((p) => p.invoiceNo.like(searchQuery))
          ..orderBy([(p) => OrderingTerm.desc(p.purchaseDate)]))
        .get();

    // Get suppliers matching query
    final suppliers = await _supplierDao.searchSuppliers(query);
    final supplierIds = suppliers.map((s) => s.uuid).toList();

    if (supplierIds.isEmpty) {
      return purchasesByInvoice;
    }

    // Get purchases by supplier
    final purchasesBySupplier = await (select(purchases)
          ..where((p) => p.supplierId.isIn(supplierIds))
          ..orderBy([(p) => OrderingTerm.desc(p.purchaseDate)]))
        .get();

    // Combine and deduplicate
    final allPurchases = {...purchasesByInvoice, ...purchasesBySupplier}.toList();
    allPurchases.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));

    return allPurchases;
  }

  // Get purchases by status
  Future<List<Purchase>> getPurchasesByStatus(String status) {
    return (select(purchases)
          ..where((p) => p.status.equals(status))
          ..orderBy([(p) => OrderingTerm.desc(p.purchaseDate)]))
        .get();
  }

  // Get purchases by date range
  Future<List<Purchase>> getPurchasesByDateRange(DateTime start, DateTime end) {
    return (select(purchases)
          ..where((p) =>
              p.purchaseDate.isBiggerOrEqualValue(start) &
              p.purchaseDate.isSmallerOrEqualValue(end))
          ..orderBy([(p) => OrderingTerm.desc(p.purchaseDate)]))
        .get();
  }

  // Get purchases by supplier
  Future<List<Purchase>> getPurchasesBySupplier(String supplierId) {
    return (select(purchases)
          ..where((p) => p.supplierId.equals(supplierId))
          ..orderBy([(p) => OrderingTerm.desc(p.purchaseDate)]))
        .get();
  }

  // Create purchase with line items (transaction)
  Future<String> createPurchaseWithItems({
    required PurchasesCompanion purchase,
    required List<PurchaseLineItemsCompanion> lineItems,
  }) async {
    return await transaction(() async {
      // Insert purchase
      final purchaseId = await into(purchases).insert(purchase);
      final purchaseUuid = purchase.uuid.value;

      // Insert line items
      for (final item in lineItems) {
        await into(purchaseLineItems).insert(item);
      }

      return purchaseUuid;
    });
  }

  // Update purchase
  Future<bool> updatePurchase(Purchase purchase) {
    return update(purchases).replace(purchase);
  }

  // Delete purchase line item
  Future<int> deletePurchaseLineItem(int lineItemId) {
    return (delete(purchaseLineItems)..where((li) => li.id.equals(lineItemId))).go();
  }

  // Approve purchase (update stock and supplier balance)
  Future<void> approvePurchase(String purchaseId) async {
    await transaction(() async {
      final purchase = await getPurchaseById(purchaseId);
      if (purchase == null) throw Exception('Purchase not found');

      if (purchase.status == 'Approved') {
        throw Exception('Purchase already approved');
      }

      final lineItems = await getPurchaseLineItems(purchaseId);

      // Update stock for each line item
      for (final item in lineItems) {
        await _productDao.increaseStock(item.productId, item.quantity);
      }

      // Update supplier balance if credit purchase
      if (purchase.paymentMode == 'Credit') {
        await _supplierDao.addToBalance(purchase.supplierId, purchase.totalAmount);
      }

      // Update purchase status
      await (update(purchases)..where((p) => p.uuid.equals(purchaseId)))
          .write(PurchasesCompanion(
        status: const Value('Approved'),
        lastModified: Value(DateTime.now()),
      ));
    });
  }

  // Delete purchase (and line items via cascade)
  Future<int> deletePurchase(String uuid) {
    return (delete(purchases)..where((p) => p.uuid.equals(uuid))).go();
  }

  // Get total purchase amount by date range
  Future<double> getTotalPurchaseAmount(DateTime start, DateTime end) async {
    final purchaseList = await getPurchasesByDateRange(start, end);
    return purchaseList.fold(
      0.0,
      (sum, purchase) => sum + purchase.totalAmount,
    );
  }

  // Get purchases count
  Future<int> getPurchasesCount() async {
    final count = countAll();
    return (selectOnly(purchases)..addColumns([count]))
        .map((row) => row.read(count)!)
        .getSingle();
  }

  // Get pending purchases count
  Future<int> getPendingPurchasesCount() async {
    final count = countAll();
    return (selectOnly(purchases)
          ..addColumns([count])
          ..where(purchases.status.equals('Pending')))
        .map((row) => row.read(count)!)
        .getSingle();
  }

  // Watch all purchases (real-time updates)
  Stream<List<Purchase>> watchAllPurchases() {
    return (select(purchases)..orderBy([(p) => OrderingTerm.desc(p.purchaseDate)])).watch();
  }

  // Watch purchase by ID
  Stream<Purchase?> watchPurchaseById(String uuid) {
    return (select(purchases)..where((p) => p.uuid.equals(uuid))).watchSingleOrNull();
  }

  // Watch purchase line items
  Stream<List<PurchaseLineItem>> watchPurchaseLineItems(String purchaseId) {
    return (select(purchaseLineItems)
          ..where((li) => li.purchaseId.equals(purchaseId))
          ..orderBy([(li) => OrderingTerm.asc(li.id)]))
        .watch();
  }

  // Watch pending purchases
  Stream<List<Purchase>> watchPendingPurchases() {
    return (select(purchases)
          ..where((p) => p.status.equals('Pending'))
          ..orderBy([(p) => OrderingTerm.desc(p.purchaseDate)]))
        .watch();
  }
}

// Helper class for purchase with line items
class PurchaseWithItems {
  final Purchase purchase;
  final List<PurchaseLineItem> lineItems;

  PurchaseWithItems({
    required this.purchase,
    required this.lineItems,
  });

  double get totalItems => lineItems.fold(0.0, (sum, item) => sum + item.quantity);
  double get totalAmount => lineItems.fold(0.0, (sum, item) => sum + item.totalAmount);
}
