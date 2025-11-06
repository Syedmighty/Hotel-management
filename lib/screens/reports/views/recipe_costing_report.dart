import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../providers/recipe_provider.dart';
import '../../../db/daos/recipe_dao.dart';
import '../../../services/pdf_service.dart';

class RecipeCostingReport extends ConsumerStatefulWidget {
  const RecipeCostingReport({super.key});

  @override
  ConsumerState<RecipeCostingReport> createState() =>
      _RecipeCostingReportState();
}

class _RecipeCostingReportState extends ConsumerState<RecipeCostingReport> {
  String? _selectedCategory;
  double _minMargin = 0;
  double _maxMargin = 1000;

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(recipesProvider);
    final categoriesAsync = ref.watch(recipeCategoriesProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Costing Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export to PDF',
            onPressed: () => _exportToPdf(recipesAsync),
          ),
        ],
      ),
      body: recipesAsync.when(
        data: (recipes) {
          // Calculate cost details for all recipes
          final recipesWithCosts = recipes.map((recipe) {
            final costPerServing = recipe.costPerServing;
            final profitPerServing = recipe.sellingPrice - costPerServing;
            final profitMargin = costPerServing > 0
                ? (profitPerServing / costPerServing) * 100
                : 0.0;

            return _RecipeCostData(
              recipe: recipe,
              costPerServing: costPerServing,
              profitPerServing: profitPerServing,
              profitMargin: profitMargin,
            );
          }).toList();

          // Apply filters
          var filteredRecipes = recipesWithCosts.where((data) {
            // Category filter
            if (_selectedCategory != null &&
                data.recipe.category != _selectedCategory) {
              return false;
            }
            // Margin filter
            if (data.profitMargin < _minMargin ||
                data.profitMargin > _maxMargin) {
              return false;
            }
            return true;
          }).toList();

          // Sort by profit margin descending
          filteredRecipes
              .sort((a, b) => b.profitMargin.compareTo(a.profitMargin));

          // Calculate totals
          double totalRevenue = 0;
          double totalCost = 0;
          double averageMargin = 0;
          int highProfitCount = 0;
          int mediumProfitCount = 0;
          int lowProfitCount = 0;

          for (final data in filteredRecipes) {
            totalRevenue += data.recipe.sellingPrice;
            totalCost += data.costPerServing;
            if (data.profitMargin >= 50) {
              highProfitCount++;
            } else if (data.profitMargin >= 25) {
              mediumProfitCount++;
            } else {
              lowProfitCount++;
            }
          }

          averageMargin = filteredRecipes.isNotEmpty
              ? filteredRecipes.fold(0.0,
                      (sum, data) => sum + data.profitMargin) /
                  filteredRecipes.length
              : 0.0;

          return SingleChildScrollView(
            padding: EdgeInsets.all(isWeb ? 24.0 : 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recipe Costing Report',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Menu Engineering & Profit Analysis',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                        Text(
                          'Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Filters
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Filters',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 16),
                        if (isWeb)
                          Row(
                            children: [
                              Expanded(child: _buildCategoryFilter(categoriesAsync)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildMinMarginFilter()),
                              const SizedBox(width: 12),
                              Expanded(child: _buildMaxMarginFilter()),
                            ],
                          )
                        else ...[
                          _buildCategoryFilter(categoriesAsync),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _buildMinMarginFilter()),
                              const SizedBox(width: 12),
                              Expanded(child: _buildMaxMarginFilter()),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Summary Cards
                if (isWeb)
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          title: 'Total Recipes',
                          value: filteredRecipes.length.toString(),
                          icon: Icons.restaurant_menu,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Avg Margin',
                          value: '${averageMargin.toStringAsFixed(1)}%',
                          icon: Icons.trending_up,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'High Profit (>50%)',
                          value: highProfitCount.toString(),
                          icon: Icons.star,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Need Review (<25%)',
                          value: lowProfitCount.toString(),
                          icon: Icons.warning,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          title: 'Recipes',
                          value: filteredRecipes.length.toString(),
                          icon: Icons.restaurant_menu,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Avg Margin',
                          value: '${averageMargin.toStringAsFixed(1)}%',
                          icon: Icons.trending_up,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          title: 'High Profit',
                          value: highProfitCount.toString(),
                          icon: Icons.star,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Need Review',
                          value: lowProfitCount.toString(),
                          icon: Icons.warning,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                // Profit Distribution
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profit Margin Distribution',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        _ProfitBar(
                          label: 'High Profit (≥50%)',
                          count: highProfitCount,
                          total: filteredRecipes.length,
                          color: Colors.green,
                        ),
                        const SizedBox(height: 12),
                        _ProfitBar(
                          label: 'Medium Profit (25-50%)',
                          count: mediumProfitCount,
                          total: filteredRecipes.length,
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 12),
                        _ProfitBar(
                          label: 'Low Profit (<25%)',
                          count: lowProfitCount,
                          total: filteredRecipes.length,
                          color: Colors.orange,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Recipes List
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
                        if (filteredRecipes.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Text(
                                'No recipes found for selected filters',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          )
                        else if (isWeb)
                          _buildWebTable(filteredRecipes)
                        else
                          _buildMobileList(filteredRecipes),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Future<void> _exportToPdf(AsyncValue<List<dynamic>> recipesAsync) async {
    await recipesAsync.when(
      data: (recipes) async {
        try {
          final currencyFormat = NumberFormat.currency(symbol: '₹');

          // Calculate cost details for all recipes
          final recipesWithCosts = recipes.map((recipe) {
            final costPerServing = recipe.costPerServing;
            final profitPerServing = recipe.sellingPrice - costPerServing;
            final profitMargin = costPerServing > 0
                ? (profitPerServing / costPerServing) * 100
                : 0.0;

            return _RecipeCostData(
              recipe: recipe,
              costPerServing: costPerServing,
              profitPerServing: profitPerServing,
              profitMargin: profitMargin,
            );
          }).toList();

          // Apply same filters as UI
          var filteredRecipes = recipesWithCosts.where((data) {
            if (_selectedCategory != null &&
                data.recipe.category != _selectedCategory) {
              return false;
            }
            if (data.profitMargin < _minMargin ||
                data.profitMargin > _maxMargin) {
              return false;
            }
            return true;
          }).toList();

          // Sort by profit margin descending
          filteredRecipes
              .sort((a, b) => b.profitMargin.compareTo(a.profitMargin));

          // Calculate summary
          double averageMargin = 0;
          int highProfitCount = 0;
          int mediumProfitCount = 0;
          int lowProfitCount = 0;

          for (final data in filteredRecipes) {
            if (data.profitMargin >= 50) {
              highProfitCount++;
            } else if (data.profitMargin >= 25) {
              mediumProfitCount++;
            } else {
              lowProfitCount++;
            }
          }

          averageMargin = filteredRecipes.isNotEmpty
              ? filteredRecipes.fold(0.0,
                      (sum, data) => sum + data.profitMargin) /
                  filteredRecipes.length
              : 0.0;

          // Prepare filters list
          List<String> filters = [];
          if (_selectedCategory != null) {
            filters.add('Category: $_selectedCategory');
          }
          if (_minMargin > 0 || _maxMargin < 1000) {
            filters.add('Margin: ${_minMargin}% - ${_maxMargin}%');
          }

          // Prepare table data
          final tableHeaders = [
            ['Recipe', 'Category', 'Cost', 'Price', 'Profit', 'Margin %'],
          ];
          final tableData = filteredRecipes.map((data) {
            return [
              data.recipe.dishName,
              data.recipe.category,
              currencyFormat.format(data.costPerServing),
              currencyFormat.format(data.recipe.sellingPrice),
              currencyFormat.format(data.profitPerServing),
              '${data.profitMargin.toStringAsFixed(1)}%',
            ];
          }).toList();

          // Create report config
          final config = ReportConfig(
            title: 'Recipe Costing Report',
            subtitle: 'Menu Engineering & Profit Analysis',
            generatedDate: DateTime.now(),
            filters: filters.isEmpty ? null : filters,
            summaryData: {
              'Total Recipes': filteredRecipes.length.toString(),
              'Avg Margin': '${averageMargin.toStringAsFixed(1)}%',
              'High Profit (≥50%)': highProfitCount.toString(),
              'Need Review (<25%)': lowProfitCount.toString(),
            },
            tableHeaders: tableHeaders,
            tableData: tableData,
          );

          // Generate PDF
          final pdfService = PdfService();
          final file = await pdfService.generateReport(config);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('PDF saved: ${file.path}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error generating PDF: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      loading: () async {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loading data...')),
        );
      },
      error: (error, stack) async {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  Widget _buildCategoryFilter(List<String> categories) {
    return DropdownButtonFormField<String?>(
      value: _selectedCategory,
      decoration: const InputDecoration(
        labelText: 'Category',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('All Categories')),
        ...categories.map((cat) => DropdownMenuItem(
              value: cat,
              child: Text(cat),
            )),
      ],
      onChanged: (value) => setState(() => _selectedCategory = value),
    );
  }

  Widget _buildMinMarginFilter() {
    return TextFormField(
      initialValue: _minMargin.toString(),
      decoration: const InputDecoration(
        labelText: 'Min Margin %',
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      onChanged: (value) {
        setState(() {
          _minMargin = double.tryParse(value) ?? 0;
        });
      },
    );
  }

  Widget _buildMaxMarginFilter() {
    return TextFormField(
      initialValue: _maxMargin.toString(),
      decoration: const InputDecoration(
        labelText: 'Max Margin %',
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      onChanged: (value) {
        setState(() {
          _maxMargin = double.tryParse(value) ?? 1000;
        });
      },
    );
  }

  Widget _buildWebTable(List<_RecipeCostData> recipes) {
    final currencyFormat = NumberFormat.currency(symbol: '₹');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Recipe')),
          DataColumn(label: Text('Category')),
          DataColumn(label: Text('Cost/Serving')),
          DataColumn(label: Text('Selling Price')),
          DataColumn(label: Text('Profit/Serving')),
          DataColumn(label: Text('Margin %')),
        ],
        rows: recipes.map((data) {
          final marginColor = data.profitMargin >= 50
              ? Colors.green
              : (data.profitMargin >= 25 ? Colors.blue : Colors.orange);

          return DataRow(
            cells: [
              DataCell(Text(data.recipe.dishName)),
              DataCell(Text(data.recipe.category)),
              DataCell(Text(currencyFormat.format(data.costPerServing))),
              DataCell(Text(currencyFormat.format(data.recipe.sellingPrice))),
              DataCell(
                Text(
                  currencyFormat.format(data.profitPerServing),
                  style: TextStyle(
                    color: marginColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: marginColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${data.profitMargin.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: marginColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileList(List<_RecipeCostData> recipes) {
    final currencyFormat = NumberFormat.currency(symbol: '₹');

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final data = recipes[index];
        final marginColor = data.profitMargin >= 50
            ? Colors.green
            : (data.profitMargin >= 25 ? Colors.blue : Colors.orange);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        data.recipe.dishName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: marginColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${data.profitMargin.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: marginColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  data.recipe.category,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cost/Serving',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                        Text(currencyFormat.format(data.costPerServing),
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Selling Price',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                        Text(currencyFormat.format(data.recipe.sellingPrice),
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: marginColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Profit/Serving',
                          style: TextStyle(fontSize: 14, color: marginColor)),
                      Text(currencyFormat.format(data.profitPerServing),
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: marginColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RecipeCostData {
  final dynamic recipe;
  final double costPerServing;
  final double profitPerServing;
  final double profitMargin;

  _RecipeCostData({
    required this.recipe,
    required this.costPerServing,
    required this.profitPerServing,
    required this.profitMargin,
  });
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfitBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _ProfitBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (count / total) * 100 : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Text(
              '$count recipes (${percentage.toStringAsFixed(1)}%)',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
        ),
      ],
    );
  }
}
