import 'package:drift/drift.dart';
import 'package:hotel_inventory_management/db/app_database.dart';

part 'sync_dao.g.dart';

@DriftAccessor(tables: [SyncQueue, ConflictLogs])
class SyncDao extends DatabaseAccessor<AppDatabase> with _$SyncDaoMixin {
  SyncDao(AppDatabase db) : super(db);

  // ============================================================================
  // SYNC QUEUE METHODS
  // ============================================================================

  // Add item to sync queue
  Future<int> addToSyncQueue({
    required String tableName,
    required String recordId,
    required String operation, // INSERT, UPDATE, DELETE
    required String data, // JSON payload
  }) {
    return into(syncQueue).insert(SyncQueueCompanion.insert(
      tableName: tableName,
      recordId: recordId,
      operation: operation,
      data: data,
      createdAt: DateTime.now(),
    ));
  }

  // Get all pending sync queue items
  Future<List<SyncQueueItem>> getPendingSyncItems() {
    return (select(syncQueue)
          ..orderBy([(sq) => OrderingTerm.asc(sq.createdAt)]))
        .get();
  }

  // Get pending sync items by table
  Future<List<SyncQueueItem>> getPendingSyncItemsByTable(String tableName) {
    return (select(syncQueue)
          ..where((sq) => sq.tableName.equals(tableName))
          ..orderBy([(sq) => OrderingTerm.asc(sq.createdAt)]))
        .get();
  }

  // Remove item from sync queue after successful sync
  Future<int> removeSyncQueueItem(int id) {
    return (delete(syncQueue)..where((sq) => sq.id.equals(id))).go();
  }

  // Increment retry count for a sync queue item
  Future<int> incrementRetryCount(int id, String errorMsg) {
    return (update(syncQueue)..where((sq) => sq.id.equals(id)))
        .write(SyncQueueCompanion(
      retryCount: Value((select(syncQueue)
                ..where((sq) => sq.id.equals(id)))
              .getSingle()
              .then((item) => item.retryCount + 1) as int),
      errorMsg: Value(errorMsg),
      lastAttempt: Value(DateTime.now()),
    ));
  }

  // Clear all sync queue items
  Future<int> clearSyncQueue() {
    return delete(syncQueue).go();
  }

  // Get sync queue count
  Future<int> getSyncQueueCount() async {
    final count = countAll();
    return (selectOnly(syncQueue)..addColumns([count]))
        .map((row) => row.read(count)!)
        .getSingle();
  }

  // ============================================================================
  // CONFLICT LOG METHODS
  // ============================================================================

  // Add conflict to log
  Future<int> addConflict({
    required String tableName,
    required String recordId,
    required String clientData, // JSON
    required String serverData, // JSON
  }) {
    return into(conflictLogs).insert(ConflictLogsCompanion.insert(
      tableName: tableName,
      recordId: recordId,
      clientData: clientData,
      serverData: serverData,
      conflictDate: DateTime.now(),
    ));
  }

  // Get all unresolved conflicts
  Future<List<ConflictLog>> getUnresolvedConflicts() {
    return (select(conflictLogs)
          ..where((cl) => cl.isResolved.equals(false))
          ..orderBy([(cl) => OrderingTerm.desc(cl.conflictDate)]))
        .get();
  }

  // Get unresolved conflicts by table
  Future<List<ConflictLog>> getUnresolvedConflictsByTable(String tableName) {
    return (select(conflictLogs)
          ..where((cl) =>
              cl.tableName.equals(tableName) & cl.isResolved.equals(false))
          ..orderBy([(cl) => OrderingTerm.desc(cl.conflictDate)]))
        .get();
  }

  // Get all conflicts (resolved and unresolved)
  Future<List<ConflictLog>> getAllConflicts() {
    return (select(conflictLogs)
          ..orderBy([(cl) => OrderingTerm.desc(cl.conflictDate)]))
        .get();
  }

  // Get conflict by ID
  Future<ConflictLog?> getConflictById(int id) {
    return (select(conflictLogs)..where((cl) => cl.id.equals(id))).getSingleOrNull();
  }

  // Resolve conflict
  Future<int> resolveConflict({
    required int conflictId,
    required String resolution, // 'keep_device', 'use_server', 'manual_merge'
    required String resolvedBy,
  }) {
    return (update(conflictLogs)..where((cl) => cl.id.equals(conflictId)))
        .write(ConflictLogsCompanion(
      resolution: Value(resolution),
      resolvedBy: Value(resolvedBy),
      resolvedDate: Value(DateTime.now()),
      isResolved: const Value(true),
    ));
  }

  // Delete resolved conflicts older than specified days
  Future<int> deleteOldResolvedConflicts(int daysOld) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
    return (delete(conflictLogs)
          ..where((cl) =>
              cl.isResolved.equals(true) &
              cl.resolvedDate.isSmallerThanValue(cutoffDate)))
        .go();
  }

  // Get unresolved conflicts count
  Future<int> getUnresolvedConflictsCount() async {
    final count = countAll();
    return (selectOnly(conflictLogs)
          ..addColumns([count])
          ..where(conflictLogs.isResolved.equals(false)))
        .map((row) => row.read(count)!)
        .getSingle();
  }

  // Watch unresolved conflicts (stream)
  Stream<List<ConflictLog>> watchUnresolvedConflicts() {
    return (select(conflictLogs)
          ..where((cl) => cl.isResolved.equals(false))
          ..orderBy([(cl) => OrderingTerm.desc(cl.conflictDate)]))
        .watch();
  }

  // Watch unresolved conflicts count (stream)
  Stream<int> watchUnresolvedConflictsCount() {
    final count = countAll();
    return (selectOnly(conflictLogs)
          ..addColumns([count])
          ..where(conflictLogs.isResolved.equals(false)))
        .map((row) => row.read(count) ?? 0)
        .watch();
  }
}
