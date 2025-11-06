import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../db/app_database.dart';
import '../../providers/wastage_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../config/constants.dart';

class WastageFormScreen extends ConsumerStatefulWidget {
  final String? wastageId;
  final String? initialType; // 'Wastage' or 'Return' from query params

  const WastageFormScreen({
    super.key,
    this.wastageId,
    this.initialType,
  });

  @override
  ConsumerState<WastageFormScreen> createState() => _WastageFormScreenState();
}

class _WastageFormScreenState extends ConsumerState<WastageFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _wastageNoController = TextEditingController();
  final _remarksController = TextEditingController();

  DateTime _wastageDate = DateTime.now();
  String _type = 'Wastage'; // 'Wastage' or 'Return'
  String? _selectedSupplierId;
  final List<WastageLineItemModel> _lineItems = [];
  bool _isLoading = false;
  bool _isApproved = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? 'Wastage';
    _initializeForm();
  }

  Future<void> _initializeForm() async {
    if (widget.wastageId != null) {
      // Load existing wastage
      await _loadWastage();
    } else {
      // Generate next wastage number
      final nextWastageNo = await ref
          .read(wastageNotifierProvider.notifier)
          .getNextWastageNo(_type);
      _wastageNoController.text = nextWastageNo;

      // Add one empty line item
      setState(() {
        _lineItems.add(WastageLineItemModel(
          productId: null,
          quantity: 0.0,
          rate: 0.0,
          reason: 'Spoilage',
          batchNo: null,
          expiryDate: null,
        ));
      });
    }
  }

  Future<void> _loadWastage() async {
    setState(() => _isLoading = true);
    try {
      final wastageDao = ref.read(wastageDaoProvider);
      final wastage = await wastageDao.getWastageById(widget.wastageId!);
      final lineItems = await wastageDao.getWastageLineItems(widget.wastageId!);

      if (wastage != null) {
        setState(() {
          _wastageNoController.text = wastage.wastageNo;
          _wastageDate = wastage.wastageDate;
          _type = wastage.type;
          _selectedSupplierId = wastage.supplierId;
          _remarksController.text = wastage.remarks ?? '';
          _isApproved = wastage.status == 'Approved';

          _lineItems.clear();
          _lineItems.addAll(lineItems.map((item) => WastageLineItemModel(
                productId: item.productId,
                quantity: item.quantity,
                rate: item.rate,
                reason: item.reason,
                batchNo: item.batchNo,
                expiryDate: item.expiryDate,
              )));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading wastage: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addLineItem() {
    setState(() {
      _lineItems.add(WastageLineItemModel(
        productId: null,
        quantity: 0.0,
        rate: 0.0,
        reason: 'Spoilage',
        batchNo: null,
        expiryDate: null,
      ));
    });
  }

  void _removeLineItem(int index) {
    setState(() {
      _lineItems.removeAt(index);
    });
  }

  void _updateLineItem(int index, WastageLineItemModel item) {
    setState(() {
      _lineItems[index] = item;
    });
  }

  double _calculateTotal() {
    return _lineItems.fold(0.0, (sum, item) {
      return sum + (item.quantity * item.rate);
    });
  }

  Future<void> _saveWastage({bool approve = false}) async {
    if (!_formKey.currentState!.validate()) return;

    // Validate: If type is Return, supplier must be selected
    if (_type == 'Return' &&
        (_selectedSupplierId == null || _selectedSupplierId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a supplier for return type')),
      );
      return;
    }

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
          .map((item) => WastageLineItemsCompanion.insert(
                wastageId: '', // Will be set by DAO
                productId: item.productId!,
                quantity: item.quantity,
                rate: item.rate,
                reason: item.reason,
                batchNo: drift.Value(item.batchNo),
                expiryDate: drift.Value(item.expiryDate),
                createdAt: DateTime.now(),
                lastModified: DateTime.now(),
              ))
          .toList();

      final notifier = ref.read(wastageNotifierProvider.notifier);
      String? resultId;

      if (widget.wastageId != null) {
        // Update existing wastage
        final success = await notifier.updateWastage(
          wastageId: widget.wastageId!,
          wastageNo: _wastageNoController.text,
          wastageDate: _wastageDate,
          type: _type,
          supplierId: _selectedSupplierId,
          totalAmount: _calculateTotal(),
          lineItems: lineItemsCompanions,
          remarks: _remarksController.text.isEmpty
              ? null
              : _remarksController.text,
        );

        if (success) {
          resultId = widget.wastageId;
        }
      } else {
        // Create new wastage
        resultId = await notifier.createWastage(
          wastageNo: _wastageNoController.text,
          wastageDate: _wastageDate,
          type: _type,
          supplierId: _selectedSupplierId,
          totalAmount: _calculateTotal(),
          lineItems: lineItemsCompanions,
          remarks: _remarksController.text.isEmpty
              ? null
              : _remarksController.text,
        );
      }

      if (resultId != null) {
        // If approve flag is set, approve the wastage
        if (approve && !_isApproved) {
          final approved = await notifier.approveWastage(resultId);
          if (!approved) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('Wastage saved but approval failed')),
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
                  ? '${_type} approved successfully'
                  : '${_type} saved successfully'),
            ),
          );
          context.pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save ${_type.toLowerCase()}')),
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
    _wastageNoController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.wastageId != null;
    final suppliersAsync = ref.watch(suppliersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit $_type' : 'New $_type'),
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
                                        _type == 'Wastage'
                                            ? Icons.delete_outline
                                            : Icons.keyboard_return,
                                        color: _type == 'Wastage'
                                            ? Colors.orange
                                            : Colors.blue,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${_type} Details',
                                        style: const TextStyle(
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
                                          controller: _wastageNoController,
                                          decoration: InputDecoration(
                                            labelText: '${_type} No *',
                                            prefixIcon:
                                                const Icon(Icons.numbers),
                                            border: const OutlineInputBorder(),
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
                                                    initialDate: _wastageDate,
                                                    firstDate: DateTime(2000),
                                                    lastDate: DateTime(2100),
                                                  );
                                                  if (date != null) {
                                                    setState(() {
                                                      _wastageDate = date;
                                                    });
                                                  }
                                                },
                                          child: InputDecorator(
                                            decoration: const InputDecoration(
                                              labelText: 'Date *',
                                              prefixIcon:
                                                  Icon(Icons.calendar_today),
                                              border: OutlineInputBorder(),
                                            ),
                                            child: Text(
                                              DateFormat('dd MMM yyyy')
                                                  .format(_wastageDate),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Supplier selection (only for Return type)
                                  if (_type == 'Return')
                                    suppliersAsync.when(
                                      data: (suppliers) {
                                        return DropdownButtonFormField<String>(
                                          value: _selectedSupplierId,
                                          decoration: const InputDecoration(
                                            labelText: 'Supplier *',
                                            prefixIcon:
                                                Icon(Icons.business),
                                            border: OutlineInputBorder(),
                                          ),
                                          items: suppliers
                                              .map((supplier) =>
                                                  DropdownMenuItem(
                                                    value: supplier.uuid,
                                                    child:
                                                        Text(supplier.name),
                                                  ))
                                              .toList(),
                                          onChanged: _isApproved
                                              ? null
                                              : (value) {
                                                  setState(() {
                                                    _selectedSupplierId = value;
                                                  });
                                                },
                                          validator: (value) {
                                            if (_type == 'Return' &&
                                                (value?.isEmpty ?? true)) {
                                              return 'Please select a supplier';
                                            }
                                            return null;
                                          },
                                        );
                                      },
                                      loading: () =>
                                          const CircularProgressIndicator(),
                                      error: (error, stack) =>
                                          Text('Error loading suppliers: $error'),
                                    ),
                                  if (_type == 'Return')
                                    const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _remarksController,
                                    decoration: const InputDecoration(
                                      labelText: 'Remarks',
                                      prefixIcon: Icon(Icons.note),
                                      border: OutlineInputBorder(),
                                      hintText: 'Additional notes...',
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
                                type: _type,
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
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _type == 'Wastage'
                                    ? Colors.red
                                    : Colors.blue,
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
                                      _isLoading ? null : () => _saveWastage(),
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
                                      : () => _saveWastage(approve: true),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    backgroundColor: Colors.green,
                                  ),
                                  child: const Text('Approve & Process'),
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
                                  '$_type Already Approved',
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
class WastageLineItemModel {
  final String? productId;
  final double quantity;
  final double rate;
  final String reason;
  final String? batchNo;
  final DateTime? expiryDate;

  WastageLineItemModel({
    required this.productId,
    required this.quantity,
    required this.rate,
    required this.reason,
    this.batchNo,
    this.expiryDate,
  });

  WastageLineItemModel copyWith({
    String? productId,
    double? quantity,
    double? rate,
    String? reason,
    String? batchNo,
    DateTime? expiryDate,
  }) {
    return WastageLineItemModel(
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      reason: reason ?? this.reason,
      batchNo: batchNo ?? this.batchNo,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }
}

// Line item card widget
class _LineItemCard extends ConsumerStatefulWidget {
  final WastageLineItemModel item;
  final int index;
  final String type;
  final Function(WastageLineItemModel) onUpdate;
  final VoidCallback onRemove;
  final bool enabled;

  const _LineItemCard({
    super.key,
    required this.item,
    required this.index,
    required this.type,
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

  Future<void> _selectExpiryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: widget.item.expiryDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (date != null) {
      widget.onUpdate(widget.item.copyWith(expiryDate: date));
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

            // Reason dropdown
            DropdownButtonFormField<String>(
              value: widget.item.reason,
              decoration: const InputDecoration(
                labelText: 'Reason *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.info_outline),
              ),
              items: AppConstants.wastageReasons
                  .map((reason) => DropdownMenuItem(
                        value: reason,
                        child: Text(reason),
                      ))
                  .toList(),
              onChanged: widget.enabled
                  ? (value) {
                      if (value != null) {
                        widget.onUpdate(widget.item.copyWith(reason: value));
                      }
                    }
                  : null,
            ),

            const SizedBox(height: 16),

            // Batch No and Expiry Date
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _batchNoController,
                    decoration: const InputDecoration(
                      labelText: 'Batch No',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.qr_code),
                    ),
                    enabled: widget.enabled,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: widget.enabled ? _selectExpiryDate : null,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Expiry Date',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        widget.item.expiryDate != null
                            ? DateFormat('dd MMM yyyy')
                                .format(widget.item.expiryDate!)
                            : 'Select date',
                        style: TextStyle(
                          color: widget.item.expiryDate == null
                              ? Colors.grey
                              : Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: widget.type == 'Wastage' ? Colors.red : Colors.blue,
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
