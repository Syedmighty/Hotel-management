import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotel_inventory_management/config/router.dart';
import 'package:hotel_inventory_management/config/theme.dart';
import 'package:hotel_inventory_management/db/app_database.dart';
import 'package:hotel_inventory_management/services/backup_service.dart';
import 'package:hotel_inventory_management/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database
  final database = AppDatabase();

  // Initialize notifications
  await NotificationService().initialize();

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
        debugPrint('Auto-backup created: ${backupFile.path}');
      }
    }
  } catch (e) {
    // Log error but don't block app startup
    debugPrint('Auto-backup failed: $e');
  }
}

/// Check for low stock items and send notifications
Future<void> _checkLowStockItems(AppDatabase database) async {
  try {
    final notificationService = NotificationService();

    // Get all stock items
    final stockItems = await database.stockItemDao.getAllStockItems();

    // Check each item for low stock
    for (final item in stockItems) {
      if (item.currentStock < item.minStock) {
        await notificationService.showLowStockNotification(
          itemName: item.itemName,
          currentStock: item.currentStock,
          minStock: item.minStock,
          unit: item.unit,
        );
        debugPrint(
            'Low stock alert: ${item.itemName} (${item.currentStock} ${item.unit})');
      }
    }
  } catch (e) {
    // Log error but don't block app startup
    debugPrint('Low stock check failed: $e');
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
