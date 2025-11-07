import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/app_database.dart';
import '../db/daos/wastage_dao.dart';
import 'database_provider.dart';

// Wastage DAO provider
final wastageDaoProvider = Provider<WastageDao>((ref) {
  final database = ref.watch(databaseProvider);
  return WastageDao(database);
});

// All wastages stream provider
final wastagesProvider = StreamProvider<List<WastageReturn>>((ref) {
  final wastageDao = ref.watch(wastageDaoProvider);
  return wastageDao.watchAllWastages();
});

// Pending wastages stream provider
final pendingWastagesProvider = StreamProvider<List<WastageReturn>>((ref) {
  final wastageDao = ref.watch(wastageDaoProvider);
  return wastageDao.watchPendingWastages();
});

// Search query state provider
final wastageSearchQueryProvider = StateProvider<String>((ref) => '');

// Type filter provider (null = all, 'Wastage', 'Return')
final wastageTypeFilterProvider = StateProvider<String?>((ref) => null);

// Status filter provider (null = all, 'Pending', 'Approved')
final wastageStatusFilterProvider = StateProvider<String?>((ref) => null);

// Filtered wastages provider (combines search, type, and status filters)
final filteredWastagesProvider = StreamProvider<List<WastageReturn>>((ref) {
  final wastagesAsync = ref.watch(wastagesProvider);
  final searchQuery = ref.watch(wastageSearchQueryProvider);
  final typeFilter = ref.watch(wastageTypeFilterProvider);
  final statusFilter = ref.watch(wastageStatusFilterProvider);

  return wastagesAsync.when(
    data: (wastages) async* {
      var filtered = wastages;

      // Apply type filter
      if (typeFilter != null) {
        filtered = filtered.where((w) => w.type == typeFilter).toList();
      }

      // Apply status filter
      if (statusFilter != null) {
        filtered = filtered.where((w) => w.status == statusFilter).toList();
      }

      // Apply search query
      if (searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        filtered = filtered.where((w) {
          return w.wastageNo.toLowerCase().contains(lowerQuery) ||
              w.type.toLowerCase().contains(lowerQuery) ||
              (w.remarks?.toLowerCase().contains(lowerQuery) ?? false);
        }).toList();
      }

      yield filtered;
    },
    loading: () async* {
      yield [];
    },
    error: (error, stack) async* {
      yield [];
    },
  );
});

// Wastage line items stream provider
final wastageLineItemsProvider =
    StreamProvider.family<List<WastageLineItem>, String>((ref, wastageId) {
  final wastageDao = ref.watch(wastageDaoProvider);
  return wastageDao.watchWastageLineItems(wastageId);
});

// Wastage notifier for CRUD operations
final wastageNotifierProvider =
    StateNotifierProvider<WastageNotifier, AsyncValue<void>>((ref) {
  final wastageDao = ref.watch(wastageDaoProvider);
  return WastageNotifier(wastageDao);
});

class WastageNotifier extends StateNotifier<AsyncValue<void>> {
  final WastageDao _wastageDao;

  WastageNotifier(this._wastageDao) : super(const AsyncValue.data(null));

  // Create wastage/return with line items
  Future<String?> createWastage({
    required String wastageNo,
    required DateTime wastageDate,
    required String type,
    String? supplierId,
    required double totalAmount,
    required List<WastageLineItemsCompanion> lineItems,
    String? remarks,
  }) async {
    state = const AsyncValue.loading();
    try {
      final wastageId = await _wastageDao.createWastageWithItems(
        wastageNo: wastageNo,
        wastageDate: wastageDate,
        type: type,
        supplierId: supplierId,
        totalAmount: totalAmount,
        lineItems: lineItems,
        remarks: remarks,
      );
      state = const AsyncValue.data(null);
      return wastageId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  // Update wastage/return with line items
  Future<bool> updateWastage({
    required String wastageId,
    required String wastageNo,
    required DateTime wastageDate,
    required String type,
    String? supplierId,
    required double totalAmount,
    required List<WastageLineItemsCompanion> lineItems,
    String? remarks,
  }) async {
    state = const AsyncValue.loading();
    try {
      final success = await _wastageDao.updateWastageWithItems(
        wastageId: wastageId,
        wastageNo: wastageNo,
        wastageDate: wastageDate,
        type: type,
        supplierId: supplierId,
        totalAmount: totalAmount,
        lineItems: lineItems,
        remarks: remarks,
      );
      state = const AsyncValue.data(null);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  // Approve wastage/return (adjust stock)
  Future<bool> approveWastage(String wastageId) async {
    state = const AsyncValue.loading();
    try {
      await _wastageDao.approveWastage(wastageId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  // Delete wastage/return
  Future<bool> deleteWastage(String wastageId) async {
    state = const AsyncValue.loading();
    try {
      final success = await _wastageDao.deleteWastage(wastageId);
      state = const AsyncValue.data(null);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  // Get next wastage number
  Future<String> getNextWastageNo(String type) async {
    try {
      return await _wastageDao.getNextWastageNo(type);
    } catch (e) {
      return type == 'Wastage' ? 'WST-0001' : 'RET-0001';
    }
  }
}
