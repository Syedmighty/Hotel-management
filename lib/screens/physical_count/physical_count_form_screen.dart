import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../db/app_database.dart';
import '../../providers/physical_count_provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/constants.dart';

class PhysicalCountFormScreen extends ConsumerStatefulWidget {
  final String? countId;

  const PhysicalCountFormScreen({
    super.key,
    this.countId,
  });

  @override
  ConsumerState<PhysicalCountFormScreen> createState() =>
      _PhysicalCountFormScreenState();
}

class _PhysicalCountFormScreenState
    extends ConsumerState<PhysicalCountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _countNoController = TextEditingController();
  final _countedByController = TextEditingController();
  final _remarksController = TextEditingController();
  final _searchController = TextEditingController();

  DateTime _countDate = DateTime.now();
  final List<CountLineItemModel> _lineItems = [];
  bool _isLoading = false;
  bool _isApproved = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  Future<void> _initializeForm() async {
    if (widget.countId != null) {
      // Load existing count
      await _loadCount();
    } else {
      // Generate next count number and initialize
      final nextCountNo = await ref
          .read(physicalCountNotifierProvider.notifier)
          .getNextCountNo();
      _countNoController.text = nextCountNo;

      final currentUser = ref.read(currentUserProvider);
      _countedByController.text = currentUser?.username ?? '';

      // Load all products for counting
      await _loadProductsForCount();
    }
  }

  Future<void> _loadCount() async {
    setState(() => _isLoading = true);
    try {
      final countDao = ref.read(physicalCountDaoProvider);
      final count = await countDao.getPhysicalCountById(widget.countId!);

      if (count != null) {
        _countNoController.text = count.countNo;
        _countDate = count.countDate;
        _countedByController.text = count.countedBy;
        _remarksController.text = count.remarks ?? '';
        _isApproved = count.status == 'Approved';

        // Load line items with variance
        final itemsWithVariance =
            await countDao.getLineItemsWithVariance(widget.countId!);

        setState(() {
          _lineItems.clear();
          _lineItems.addAll(itemsWithVariance.map((item) =>
              CountLineItemModel(
                product: item.product,
                systemStock: item.systemStock,
                countedQuantity: item.lineItem.countedQuantity,
                variance: item.variance,
                varianceReason: item.lineItem.varianceReason,
              )));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading count: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProductsForCount() async {
    setState(() => _isLoading = true);
    try {
      final countDao = ref.read(physicalCountDaoProvider);
      final productsForCount = await countDao.getProductsForCount();

      setState(() {
        _lineItems.clear();
        _lineItems.addAll(productsForCount.map((pfc) => CountLineItemModel(
              product: pfc.product,
              systemStock: pfc.systemStock,
              countedQuantity: pfc.systemStock, // Default to system stock
              variance: 0.0,
              varianceReason: null,
            )));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updateLineItem(int index, CountLineItemModel item) {
    setState(() {
      _lineItems[index] = item;
    });
  }

  List<CountLineItemModel> get _filteredLineItems {
    if (_searchQuery.isEmpty) {
      return _lineItems;
    }
    final lowerQuery = _searchQuery.toLowerCase();
    return _lineItems.where((item) {
      return item.product.name.toLowerCase().contains(lowerQuery) ||
          item.product.category.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  Future<void> _saveCount({bool approve = false}) async {
    if (!_formKey.currentState!.validate()) return;

    // Validate that at least one item is counted
    if (_lineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No products available for counting')),
      );
      return;
    }

    // If approving, validate variance reasons for items with variance
    if (approve) {
      for (int i = 0; i < _lineItems.length; i++) {
        final item = _lineItems[i];
        if (item.variance != 0 &&
            (item.varianceReason == null || item.varianceReason!.isEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Please provide variance reason for ${item.product.name}')),
          );
          return;
        }
      }
    }

    setState(() => _isLoading = true);

    try {
      final lineItemsCompanions = _lineItems
          .map((item) => PhysicalCountLineItemsCompanion.insert(
                countId: '', // Will be set by DAO
                productId: item.product.uuid,
                systemStock: item.systemStock,
                countedQuantity: item.countedQuantity,
                variance: drift.Value(item.variance),
                varianceReason: drift.Value(item.varianceReason),
                createdAt: DateTime.now(),
                lastModified: DateTime.now(),
              ))
          .toList();

      final notifier = ref.read(physicalCountNotifierProvider.notifier);
      String? resultId;

      if (widget.countId != null) {
        // Update existing count
        final success = await notifier.updatePhysicalCount(
          countId: widget.countId!,
          countNo: _countNoController.text,
          countDate: _countDate,
          countedBy: _countedByController.text,
          lineItems: lineItemsCompanions,
          remarks: _remarksController.text.isEmpty
              ? null
              : _remarksController.text,
        );

        if (success) {
          resultId = widget.countId;
        }
      } else {
        // Create new count
        resultId = await notifier.createPhysicalCount(
          countNo: _countNoController.text,
          countDate: _countDate,
          countedBy: _countedByController.text,
          lineItems: lineItemsCompanions,
          remarks: _remarksController.text.isEmpty
              ? null
              : _remarksController.text,
        );
      }

      if (resultId != null) {
        // If approve flag is set, approve the count
        if (approve && !_isApproved) {
          final approved = await notifier.approvePhysicalCount(resultId);
          if (!approved) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Count saved but approval failed')),
              );
            }
            setState(() => _isLoading = false);
            return;
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(approve
                  ? 'Physical count approved and stock adjusted'
                  : 'Physical count saved successfully'),
            ),
          );
          context.pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save physical count')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _countNoController.dispose();
    _countedByController.dispose();
    _remarksController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.countId != null;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 900;

    // Calculate summary statistics
    int itemsWithVariance = 0;
    double totalVarianceValue = 0.0;
    for (final item in _lineItems) {
      if (item.variance != 0) {
        itemsWithVariance++;
        totalVarianceValue +=
            item.variance * item.product.purchaseRate;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Physical Count' : 'New Physical Count'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isWeb ? 24 : 16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Section
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.inventory,
                                        color: Colors.blue[700],
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Physical Count Details',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _countNoController,
                                          decoration: const InputDecoration(
                                            labelText: 'Count No *',
                                            prefixIcon: Icon(Icons.numbers),
                                            border: OutlineInputBorder(),
                                          ),
                                          validator: (value) {
                                            if (value?.isEmpty ?? true) {
                                              return 'Required';
                                            }
                                            return null;
                                          },
                                          enabled: !_isApproved,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: InkWell(
                                          onTap: _isApproved
                                              ? null
                                              : () async {
                                                  final date =
                                                      await showDatePicker(
                                                    context: context,
                                                    initialDate: _countDate,
                                                    firstDate: DateTime(2000),
                                                    lastDate: DateTime(2100),
                                                  );
                                                  if (date != null) {
                                                    setState(() {
                                                      _countDate = date;
                                                    });
                                                  }
                                                },
                                          child: InputDecorator(
                                            decoration: const InputDecoration(
                                              labelText: 'Count Date *',
                                              prefixIcon:
                                                  Icon(Icons.calendar_today),
                                              border: OutlineInputBorder(),
                                            ),
                                            child: Text(
                                              DateFormat('dd MMM yyyy')
                                                  .format(_countDate),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _countedByController,
                                    decoration: const InputDecoration(
                                      labelText: 'Counted By *',
                                      prefixIcon: Icon(Icons.person),
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      if (value?.isEmpty ?? true) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                    enabled: !_isApproved,
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _remarksController,
                                    decoration: const InputDecoration(
                                      labelText: 'Remarks',
                                      prefixIcon: Icon(Icons.note),
                                      border: OutlineInputBorder(),
                                    ),
                                    maxLines: 2,
                                    enabled: !_isApproved,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Summary Card
                          if (isEdit)
                            Card(
                              color: itemsWithVariance > 0
                                  ? Colors.orange[50]
                                  : Colors.green[50],
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _SummaryItem(
                                          label: 'Total Items',
                                          value: _lineItems.length.toString(),
                                          icon: Icons.inventory_2,
                                          color: Colors.blue,
                                        ),
                                        _SummaryItem(
                                          label: 'With Variance',
                                          value: itemsWithVariance.toString(),
                                          icon: Icons.warning,
                                          color: Colors.orange,
                                        ),
                                        _SummaryItem(
                                          label: 'Variance Value',
                                          value: NumberFormat.currency(
                                                  symbol: '₹', decimalDigits: 0)
                                              .format(totalVarianceValue.abs()),
                                          icon: totalVarianceValue >= 0
                                              ? Icons.arrow_upward
                                              : Icons.arrow_downward,
                                          color: totalVarianceValue >= 0
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          const SizedBox(height: 24),

                          // Products Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Products to Count',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${_filteredLineItems.length} items',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Search bar
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search products...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          _searchQuery = '';
                                        });
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                            enabled: !_isApproved,
                          ),

                          const SizedBox(height: 16),

                          // Products list
                          if (_filteredLineItems.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  children: [
                                    Icon(Icons.inventory_2_outlined,
                                        size: 48, color: Colors.grey[400]),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No products found',
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
                            ..._filteredLineItems.asMap().entries.map((entry) {
                              final originalIndex =
                                  _lineItems.indexOf(entry.value);
                              final item = entry.value;
                              return _CountLineItemCard(
                                key: ValueKey(item.product.uuid),
                                item: item,
                                index: entry.key,
                                onUpdate: (updatedItem) =>
                                    _updateLineItem(originalIndex, updatedItem),
                                enabled: !_isApproved,
                              );
                            }).toList(),

                          const SizedBox(height: 100), // Space for bottom bar
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom action bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: SafeArea(
                    child: !_isApproved
                        ? Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed:
                                      _isLoading ? null : () => _saveCount(),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                  ),
                                  child: const Text('Save as Pending'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () => _saveCount(approve: true),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    backgroundColor: Colors.green,
                                  ),
                                  child:
                                      const Text('Approve & Adjust Stock'),
                                ),
                              ),
                            ],
                          )
                        : Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle,
                                    color: Colors.green[800]),
                                const SizedBox(width: 8),
                                Text(
                                  'Physical Count Approved & Stock Adjusted',
                                  style: TextStyle(
                                    color: Colors.green[800],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}

// Line item model for state management
class CountLineItemModel {
  final Product product;
  final double systemStock;
  final double countedQuantity;
  final double variance;
  final String? varianceReason;

  CountLineItemModel({
    required this.product,
    required this.systemStock,
    required this.countedQuantity,
    required this.variance,
    this.varianceReason,
  });

  CountLineItemModel copyWith({
    Product? product,
    double? systemStock,
    double? countedQuantity,
    double? variance,
    String? varianceReason,
  }) {
    return CountLineItemModel(
      product: product ?? this.product,
      systemStock: systemStock ?? this.systemStock,
      countedQuantity: countedQuantity ?? this.countedQuantity,
      variance: variance ?? this.variance,
      varianceReason: varianceReason ?? this.varianceReason,
    );
  }
}

// Summary item widget
class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

// Count line item card widget
class _CountLineItemCard extends ConsumerStatefulWidget {
  final CountLineItemModel item;
  final int index;
  final Function(CountLineItemModel) onUpdate;
  final bool enabled;

  const _CountLineItemCard({
    super.key,
    required this.item,
    required this.index,
    required this.onUpdate,
    required this.enabled,
  });

  @override
  ConsumerState<_CountLineItemCard> createState() =>
      _CountLineItemCardState();
}

class _CountLineItemCardState extends ConsumerState<_CountLineItemCard> {
  final _countedQtyController = TextEditingController();
  String? _selectedVarianceReason;

  @override
  void initState() {
    super.initState();
    _countedQtyController.text = widget.item.countedQuantity > 0
        ? widget.item.countedQuantity.toString()
        : '';
    _selectedVarianceReason = widget.item.varianceReason;

    _countedQtyController.addListener(_updateItem);
  }

  void _updateItem() {
    final countedQty = double.tryParse(_countedQtyController.text) ?? 0.0;
    final variance = countedQty - widget.item.systemStock;

    widget.onUpdate(widget.item.copyWith(
      countedQuantity: countedQty,
      variance: variance,
      varianceReason: _selectedVarianceReason,
    ));
  }

  @override
  void dispose() {
    _countedQtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final variance = widget.item.variance;
    final hasVariance = variance.abs() > 0.001; // Accounting for floating point

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: hasVariance ? Colors.orange[50] : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.product.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.item.product.category} • ${widget.item.product.unit}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasVariance)
                  Icon(
                    Icons.warning,
                    color: Colors.orange[700],
                    size: 20,
                  ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'System Stock',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.item.systemStock.toString(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _countedQtyController,
                    decoration: const InputDecoration(
                      labelText: 'Counted Qty *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    enabled: widget.enabled,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Variance',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        variance.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: variance > 0
                              ? Colors.green
                              : (variance < 0 ? Colors.red : Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasVariance) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedVarianceReason,
                decoration: const InputDecoration(
                  labelText: 'Variance Reason *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info_outline),
                ),
                items: [
                  'Count Error',
                  'System Error',
                  'Theft/Pilferage',
                  'Spillage/Breakage',
                  'Unrecorded Usage',
                  'Unrecorded Purchase',
                  'Expired/Damaged',
                  'Other',
                ].map((reason) => DropdownMenuItem(
                      value: reason,
                      child: Text(reason),
                    ))
                    .toList(),
                onChanged: widget.enabled
                    ? (value) {
                        setState(() {
                          _selectedVarianceReason = value;
                        });
                        _updateItem();
                      }
                    : null,
                validator: (value) {
                  if (hasVariance && (value == null || value.isEmpty)) {
                    return 'Required for variance';
                  }
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
