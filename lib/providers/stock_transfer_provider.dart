import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/app_database.dart';
import '../db/daos/stock_transfer_dao.dart';
import 'database_provider.dart';

// Stock Transfer DAO provider
final stockTransferDaoProvider = Provider<StockTransferDao>((ref) {
  final database = ref.watch(databaseProvider);
  return StockTransferDao(database);
});

// All stock transfers stream provider
final stockTransfersProvider = StreamProvider<List<StockTransfer>>((ref) {
  final stockTransferDao = ref.watch(stockTransferDaoProvider);
  return stockTransferDao.watchAllStockTransfers();
});

// Pending stock transfers stream provider
final pendingStockTransfersProvider =
    StreamProvider<List<StockTransfer>>((ref) {
  final stockTransferDao = ref.watch(stockTransferDaoProvider);
  return stockTransferDao.watchPendingStockTransfers();
});

// Search query state provider
final stockTransferSearchQueryProvider = StateProvider<String>((ref) => '');

// Status filter provider
final stockTransferStatusFilterProvider = StateProvider<String?>(
    (ref) => null); // null = all, 'Pending', 'Approved'

// Filtered stock transfers provider (combines search and status filter)
final filteredStockTransfersProvider =
    StreamProvider<List<StockTransfer>>((ref) {
  final transfersAsync = ref.watch(stockTransfersProvider);
  final searchQuery = ref.watch(stockTransferSearchQueryProvider);
  final statusFilter = ref.watch(stockTransferStatusFilterProvider);

  return transfersAsync.when(
    data: (transfers) async* {
      var filtered = transfers;

      // Apply status filter
      if (statusFilter != null) {
        filtered = filtered.where((t) => t.status == statusFilter).toList();
      }

      // Apply search query
      if (searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        filtered = filtered.where((t) {
          return t.transferNo.toLowerCase().contains(lowerQuery) ||
              t.fromLocation.toLowerCase().contains(lowerQuery) ||
              t.toLocation.toLowerCase().contains(lowerQuery) ||
              t.requestedBy.toLowerCase().contains(lowerQuery);
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

// Stock transfer line items stream provider
final stockTransferLineItemsProvider =
    StreamProvider.family<List<StockTransferLineItem>, String>(
        (ref, transferId) {
  final stockTransferDao = ref.watch(stockTransferDaoProvider);
  return stockTransferDao.watchStockTransferLineItems(transferId);
});

// Stock transfer notifier for CRUD operations
final stockTransferNotifierProvider =
    StateNotifierProvider<StockTransferNotifier, AsyncValue<void>>((ref) {
  final stockTransferDao = ref.watch(stockTransferDaoProvider);
  return StockTransferNotifier(stockTransferDao);
});

class StockTransferNotifier extends StateNotifier<AsyncValue<void>> {
  final StockTransferDao _stockTransferDao;

  StockTransferNotifier(this._stockTransferDao)
      : super(const AsyncValue.data(null));

  // Create stock transfer with line items
  Future<String?> createStockTransfer({
    required String transferNo,
    required DateTime transferDate,
    required String fromLocation,
    required String toLocation,
    required String requestedBy,
    required double totalAmount,
    required List<StockTransferLineItemsCompanion> lineItems,
    String? remarks,
  }) async {
    state = const AsyncValue.loading();
    try {
      final transferId =
          await _stockTransferDao.createStockTransferWithItems(
        transferNo: transferNo,
        transferDate: transferDate,
        fromLocation: fromLocation,
        toLocation: toLocation,
        requestedBy: requestedBy,
        totalAmount: totalAmount,
        lineItems: lineItems,
        remarks: remarks,
      );
      state = const AsyncValue.data(null);
      return transferId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  // Update stock transfer with line items
  Future<bool> updateStockTransfer({
    required String transferId,
    required String transferNo,
    required DateTime transferDate,
    required String fromLocation,
    required String toLocation,
    required String requestedBy,
    required double totalAmount,
    required List<StockTransferLineItemsCompanion> lineItems,
    String? remarks,
  }) async {
    state = const AsyncValue.loading();
    try {
      final success =
          await _stockTransferDao.updateStockTransferWithItems(
        transferId: transferId,
        transferNo: transferNo,
        transferDate: transferDate,
        fromLocation: fromLocation,
        toLocation: toLocation,
        requestedBy: requestedBy,
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

  // Approve stock transfer
  Future<bool> approveStockTransfer(String transferId) async {
    state = const AsyncValue.loading();
    try {
      await _stockTransferDao.approveStockTransfer(transferId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  // Delete stock transfer
  Future<bool> deleteStockTransfer(String transferId) async {
    state = const AsyncValue.loading();
    try {
      final success = await _stockTransferDao.deleteStockTransfer(transferId);
      state = const AsyncValue.data(null);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  // Get next transfer number
  Future<String> getNextTransferNo() async {
    try {
      return await _stockTransferDao.getNextTransferNo();
    } catch (e) {
      return 'TRF-0001';
    }
  }
}
