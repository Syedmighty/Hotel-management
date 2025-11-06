import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/recipe_provider.dart';
import '../../db/app_database.dart';
import '../../widgets/app_drawer.dart';

class RecipeListScreen extends ConsumerStatefulWidget {
  const RecipeListScreen({super.key});

  @override
  ConsumerState<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends ConsumerState<RecipeListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecipesAsync = ref.watch(filteredRecipesProvider);
    final categoryFilter = ref.watch(recipeCategoryFilterProvider);
    final categories = ref.watch(recipeCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Management'),
        actions: [
          // Category filter dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButton<String?>(
              value: categoryFilter,
              underline: const SizedBox(),
              icon: const Icon(Icons.filter_list),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Categories')),
                ...categories.map((category) {
                  return DropdownMenuItem(value: category, child: Text(category));
                }),
              ],
              onChanged: (value) {
                ref.read(recipeCategoryFilterProvider.notifier).state = value;
              },
            ),
          ),
          // Recalculate all costs
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recalculate All Costs',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Recalculate Costs'),
                  content: const Text(
                    'This will recalculate all recipe costs based on current ingredient prices. Continue?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Recalculate'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await ref
                    .read(recipeNotifierProvider.notifier)
                    .recalculateAllRecipeCosts();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All recipe costs recalculated'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search recipes by name or category...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(recipeSearchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                ref.read(recipeSearchQueryProvider.notifier).state = value;
              },
            ),
          ),

          // Recipes list
          Expanded(
            child: filteredRecipesAsync.when(
              data: (recipes) {
                if (recipes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_menu,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No recipes found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create menu items with ingredient costing',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: recipes.length,
                  itemBuilder: (context, index) {
                    final recipe = recipes[index];
                    return _RecipeCard(
                      recipe: recipe,
                      onTap: () {
                        context.push('/recipes/edit/${recipe.uuid}');
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Error: $error'),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/recipes/new');
        },
        icon: const Icon(Icons.add),
        label: const Text('New Recipe'),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const _RecipeCard({
    required this.recipe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹');
    final profitMargin = recipe.costPerServing > 0
        ? ((recipe.sellingPrice - recipe.costPerServing) /
                recipe.costPerServing) *
            100
        : 0.0;

    Color profitColor;
    if (profitMargin >= 50) {
      profitColor = Colors.green;
    } else if (profitMargin >= 25) {
      profitColor = Colors.blue;
    } else if (profitMargin >= 0) {
      profitColor = Colors.orange;
    } else {
      profitColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Image placeholder
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      image: recipe.imageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(recipe.imageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: recipe.imageUrl == null
                        ? Icon(
                            Icons.restaurant,
                            size: 40,
                            color: Colors.grey[400],
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe.dishName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                recipe.category,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.people, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '${recipe.servingSize} serving${recipe.servingSize > 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Profit margin badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: profitColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: profitColor.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${profitMargin.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: profitColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Margin',
                          style: TextStyle(
                            color: profitColor,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              // Cost breakdown
              Row(
                children: [
                  Expanded(
                    child: _CostItem(
                      label: 'Cost/Serving',
                      value: currencyFormat.format(recipe.costPerServing),
                      icon: Icons.money_off,
                      color: Colors.orange,
                    ),
                  ),
                  Expanded(
                    child: _CostItem(
                      label: 'Selling Price',
                      value: currencyFormat.format(recipe.sellingPrice),
                      icon: Icons.attach_money,
                      color: Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _CostItem(
                      label: 'Profit/Serving',
                      value: currencyFormat.format(
                          recipe.sellingPrice - recipe.costPerServing),
                      icon: Icons.trending_up,
                      color: profitColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CostItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _CostItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
