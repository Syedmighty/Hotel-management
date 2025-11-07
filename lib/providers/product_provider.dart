import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotel_inventory_management/db/app_database.dart';
import 'package:hotel_inventory_management/db/daos/product_dao.dart';
import 'package:hotel_inventory_management/main.dart';

// ProductDao provider
final productDaoProvider = Provider<ProductDao>((ref) {
  final database = ref.watch(databaseProvider);
  return ProductDao(database);
});

// All products provider
final productsProvider = StreamProvider<List<Product>>((ref) {
  final productDao = ref.watch(productDaoProvider);
  return productDao.watchAllProducts();
});

// Low stock products provider
final lowStockProductsProvider = StreamProvider<List<Product>>((ref) {
  final productDao = ref.watch(productDaoProvider);
  return productDao.watchLowStockProducts();
});

// Product by ID provider
final productByIdProvider = StreamProvider.family<Product?, String>((ref, uuid) {
  final productDao = ref.watch(productDaoProvider);
  return productDao.watchProductById(uuid);
});

// Products count provider
final productsCountProvider = FutureProvider<int>((ref) async {
  final productDao = ref.watch(productDaoProvider);
  return productDao.getProductsCount();
});

// Total inventory value provider
final totalInventoryValueProvider = FutureProvider<double>((ref) async {
  final productDao = ref.watch(productDaoProvider);
  return productDao.getTotalInventoryValue();
});

// Categories provider
final categoriesProvider = FutureProvider<List<String>>((ref) async {
  final productDao = ref.watch(productDaoProvider);
  return productDao.getAllCategories();
});

// Product search query state
final productSearchQueryProvider = StateProvider<String>((ref) => '');

// Selected category filter
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

// Filtered products provider
final filteredProductsProvider = StreamProvider<List<Product>>((ref) {
  final productDao = ref.watch(productDaoProvider);
  final searchQuery = ref.watch(productSearchQueryProvider);
  final selectedCategory = ref.watch(selectedCategoryProvider);

  if (searchQuery.isNotEmpty) {
    return productDao.searchProducts(searchQuery).asStream();
  } else if (selectedCategory != null) {
    return productDao.getProductsByCategory(selectedCategory).asStream();
  } else {
    return productDao.watchAllProducts();
  }
});

// Product CRUD operations notifier
class ProductNotifier extends StateNotifier<AsyncValue<void>> {
  final ProductDao _productDao;

  ProductNotifier(this._productDao) : super(const AsyncValue.data(null));

  Future<void> createProduct(ProductsCompanion product) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _productDao.createProduct(product);
    });
  }

  Future<void> updateProduct(Product product) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _productDao.updateProduct(product);
    });
  }

  Future<void> deleteProduct(String uuid) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _productDao.deleteProduct(uuid);
    });
  }

  Future<void> updateStock(String uuid, double newStock) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _productDao.updateProductStock(uuid, newStock);
    });
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    return _productDao.getProductByBarcode(barcode);
  }
}

// Product notifier provider
final productNotifierProvider = StateNotifierProvider<ProductNotifier, AsyncValue<void>>((ref) {
  final productDao = ref.watch(productDaoProvider);
  return ProductNotifier(productDao);
});
