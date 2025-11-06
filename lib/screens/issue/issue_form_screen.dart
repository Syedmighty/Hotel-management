import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../db/app_database.dart';
import '../../providers/issue_provider.dart';
import '../../providers/product_provider.dart';

class IssueFormScreen extends ConsumerStatefulWidget {
  final String? issueId;

  const IssueFormScreen({super.key, this.issueId});

  @override
  ConsumerState<IssueFormScreen> createState() => _IssueFormScreenState();
}

class _IssueFormScreenState extends ConsumerState<IssueFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _issueNoController = TextEditingController();
  final _issuedToController = TextEditingController();
  final _requestedByController = TextEditingController();
  final _purposeController = TextEditingController();
  final _remarksController = TextEditingController();

  DateTime _issueDate = DateTime.now();
  final List<IssueLineItemModel> _lineItems = [];
  bool _isLoading = false;
  bool _isApproved = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  Future<void> _initializeForm() async {
    if (widget.issueId != null) {
      // Load existing issue
      await _loadIssue();
    } else {
      // Generate next issue number
      final nextIssueNo =
          await ref.read(issueNotifierProvider.notifier).getNextIssueNo();
      _issueNoController.text = nextIssueNo;

      // Add one empty line item
      setState(() {
        _lineItems.add(IssueLineItemModel(
          productId: null,
          quantity: 0.0,
          rate: 0.0,
          batchNo: null,
        ));
      });
    }
  }

  Future<void> _loadIssue() async {
    setState(() => _isLoading = true);
    try {
      final issueDao = ref.read(issueDaoProvider);
      final issue = await issueDao.getIssueById(widget.issueId!);
      final lineItems = await issueDao.getIssueLineItems(widget.issueId!);

      if (issue != null) {
        setState(() {
          _issueNoController.text = issue.issueNo;
          _issueDate = issue.issueDate;
          _issuedToController.text = issue.issuedTo;
          _requestedByController.text = issue.requestedBy;
          _purposeController.text = issue.purpose;
          _remarksController.text = issue.remarks ?? '';
          _isApproved = issue.status == 'Approved';

          _lineItems.clear();
          _lineItems.addAll(lineItems.map((item) => IssueLineItemModel(
                productId: item.productId,
                quantity: item.quantity,
                rate: item.rate,
                batchNo: item.batchNo,
              )));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading issue: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addLineItem() {
    setState(() {
      _lineItems.add(IssueLineItemModel(
        productId: null,
        quantity: 0.0,
        rate: 0.0,
        batchNo: null,
      ));
    });
  }

  void _removeLineItem(int index) {
    setState(() {
      _lineItems.removeAt(index);
    });
  }

  void _updateLineItem(int index, IssueLineItemModel item) {
    setState(() {
      _lineItems[index] = item;
    });
  }

  double _calculateTotal() {
    return _lineItems.fold(0.0, (sum, item) {
      return sum + (item.quantity * item.rate);
    });
  }

  Future<void> _saveIssue({bool approve = false}) async {
    if (!_formKey.currentState!.validate()) return;

    // Validate line items
    if (_lineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one line item')),
      );
      return;
    }

    for (int i = 0; i < _lineItems.length; i++) {
      final item = _lineItems[i];
      if (item.productId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select a product for line ${i + 1}')),
        );
        return;
      }
      if (item.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter quantity for line ${i + 1}')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final lineItemsCompanions = _lineItems
          .map((item) => IssueLineItemsCompanion.insert(
                issueId: '', // Will be set by DAO
                productId: item.productId!,
                quantity: item.quantity,
                rate: item.rate,
                batchNo: drift.Value(item.batchNo),
                createdAt: DateTime.now(),
                lastModified: DateTime.now(),
              ))
          .toList();

      final notifier = ref.read(issueNotifierProvider.notifier);
      String? resultId;

      if (widget.issueId != null) {
        // Update existing issue
        final success = await notifier.updateIssue(
          issueId: widget.issueId!,
          issueNo: _issueNoController.text,
          issueDate: _issueDate,
          issuedTo: _issuedToController.text,
          requestedBy: _requestedByController.text,
          purpose: _purposeController.text,
          totalAmount: _calculateTotal(),
          lineItems: lineItemsCompanions,
          remarks: _remarksController.text.isEmpty
              ? null
              : _remarksController.text,
        );

        if (success) {
          resultId = widget.issueId;
        }
      } else {
        // Create new issue
        resultId = await notifier.createIssue(
          issueNo: _issueNoController.text,
          issueDate: _issueDate,
          issuedTo: _issuedToController.text,
          requestedBy: _requestedByController.text,
          purpose: _purposeController.text,
          totalAmount: _calculateTotal(),
          lineItems: lineItemsCompanions,
          remarks: _remarksController.text.isEmpty
              ? null
              : _remarksController.text,
        );
      }

      if (resultId != null) {
        // If approve flag is set, approve the issue
        if (approve && !_isApproved) {
          final approved = await notifier.approveIssue(resultId);
          if (!approved) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Issue saved but approval failed')),
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
                  ? 'Issue approved successfully'
                  : 'Issue saved successfully'),
            ),
          );
          context.pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save issue')),
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
    _issueNoController.dispose();
    _issuedToController.dispose();
    _requestedByController.dispose();
    _purposeController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.issueId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Issue Voucher' : 'New Issue Voucher'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Issue Header Section
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Issue Details',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _issueNoController,
                                          decoration: const InputDecoration(
                                            labelText: 'Issue No *',
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
                                                    initialDate: _issueDate,
                                                    firstDate: DateTime(2000),
                                                    lastDate: DateTime(2100),
                                                  );
                                                  if (date != null) {
                                                    setState(() {
                                                      _issueDate = date;
                                                    });
                                                  }
                                                },
                                          child: InputDecorator(
                                            decoration: const InputDecoration(
                                              labelText: 'Issue Date *',
                                              prefixIcon:
                                                  Icon(Icons.calendar_today),
                                              border: OutlineInputBorder(),
                                            ),
                                            child: Text(
                                              DateFormat('dd MMM yyyy')
                                                  .format(_issueDate),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _issuedToController,
                                    decoration: const InputDecoration(
                                      labelText: 'Issued To (Department) *',
                                      prefixIcon: Icon(Icons.business),
                                      border: OutlineInputBorder(),
                                      hintText:
                                          'Kitchen, Bar, Housekeeping, etc.',
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
                                    controller: _requestedByController,
                                    decoration: const InputDecoration(
                                      labelText: 'Requested By *',
                                      prefixIcon: Icon(Icons.person),
                                      border: OutlineInputBorder(),
                                      hintText: 'Name of requester',
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
                                    controller: _purposeController,
                                    decoration: const InputDecoration(
                                      labelText: 'Purpose *',
                                      prefixIcon: Icon(Icons.description),
                                      border: OutlineInputBorder(),
                                      hintText:
                                          'Daily usage, event, catering, etc.',
                                    ),
                                    validator: (value) {
                                      if (value?.isEmpty ?? true) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                    maxLines: 2,
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

                          // Line Items Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Line Items',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (!_isApproved)
                                ElevatedButton.icon(
                                  onPressed: _addLineItem,
                                  icon: const Icon(Icons.add, size: 20),
                                  label: const Text('Add Item'),
                                ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Line items list
                          if (_lineItems.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  children: [
                                    Icon(Icons.inventory_2_outlined,
                                        size: 48, color: Colors.grey[400]),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No items added yet',
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
                            ..._lineItems.asMap().entries.map((entry) {
                              final index = entry.key;
                              final item = entry.value;
                              return _LineItemCard(
                                key: ValueKey(index),
                                item: item,
                                index: index,
                                onUpdate: (updatedItem) =>
                                    _updateLineItem(index, updatedItem),
                                onRemove: () => _removeLineItem(index),
                                enabled: !_isApproved,
                              );
                            }).toList(),

                          const SizedBox(height: 100), // Space for bottom bar
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom total bar
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Amount',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              NumberFormat.currency(symbol: '₹')
                                  .format(_calculateTotal()),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (!_isApproved)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed:
                                      _isLoading ? null : () => _saveIssue(),
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
                                      : () => _saveIssue(approve: true),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    backgroundColor: Colors.green,
                                  ),
                                  child: const Text('Approve & Issue'),
                                ),
                              ),
                            ],
                          )
                        else
                          Container(
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
                                  'Issue Already Approved',
                                  style: TextStyle(
                                    color: Colors.green[800],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// Line item model for state management
class IssueLineItemModel {
  final String? productId;
  final double quantity;
  final double rate;
  final String? batchNo;

  IssueLineItemModel({
    required this.productId,
    required this.quantity,
    required this.rate,
    this.batchNo,
  });

  IssueLineItemModel copyWith({
    String? productId,
    double? quantity,
    double? rate,
    String? batchNo,
  }) {
    return IssueLineItemModel(
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      batchNo: batchNo ?? this.batchNo,
    );
  }
}

// Line item card widget
class _LineItemCard extends ConsumerStatefulWidget {
  final IssueLineItemModel item;
  final int index;
  final Function(IssueLineItemModel) onUpdate;
  final VoidCallback onRemove;
  final bool enabled;

  const _LineItemCard({
    super.key,
    required this.item,
    required this.index,
    required this.onUpdate,
    required this.onRemove,
    required this.enabled,
  });

  @override
  ConsumerState<_LineItemCard> createState() => _LineItemCardState();
}

class _LineItemCardState extends ConsumerState<_LineItemCard> {
  final _quantityController = TextEditingController();
  final _rateController = TextEditingController();
  final _batchNoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _quantityController.text =
        widget.item.quantity > 0 ? widget.item.quantity.toString() : '';
    _rateController.text =
        widget.item.rate > 0 ? widget.item.rate.toString() : '';
    _batchNoController.text = widget.item.batchNo ?? '';

    _quantityController.addListener(_updateItem);
    _rateController.addListener(_updateItem);
    _batchNoController.addListener(_updateItem);
  }

  void _updateItem() {
    widget.onUpdate(widget.item.copyWith(
      quantity: double.tryParse(_quantityController.text) ?? 0.0,
      rate: double.tryParse(_rateController.text) ?? 0.0,
      batchNo:
          _batchNoController.text.isEmpty ? null : _batchNoController.text,
    ));
  }

  Future<void> _selectProduct() async {
    final productsAsync = ref.read(productsProvider);
    final products = productsAsync.value ?? [];

    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No products available. Please add products first.')),
      );
      return;
    }

    final selectedProduct = await showDialog<Product>(
      context: context,
      builder: (context) => _ProductSelectionDialog(products: products),
    );

    if (selectedProduct != null) {
      // Check stock availability
      if (selectedProduct.currentStock <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${selectedProduct.name} is out of stock (Available: ${selectedProduct.currentStock})'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // Auto-fill rate from product
      _rateController.text = selectedProduct.purchaseRate.toString();

      // Update the item with selected product
      widget.onUpdate(widget.item.copyWith(
        productId: selectedProduct.uuid,
        rate: selectedProduct.purchaseRate,
      ));
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _rateController.dispose();
    _batchNoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final selectedProduct = productsAsync.value?.firstWhere(
      (p) => p.uuid == widget.item.productId,
      orElse: () => Product(
        uuid: '',
        name: 'Select Product',
        category: '',
        unit: '',
        purchaseRate: 0.0,
        sellingRate: 0.0,
        gstPercent: 0.0,
        currentStock: 0.0,
        minStockLevel: 0.0,
        maxStockLevel: 0.0,
        isActive: true,
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
        isSynced: false,
      ),
    );

    final lineTotal = widget.item.quantity * widget.item.rate;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Item ${widget.index + 1}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.enabled)
                  IconButton(
                    onPressed: widget.onRemove,
                    icon: const Icon(Icons.delete, color: Colors.red),
                  ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Product selection
            InkWell(
              onTap: widget.enabled ? _selectProduct : null,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Product *',
                  border: const OutlineInputBorder(),
                  suffixIcon: widget.enabled
                      ? const Icon(Icons.arrow_drop_down)
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        selectedProduct?.name ?? 'Select Product',
                        style: TextStyle(
                          color: widget.item.productId == null
                              ? Colors.grey
                              : Colors.black,
                        ),
                      ),
                    ),
                    if (selectedProduct != null &&
                        widget.item.productId != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: selectedProduct.currentStock > 0
                              ? Colors.green[100]
                              : Colors.red[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Stock: ${selectedProduct.currentStock}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: selectedProduct.currentStock > 0
                                ? Colors.green[800]
                                : Colors.red[800],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Quantity and Rate
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    enabled: widget.enabled,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _rateController,
                    decoration: const InputDecoration(
                      labelText: 'Rate',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    enabled: widget.enabled,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Batch No
            TextFormField(
              controller: _batchNoController,
              decoration: const InputDecoration(
                labelText: 'Batch No',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code),
              ),
              enabled: widget.enabled,
            ),

            const Divider(height: 32),

            // Line total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Line Total',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  NumberFormat.currency(symbol: '₹').format(lineTotal),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Product selection dialog
class _ProductSelectionDialog extends StatefulWidget {
  final List<Product> products;

  const _ProductSelectionDialog({required this.products});

  @override
  State<_ProductSelectionDialog> createState() =>
      _ProductSelectionDialogState();
}

class _ProductSelectionDialogState extends State<_ProductSelectionDialog> {
  final _searchController = TextEditingController();
  List<Product> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _filteredProducts = widget.products;
  }

  void _filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = widget.products;
      } else {
        _filteredProducts = widget.products
            .where((p) =>
                p.name.toLowerCase().contains(query.toLowerCase()) ||
                p.category.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Select Product',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: _filterProducts,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = _filteredProducts[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: product.currentStock > 0
                          ? Colors.green[100]
                          : Colors.red[100],
                      child: Icon(
                        Icons.inventory_2,
                        color: product.currentStock > 0
                            ? Colors.green[800]
                            : Colors.red[800],
                      ),
                    ),
                    title: Text(product.name),
                    subtitle: Text(
                      '${product.category} • Stock: ${product.currentStock} ${product.unit}',
                    ),
                    trailing: Text(
                      '₹${product.purchaseRate}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(product),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
