import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/app_database.dart';

/// Provider for the AppDatabase instance
///
/// This provider is overridden in main.dart with the actual database instance.
/// All other providers that need database access should watch this provider.
///
/// Example usage:
/// ```dart
/// final myDaoProvider = Provider<MyDao>((ref) {
///   final database = ref.watch(databaseProvider);
///   return MyDao(database);
/// });
/// ```
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError(
    'databaseProvider must be overridden in main.dart with the actual database instance',
  );
});
