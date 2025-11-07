import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:go_router/go_router.dart';
import 'package:hotel_inventory_management/config/constants.dart';
import 'package:hotel_inventory_management/config/theme.dart';
import 'package:hotel_inventory_management/db/app_database.dart';
import 'package:hotel_inventory_management/providers/purchase_provider.dart';
import 'package:hotel_inventory_management/providers/product_provider.dart';
import 'package:hotel_inventory_management/providers/supplier_provider.dart';
import 'package:hotel_inventory_management/providers/auth_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class PurchaseFormScreen extends ConsumerStatefulWidget {
  final String? purchaseId;

  const PurchaseFormScreen({super.key, this.purchaseId});

  @override
  ConsumerState<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends ConsumerState<PurchaseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceController = TextEditingController();
  final _remarksController = TextEditingController();

  String? _selectedSupplierId;
  DateTime _purchaseDate = DateTime.now();
  String _paymentMode = AppConstants.paymentCash;
  bool _isLoading = false;
  Purchase? _existingPurchase;

  // Line items
  final List<PurchaseLineItemModel> _lineItems = [];

  @override
  void initState() {
    super.initState();
    if (widget.purchaseId != null) {
      _loadPurchase();
    }
  }

  Future<void> _loadPurchase() async {
    setState(() => _isLoading = true);
    final purchaseNotifier = ref.read(purchaseNotifierProvider.notifier);
    final purchaseWithItems = await purchaseNotifier.getPurchaseWithItems(widget.purchaseId!);

    if (purchaseWithItems != null && mounted) {
      setState(() {
        _existingPurchase = purchaseWithItems.purchase;
        _selectedSupplierId = purchaseWithItems.purchase.supplierId;
        _invoiceController.text = purchaseWithItems.purchase.invoiceNo;
        _purchaseDate = purchaseWithItems.purchase.purchaseDate;
        _paymentMode = purchaseWithItems.purchase.paymentMode;
        _remarksController.text = purchaseWithItems.purchase.remarks ?? '';

        // Load line items
        _lineItems.clear();
        for (final item in purchaseWithItems.lineItems) {
          _lineItems.add(PurchaseLineItemModel(
            productId: item.productId,
            quantity: item.quantity,
            rate: item.rate,
            gstPercent: item.gstPercent,
            batchNo: item.batchNo,
            expiryDate: item.expiryDate,
          ));
        }

        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _invoiceController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _addLineItem() {
    setState(() {
      _lineItems.add(PurchaseLineItemModel());
    });
  }

  void _removeLineItem(int index) {
    setState(() {
      _lineItems.removeAt(index);
    });
  }

  double _calculateTotal() {
    return _lineItems.fold(0.0, (sum, item) {
      final amount = item.quantity * item.rate;
      final gstAmount = amount * (item.gstPercent / 100);
      return sum + amount + gstAmount;
    });
  }

  Future<void> _savePurchase() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a supplier'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_lineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Validate line items
    for (int i = 0; i < _lineItems.length; i++) {
      final item = _lineItems[i];
      if (item.productId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select product for item ${i + 1}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
      if (item.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid quantity for item ${i + 1}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(currentUserProvider);
      final purchaseNotifier = ref.read(purchaseNotifierProvider.notifier);
      final purchaseUuid = _existingPurchase?.uuid ?? const Uuid().v4();

      // Create purchase
      final purchase = PurchasesCompanion(
        uuid: drift.Value(purchaseUuid),
        supplierId: drift.Value(_selectedSupplierId!),
        invoiceNo: drift.Value(_invoiceController.text.trim()),
        purchaseDate: drift.Value(_purchaseDate),
        totalAmount: drift.Value(_calculateTotal()),
        paymentMode: drift.Value(_paymentMode),
        receivedBy: drift.Value(currentUser?.username ?? 'Unknown'),
        status: const drift.Value('Pending'),
        remarks: drift.Value(_remarksController.text.trim().isEmpty
            ? null
            : _remarksController.text.trim()),
        lastModified: drift.Value(DateTime.now()),
        isSynced: const drift.Value(false),
        sourceDevice: const drift.Value('local'),
      );

      // Create line items
      final lineItems = _lineItems.map((item) {
        final amount = item.quantity * item.rate;
        final gstAmount = amount * (item.gstPercent / 100);
        final totalAmount = amount + gstAmount;

        return PurchaseLineItemsCompanion(
          purchaseId: drift.Value(purchaseUuid),
          productId: drift.Value(item.productId!),
          quantity: drift.Value(item.quantity),
          rate: drift.Value(item.rate),
          gstPercent: drift.Value(item.gstPercent),
          batchNo: drift.Value(item.batchNo),
          expiryDate: drift.Value(item.expiryDate),
          amount: drift.Value(amount),
          gstAmount: drift.Value(gstAmount),
          totalAmount: drift.Value(totalAmount),
          lastModified: drift.Value(DateTime.now()),
        );
      }).toList();

      await purchaseNotifier.createPurchaseWithItems(
        purchase: purchase,
        lineItems: lineItems,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase created successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.go('/purchases');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _approvePurchase() async {
    if (_existingPurchase == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Purchase'),
        content: const Text(
          'This will update product stock and supplier balance. This action cannot be undone. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final purchaseNotifier = ref.read(purchaseNotifierProvider.notifier);
      await purchaseNotifier.approvePurchase(_existingPurchase!.uuid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase approved successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.go('/purchases');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
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
    final isEdit = _existingPurchase != null;
    final isPending = _existingPurchase?.status == 'Pending';
    final suppliersAsync = ref.watch(suppliersProvider);

    if (_isLoading && _existingPurchase == null && widget.purchaseId != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'View Purchase' : 'New Purchase Entry'),
        actions: [
          if (isEdit && isPending)
            IconButton(
              icon: const Icon(Icons.check_circle),
              onPressed: _approvePurchase,
              tooltip: 'Approve Purchase',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Purchase Header
                    Text('Purchase Information', style: AppTheme.heading3),
                    const SizedBox(height: 16),

                    // Supplier Dropdown
                    suppliersAsync.when(
                      data: (suppliers) => DropdownButtonFormField<String>(
                        value: _selectedSupplierId,
                        decoration: const InputDecoration(
                          labelText: 'Supplier *',
                          prefixIcon: Icon(Icons.business),
                        ),
                        items: suppliers
                            .map((supplier) => DropdownMenuItem(
                                  value: supplier.uuid,
                                  child: Text(supplier.name),
                                ))
                            .toList(),
                        onChanged: isEdit
                            ? null
                            : (value) {
                                setState(() => _selectedSupplierId = value);
                              },
                        validator: (value) =>
                            value == null ? 'Please select a supplier' : null,
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Error loading suppliers'),
                    ),
                    const SizedBox(height: 16),

                    // Invoice Number
                    TextFormField(
                      controller: _invoiceController,
                      decoration: const InputDecoration(
                        labelText: 'Invoice Number *',
                        prefixIcon: Icon(Icons.receipt),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter invoice number';
                        }
                        return null;
                      },
                      enabled: !isEdit,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        // Purchase Date
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.calendar_today),
                            title: const Text('Purchase Date'),
                            subtitle: Text(
                              DateFormat('dd MMM yyyy').format(_purchaseDate),
                            ),
                            onTap: isEdit ? null : _selectDate,
                          ),
                        ),

                        // Payment Mode
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _paymentMode,
                            decoration: const InputDecoration(
                              labelText: 'Payment Mode',
                              prefixIcon: Icon(Icons.payment),
                            ),
                            items: [
                              AppConstants.paymentCash,
                              AppConstants.paymentCredit,
                              AppConstants.paymentUPI,
                              AppConstants.paymentCard,
                              AppConstants.paymentBankTransfer,
                            ]
                                .map((mode) => DropdownMenuItem(
                                      value: mode,
                                      child: Text(mode),
                                    ))
                                .toList(),
                            onChanged: isEdit
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setState(() => _paymentMode = value);
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Remarks
                    TextFormField(
                      controller: _remarksController,
                      decoration: const InputDecoration(
                        labelText: 'Remarks',
                        prefixIcon: Icon(Icons.note),
                      ),
                      maxLines: 2,
                      enabled: !isEdit,
                    ),
                    const SizedBox(height: 24),

                    // Line Items Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Items', style: AppTheme.heading3),
                        if (!isEdit)
                          ElevatedButton.icon(
                            onPressed: _addLineItem,
                            icon: const Icon(Icons.add, size: 20),
                            label: const Text('Add Item'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Line Items List
                    if (_lineItems.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.inventory_2,
                                  size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                'No items added',
                                style: AppTheme.bodyMedium
                                    .copyWith(color: Colors.grey),
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
                          onRemove: isEdit ? null : () => _removeLineItem(index),
                          onChanged: isEdit ? null : (updated) {
                            setState(() {
                              _lineItems[index] = updated;
                            });
                          },
                        );
                      }),
                  ],
                ),
              ),
            ),

            // Bottom Total Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Amount:', style: AppTheme.heading3),
                      Text(
                        NumberFormat.currency(symbol: '₹')
                            .format(_calculateTotal()),
                        style: AppTheme.heading2.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  if (!isEdit) ...[
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _savePurchase,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Save Purchase Entry',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ] else if (isPending) ...[
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _approvePurchase,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: AppTheme.successColor,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Approve Purchase',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() => _purchaseDate = date);
    }
  }
}

// Line Item Card Widget
class _LineItemCard extends ConsumerStatefulWidget {
  final PurchaseLineItemModel item;
  final int index;
  final VoidCallback? onRemove;
  final Function(PurchaseLineItemModel)? onChanged;

  const _LineItemCard({
    super.key,
    required this.item,
    required this.index,
    this.onRemove,
    this.onChanged,
  });

  @override
  ConsumerState<_LineItemCard> createState() => _LineItemCardState();
}

class _LineItemCardState extends ConsumerState<_LineItemCard> {
  final _qtyController = TextEditingController();
  final _rateController = TextEditingController();
  final _gstController = TextEditingController();
  final _batchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _qtyController.text = widget.item.quantity.toString();
    _rateController.text = widget.item.rate.toString();
    _gstController.text = widget.item.gstPercent.toString();
    _batchController.text = widget.item.batchNo ?? '';
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _rateController.dispose();
    _gstController.dispose();
    _batchController.dispose();
    super.dispose();
  }

  void _updateItem() {
    if (widget.onChanged == null) return;

    final updatedItem = widget.item.copyWith(
      quantity: double.tryParse(_qtyController.text) ?? 0,
      rate: double.tryParse(_rateController.text) ?? 0,
      gstPercent: double.tryParse(_gstController.text) ?? 0,
      batchNo: _batchController.text.isEmpty ? null : _batchController.text,
    );

    widget.onChanged!(updatedItem);
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final isReadOnly = widget.onChanged == null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Item ${widget.index + 1}',
                  style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (widget.onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete, color: AppTheme.errorColor),
                    onPressed: widget.onRemove,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Product Dropdown
            productsAsync.when(
              data: (products) => DropdownButtonFormField<String>(
                value: widget.item.productId,
                decoration: const InputDecoration(
                  labelText: 'Product *',
                  prefixIcon: Icon(Icons.inventory_2),
                ),
                items: products
                    .map((product) => DropdownMenuItem(
                          value: product.uuid,
                          child: Text(product.name),
                        ))
                    .toList(),
                onChanged: isReadOnly
                    ? null
                    : (value) {
                        final updatedItem = widget.item.copyWith(productId: value);
                        widget.onChanged!(updatedItem);

                        // Auto-fill GST from product
                        final selectedProduct = products.firstWhere(
                          (p) => p.uuid == value,
                          orElse: () => products.first,
                        );
                        _gstController.text = selectedProduct.gstPercent.toString();
                        _rateController.text = selectedProduct.purchaseRate.toString();
                        _updateItem();
                      },
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Error loading products'),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _qtyController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      prefixIcon: Icon(Icons.numbers),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: isReadOnly ? null : (_) => _updateItem(),
                    enabled: !isReadOnly,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _rateController,
                    decoration: const InputDecoration(
                      labelText: 'Rate',
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: isReadOnly ? null : (_) => _updateItem(),
                    enabled: !isReadOnly,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _gstController,
                    decoration: const InputDecoration(
                      labelText: 'GST %',
                      prefixIcon: Icon(Icons.percent),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: isReadOnly ? null : (_) => _updateItem(),
                    enabled: !isReadOnly,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Batch Number (Optional)
            TextFormField(
              controller: _batchController,
              decoration: const InputDecoration(
                labelText: 'Batch Number (Optional)',
                prefixIcon: Icon(Icons.qr_code),
              ),
              onChanged: isReadOnly ? null : (_) => _updateItem(),
              enabled: !isReadOnly,
            ),
            const SizedBox(height: 12),

            // Total for this item
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Item Total:'),
                  Text(
                    NumberFormat.currency(symbol: '₹').format(
                      widget.item.quantity * widget.item.rate * (1 + widget.item.gstPercent / 100),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Purchase Line Item Model
class PurchaseLineItemModel {
  String? productId;
  double quantity;
  double rate;
  double gstPercent;
  String? batchNo;
  DateTime? expiryDate;

  PurchaseLineItemModel({
    this.productId,
    this.quantity = 0,
    this.rate = 0,
    this.gstPercent = 0,
    this.batchNo,
    this.expiryDate,
  });

  PurchaseLineItemModel copyWith({
    String? productId,
    double? quantity,
    double? rate,
    double? gstPercent,
    String? batchNo,
    DateTime? expiryDate,
  }) {
    return PurchaseLineItemModel(
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      gstPercent: gstPercent ?? this.gstPercent,
      batchNo: batchNo ?? this.batchNo,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }
}
