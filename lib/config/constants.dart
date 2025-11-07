class AppConstants {
  // App Info
  static const String appName = 'Hotel Inventory Management System';
  static const String appVersion = '1.0.0';
  static const String appShortName = 'HIMS';

  // User Roles
  static const String roleAdmin = 'Admin';
  static const String roleStorekeeper = 'Storekeeper';
  static const String roleChef = 'Chef';
  static const String roleAccountant = 'Accountant';
  static const String roleAuditor = 'Auditor';

  // Transaction Status
  static const String statusPending = 'Pending';
  static const String statusApproved = 'Approved';
  static const String statusRejected = 'Rejected';
  static const String statusReceived = 'Received';
  static const String statusInProgress = 'In Progress';
  static const String statusCompleted = 'Completed';

  // Payment Modes
  static const String paymentCash = 'Cash';
  static const String paymentCredit = 'Credit';
  static const String paymentUPI = 'UPI';
  static const String paymentCard = 'Card';
  static const String paymentBankTransfer = 'Bank Transfer';

  // Wastage Types
  static const String typeWastage = 'Wastage';
  static const String typeReturn = 'Return';

  // Stock Valuation Methods
  static const String valuationFIFO = 'FIFO';
  static const String valuationLIFO = 'LIFO';
  static const String valuationWeightedAverage = 'Weighted Average';

  // Units
  static const List<String> units = [
    'kg',
    'g',
    'litre',
    'ml',
    'piece',
    'packet',
    'box',
    'dozen',
    'bundle',
  ];

  // Categories
  static const List<String> productCategories = [
    'Meat',
    'Vegetables',
    'Fruits',
    'Dairy',
    'Spices',
    'Grains',
    'Beverages',
    'Bakery',
    'Frozen Items',
    'Dry Goods',
    'Cleaning Supplies',
    'Other',
  ];

  // Departments
  static const List<String> departments = [
    'Main Kitchen',
    'Chinese Kitchen',
    'Bakery',
    'Banquet Hall',
    'Restaurant',
    'Bar',
    'Room Service',
  ];

  // Wastage Reasons
  static const List<String> wastageReasons = [
    'Spoilage',
    'Expiry',
    'Breakage',
    'Spillage',
    'Contamination',
    'Overproduction',
    'Quality Issue',
    'Pest Infestation',
    'Equipment Failure',
    'Power Outage',
    'Other',
  ];

  // Sync
  static const int syncBatchSize = 100;
  static const Duration syncTimeout = Duration(seconds: 30);
  static const int maxSyncRetries = 3;

  // Pagination
  static const int defaultPageSize = 20;

  // Date Formats
  static const String dateFormat = 'dd/MM/yyyy';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';
  static const String timeFormat = 'HH:mm';

  // Local Storage Keys
  static const String keyCurrentUser = 'current_user';
  static const String keyAuthToken = 'auth_token';
  static const String keyDeviceId = 'device_id';
  static const String keyServerUrl = 'server_url';
  static const String keyLastSyncTime = 'last_sync_time';

  // Printer Types
  static const String printerA4 = 'A4';
  static const String printerThermal = 'Thermal';

  // Document Types
  static const String docTypePurchase = 'Purchase';
  static const String docTypeIssue = 'Issue';
  static const String docTypeWastage = 'Wastage';
  static const String docTypeReport = 'Report';

  // Copy Labels
  static const String copyStore = 'Store Copy';
  static const String copyManager = 'Manager Copy';
  static const String copySupplier = 'Supplier Copy';
  static const String copyDepartment = 'Department Copy';

  // Log Levels
  static const String logInfo = 'INFO';
  static const String logWarning = 'WARNING';
  static const String logError = 'ERROR';

  // Notifications
  static const String notifChannelId = 'hims_notifications';
  static const String notifChannelName = 'HIMS Notifications';
  static const String notifChannelDesc = 'Notifications for stock alerts and sync updates';
}
