import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotel_inventory_management/db/app_database.dart';
import 'package:hotel_inventory_management/db/daos/purchase_dao.dart';
import 'package:hotel_inventory_management/db/daos/product_dao.dart';
import 'package:hotel_inventory_management/db/daos/supplier_dao.dart';
import 'package:hotel_inventory_management/main.dart';
import 'package:hotel_inventory_management/providers/product_provider.dart';
import 'package:hotel_inventory_management/providers/supplier_provider.dart';

// PurchaseDao provider
final purchaseDaoProvider = Provider<PurchaseDao>((ref) {
  final database = ref.watch(databaseProvider);
  final productDao = ref.watch(productDaoProvider);
  final supplierDao = ref.watch(supplierDaoProvider);
  return PurchaseDao(database, productDao, supplierDao);
});

// All purchases provider
final purchasesProvider = StreamProvider<List<Purchase>>((ref) {
  final purchaseDao = ref.watch(purchaseDaoProvider);
  return purchaseDao.watchAllPurchases();
});

// Pending purchases provider
final pendingPurchasesProvider = StreamProvider<List<Purchase>>((ref) {
  final purchaseDao = ref.watch(purchaseDaoProvider);
  return purchaseDao.watchPendingPurchases();
});

// Purchase by ID provider
final purchaseByIdProvider = StreamProvider.family<Purchase?, String>((ref, uuid) {
  final purchaseDao = ref.watch(purchaseDaoProvider);
  return purchaseDao.watchPurchaseById(uuid);
});

// Purchase line items provider
final purchaseLineItemsProvider = StreamProvider.family<List<PurchaseLineItem>, String>((ref, purchaseId) {
  final purchaseDao = ref.watch(purchaseDaoProvider);
  return purchaseDao.watchPurchaseLineItems(purchaseId);
});

// Purchases count provider
final purchasesCountProvider = FutureProvider<int>((ref) async {
  final purchaseDao = ref.watch(purchaseDaoProvider);
  return purchaseDao.getPurchasesCount();
});

// Pending purchases count provider
final pendingPurchasesCountProvider = FutureProvider<int>((ref) async {
  final purchaseDao = ref.watch(purchaseDaoProvider);
  return purchaseDao.getPendingPurchasesCount();
});

// Purchase search query state
final purchaseSearchQueryProvider = StateProvider<String>((ref) => '');

// Selected status filter
final selectedPurchaseStatusProvider = StateProvider<String?>((ref) => null);

// Filtered purchases provider
final filteredPurchasesProvider = StreamProvider<List<Purchase>>((ref) {
  final purchaseDao = ref.watch(purchaseDaoProvider);
  final searchQuery = ref.watch(purchaseSearchQueryProvider);
  final selectedStatus = ref.watch(selectedPurchaseStatusProvider);

  if (searchQuery.isNotEmpty) {
    return purchaseDao.searchPurchases(searchQuery).asStream();
  } else if (selectedStatus != null) {
    return purchaseDao.getPurchasesByStatus(selectedStatus).asStream();
  } else {
    return purchaseDao.watchAllPurchases();
  }
});

// Purchase CRUD operations notifier
class PurchaseNotifier extends StateNotifier<AsyncValue<void>> {
  final PurchaseDao _purchaseDao;

  PurchaseNotifier(this._purchaseDao) : super(const AsyncValue.data(null));

  Future<String> createPurchaseWithItems({
    required PurchasesCompanion purchase,
    required List<PurchaseLineItemsCompanion> lineItems,
  }) async {
    state = const AsyncValue.loading();
    try {
      final purchaseId = await _purchaseDao.createPurchaseWithItems(
        purchase: purchase,
        lineItems: lineItems,
      );
      state = const AsyncValue.data(null);
      return purchaseId;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updatePurchase(Purchase purchase) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _purchaseDao.updatePurchase(purchase);
    });
  }

  Future<void> approvePurchase(String purchaseId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _purchaseDao.approvePurchase(purchaseId);
    });
  }

  Future<void> deletePurchase(String uuid) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _purchaseDao.deletePurchase(uuid);
    });
  }

  Future<PurchaseWithItems?> getPurchaseWithItems(String uuid) async {
    return _purchaseDao.getPurchaseWithItems(uuid);
  }
}

// Purchase notifier provider
final purchaseNotifierProvider = StateNotifierProvider<PurchaseNotifier, AsyncValue<void>>((ref) {
  final purchaseDao = ref.watch(purchaseDaoProvider);
  return PurchaseNotifier(purchaseDao);
});
