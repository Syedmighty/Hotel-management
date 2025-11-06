import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/app_database.dart';
import '../db/daos/physical_count_dao.dart';
import 'database_provider.dart';

// Physical Count DAO provider
final physicalCountDaoProvider = Provider<PhysicalCountDao>((ref) {
  final database = ref.watch(databaseProvider);
  return PhysicalCountDao(database);
});

// All physical counts stream provider
final physicalCountsProvider = StreamProvider<List<PhysicalCount>>((ref) {
  final physicalCountDao = ref.watch(physicalCountDaoProvider);
  return physicalCountDao.watchAllPhysicalCounts();
});

// Pending physical counts stream provider
final pendingPhysicalCountsProvider =
    StreamProvider<List<PhysicalCount>>((ref) {
  final physicalCountDao = ref.watch(physicalCountDaoProvider);
  return physicalCountDao.watchPendingPhysicalCounts();
});

// Search query state provider
final physicalCountSearchQueryProvider = StateProvider<String>((ref) => '');

// Status filter provider
final physicalCountStatusFilterProvider = StateProvider<String?>(
    (ref) => null); // null = all, 'Pending', 'Approved'

// Filtered physical counts provider (combines search and status filter)
final filteredPhysicalCountsProvider =
    StreamProvider<List<PhysicalCount>>((ref) {
  final countsAsync = ref.watch(physicalCountsProvider);
  final searchQuery = ref.watch(physicalCountSearchQueryProvider);
  final statusFilter = ref.watch(physicalCountStatusFilterProvider);

  return countsAsync.when(
    data: (counts) async* {
      var filtered = counts;

      // Apply status filter
      if (statusFilter != null) {
        filtered = filtered.where((c) => c.status == statusFilter).toList();
      }

      // Apply search query
      if (searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        filtered = filtered.where((c) {
          return c.countNo.toLowerCase().contains(lowerQuery) ||
              c.countedBy.toLowerCase().contains(lowerQuery);
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

// Physical count line items stream provider
final physicalCountLineItemsProvider =
    StreamProvider.family<List<PhysicalCountLineItem>, String>(
        (ref, countId) {
  final physicalCountDao = ref.watch(physicalCountDaoProvider);
  return physicalCountDao.watchPhysicalCountLineItems(countId);
});

// Line items with variance provider
final lineItemsWithVarianceProvider = FutureProvider.family<
    List<PhysicalCountLineItemWithVariance>, String>((ref, countId) async {
  final physicalCountDao = ref.watch(physicalCountDaoProvider);
  return await physicalCountDao.getLineItemsWithVariance(countId);
});

// Variance summary provider
final varianceSummaryProvider = FutureProvider.family<
    PhysicalCountVarianceSummary, String>((ref, countId) async {
  final physicalCountDao = ref.watch(physicalCountDaoProvider);
  return await physicalCountDao.getVarianceSummary(countId);
});

// Products for count provider
final productsForCountProvider =
    FutureProvider<List<ProductForCount>>((ref) async {
  final physicalCountDao = ref.watch(physicalCountDaoProvider);
  return await physicalCountDao.getProductsForCount();
});

// Physical count notifier for CRUD operations
final physicalCountNotifierProvider =
    StateNotifierProvider<PhysicalCountNotifier, AsyncValue<void>>((ref) {
  final physicalCountDao = ref.watch(physicalCountDaoProvider);
  return PhysicalCountNotifier(physicalCountDao);
});

class PhysicalCountNotifier extends StateNotifier<AsyncValue<void>> {
  final PhysicalCountDao _physicalCountDao;

  PhysicalCountNotifier(this._physicalCountDao)
      : super(const AsyncValue.data(null));

  // Create physical count with line items
  Future<String?> createPhysicalCount({
    required String countNo,
    required DateTime countDate,
    required String countedBy,
    required List<PhysicalCountLineItemsCompanion> lineItems,
    String? remarks,
  }) async {
    state = const AsyncValue.loading();
    try {
      final countId = await _physicalCountDao.createPhysicalCountWithItems(
        countNo: countNo,
        countDate: countDate,
        countedBy: countedBy,
        lineItems: lineItems,
        remarks: remarks,
      );
      state = const AsyncValue.data(null);
      return countId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  // Update physical count with line items
  Future<bool> updatePhysicalCount({
    required String countId,
    required String countNo,
    required DateTime countDate,
    required String countedBy,
    required List<PhysicalCountLineItemsCompanion> lineItems,
    String? remarks,
  }) async {
    state = const AsyncValue.loading();
    try {
      final success = await _physicalCountDao.updatePhysicalCountWithItems(
        countId: countId,
        countNo: countNo,
        countDate: countDate,
        countedBy: countedBy,
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

  // Approve physical count (adjust stock)
  Future<bool> approvePhysicalCount(String countId) async {
    state = const AsyncValue.loading();
    try {
      await _physicalCountDao.approvePhysicalCount(countId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  // Delete physical count
  Future<bool> deletePhysicalCount(String countId) async {
    state = const AsyncValue.loading();
    try {
      final success = await _physicalCountDao.deletePhysicalCount(countId);
      state = const AsyncValue.data(null);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  // Get next count number
  Future<String> getNextCountNo() async {
    try {
      return await _physicalCountDao.getNextCountNo();
    } catch (e) {
      return 'CNT-0001';
    }
  }
}
