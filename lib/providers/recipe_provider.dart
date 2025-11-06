import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/app_database.dart';
import '../db/daos/recipe_dao.dart';
import 'database_provider.dart';

// Recipe DAO provider
final recipeDaoProvider = Provider<RecipeDao>((ref) {
  final database = ref.watch(databaseProvider);
  return RecipeDao(database);
});

// All recipes stream provider
final recipesProvider = StreamProvider<List<Recipe>>((ref) {
  final recipeDao = ref.watch(recipeDaoProvider);
  return recipeDao.watchAllRecipes();
});

// Recipe categories provider
final recipeCategoriesProvider = Provider<List<String>>((ref) {
  return [
    'Appetizer',
    'Main Course',
    'Dessert',
    'Beverage',
    'Side Dish',
    'Soup',
    'Salad',
    'Breakfast',
    'Snack',
  ];
});

// Category filter provider
final recipeCategoryFilterProvider = StateProvider<String?>((ref) => null);

// Search query state provider
final recipeSearchQueryProvider = StateProvider<String>((ref) => '');

// Filtered recipes provider (combines search and category filter)
final filteredRecipesProvider = StreamProvider<List<Recipe>>((ref) {
  final recipesAsync = ref.watch(recipesProvider);
  final searchQuery = ref.watch(recipeSearchQueryProvider);
  final categoryFilter = ref.watch(recipeCategoryFilterProvider);

  return recipesAsync.when(
    data: (recipes) async* {
      var filtered = recipes;

      // Apply category filter
      if (categoryFilter != null) {
        filtered = filtered.where((r) => r.category == categoryFilter).toList();
      }

      // Apply search query
      if (searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        filtered = filtered.where((r) {
          return r.dishName.toLowerCase().contains(lowerQuery) ||
              r.category.toLowerCase().contains(lowerQuery);
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

// Recipe ingredients stream provider
final recipeIngredientsProvider =
    StreamProvider.family<List<RecipeIngredient>, String>((ref, recipeId) {
  final recipeDao = ref.watch(recipeDaoProvider);
  return recipeDao.watchRecipeIngredients(recipeId);
});

// Recipe with cost details provider
final recipeWithCostDetailsProvider =
    FutureProvider.family<RecipeWithCostDetails?, String>((ref, recipeId) {
  final recipeDao = ref.watch(recipeDaoProvider);
  return recipeDao.getRecipeWithCostDetails(recipeId);
});

// Recipe statistics provider
final recipeStatisticsProvider = FutureProvider<RecipeStatistics>((ref) {
  final recipeDao = ref.watch(recipeDaoProvider);
  return recipeDao.getRecipeStatistics();
});

// High profit recipes provider
final highProfitRecipesProvider =
    FutureProvider<List<RecipeWithCostDetails>>((ref) {
  final recipeDao = ref.watch(recipeDaoProvider);
  return recipeDao.getHighProfitRecipes(limit: 10);
});

// Low profit recipes provider
final lowProfitRecipesProvider =
    FutureProvider<List<RecipeWithCostDetails>>((ref) {
  final recipeDao = ref.watch(recipeDaoProvider);
  return recipeDao.getLowProfitRecipes(limit: 10);
});

// Recipe notifier for CRUD operations
final recipeNotifierProvider =
    StateNotifierProvider<RecipeNotifier, AsyncValue<void>>((ref) {
  final recipeDao = ref.watch(recipeDaoProvider);
  return RecipeNotifier(recipeDao);
});

class RecipeNotifier extends StateNotifier<AsyncValue<void>> {
  final RecipeDao _recipeDao;

  RecipeNotifier(this._recipeDao) : super(const AsyncValue.data(null));

  // Create recipe with ingredients
  Future<String?> createRecipe({
    required String dishName,
    required String category,
    required int servingSize,
    required double sellingPrice,
    required List<RecipeIngredientsCompanion> ingredients,
    String? instructions,
    String? imageUrl,
  }) async {
    state = const AsyncValue.loading();
    try {
      final recipeId = await _recipeDao.createRecipeWithIngredients(
        dishName: dishName,
        category: category,
        servingSize: servingSize,
        sellingPrice: sellingPrice,
        ingredients: ingredients,
        instructions: instructions,
        imageUrl: imageUrl,
      );
      state = const AsyncValue.data(null);
      return recipeId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  // Update recipe with ingredients
  Future<bool> updateRecipe({
    required String recipeId,
    required String dishName,
    required String category,
    required int servingSize,
    required double sellingPrice,
    required List<RecipeIngredientsCompanion> ingredients,
    String? instructions,
    String? imageUrl,
  }) async {
    state = const AsyncValue.loading();
    try {
      final success = await _recipeDao.updateRecipeWithIngredients(
        recipeId: recipeId,
        dishName: dishName,
        category: category,
        servingSize: servingSize,
        sellingPrice: sellingPrice,
        ingredients: ingredients,
        instructions: instructions,
        imageUrl: imageUrl,
      );
      state = const AsyncValue.data(null);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  // Delete recipe
  Future<bool> deleteRecipe(String recipeId) async {
    state = const AsyncValue.loading();
    try {
      final success = await _recipeDao.deleteRecipe(recipeId);
      state = const AsyncValue.data(null);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  // Recalculate recipe cost
  Future<void> recalculateRecipeCost(String recipeId) async {
    state = const AsyncValue.loading();
    try {
      await _recipeDao.recalculateRecipeCost(recipeId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // Recalculate all recipe costs
  Future<void> recalculateAllRecipeCosts() async {
    state = const AsyncValue.loading();
    try {
      await _recipeDao.recalculateAllRecipeCosts();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
