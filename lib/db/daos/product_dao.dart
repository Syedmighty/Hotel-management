import 'package:drift/drift.dart';
import 'package:hotel_inventory_management/db/app_database.dart';

part 'product_dao.g.dart';

@DriftAccessor(tables: [Products])
class ProductDao extends DatabaseAccessor<AppDatabase> with _$ProductDaoMixin {
  ProductDao(AppDatabase db) : super(db);

  // Get all products
  Future<List<Product>> getAllProducts() {
    return (select(products)
          ..where((p) => p.isActive.equals(true))
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .get();
  }

  // Get product by UUID
  Future<Product?> getProductById(String uuid) {
    return (select(products)..where((p) => p.uuid.equals(uuid))).getSingleOrNull();
  }

  // Get product by barcode
  Future<Product?> getProductByBarcode(String barcode) {
    return (select(products)..where((p) => p.barcode.equals(barcode)))
        .getSingleOrNull();
  }

  // Search products by name or category
  Future<List<Product>> searchProducts(String query) {
    final searchQuery = '%$query%';
    return (select(products)
          ..where((p) =>
              p.isActive.equals(true) &
              (p.name.like(searchQuery) | p.category.like(searchQuery))))
        .get();
  }

  // Get products by category
  Future<List<Product>> getProductsByCategory(String category) {
    return (select(products)
          ..where((p) => p.category.equals(category) & p.isActive.equals(true))
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .get();
  }

  // Get low stock products
  Future<List<Product>> getLowStockProducts() {
    return (select(products)
          ..where((p) =>
              p.isActive.equals(true) &
              p.currentStock.isSmallerOrEqualValue(p.reorderLevel))
          ..orderBy([(p) => OrderingTerm.asc(p.currentStock)]))
        .get();
  }

  // Get out of stock products
  Future<List<Product>> getOutOfStockProducts() {
    return (select(products)
          ..where((p) => p.isActive.equals(true) & p.currentStock.equals(0.0))
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .get();
  }

  // Get products with expiry tracking
  Future<List<Product>> getProductsWithExpiryTracking() {
    return (select(products)
          ..where((p) => p.isActive.equals(true) & p.batchTracking.equals(true))
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .get();
  }

  // Get expiring products (within next 30 days)
  Future<List<Product>> getExpiringProducts() {
    final thirtyDaysFromNow = DateTime.now().add(const Duration(days: 30));
    return (select(products)
          ..where((p) =>
              p.isActive.equals(true) &
              p.expiryDate.isSmallerThanValue(thirtyDaysFromNow) &
              p.expiryDate.isBiggerThanValue(DateTime.now())))
        .get();
  }

  // Create product
  Future<int> createProduct(ProductsCompanion product) {
    return into(products).insert(product);
  }

  // Update product
  Future<bool> updateProduct(Product product) {
    return update(products).replace(product);
  }

  // Update product stock
  Future<int> updateProductStock(String uuid, double newStock) {
    return (update(products)..where((p) => p.uuid.equals(uuid)))
        .write(ProductsCompanion(
      currentStock: Value(newStock),
      lastModified: Value(DateTime.now()),
    ));
  }

  // Increase product stock (for purchases)
  Future<int> increaseStock(String uuid, double quantity) async {
    final product = await getProductById(uuid);
    if (product == null) return 0;

    final newStock = product.currentStock + quantity;
    return updateProductStock(uuid, newStock);
  }

  // Decrease product stock (for issues/wastage)
  Future<int> decreaseStock(String uuid, double quantity) async {
    final product = await getProductById(uuid);
    if (product == null) return 0;

    final newStock = (product.currentStock - quantity).clamp(0.0, double.infinity);
    return updateProductStock(uuid, newStock);
  }

  // Delete product (soft delete)
  Future<int> deleteProduct(String uuid) {
    return (update(products)..where((p) => p.uuid.equals(uuid)))
        .write(ProductsCompanion(
      isActive: const Value(false),
      lastModified: Value(DateTime.now()),
    ));
  }

  // Restore deleted product
  Future<int> restoreProduct(String uuid) {
    return (update(products)..where((p) => p.uuid.equals(uuid)))
        .write(ProductsCompanion(
      isActive: const Value(true),
      lastModified: Value(DateTime.now()),
    ));
  }

  // Get total inventory value
  Future<double> getTotalInventoryValue() async {
    final allProducts = await getAllProducts();
    return allProducts.fold(
      0.0,
      (sum, product) => sum + (product.currentStock * product.purchaseRate),
    );
  }

  // Get inventory value by category
  Future<Map<String, double>> getInventoryValueByCategory() async {
    final allProducts = await getAllProducts();
    final categoryValues = <String, double>{};

    for (final product in allProducts) {
      final value = product.currentStock * product.purchaseRate;
      categoryValues[product.category] =
          (categoryValues[product.category] ?? 0.0) + value;
    }

    return categoryValues;
  }

  // Get all unique categories
  Future<List<String>> getAllCategories() async {
    final allProducts = await getAllProducts();
    final categories = allProducts.map((p) => p.category).toSet().toList();
    categories.sort();
    return categories;
  }

  // Get products count
  Future<int> getProductsCount() async {
    final count = countAll();
    return (selectOnly(products)
          ..addColumns([count])
          ..where(products.isActive.equals(true)))
        .map((row) => row.read(count)!)
        .getSingle();
  }

  // Watch all products (real-time updates)
  Stream<List<Product>> watchAllProducts() {
    return (select(products)
          ..where((p) => p.isActive.equals(true))
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .watch();
  }

  // Watch product by ID
  Stream<Product?> watchProductById(String uuid) {
    return (select(products)..where((p) => p.uuid.equals(uuid)))
        .watchSingleOrNull();
  }

  // Watch low stock products
  Stream<List<Product>> watchLowStockProducts() {
    return (select(products)
          ..where((p) =>
              p.isActive.equals(true) &
              p.currentStock.isSmallerOrEqualValue(p.reorderLevel))
          ..orderBy([(p) => OrderingTerm.asc(p.currentStock)]))
        .watch();
  }

  // ============================================================================
  // SYNC METHODS
  // ============================================================================

  // Get all unsynced products
  Future<List<Product>> getUnsyncedProducts() {
    return (select(products)..where((p) => p.isSynced.equals(false))).get();
  }

  // Get products modified since a specific timestamp
  Future<List<Product>> getProductsSince(DateTime since) {
    return (select(products)
          ..where((p) => p.lastModified.isBiggerOrEqualValue(since))
          ..orderBy([(p) => OrderingTerm.asc(p.lastModified)]))
        .get();
  }

  // Mark product as synced
  Future<int> markProductAsSynced(String uuid) {
    return (update(products)..where((p) => p.uuid.equals(uuid)))
        .write(ProductsCompanion(
      isSynced: const Value(true),
    ));
  }

  // Mark multiple products as synced
  Future<void> markProductsAsSynced(List<String> uuids) async {
    for (final uuid in uuids) {
      await markProductAsSynced(uuid);
    }
  }

  // Upsert product from server (insert or update)
  Future<int> upsertProductFromServer(ProductsCompanion product) async {
    return into(products).insertOnConflictUpdate(product);
  }

  // Batch upsert products from server
  Future<void> batchUpsertProducts(List<ProductsCompanion> productList) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(products, productList);
    });
  }

  // Get product by UUID for sync conflict detection
  Future<Product?> getProductForSync(String uuid) {
    return (select(products)..where((p) => p.uuid.equals(uuid))).getSingleOrNull();
  }
}
