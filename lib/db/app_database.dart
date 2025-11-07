import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:hotel_inventory_management/utils/password_hasher.dart';
import 'package:hotel_inventory_management/db/daos/product_dao.dart';
import 'package:hotel_inventory_management/db/daos/supplier_dao.dart';
import 'package:hotel_inventory_management/db/daos/purchase_dao.dart';
import 'package:hotel_inventory_management/db/daos/issue_dao.dart';
import 'package:hotel_inventory_management/db/daos/sync_dao.dart';

part 'app_database.g.dart';

// ============================================================================
// PRODUCTS TABLE
// ============================================================================
@DataClassName('Product')
class Products extends Table {
  TextColumn get uuid => text()();
  TextColumn get name => text()();
  TextColumn get category => text()();
  TextColumn get unit => text()(); // kg, litre, piece, etc.
  RealColumn get unitConversion => real().withDefault(const Constant(1.0))();
  RealColumn get gstPercent => real().withDefault(const Constant(0.0))();
  RealColumn get purchaseRate => real()();
  RealColumn get sellingRate => real()();
  RealColumn get openingStock => real().withDefault(const Constant(0.0))();
  RealColumn get currentStock => real().withDefault(const Constant(0.0))();
  RealColumn get reorderLevel => real().withDefault(const Constant(0.0))();
  BoolColumn get batchTracking => boolean().withDefault(const Constant(false))();
  TextColumn get barcode => text().nullable()(); // Added for barcode scanning
  DateTimeColumn get expiryDate => dateTime().nullable()();
  DateTimeColumn get lastModified => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get sourceDevice => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {uuid};
}

// ============================================================================
// SUPPLIERS TABLE
// ============================================================================
@DataClassName('Supplier')
class Suppliers extends Table {
  TextColumn get uuid => text()();
  TextColumn get name => text()();
  TextColumn get contact => text()();
  TextColumn get gstin => text().nullable()();
  TextColumn get address => text()();
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  DateTimeColumn get lastModified => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get sourceDevice => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {uuid};
}

// ============================================================================
// PURCHASE ENTRIES (GRN - Goods Receipt Note)
// ============================================================================
@DataClassName('Purchase')
class Purchases extends Table {
  TextColumn get uuid => text()();
  TextColumn get supplierId => text().references(Suppliers, #uuid)();
  TextColumn get invoiceNo => text()();
  DateTimeColumn get purchaseDate => dateTime()();
  RealColumn get totalAmount => real()();
  TextColumn get paymentMode => text()(); // Cash, Credit, UPI, etc.
  TextColumn get batchNo => text().nullable()();
  TextColumn get receivedBy => text()();
  TextColumn get status => text().withDefault(const Constant('Pending'))(); // Pending, Approved
  TextColumn get remarks => text().nullable()();
  DateTimeColumn get lastModified => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get sourceDevice => text()();

  @override
  Set<Column> get primaryKey => {uuid};
}

// ============================================================================
// PURCHASE LINE ITEMS (Normalized)
// ============================================================================
@DataClassName('PurchaseLineItem')
class PurchaseLineItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get purchaseId => text().references(Purchases, #uuid, onDelete: KeyAction.cascade)();
  TextColumn get productId => text().references(Products, #uuid)();
  RealColumn get quantity => real()();
  RealColumn get rate => real()();
  RealColumn get gstPercent => real()();
  TextColumn get batchNo => text().nullable()();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  RealColumn get amount => real()(); // qty * rate
  RealColumn get gstAmount => real()(); // calculated GST
  RealColumn get totalAmount => real()(); // amount + gstAmount
  DateTimeColumn get lastModified => dateTime()();
}

// ============================================================================
// ISSUE VOUCHERS (Kitchen/Department Issues)
// ============================================================================
@DataClassName('IssueVoucher')
class IssueVouchers extends Table {
  TextColumn get uuid => text()();
  TextColumn get department => text()(); // Chinese Kitchen, Banquet Hall, etc.
  TextColumn get issuedBy => text()();
  TextColumn get receivedBy => text()();
  DateTimeColumn get issueDate => dateTime()();
  TextColumn get approvalStatus => text().withDefault(const Constant('Pending'))(); // Pending, Received
  TextColumn get remarks => text().nullable()();
  DateTimeColumn get lastModified => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get sourceDevice => text()();

  @override
  Set<Column> get primaryKey => {uuid};
}

// ============================================================================
// ISSUE LINE ITEMS (Normalized)
// ============================================================================
@DataClassName('IssueLineItem')
class IssueLineItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get issueId => text().references(IssueVouchers, #uuid, onDelete: KeyAction.cascade)();
  TextColumn get productId => text().references(Products, #uuid)();
  RealColumn get quantity => real()();
  RealColumn get rate => real()(); // For valuation
  RealColumn get amount => real()(); // qty * rate
  TextColumn get batchNo => text().nullable()();
  DateTimeColumn get lastModified => dateTime()();
}

// ============================================================================
// WASTAGE AND RETURNS
// ============================================================================
@DataClassName('WastageReturn')
class WastageReturns extends Table {
  TextColumn get uuid => text()();
  TextColumn get type => text()(); // Wastage, Return
  TextColumn get reason => text()();
  TextColumn get approvedBy => text().nullable()();
  BoolColumn get returnToSupplier => boolean().withDefault(const Constant(false))();
  TextColumn get supplierId => text().nullable().references(Suppliers, #uuid)();
  DateTimeColumn get date => dateTime()();
  TextColumn get remarks => text().nullable()();
  DateTimeColumn get lastModified => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get sourceDevice => text()();

  @override
  Set<Column> get primaryKey => {uuid};
}

// ============================================================================
// WASTAGE/RETURN LINE ITEMS (Normalized)
// ============================================================================
@DataClassName('WastageLineItem')
class WastageLineItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get wastageId => text().references(WastageReturns, #uuid, onDelete: KeyAction.cascade)();
  TextColumn get productId => text().references(Products, #uuid)();
  RealColumn get quantity => real()();
  RealColumn get rate => real()();
  RealColumn get amount => real()();
  TextColumn get batchNo => text().nullable()();
  DateTimeColumn get lastModified => dateTime()();
}

// ============================================================================
// STOCK ADJUSTMENTS (Manual corrections)
// ============================================================================
@DataClassName('StockAdjustment')
class StockAdjustments extends Table {
  TextColumn get uuid => text()();
  TextColumn get productId => text().references(Products, #uuid)();
  RealColumn get adjustmentQty => real()(); // Can be positive or negative
  RealColumn get oldStock => real()();
  RealColumn get newStock => real()();
  TextColumn get reason => text()();
  TextColumn get adjustedBy => text()();
  TextColumn get approvedBy => text().nullable()();
  DateTimeColumn get adjustmentDate => dateTime()();
  DateTimeColumn get lastModified => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get sourceDevice => text()();

  @override
  Set<Column> get primaryKey => {uuid};
}

// ============================================================================
// STOCK TRANSFERS (Between departments/locations)
// ============================================================================
@DataClassName('StockTransfer')
class StockTransfers extends Table {
  TextColumn get uuid => text()();
  TextColumn get fromLocation => text()();
  TextColumn get toLocation => text()();
  TextColumn get transferredBy => text()();
  TextColumn get receivedBy => text().nullable()();
  DateTimeColumn get transferDate => dateTime()();
  TextColumn get status => text().withDefault(const Constant('Pending'))(); // Pending, Received
  TextColumn get remarks => text().nullable()();
  DateTimeColumn get lastModified => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get sourceDevice => text()();

  @override
  Set<Column> get primaryKey => {uuid};
}

// ============================================================================
// STOCK TRANSFER LINE ITEMS
// ============================================================================
@DataClassName('StockTransferLineItem')
class StockTransferLineItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get transferId => text().references(StockTransfers, #uuid, onDelete: KeyAction.cascade)();
  TextColumn get productId => text().references(Products, #uuid)();
  RealColumn get quantity => real()();
  RealColumn get rate => real()();
  TextColumn get batchNo => text().nullable()();
  DateTimeColumn get lastModified => dateTime()();
}

// ============================================================================
// PHYSICAL STOCK AUDITS
// ============================================================================
@DataClassName('PhysicalCount')
class PhysicalCounts extends Table {
  TextColumn get uuid => text()();
  DateTimeColumn get countDate => dateTime()();
  TextColumn get countedBy => text()();
  TextColumn get verifiedBy => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('In Progress'))(); // In Progress, Completed
  TextColumn get remarks => text().nullable()();
  DateTimeColumn get lastModified => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get sourceDevice => text()();

  @override
  Set<Column> get primaryKey => {uuid};
}

// ============================================================================
// PHYSICAL COUNT LINE ITEMS
// ============================================================================
@DataClassName('PhysicalCountLineItem')
class PhysicalCountLineItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get countId => text().references(PhysicalCounts, #uuid, onDelete: KeyAction.cascade)();
  TextColumn get productId => text().references(Products, #uuid)();
  RealColumn get systemStock => real()();
  RealColumn get physicalStock => real()();
  RealColumn get variance => real()(); // physical - system
  TextColumn get remarks => text().nullable()();
  DateTimeColumn get lastModified => dateTime()();
}

// ============================================================================
// RECIPES (for menu costing)
// ============================================================================
@DataClassName('Recipe')
class Recipes extends Table {
  TextColumn get uuid => text()();
  TextColumn get dishName => text()();
  TextColumn get category => text()(); // Appetizer, Main Course, Dessert, etc.
  IntColumn get servingSize => integer().withDefault(const Constant(1))();
  RealColumn get sellingPrice => real()();
  RealColumn get costPerServing => real().withDefault(const Constant(0.0))(); // Auto-calculated
  TextColumn get instructions => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  DateTimeColumn get lastModified => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get sourceDevice => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {uuid};
}

// ============================================================================
// RECIPE INGREDIENTS (line items)
// ============================================================================
@DataClassName('RecipeIngredient')
class RecipeIngredients extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get recipeId => text().references(Recipes, #uuid, onDelete: KeyAction.cascade)();
  TextColumn get productId => text().references(Products, #uuid)();
  RealColumn get quantity => real()();
  TextColumn get unit => text()();
  RealColumn get cost => real().withDefault(const Constant(0.0))(); // Auto-calculated from product rate
  DateTimeColumn get lastModified => dateTime()();
}

// ============================================================================
// USERS & ROLES
// ============================================================================
@DataClassName('User')
class Users extends Table {
  TextColumn get userId => text()();
  TextColumn get username => text()();
  TextColumn get passwordHash => text()(); // bcrypt hash
  TextColumn get role => text()(); // Admin, Storekeeper, Chef, Accountant, Auditor
  TextColumn get permissions => text()(); // JSON string
  TextColumn get deviceId => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastLogin => dateTime().nullable()();
  DateTimeColumn get lastModified => dateTime()();

  @override
  Set<Column> get primaryKey => {userId};
}

// ============================================================================
// SYSTEM SETTINGS
// ============================================================================
@DataClassName('Setting')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get lastModified => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

// ============================================================================
// SYNC QUEUE (Pending sync operations)
// ============================================================================
@DataClassName('SyncQueueItem')
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tableName => text()();
  TextColumn get recordId => text()();
  TextColumn get operation => text()(); // INSERT, UPDATE, DELETE
  TextColumn get data => text()(); // JSON payload
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get errorMsg => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastAttempt => dateTime().nullable()();
}

// ============================================================================
// SYNC CONFLICT LOG
// ============================================================================
@DataClassName('ConflictLog')
class ConflictLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tableName => text()();
  TextColumn get recordId => text()();
  TextColumn get clientData => text()(); // JSON
  TextColumn get serverData => text()(); // JSON
  TextColumn get resolution => text().nullable()(); // How it was resolved
  TextColumn get resolvedBy => text().nullable()();
  DateTimeColumn get conflictDate => dateTime()();
  DateTimeColumn get resolvedDate => dateTime().nullable()();
  BoolColumn get isResolved => boolean().withDefault(const Constant(false))();
}

// ============================================================================
// PRINT LOGS
// ============================================================================
@DataClassName('PrintLog')
class PrintLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get documentType => text()(); // GRN, Issue, Report
  TextColumn get documentId => text()();
  TextColumn get printerType => text()(); // A4, Thermal
  TextColumn get printerName => text().nullable()();
  TextColumn get copyLabel => text()(); // Store Copy, Manager Copy
  TextColumn get printedBy => text()();
  TextColumn get status => text()(); // Success, Failed
  TextColumn get errorMsg => text().nullable()();
  DateTimeColumn get printedAt => dateTime()();
}

// ============================================================================
// AUTO REPORT SETTINGS
// ============================================================================
@DataClassName('AutoReportSetting')
class AutoReportSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get reportType => text()(); // Daily Summary, Stock Alert, etc.
  TextColumn get schedule => text()(); // Cron expression or time
  TextColumn get recipients => text()(); // JSON array of emails/phones
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastRun => dateTime().nullable()();
  DateTimeColumn get nextRun => dateTime().nullable()();
}

// ============================================================================
// AUTO REPORT LOGS
// ============================================================================
@DataClassName('AutoReportLog')
class AutoReportLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get reportType => text()();
  TextColumn get status => text()(); // Success, Failed
  TextColumn get errorMsg => text().nullable()();
  TextColumn get filePath => text().nullable()();
  DateTimeColumn get generatedAt => dateTime()();
}

// ============================================================================
// EXCEL IMPORT LOGS
// ============================================================================
@DataClassName('ImportLog')
class ImportLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fileName => text()();
  TextColumn get importType => text()(); // Products, Suppliers
  IntColumn get recordsProcessed => integer()();
  IntColumn get recordsSuccess => integer()();
  IntColumn get recordsFailed => integer()();
  TextColumn get errors => text().nullable()(); // JSON array of errors
  TextColumn get importedBy => text()();
  DateTimeColumn get importedAt => dateTime()();
}

// ============================================================================
// SYSTEM LOGS
// ============================================================================
@DataClassName('SystemLog')
class SystemLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get logLevel => text()(); // INFO, WARNING, ERROR
  TextColumn get module => text()();
  TextColumn get message => text()();
  TextColumn get stackTrace => text().nullable()();
  TextColumn get userId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

// ============================================================================
// AUTH LOGS
// ============================================================================
@DataClassName('AuthLog')
class AuthLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userId => text()();
  TextColumn get action => text()(); // Login, Logout, Failed Login
  TextColumn get deviceId => text().nullable()();
  TextColumn get ipAddress => text().nullable()();
  BoolColumn get success => boolean()();
  TextColumn get errorMsg => text().nullable()();
  DateTimeColumn get timestamp => dateTime()();
}

// ============================================================================
// DATABASE CLASS
// ============================================================================
@DriftDatabase(tables: [
  Products,
  Suppliers,
  Purchases,
  PurchaseLineItems,
  IssueVouchers,
  IssueLineItems,
  WastageReturns,
  WastageLineItems,
  StockAdjustments,
  StockTransfers,
  StockTransferLineItems,
  PhysicalCounts,
  PhysicalCountLineItems,
  Recipes,
  RecipeIngredients,
  Users,
  Settings,
  SyncQueue,
  ConflictLogs,
  PrintLogs,
  AutoReportSettings,
  AutoReportLogs,
  ImportLogs,
  SystemLogs,
  AuthLogs,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // ============================================================================
  // DAO GETTERS (Lazy instantiation)
  // ============================================================================

  ProductDao? _productDao;
  ProductDao get productDao => _productDao ??= ProductDao(this);

  SupplierDao? _supplierDao;
  SupplierDao get supplierDao => _supplierDao ??= SupplierDao(this);

  PurchaseDao? _purchaseDao;
  PurchaseDao get purchaseDao => _purchaseDao ??= PurchaseDao(this, productDao, supplierDao);

  IssueDao? _issueDao;
  IssueDao get issueDao => _issueDao ??= IssueDao(this);

  SyncDao? _syncDao;
  SyncDao get syncDao => _syncDao ??= SyncDao(this);

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();

        // Insert default settings
        await into(settings).insert(Setting(
          key: 'stock_valuation_method',
          value: 'FIFO',
          description: 'Stock valuation method: FIFO, LIFO, or Weighted Average',
          lastModified: DateTime.now(),
        ));

        await into(settings).insert(Setting(
          key: 'currency',
          value: 'INR',
          description: 'Currency symbol',
          lastModified: DateTime.now(),
        ));

        await into(settings).insert(Setting(
          key: 'hotel_name',
          value: 'My Hotel',
          description: 'Hotel name for reports',
          lastModified: DateTime.now(),
        ));

        // Create default admin user (password: admin123)
        // IMPORTANT: Change this password after first login!
        final adminPasswordHash = PasswordHasher.hashPassword('admin123');
        await into(users).insert(User(
          userId: 'admin',
          username: 'Administrator',
          passwordHash: adminPasswordHash,
          role: 'Admin',
          permissions: '{"all": true}',
          isActive: true,
          createdAt: DateTime.now(),
          lastModified: DateTime.now(),
        ));
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Handle future schema upgrades
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'hotel_inventory.sqlite'));

    // Make sqlite3 pick a more suitable location for temporary files
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    // Make sqlite3 accessible on iOS
    final cacheBase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cacheBase;

    return NativeDatabase.createInBackground(file);
  });
}
