import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotel_inventory_management/config/router.dart';
import 'package:hotel_inventory_management/config/theme.dart';
import 'package:hotel_inventory_management/db/app_database.dart';
import 'package:hotel_inventory_management/services/backup_service.dart';
import 'package:hotel_inventory_management/services/notification_service.dart';
import 'package:hotel_inventory_management/services/error_service.dart';
import 'package:hotel_inventory_management/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize error handling first (catches all errors)
  ErrorService().initialize();
  ErrorService().logInfo('HIMS Application Starting', data: {
    'timestamp': DateTime.now().toIso8601String(),
  });

  // Initialize database
  final database = AppDatabase();

  // Initialize notifications
  await NotificationService().initialize();

  // Initialize sync service (non-blocking)
  _initializeSyncService(database);

  // Perform auto-backup if due
  _performAutoBackupIfDue();

  // Check for low stock items and send notifications
  _checkLowStockItems(database);

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
      ],
      child: const HIMSApp(),
    ),
  );
}

/// Initialize sync service (runs in background, doesn't block app startup)
Future<void> _initializeSyncService(AppDatabase database) async {
  try {
    ErrorService().logInfo('Initializing SyncService');
    final syncService = SyncService();
    await syncService.initialize(database);
    ErrorService().logInfo('✅ SyncService initialized successfully', data: {
      'discovery_port': SyncService.discoveryPort,
      'sync_interval': '${SyncService.syncInterval.inMinutes} minutes',
    });
  } catch (e, stackTrace) {
    // Log error but don't block app startup
    ErrorService().logError(
      e,
      stackTrace: stackTrace,
      context: 'SyncService Initialization',
    );
    ErrorService().logWarning(
      'App will continue without sync functionality. '
      'Check network connectivity and server availability.',
    );
  }
}

/// Check and perform auto-backup on app startup if due
Future<void> _performAutoBackupIfDue() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final autoBackupEnabled = prefs.getBool('auto_backup') ?? true;
    final backupFrequency = prefs.getString('backup_frequency') ?? 'daily';

    if (autoBackupEnabled) {
      final backupService = BackupService();
      final backupFile = await backupService.performAutoBackupIfDue(
        autoBackupEnabled,
        backupFrequency,
      );

      if (backupFile != null) {
        ErrorService().logInfo('Auto-backup created', data: {
          'file': backupFile.path,
          'frequency': backupFrequency,
        });
      }
    }
  } catch (e, stackTrace) {
    // Log error but don't block app startup
    ErrorService().logError(
      e,
      stackTrace: stackTrace,
      context: 'Auto-Backup on Startup',
    );
  }
}

/// Check for low stock items and send notifications
Future<void> _checkLowStockItems(AppDatabase database) async {
  try {
    final notificationService = NotificationService();

    // Get low stock products (currentStock <= reorderLevel)
    final lowStockProducts = await database.productDao.getLowStockProducts();

    int lowStockCount = 0;
    // Send notification for each low stock item
    for (final product in lowStockProducts) {
      await notificationService.showLowStockNotification(
        itemName: product.name,
        currentStock: product.currentStock,
        minStock: product.reorderLevel,
        unit: product.unit,
      );
      lowStockCount++;
    }

    if (lowStockCount > 0) {
      ErrorService().logWarning('Low stock items detected', data: {
        'count': lowStockCount,
        'items': lowStockProducts.map((p) => p.name).take(5).toList(),
      });
    } else {
      ErrorService().logInfo('All stock levels are adequate');
    }
  } catch (e, stackTrace) {
    // Log error but don't block app startup
    ErrorService().logError(
      e,
      stackTrace: stackTrace,
      context: 'Low Stock Check on Startup',
    );
  }
}

// Database provider
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError();
});

class HIMSApp extends ConsumerWidget {
  const HIMSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Hotel Inventory Management System',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
