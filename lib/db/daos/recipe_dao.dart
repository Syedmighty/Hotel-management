import 'package:drift/drift.dart';
import '../app_database.dart';
import 'product_dao.dart';

part 'recipe_dao.g.dart';

@DriftAccessor(tables: [Recipes, RecipeIngredients])
class RecipeDao extends DatabaseAccessor<AppDatabase> with _$RecipeDaoMixin {
  RecipeDao(AppDatabase db) : super(db);

  final ProductDao _productDao = ProductDao(AppDatabase());

  // Create recipe with ingredients (transaction-based)
  Future<String> createRecipeWithIngredients({
    required String dishName,
    required String category,
    required int servingSize,
    required double sellingPrice,
    required List<RecipeIngredientsCompanion> ingredients,
    String? instructions,
    String? imageUrl,
  }) async {
    return await transaction(() async {
      // Calculate cost per serving from ingredients
      double totalCost = 0.0;
      for (final ingredient in ingredients) {
        totalCost += ingredient.cost.value;
      }
      final costPerServing = servingSize > 0 ? totalCost / servingSize : 0.0;

      // Insert recipe record
      final recipeId = await into(recipes).insert(
        RecipesCompanion.insert(
          uuid: Value(DateTime.now().millisecondsSinceEpoch.toString() +
              '_' +
              dishName.replaceAll(' ', '_')),
          dishName: dishName,
          category: category,
          servingSize: servingSize,
          sellingPrice: sellingPrice,
          costPerServing: Value(costPerServing),
          instructions: Value(instructions),
          imageUrl: Value(imageUrl),
          lastModified: DateTime.now(),
          sourceDevice: 'local',
          isActive: const Value(true),
        ),
      );

      // Get the generated UUID
      final recipe =
          await (select(recipes)..where((r) => r.id.equals(recipeId)))
              .getSingle();

      // Insert ingredients with the recipe UUID
      for (final ingredient in ingredients) {
        await into(recipeIngredients).insert(
          ingredient.copyWith(recipeId: Value(recipe.uuid)),
        );
      }

      return recipe.uuid;
    });
  }

  // Get recipe by ID
  Future<Recipe?> getRecipeById(String recipeId) async {
    return await (select(recipes)..where((r) => r.uuid.equals(recipeId)))
        .getSingleOrNull();
  }

  // Get all recipes
  Future<List<Recipe>> getAllRecipes() async {
    return await (select(recipes)
          ..where((r) => r.isActive.equals(true))
          ..orderBy([
            (r) => OrderingTerm.asc(r.category),
            (r) => OrderingTerm.asc(r.dishName),
          ]))
        .get();
  }

  // Watch all recipes (stream)
  Stream<List<Recipe>> watchAllRecipes() {
    return (select(recipes)
          ..where((r) => r.isActive.equals(true))
          ..orderBy([
            (r) => OrderingTerm.asc(r.category),
            (r) => OrderingTerm.asc(r.dishName),
          ]))
        .watch();
  }

  // Get recipes by category
  Future<List<Recipe>> getRecipesByCategory(String category) async {
    return await (select(recipes)
          ..where((r) => r.category.equals(category) & r.isActive.equals(true))
          ..orderBy([
            (r) => OrderingTerm.asc(r.dishName),
          ]))
        .get();
  }

  // Watch recipes by category (stream)
  Stream<List<Recipe>> watchRecipesByCategory(String category) {
    return (select(recipes)
          ..where((r) => r.category.equals(category) & r.isActive.equals(true))
          ..orderBy([
            (r) => OrderingTerm.asc(r.dishName),
          ]))
        .watch();
  }

  // Search recipes
  Future<List<Recipe>> searchRecipes(String query) async {
    final lowerQuery = query.toLowerCase();
    return await (select(recipes)
          ..where((r) =>
              r.dishName.lower().like('%$lowerQuery%') &
              r.isActive.equals(true))
          ..orderBy([
            (r) => OrderingTerm.asc(r.dishName),
          ]))
        .get();
  }

  // Get ingredients for a recipe
  Future<List<RecipeIngredient>> getRecipeIngredients(String recipeId) async {
    return await (select(recipeIngredients)
          ..where((ri) => ri.recipeId.equals(recipeId))
          ..orderBy([
            (ri) => OrderingTerm.asc(ri.id),
          ]))
        .get();
  }

  // Watch ingredients for a recipe (stream)
  Stream<List<RecipeIngredient>> watchRecipeIngredients(String recipeId) {
    return (select(recipeIngredients)
          ..where((ri) => ri.recipeId.equals(recipeId))
          ..orderBy([
            (ri) => OrderingTerm.asc(ri.id),
          ]))
        .watch();
  }

  // Get recipe with calculated cost details
  Future<RecipeWithCostDetails?> getRecipeWithCostDetails(
      String recipeId) async {
    final recipe = await getRecipeById(recipeId);
    if (recipe == null) return null;

    final ingredients = await getRecipeIngredients(recipeId);
    final List<RecipeIngredientWithProduct> ingredientDetails = [];

    double totalCost = 0.0;

    for (final ingredient in ingredients) {
      final product = await _productDao.getProductById(ingredient.productId);
      if (product != null) {
        final cost = ingredient.quantity * product.purchaseRate;
        totalCost += cost;

        ingredientDetails.add(RecipeIngredientWithProduct(
          ingredient: ingredient,
          product: product,
          calculatedCost: cost,
        ));
      }
    }

    final costPerServing =
        recipe.servingSize > 0 ? totalCost / recipe.servingSize : 0.0;
    final profitPerServing = recipe.sellingPrice - costPerServing;
    final profitMarginPercent =
        costPerServing > 0 ? (profitPerServing / costPerServing) * 100 : 0.0;

    return RecipeWithCostDetails(
      recipe: recipe,
      ingredients: ingredientDetails,
      totalCost: totalCost,
      costPerServing: costPerServing,
      profitPerServing: profitPerServing,
      profitMarginPercent: profitMarginPercent,
    );
  }

  // Update recipe
  Future<bool> updateRecipe({
    required String recipeId,
    String? dishName,
    String? category,
    int? servingSize,
    double? sellingPrice,
    double? costPerServing,
    String? instructions,
    String? imageUrl,
  }) async {
    final companionData = RecipesCompanion(
      dishName: dishName != null ? Value(dishName) : const Value.absent(),
      category: category != null ? Value(category) : const Value.absent(),
      servingSize:
          servingSize != null ? Value(servingSize) : const Value.absent(),
      sellingPrice:
          sellingPrice != null ? Value(sellingPrice) : const Value.absent(),
      costPerServing: costPerServing != null
          ? Value(costPerServing)
          : const Value.absent(),
      instructions:
          instructions != null ? Value(instructions) : const Value.absent(),
      imageUrl: imageUrl != null ? Value(imageUrl) : const Value.absent(),
      lastModified: Value(DateTime.now()),
      isSynced: const Value(false),
    );

    final rowsAffected = await (update(recipes)
          ..where((r) => r.uuid.equals(recipeId)))
        .write(companionData);

    return rowsAffected > 0;
  }

  // Update recipe with ingredients (transaction-based)
  Future<bool> updateRecipeWithIngredients({
    required String recipeId,
    required String dishName,
    required String category,
    required int servingSize,
    required double sellingPrice,
    required List<RecipeIngredientsCompanion> ingredients,
    String? instructions,
    String? imageUrl,
  }) async {
    return await transaction(() async {
      // Calculate cost per serving from ingredients
      double totalCost = 0.0;
      for (final ingredient in ingredients) {
        totalCost += ingredient.cost.value;
      }
      final costPerServing = servingSize > 0 ? totalCost / servingSize : 0.0;

      // Update recipe
      final updated = await updateRecipe(
        recipeId: recipeId,
        dishName: dishName,
        category: category,
        servingSize: servingSize,
        sellingPrice: sellingPrice,
        costPerServing: costPerServing,
        instructions: instructions,
        imageUrl: imageUrl,
      );

      if (!updated) return false;

      // Delete existing ingredients
      await (delete(recipeIngredients)
            ..where((ri) => ri.recipeId.equals(recipeId)))
          .go();

      // Insert new ingredients
      for (final ingredient in ingredients) {
        await into(recipeIngredients).insert(
          ingredient.copyWith(recipeId: Value(recipeId)),
        );
      }

      return true;
    });
  }

  // Recalculate recipe costs (useful when product prices change)
  Future<void> recalculateRecipeCost(String recipeId) async {
    await transaction(() async {
      final recipe = await getRecipeById(recipeId);
      if (recipe == null) return;

      final ingredients = await getRecipeIngredients(recipeId);
      double totalCost = 0.0;

      for (final ingredient in ingredients) {
        final product = await _productDao.getProductById(ingredient.productId);
        if (product != null) {
          final cost = ingredient.quantity * product.purchaseRate;
          totalCost += cost;

          // Update ingredient cost
          await (update(recipeIngredients)
                ..where((ri) => ri.id.equals(ingredient.id)))
              .write(RecipeIngredientsCompanion(
            cost: Value(cost),
            lastModified: Value(DateTime.now()),
          ));
        }
      }

      // Update recipe cost per serving
      final costPerServing =
          recipe.servingSize > 0 ? totalCost / recipe.servingSize : 0.0;
      await updateRecipe(
        recipeId: recipeId,
        costPerServing: costPerServing,
      );
    });
  }

  // Recalculate all recipe costs
  Future<void> recalculateAllRecipeCosts() async {
    final allRecipes = await getAllRecipes();
    for (final recipe in allRecipes) {
      await recalculateRecipeCost(recipe.uuid);
    }
  }

  // Delete recipe (soft delete)
  Future<bool> deleteRecipe(String recipeId) async {
    final rowsAffected = await (update(recipes)
          ..where((r) => r.uuid.equals(recipeId)))
        .write(RecipesCompanion(
      isActive: const Value(false),
      lastModified: Value(DateTime.now()),
      isSynced: const Value(false),
    ));

    return rowsAffected > 0;
  }

  // Get recipe statistics
  Future<RecipeStatistics> getRecipeStatistics() async {
    final allRecipes = await getAllRecipes();

    int totalRecipes = allRecipes.length;
    double totalRevenuePotential = 0.0;
    double totalCostValue = 0.0;

    // Group by category
    Map<String, int> recipesByCategory = {};

    for (final recipe in allRecipes) {
      // Count by category
      recipesByCategory[recipe.category] =
          (recipesByCategory[recipe.category] ?? 0) + 1;

      // Sum values
      totalRevenuePotential += recipe.sellingPrice;
      totalCostValue += recipe.costPerServing;
    }

    final averageProfitMargin = totalCostValue > 0
        ? ((totalRevenuePotential - totalCostValue) / totalCostValue) * 100
        : 0.0;

    return RecipeStatistics(
      totalRecipes: totalRecipes,
      recipesByCategory: recipesByCategory,
      averageProfitMargin: averageProfitMargin,
      totalRevenuePotential: totalRevenuePotential,
      totalCostValue: totalCostValue,
    );
  }

  // Get high-profit recipes
  Future<List<RecipeWithCostDetails>> getHighProfitRecipes(
      {int limit = 10}) async {
    final allRecipes = await getAllRecipes();
    final List<RecipeWithCostDetails> recipesWithDetails = [];

    for (final recipe in allRecipes) {
      final details = await getRecipeWithCostDetails(recipe.uuid);
      if (details != null) {
        recipesWithDetails.add(details);
      }
    }

    // Sort by profit margin descending
    recipesWithDetails.sort(
        (a, b) => b.profitMarginPercent.compareTo(a.profitMarginPercent));

    return recipesWithDetails.take(limit).toList();
  }

  // Get low-profit recipes (need review)
  Future<List<RecipeWithCostDetails>> getLowProfitRecipes(
      {int limit = 10}) async {
    final allRecipes = await getAllRecipes();
    final List<RecipeWithCostDetails> recipesWithDetails = [];

    for (final recipe in allRecipes) {
      final details = await getRecipeWithCostDetails(recipe.uuid);
      if (details != null) {
        recipesWithDetails.add(details);
      }
    }

    // Sort by profit margin ascending
    recipesWithDetails.sort(
        (a, b) => a.profitMarginPercent.compareTo(b.profitMarginPercent));

    return recipesWithDetails.take(limit).toList();
  }

  // Get recipes by price range
  Future<List<Recipe>> getRecipesByPriceRange(
      double minPrice, double maxPrice) async {
    return await (select(recipes)
          ..where((r) =>
              r.sellingPrice.isBiggerOrEqualValue(minPrice) &
              r.sellingPrice.isSmallerOrEqualValue(maxPrice) &
              r.isActive.equals(true))
          ..orderBy([
            (r) => OrderingTerm.asc(r.sellingPrice),
          ]))
        .get();
  }
}

// Data models for recipe
class RecipeIngredientWithProduct {
  final RecipeIngredient ingredient;
  final Product product;
  final double calculatedCost;

  RecipeIngredientWithProduct({
    required this.ingredient,
    required this.product,
    required this.calculatedCost,
  });
}

class RecipeWithCostDetails {
  final Recipe recipe;
  final List<RecipeIngredientWithProduct> ingredients;
  final double totalCost;
  final double costPerServing;
  final double profitPerServing;
  final double profitMarginPercent;

  RecipeWithCostDetails({
    required this.recipe,
    required this.ingredients,
    required this.totalCost,
    required this.costPerServing,
    required this.profitPerServing,
    required this.profitMarginPercent,
  });
}

class RecipeStatistics {
  final int totalRecipes;
  final Map<String, int> recipesByCategory;
  final double averageProfitMargin;
  final double totalRevenuePotential;
  final double totalCostValue;

  RecipeStatistics({
    required this.totalRecipes,
    required this.recipesByCategory,
    required this.averageProfitMargin,
    required this.totalRevenuePotential,
    required this.totalCostValue,
  });
}
