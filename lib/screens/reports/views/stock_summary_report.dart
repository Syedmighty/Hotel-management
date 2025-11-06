import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../providers/product_provider.dart';
import '../../../db/app_database.dart';
import '../../../services/pdf_service.dart';

class StockSummaryReport extends ConsumerStatefulWidget {
  const StockSummaryReport({super.key});

  @override
  ConsumerState<StockSummaryReport> createState() =>
      _StockSummaryReportState();
}

class _StockSummaryReportState extends ConsumerState<StockSummaryReport> {
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Summary Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export to PDF',
            onPressed: () => _exportToPdf(productsAsync),
          ),
        ],
      ),
      body: productsAsync.when(
        data: (products) {
          // Filter by category if selected
          var filteredProducts = products.where((p) => p.isActive).toList();
          if (_selectedCategory != null) {
            filteredProducts = filteredProducts
                .where((p) => p.category == _selectedCategory)
                .toList();
          }

          // Calculate totals
          double totalValue = 0;
          double totalPurchaseValue = 0;
          int lowStockItems = 0;
          int outOfStockItems = 0;

          for (final product in filteredProducts) {
            final value = product.currentStock * product.sellingRate;
            final purchaseValue = product.currentStock * product.purchaseRate;
            totalValue += value;
            totalPurchaseValue += purchaseValue;

            if (product.currentStock <= 0) {
              outOfStockItems++;
            } else if (product.currentStock <= product.minStockLevel) {
              lowStockItems++;
            }
          }

          // Group by category
          Map<String, List<Product>> byCategory = {};
          for (final product in filteredProducts) {
            if (!byCategory.containsKey(product.category)) {
              byCategory[product.category] = [];
            }
            byCategory[product.category]!.add(product);
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(isWeb ? 24.0 : 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with date
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stock Summary Report',
                          style:
                              Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Generated on: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
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
                          title: 'Total Items',
                          value: filteredProducts.length.toString(),
                          icon: Icons.inventory_2,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Total Value (Selling)',
                          value: NumberFormat.currency(symbol: '₹')
                              .format(totalValue),
                          icon: Icons.attach_money,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Low Stock Items',
                          value: lowStockItems.toString(),
                          icon: Icons.warning,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Out of Stock',
                          value: outOfStockItems.toString(),
                          icon: Icons.remove_circle,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          title: 'Total Items',
                          value: filteredProducts.length.toString(),
                          icon: Icons.inventory_2,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Total Value',
                          value: NumberFormat.compactCurrency(symbol: '₹')
                              .format(totalValue),
                          icon: Icons.attach_money,
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
                          title: 'Low Stock',
                          value: lowStockItems.toString(),
                          icon: Icons.warning,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Out of Stock',
                          value: outOfStockItems.toString(),
                          icon: Icons.remove_circle,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                // Category Filter
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Text(
                          'Filter by Category:',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButton<String?>(
                            value: _selectedCategory,
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('All Categories'),
                              ),
                              ...byCategory.keys.map((category) {
                                return DropdownMenuItem(
                                  value: category,
                                  child: Text(category),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedCategory = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Stock by Category
                ...byCategory.entries.map((entry) {
                  final category = entry.key;
                  final products = entry.value;

                  double categoryValue = 0;
                  for (final product in products) {
                    categoryValue +=
                        product.currentStock * product.sellingRate;
                  }

                  return _CategorySection(
                    category: category,
                    products: products,
                    categoryValue: categoryValue,
                    isWeb: isWeb,
                  );
                }),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  Future<void> _exportToPdf(AsyncValue<List<Product>> productsAsync) async {
    await productsAsync.when(
      data: (products) async {
        try {
          // Show loading indicator
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Generating PDF...'),
                duration: Duration(seconds: 2),
              ),
            );
          }

          // Filter products
          var filteredProducts = products.where((p) => p.isActive).toList();
          if (_selectedCategory != null) {
            filteredProducts = filteredProducts
                .where((p) => p.category == _selectedCategory)
                .toList();
          }

          // Calculate summary data
          double totalValue = 0;
          int lowStockItems = 0;
          int outOfStockItems = 0;

          for (final product in filteredProducts) {
            final value = product.currentStock * product.sellingRate;
            totalValue += value;

            if (product.currentStock <= 0) {
              outOfStockItems++;
            } else if (product.currentStock <= product.minStockLevel) {
              lowStockItems++;
            }
          }

          final currencyFormat = NumberFormat.currency(symbol: '₹');

          // Prepare table data
          final tableHeaders = [
            ['Product', 'Category', 'Unit', 'Stock', 'Rate', 'Value'],
          ];

          final tableData = filteredProducts.map((product) {
            final value = product.currentStock * product.sellingRate;
            return [
              product.name,
              product.category,
              product.unit,
              product.currentStock.toStringAsFixed(2),
              currencyFormat.format(product.purchaseRate),
              currencyFormat.format(value),
            ];
          }).toList();

          // Create report config
          final config = ReportConfig(
            title: 'Stock Summary Report',
            subtitle: 'Current Inventory Levels and Valuations',
            generatedDate: DateTime.now(),
            filters: _selectedCategory != null
                ? ['Category: $_selectedCategory']
                : null,
            summaryData: {
              'Total Items': filteredProducts.length.toString(),
              'Total Value': currencyFormat.format(totalValue),
              'Low Stock': lowStockItems.toString(),
              'Out of Stock': outOfStockItems.toString(),
            },
            tableHeaders: tableHeaders,
            tableData: tableData,
          );

          // Generate PDF
          final pdfService = PdfService();
          final file = await pdfService.generateReport(config);

          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('PDF saved: ${file.path}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'OK',
                  textColor: Colors.white,
                  onPressed: () {},
                ),
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
      loading: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Loading data...')),
          );
        }
      },
      error: (error, stack) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }
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
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
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

class _CategorySection extends StatelessWidget {
  final String category;
  final List<Product> products;
  final double categoryValue;
  final bool isWeb;

  const _CategorySection({
    required this.category,
    required this.products,
    required this.categoryValue,
    required this.isWeb,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  category,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${products.length} items',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      currencyFormat.format(categoryValue),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            if (isWeb)
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(3),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1),
                  4: FlexColumnWidth(1.5),
                  5: FlexColumnWidth(1.5),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                    ),
                    children: [
                      _TableHeaderCell('Product'),
                      _TableHeaderCell('Unit'),
                      _TableHeaderCell('Stock'),
                      _TableHeaderCell('Min Level'),
                      _TableHeaderCell('Purchase Rate'),
                      _TableHeaderCell('Value'),
                    ],
                  ),
                  ...products.map((product) {
                    final value =
                        product.currentStock * product.sellingRate;
                    final isLowStock =
                        product.currentStock <= product.minStockLevel;

                    return TableRow(
                      children: [
                        _TableCell(product.name),
                        _TableCell(product.unit),
                        _TableCell(
                          product.currentStock.toStringAsFixed(2),
                          color: isLowStock ? Colors.red : null,
                        ),
                        _TableCell(product.minStockLevel.toStringAsFixed(0)),
                        _TableCell(currencyFormat.format(product.purchaseRate)),
                        _TableCell(
                          currencyFormat.format(value),
                          bold: true,
                        ),
                      ],
                    );
                  }),
                ],
              )
            else
              ...products.map((product) {
                final value = product.currentStock * product.sellingRate;
                final isLowStock =
                    product.currentStock <= product.minStockLevel;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                    color: isLowStock ? Colors.red[50] : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Stock:'),
                          Text(
                            '${product.currentStock.toStringAsFixed(2)} ${product.unit}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isLowStock ? Colors.red : null,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Value:'),
                          Text(
                            currencyFormat.format(value),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _TableHeaderCell extends StatelessWidget {
  final String text;

  const _TableHeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final bool bold;
  final Color? color;

  const _TableCell(this.text, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color,
        ),
      ),
    );
  }
}
