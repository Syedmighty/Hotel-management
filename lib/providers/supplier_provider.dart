import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotel_inventory_management/db/app_database.dart';
import 'package:hotel_inventory_management/db/daos/supplier_dao.dart';
import 'package:hotel_inventory_management/main.dart';

// SupplierDao provider
final supplierDaoProvider = Provider<SupplierDao>((ref) {
  final database = ref.watch(databaseProvider);
  return SupplierDao(database);
});

// All suppliers provider
final suppliersProvider = StreamProvider<List<Supplier>>((ref) {
  final supplierDao = ref.watch(supplierDaoProvider);
  return supplierDao.watchAllSuppliers();
});

// Suppliers with outstanding balance provider
final suppliersWithBalanceProvider = StreamProvider<List<Supplier>>((ref) {
  final supplierDao = ref.watch(supplierDaoProvider);
  return supplierDao.watchSuppliersWithBalance();
});

// Supplier by ID provider
final supplierByIdProvider = StreamProvider.family<Supplier?, String>((ref, uuid) {
  final supplierDao = ref.watch(supplierDaoProvider);
  return supplierDao.watchSupplierById(uuid);
});

// Suppliers count provider
final suppliersCountProvider = FutureProvider<int>((ref) async {
  final supplierDao = ref.watch(supplierDaoProvider);
  return supplierDao.getSuppliersCount();
});

// Total outstanding balance provider
final totalOutstandingBalanceProvider = FutureProvider<double>((ref) async {
  final supplierDao = ref.watch(supplierDaoProvider);
  return supplierDao.getTotalOutstandingBalance();
});

// Supplier search query state
final supplierSearchQueryProvider = StateProvider<String>((ref) => '');

// Filtered suppliers provider
final filteredSuppliersProvider = StreamProvider<List<Supplier>>((ref) {
  final supplierDao = ref.watch(supplierDaoProvider);
  final searchQuery = ref.watch(supplierSearchQueryProvider);

  if (searchQuery.isNotEmpty) {
    return supplierDao.searchSuppliers(searchQuery).asStream();
  } else {
    return supplierDao.watchAllSuppliers();
  }
});

// Supplier CRUD operations notifier
class SupplierNotifier extends StateNotifier<AsyncValue<void>> {
  final SupplierDao _supplierDao;

  SupplierNotifier(this._supplierDao) : super(const AsyncValue.data(null));

  Future<void> createSupplier(SuppliersCompanion supplier) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _supplierDao.createSupplier(supplier);
    });
  }

  Future<void> updateSupplier(Supplier supplier) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _supplierDao.updateSupplier(supplier);
    });
  }

  Future<void> deleteSupplier(String uuid) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _supplierDao.deleteSupplier(uuid);
    });
  }

  Future<void> updateBalance(String uuid, double newBalance) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _supplierDao.updateSupplierBalance(uuid, newBalance);
    });
  }

  Future<void> addPayment(String uuid, double amount) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _supplierDao.subtractFromBalance(uuid, amount);
    });
  }
}

// Supplier notifier provider
final supplierNotifierProvider = StateNotifierProvider<SupplierNotifier, AsyncValue<void>>((ref) {
  final supplierDao = ref.watch(supplierDaoProvider);
  return SupplierNotifier(supplierDao);
});
