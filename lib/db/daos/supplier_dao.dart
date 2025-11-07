import 'package:drift/drift.dart';
import 'package:hotel_inventory_management/db/app_database.dart';

part 'supplier_dao.g.dart';

@DriftAccessor(tables: [Suppliers])
class SupplierDao extends DatabaseAccessor<AppDatabase> with _$SupplierDaoMixin {
  SupplierDao(AppDatabase db) : super(db);

  // Get all suppliers
  Future<List<Supplier>> getAllSuppliers() {
    return (select(suppliers)
          ..where((s) => s.isActive.equals(true))
          ..orderBy([(s) => OrderingTerm.asc(s.name)]))
        .get();
  }

  // Get supplier by UUID
  Future<Supplier?> getSupplierById(String uuid) {
    return (select(suppliers)..where((s) => s.uuid.equals(uuid))).getSingleOrNull();
  }

  // Search suppliers by name or contact
  Future<List<Supplier>> searchSuppliers(String query) {
    final searchQuery = '%$query%';
    return (select(suppliers)
          ..where((s) =>
              s.isActive.equals(true) &
              (s.name.like(searchQuery) |
                  s.contact.like(searchQuery) |
                  s.gstin.like(searchQuery))))
        .get();
  }

  // Get suppliers with outstanding balance
  Future<List<Supplier>> getSuppliersWithBalance() {
    return (select(suppliers)
          ..where((s) => s.isActive.equals(true) & s.balance.isBiggerThanValue(0))
          ..orderBy([(s) => OrderingTerm.desc(s.balance)]))
        .get();
  }

  // Get total outstanding balance
  Future<double> getTotalOutstandingBalance() async {
    final allSuppliers = await getAllSuppliers();
    return allSuppliers.fold(
      0.0,
      (sum, supplier) => sum + supplier.balance,
    );
  }

  // Create supplier
  Future<int> createSupplier(SuppliersCompanion supplier) {
    return into(suppliers).insert(supplier);
  }

  // Update supplier
  Future<bool> updateSupplier(Supplier supplier) {
    return update(suppliers).replace(supplier);
  }

  // Update supplier balance
  Future<int> updateSupplierBalance(String uuid, double newBalance) {
    return (update(suppliers)..where((s) => s.uuid.equals(uuid)))
        .write(SuppliersCompanion(
      balance: Value(newBalance),
      lastModified: Value(DateTime.now()),
    ));
  }

  // Add to supplier balance (for credit purchases)
  Future<int> addToBalance(String uuid, double amount) async {
    final supplier = await getSupplierById(uuid);
    if (supplier == null) return 0;

    final newBalance = supplier.balance + amount;
    return updateSupplierBalance(uuid, newBalance);
  }

  // Subtract from supplier balance (for payments)
  Future<int> subtractFromBalance(String uuid, double amount) async {
    final supplier = await getSupplierById(uuid);
    if (supplier == null) return 0;

    final newBalance = (supplier.balance - amount).clamp(0.0, double.infinity);
    return updateSupplierBalance(uuid, newBalance);
  }

  // Delete supplier (soft delete)
  Future<int> deleteSupplier(String uuid) {
    return (update(suppliers)..where((s) => s.uuid.equals(uuid)))
        .write(SuppliersCompanion(
      isActive: const Value(false),
      lastModified: Value(DateTime.now()),
    ));
  }

  // Restore deleted supplier
  Future<int> restoreSupplier(String uuid) {
    return (update(suppliers)..where((s) => s.uuid.equals(uuid)))
        .write(SuppliersCompanion(
      isActive: const Value(true),
      lastModified: Value(DateTime.now()),
    ));
  }

  // Get suppliers count
  Future<int> getSuppliersCount() async {
    final count = countAll();
    return (selectOnly(suppliers)
          ..addColumns([count])
          ..where(suppliers.isActive.equals(true)))
        .map((row) => row.read(count)!)
        .getSingle();
  }

  // Watch all suppliers (real-time updates)
  Stream<List<Supplier>> watchAllSuppliers() {
    return (select(suppliers)
          ..where((s) => s.isActive.equals(true))
          ..orderBy([(s) => OrderingTerm.asc(s.name)]))
        .watch();
  }

  // Watch supplier by ID
  Stream<Supplier?> watchSupplierById(String uuid) {
    return (select(suppliers)..where((s) => s.uuid.equals(uuid)))
        .watchSingleOrNull();
  }

  // Watch suppliers with outstanding balance
  Stream<List<Supplier>> watchSuppliersWithBalance() {
    return (select(suppliers)
          ..where((s) => s.isActive.equals(true) & s.balance.isBiggerThanValue(0))
          ..orderBy([(s) => OrderingTerm.desc(s.balance)]))
        .watch();
  }

  // ============================================================================
  // SYNC METHODS
  // ============================================================================

  // Get all unsynced suppliers
  Future<List<Supplier>> getUnsyncedSuppliers() {
    return (select(suppliers)..where((s) => s.isSynced.equals(false))).get();
  }

  // Get suppliers modified since a specific timestamp
  Future<List<Supplier>> getSuppliersSince(DateTime since) {
    return (select(suppliers)
          ..where((s) => s.lastModified.isBiggerOrEqualValue(since))
          ..orderBy([(s) => OrderingTerm.asc(s.lastModified)]))
        .get();
  }

  // Mark supplier as synced
  Future<int> markSupplierAsSynced(String uuid) {
    return (update(suppliers)..where((s) => s.uuid.equals(uuid)))
        .write(SuppliersCompanion(
      isSynced: const Value(true),
    ));
  }

  // Mark multiple suppliers as synced
  Future<void> markSuppliersAsSynced(List<String> uuids) async {
    for (final uuid in uuids) {
      await markSupplierAsSynced(uuid);
    }
  }

  // Upsert supplier from server (insert or update)
  Future<int> upsertSupplierFromServer(SuppliersCompanion supplier) async {
    return into(suppliers).insertOnConflictUpdate(supplier);
  }

  // Batch upsert suppliers from server
  Future<void> batchUpsertSuppliers(List<SuppliersCompanion> supplierList) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(suppliers, supplierList);
    });
  }

  // Get supplier by UUID for sync conflict detection
  Future<Supplier?> getSupplierForSync(String uuid) {
    return (select(suppliers)..where((s) => s.uuid.equals(uuid))).getSingleOrNull();
  }
}
