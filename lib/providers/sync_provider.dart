import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotel_inventory_management/db/daos/sync_dao.dart';
import 'package:hotel_inventory_management/main.dart';
import 'package:hotel_inventory_management/services/sync_service.dart';

// SyncDao provider
final syncDaoProvider = Provider<SyncDao>((ref) {
  final database = ref.watch(databaseProvider);
  return SyncDao(database);
});

// SyncService provider
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService();
});

// Sync status provider
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.statusStream;
});

// Server info provider
final serverInfoProvider = StreamProvider<ServerInfo?>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.serverInfoStream;
});

// Unresolved conflicts count provider
final unresolvedConflictsCountProvider = FutureProvider<int>((ref) async {
  final syncDao = ref.watch(syncDaoProvider);
  return syncDao.getUnresolvedConflictsCount();
});

// Unresolved conflicts provider
final unresolvedConflictsProvider = FutureProvider((ref) async {
  final syncDao = ref.watch(syncDaoProvider);
  return syncDao.getUnresolvedConflicts();
});

// Watch unresolved conflicts count (stream)
final watchUnresolvedConflictsCountProvider = StreamProvider<int>((ref) {
  final syncDao = ref.watch(syncDaoProvider);
  return syncDao.watchUnresolvedConflictsCount();
});

// Sync queue count provider
final syncQueueCountProvider = FutureProvider<int>((ref) async {
  final syncDao = ref.watch(syncDaoProvider);
  return syncDao.getSyncQueueCount();
});
