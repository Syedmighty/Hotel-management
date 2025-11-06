import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../db/app_database.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/product_provider.dart';

class RecipeFormScreen extends ConsumerStatefulWidget {
  final String? recipeId;

  const RecipeFormScreen({
    super.key,
    this.recipeId,
  });

  @override
  ConsumerState<RecipeFormScreen> createState() => _RecipeFormScreenState();
}

class _RecipeFormScreenState extends ConsumerState<RecipeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dishNameController = TextEditingController();
  final _servingSizeController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _instructionsController = TextEditingController();

  String _selectedCategory = 'Main Course';
  bool _isLoading = false;
  bool _isEditMode = false;

  final List<RecipeIngredientModel> _ingredients = [];

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  Future<void> _initializeForm() async {
    if (widget.recipeId != null) {
      // Edit mode - load existing recipe
      _isEditMode = true;
      await _loadRecipe();
    }
  }

  Future<void> _loadRecipe() async {
    setState(() => _isLoading = true);

    try {
      final recipeDao = ref.read(recipeDaoProvider);
      final recipe = await recipeDao.getRecipeById(widget.recipeId!);

      if (recipe == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recipe not found')),
          );
          context.pop();
        }
        return;
      }

      // Load ingredients
      final ingredients =
          await recipeDao.getRecipeIngredients(widget.recipeId!);

      // Populate form
      _dishNameController.text = recipe.dishName;
      _selectedCategory = recipe.category;
      _servingSizeController.text = recipe.servingSize.toString();
      _sellingPriceController.text = recipe.sellingPrice.toStringAsFixed(2);
      _instructionsController.text = recipe.instructions ?? '';

      // Populate ingredients
      for (final ingredient in ingredients) {
        final productDao = ref.read(productDaoProvider);
        final product = await productDao.getProductById(ingredient.productId);
        if (product != null) {
          _ingredients.add(RecipeIngredientModel(
            productId: ingredient.productId,
            productName: product.name,
            unit: ingredient.unit,
            quantity: ingredient.quantity,
            rate: product.purchaseRate,
            cost: ingredient.cost,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading recipe: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _dishNameController.dispose();
    _servingSizeController.dispose();
    _sellingPriceController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _addIngredient() {
    setState(() {
      _ingredients.add(RecipeIngredientModel(
        productId: '',
        productName: '',
        unit: '',
        quantity: 0,
        rate: 0,
        cost: 0,
      ));
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
    });
  }

  void _updateIngredient(int index, RecipeIngredientModel ingredient) {
    setState(() {
      _ingredients[index] = ingredient;
    });
  }

  double _calculateTotalCost() {
    return _ingredients.fold(0.0, (sum, item) => sum + item.cost);
  }

  double _calculateCostPerServing() {
    final servingSize = int.tryParse(_servingSizeController.text) ?? 1;
    if (servingSize <= 0) return 0.0;
    return _calculateTotalCost() / servingSize;
  }

  double _calculateProfitPerServing() {
    final sellingPrice = double.tryParse(_sellingPriceController.text) ?? 0.0;
    return sellingPrice - _calculateCostPerServing();
  }

  double _calculateProfitMargin() {
    final costPerServing = _calculateCostPerServing();
    if (costPerServing <= 0) return 0.0;
    return (_calculateProfitPerServing() / costPerServing) * 100;
  }

  bool _validateForm() {
    if (!_formKey.currentState!.validate()) {
      return false;
    }

    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one ingredient')),
      );
      return false;
    }

    // Validate ingredients
    for (int i = 0; i < _ingredients.length; i++) {
      final ingredient = _ingredients[i];
      if (ingredient.productId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Please select product for ingredient ${i + 1}')),
        );
        return false;
      }
      if (ingredient.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid quantity for ingredient ${i + 1}')),
        );
        return false;
      }
    }

    return true;
  }

  Future<void> _saveRecipe() async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);

    try {
      // Prepare ingredients data
      final ingredientsData = _ingredients.map((ingredient) {
        return RecipeIngredientsCompanion.insert(
          recipeId: const Value.absent(), // Will be set by DAO
          productId: ingredient.productId,
          quantity: ingredient.quantity,
          unit: ingredient.unit,
          cost: ingredient.cost,
          lastModified: DateTime.now(),
        );
      }).toList();

      final notifier = ref.read(recipeNotifierProvider.notifier);

      if (_isEditMode && widget.recipeId != null) {
        // Update existing recipe
        final success = await notifier.updateRecipe(
          recipeId: widget.recipeId!,
          dishName: _dishNameController.text.trim(),
          category: _selectedCategory,
          servingSize: int.parse(_servingSizeController.text),
          sellingPrice: double.parse(_sellingPriceController.text),
          ingredients: ingredientsData,
          instructions: _instructionsController.text.trim().isEmpty
              ? null
              : _instructionsController.text.trim(),
        );

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Recipe updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
            context.pop();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to update recipe'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        // Create new recipe
        final recipeId = await notifier.createRecipe(
          dishName: _dishNameController.text.trim(),
          category: _selectedCategory,
          servingSize: int.parse(_servingSizeController.text),
          sellingPrice: double.parse(_sellingPriceController.text),
          ingredients: ingredientsData,
          instructions: _instructionsController.text.trim().isEmpty
              ? null
              : _instructionsController.text.trim(),
        );

        if (mounted) {
          if (recipeId != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Recipe created successfully'),
                backgroundColor: Colors.green,
              ),
            );
            context.pop();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to create recipe'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 900;
    final categories = ref.watch(recipeCategoriesProvider);
    final currencyFormat = NumberFormat.currency(symbol: '₹');

    if (_isLoading && _ingredients.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Recipe' : 'New Recipe'),
        actions: [
          if (_isEditMode && widget.recipeId != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Recipe'),
                    content: const Text(
                      'Are you sure you want to delete this recipe?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  final notifier = ref.read(recipeNotifierProvider.notifier);
                  final success = await notifier.deleteRecipe(widget.recipeId!);
                  if (mounted) {
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Recipe deleted'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      context.pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to delete recipe'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isWeb ? 24.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Recipe Details Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recipe Details',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),

                      // Dish Name
                      TextFormField(
                        controller: _dishNameController,
                        decoration: const InputDecoration(
                          labelText: 'Dish Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.restaurant),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Category and Serving Size
                      if (isWeb)
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedCategory,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.category),
                                ),
                                items: categories.map((category) {
                                  return DropdownMenuItem(
                                    value: category,
                                    child: Text(category),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedCategory = value;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _servingSizeController,
                                decoration: const InputDecoration(
                                  labelText: 'Serving Size',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.people),
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Required';
                                  }
                                  final size = int.tryParse(value);
                                  if (size == null || size <= 0) {
                                    return 'Invalid';
                                  }
                                  return null;
                                },
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                          ),
                          items: categories.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedCategory = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _servingSizeController,
                          decoration: const InputDecoration(
                            labelText: 'Serving Size',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.people),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            final size = int.tryParse(value);
                            if (size == null || size <= 0) {
                              return 'Invalid';
                            }
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Selling Price
                      TextFormField(
                        controller: _sellingPriceController,
                        decoration: const InputDecoration(
                          labelText: 'Selling Price',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money),
                          prefixText: '₹',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'),
                          ),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final price = double.tryParse(value);
                          if (price == null || price <= 0) {
                            return 'Invalid';
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),

                      const SizedBox(height: 16),

                      // Instructions
                      TextFormField(
                        controller: _instructionsController,
                        decoration: const InputDecoration(
                          labelText: 'Cooking Instructions (Optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.note),
                        ),
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Ingredients Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Ingredients',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          ElevatedButton.icon(
                            onPressed: _addIngredient,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Ingredient'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (_ingredients.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No ingredients added yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _ingredients.length,
                          itemBuilder: (context, index) {
                            return _IngredientCard(
                              key: ValueKey(_ingredients[index].productId +
                                  index.toString()),
                              ingredient: _ingredients[index],
                              index: index,
                              onUpdate: (ingredient) =>
                                  _updateIngredient(index, ingredient),
                              onRemove: () => _removeIngredient(index),
                              isWeb: isWeb,
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Cost Summary Section
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cost Summary',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Divider(height: 24),
                      _SummaryRow(
                        label: 'Total Cost',
                        value: currencyFormat.format(_calculateTotalCost()),
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 8),
                      _SummaryRow(
                        label: 'Cost per Serving',
                        value:
                            currencyFormat.format(_calculateCostPerServing()),
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 8),
                      _SummaryRow(
                        label: 'Profit per Serving',
                        value:
                            currencyFormat.format(_calculateProfitPerServing()),
                        color: _calculateProfitPerServing() >= 0
                            ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(height: 8),
                      _SummaryRow(
                        label: 'Profit Margin',
                        value: '${_calculateProfitMargin().toStringAsFixed(1)}%',
                        color: _calculateProfitMargin() >= 50
                            ? Colors.green
                            : (_calculateProfitMargin() >= 25
                                ? Colors.blue
                                : Colors.orange),
                        isLarge: true,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveRecipe,
                  icon: const Icon(Icons.save),
                  label: Text(_isEditMode ? 'Update Recipe' : 'Create Recipe'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IngredientCard extends ConsumerStatefulWidget {
  final RecipeIngredientModel ingredient;
  final int index;
  final Function(RecipeIngredientModel) onUpdate;
  final VoidCallback onRemove;
  final bool isWeb;

  const _IngredientCard({
    super.key,
    required this.ingredient,
    required this.index,
    required this.onUpdate,
    required this.onRemove,
    required this.isWeb,
  });

  @override
  ConsumerState<_IngredientCard> createState() => _IngredientCardState();
}

class _IngredientCardState extends ConsumerState<_IngredientCard> {
  final _quantityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _quantityController.text =
        widget.ingredient.quantity > 0 ? widget.ingredient.quantity.toString() : '';
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _updateIngredient() {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final cost = quantity * widget.ingredient.rate;

    widget.onUpdate(widget.ingredient.copyWith(
      quantity: quantity,
      cost: cost,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final currencyFormat = NumberFormat.currency(symbol: '₹');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ingredient ${widget.index + 1}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Product Selection
            productsAsync.when(
              data: (products) {
                final activeProducts =
                    products.where((p) => p.isActive).toList();
                return DropdownButtonFormField<String>(
                  value: widget.ingredient.productId.isEmpty
                      ? null
                      : widget.ingredient.productId,
                  decoration: const InputDecoration(
                    labelText: 'Product',
                    border: OutlineInputBorder(),
                  ),
                  items: activeProducts.map((product) {
                    return DropdownMenuItem(
                      value: product.uuid,
                      child: Text('${product.name} (${product.unit})'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      final product =
                          activeProducts.firstWhere((p) => p.uuid == value);
                      widget.onUpdate(widget.ingredient.copyWith(
                        productId: product.uuid,
                        productName: product.name,
                        unit: product.unit,
                        rate: product.purchaseRate,
                        cost: widget.ingredient.quantity * product.purchaseRate,
                      ));
                    }
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Required';
                    }
                    return null;
                  },
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) => Text('Error: $error'),
            ),

            const SizedBox(height: 12),

            // Quantity and Cost
            if (widget.isWeb)
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        border: const OutlineInputBorder(),
                        suffixText: widget.ingredient.unit,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      onChanged: (_) => _updateIngredient(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final qty = double.tryParse(value);
                        if (qty == null || qty <= 0) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      initialValue: widget.ingredient.rate.toStringAsFixed(2),
                      decoration: const InputDecoration(
                        labelText: 'Rate',
                        border: OutlineInputBorder(),
                        prefixText: '₹/',
                      ),
                      readOnly: true,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      initialValue: currencyFormat.format(widget.ingredient.cost),
                      decoration: const InputDecoration(
                        labelText: 'Cost',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        border: const OutlineInputBorder(),
                        suffixText: widget.ingredient.unit,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      onChanged: (_) => _updateIngredient(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final qty = double.tryParse(value);
                        if (qty == null || qty <= 0) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: widget.ingredient.rate.toStringAsFixed(2),
                      decoration: const InputDecoration(
                        labelText: 'Rate',
                        border: OutlineInputBorder(),
                        prefixText: '₹/',
                      ),
                      readOnly: true,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: currencyFormat.format(widget.ingredient.cost),
                decoration: const InputDecoration(
                  labelText: 'Cost',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isLarge;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.color,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isLarge ? 18 : 16,
            fontWeight: isLarge ? FontWeight.bold : FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isLarge ? 24 : 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

// Model for ingredients
class RecipeIngredientModel {
  final String productId;
  final String productName;
  final String unit;
  final double quantity;
  final double rate;
  final double cost;

  RecipeIngredientModel({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.rate,
    required this.cost,
  });

  RecipeIngredientModel copyWith({
    String? productId,
    String? productName,
    String? unit,
    double? quantity,
    double? rate,
    double? cost,
  }) {
    return RecipeIngredientModel(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      cost: cost ?? this.cost,
    );
  }
}
