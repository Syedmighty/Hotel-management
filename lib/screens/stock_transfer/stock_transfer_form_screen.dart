import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../db/app_database.dart';
import '../../providers/stock_transfer_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/constants.dart';

class StockTransferFormScreen extends ConsumerStatefulWidget {
  final String? transferId;

  const StockTransferFormScreen({
    super.key,
    this.transferId,
  });

  @override
  ConsumerState<StockTransferFormScreen> createState() =>
      _StockTransferFormScreenState();
}

class _StockTransferFormScreenState
    extends ConsumerState<StockTransferFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _transferNoController = TextEditingController();
  final _remarksController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String? _selectedFromLocation;
  String? _selectedToLocation;
  bool _isLoading = false;
  bool _isEditMode = false;

  final List<TransferLineItemModel> _lineItems = [];

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  Future<void> _initializeForm() async {
    if (widget.transferId != null) {
      // Edit mode - load existing transfer
      _isEditMode = true;
      await _loadTransfer();
    } else {
      // New mode - generate transfer number
      final transferNo =
          await ref.read(stockTransferNotifierProvider.notifier).getNextTransferNo();
      _transferNoController.text = transferNo;
    }
  }

  Future<void> _loadTransfer() async {
    setState(() => _isLoading = true);

    try {
      final stockTransferDao = ref.read(stockTransferDaoProvider);
      final transfer = await stockTransferDao.getStockTransferById(widget.transferId!);

      if (transfer == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stock transfer not found')),
          );
          context.pop();
        }
        return;
      }

      // Check if approved (cannot edit approved transfers)
      if (transfer.status == 'Approved') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot edit approved stock transfer'),
              backgroundColor: Colors.orange,
            ),
          );
          context.pop();
        }
        return;
      }

      // Load line items
      final lineItems =
          await stockTransferDao.getStockTransferLineItems(widget.transferId!);

      // Populate form
      _transferNoController.text = transfer.transferNo;
      _selectedDate = transfer.transferDate;
      _selectedFromLocation = transfer.fromLocation;
      _selectedToLocation = transfer.toLocation;
      _remarksController.text = transfer.remarks ?? '';

      // Populate line items
      for (final item in lineItems) {
        final productDao = ref.read(productDaoProvider);
        final product = await productDao.getProductById(item.productId);
        if (product != null) {
          _lineItems.add(TransferLineItemModel(
            productId: item.productId,
            productName: product.name,
            unit: product.unit,
            quantity: item.quantity,
            rate: item.rate,
            amount: item.amount,
            batchNo: item.batchNo,
            currentStock: product.currentStock,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transfer: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _transferNoController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _addLineItem() {
    setState(() {
      _lineItems.add(TransferLineItemModel(
        productId: '',
        productName: '',
        unit: '',
        quantity: 0,
        rate: 0,
        amount: 0,
        currentStock: 0,
      ));
    });
  }

  void _removeLineItem(int index) {
    setState(() {
      _lineItems.removeAt(index);
    });
  }

  void _updateLineItem(int index, TransferLineItemModel item) {
    setState(() {
      _lineItems[index] = item;
    });
  }

  double _calculateTotal() {
    return _lineItems.fold(0.0, (sum, item) => sum + item.amount);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  bool _validateForm() {
    if (!_formKey.currentState!.validate()) {
      return false;
    }

    if (_selectedFromLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select source location')),
      );
      return false;
    }

    if (_selectedToLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select destination location')),
      );
      return false;
    }

    if (_selectedFromLocation == _selectedToLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Source and destination locations must be different'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (_lineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return false;
    }

    // Validate line items
    for (int i = 0; i < _lineItems.length; i++) {
      final item = _lineItems[i];
      if (item.productId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select product for item ${i + 1}')),
        );
        return false;
      }
      if (item.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid quantity for item ${i + 1}')),
        );
        return false;
      }
      if (item.quantity > item.currentStock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Insufficient stock for ${item.productName}. Available: ${item.currentStock}',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    }

    return true;
  }

  Future<void> _saveTransfer({bool approve = false}) async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Prepare line items
      final lineItemsData = _lineItems.map((item) {
        return StockTransferLineItemsCompanion.insert(
          transferId: const Value.absent(), // Will be set by DAO
          productId: item.productId,
          quantity: item.quantity,
          rate: item.rate,
          amount: item.amount,
          batchNo: Value(item.batchNo),
          createdAt: DateTime.now(),
          lastModified: DateTime.now(),
        );
      }).toList();

      final notifier = ref.read(stockTransferNotifierProvider.notifier);

      if (_isEditMode && widget.transferId != null) {
        // Update existing transfer
        final success = await notifier.updateStockTransfer(
          transferId: widget.transferId!,
          transferNo: _transferNoController.text.trim(),
          transferDate: _selectedDate,
          fromLocation: _selectedFromLocation!,
          toLocation: _selectedToLocation!,
          requestedBy: currentUser.username,
          totalAmount: _calculateTotal(),
          lineItems: lineItemsData,
          remarks: _remarksController.text.trim().isEmpty
              ? null
              : _remarksController.text.trim(),
        );

        if (success && approve) {
          await notifier.approveStockTransfer(widget.transferId!);
        }

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(approve
                    ? 'Stock transfer approved and processed successfully'
                    : 'Stock transfer updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
            context.pop();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to update stock transfer'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        // Create new transfer
        final transferId = await notifier.createStockTransfer(
          transferNo: _transferNoController.text.trim(),
          transferDate: _selectedDate,
          fromLocation: _selectedFromLocation!,
          toLocation: _selectedToLocation!,
          requestedBy: currentUser.username,
          totalAmount: _calculateTotal(),
          lineItems: lineItemsData,
          remarks: _remarksController.text.trim().isEmpty
              ? null
              : _remarksController.text.trim(),
        );

        if (transferId != null && approve) {
          await notifier.approveStockTransfer(transferId);
        }

        if (mounted) {
          if (transferId != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(approve
                    ? 'Stock transfer created and approved successfully'
                    : 'Stock transfer saved as pending'),
                backgroundColor: Colors.green,
              ),
            );
            context.pop();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to create stock transfer'),
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
    final dateFormat = DateFormat('dd MMM yyyy');

    if (_isLoading && _lineItems.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Stock Transfer' : 'New Stock Transfer'),
        actions: [
          if (_isEditMode && widget.transferId != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Stock Transfer'),
                    content: const Text(
                      'Are you sure you want to delete this stock transfer?',
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
                  final notifier =
                      ref.read(stockTransferNotifierProvider.notifier);
                  final success =
                      await notifier.deleteStockTransfer(widget.transferId!);
                  if (mounted) {
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Stock transfer deleted'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      context.pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to delete stock transfer'),
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
              // Header Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transfer Details',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),

                      // Transfer No and Date
                      if (isWeb)
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _transferNoController,
                                decoration: const InputDecoration(
                                  labelText: 'Transfer No',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectDate(context),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Transfer Date',
                                    border: OutlineInputBorder(),
                                    suffixIcon: Icon(Icons.calendar_today),
                                  ),
                                  child: Text(dateFormat.format(_selectedDate)),
                                ),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        TextFormField(
                          controller: _transferNoController,
                          decoration: const InputDecoration(
                            labelText: 'Transfer No',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () => _selectDate(context),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Transfer Date',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(dateFormat.format(_selectedDate)),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // From and To Location
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedFromLocation,
                              decoration: InputDecoration(
                                labelText: 'From Location',
                                border: const OutlineInputBorder(),
                                prefixIcon: Icon(
                                  Icons.call_made,
                                  color: Colors.red[700],
                                ),
                              ),
                              items: departments.map((dept) {
                                return DropdownMenuItem(
                                  value: dept,
                                  child: Text(dept),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedFromLocation = value;
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(
                              Icons.arrow_forward,
                              color: Colors.grey[600],
                            ),
                          ),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedToLocation,
                              decoration: InputDecoration(
                                labelText: 'To Location',
                                border: const OutlineInputBorder(),
                                prefixIcon: Icon(
                                  Icons.call_received,
                                  color: Colors.green[700],
                                ),
                              ),
                              items: departments.map((dept) {
                                return DropdownMenuItem(
                                  value: dept,
                                  child: Text(dept),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedToLocation = value;
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Required';
                                }
                                return null;
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
                          labelText: 'Remarks (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Line Items Section
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
                            'Items',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          ElevatedButton.icon(
                            onPressed: _addLineItem,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Item'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (_lineItems.isEmpty)
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
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _lineItems.length,
                          itemBuilder: (context, index) {
                            return _TransferLineItemCard(
                              key: ValueKey(_lineItems[index].productId +
                                  index.toString()),
                              item: _lineItems[index],
                              index: index,
                              onUpdate: (item) => _updateLineItem(index, item),
                              onRemove: () => _removeLineItem(index),
                              isWeb: isWeb,
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Total Section
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Transfer Value',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        NumberFormat.currency(symbol: '₹')
                            .format(_calculateTotal()),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.blue[900],
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              if (isWeb)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => _saveTransfer(approve: false),
                        icon: const Icon(Icons.save),
                        label: const Text('Save as Pending'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => _saveTransfer(approve: true),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Approve & Transfer'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed:
                          _isLoading ? null : () => _saveTransfer(approve: false),
                      icon: const Icon(Icons.save),
                      label: const Text('Save as Pending'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed:
                          _isLoading ? null : () => _saveTransfer(approve: true),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Approve & Transfer'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
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

class _TransferLineItemCard extends ConsumerStatefulWidget {
  final TransferLineItemModel item;
  final int index;
  final Function(TransferLineItemModel) onUpdate;
  final VoidCallback onRemove;
  final bool isWeb;

  const _TransferLineItemCard({
    super.key,
    required this.item,
    required this.index,
    required this.onUpdate,
    required this.onRemove,
    required this.isWeb,
  });

  @override
  ConsumerState<_TransferLineItemCard> createState() =>
      _TransferLineItemCardState();
}

class _TransferLineItemCardState extends ConsumerState<_TransferLineItemCard> {
  final _quantityController = TextEditingController();
  final _batchNoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _quantityController.text =
        widget.item.quantity > 0 ? widget.item.quantity.toString() : '';
    _batchNoController.text = widget.item.batchNo ?? '';
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _batchNoController.dispose();
    super.dispose();
  }

  void _updateItem() {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final amount = quantity * widget.item.rate;

    widget.onUpdate(widget.item.copyWith(
      quantity: quantity,
      amount: amount,
      batchNo: _batchNoController.text.isEmpty ? null : _batchNoController.text,
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
                    'Item ${widget.index + 1}',
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
                  value: widget.item.productId.isEmpty ? null : widget.item.productId,
                  decoration: const InputDecoration(
                    labelText: 'Product',
                    border: OutlineInputBorder(),
                  ),
                  items: activeProducts.map((product) {
                    return DropdownMenuItem(
                      value: product.uuid,
                      child: Text(
                        '${product.name} (Stock: ${product.currentStock} ${product.unit})',
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      final product =
                          activeProducts.firstWhere((p) => p.uuid == value);
                      widget.onUpdate(widget.item.copyWith(
                        productId: product.uuid,
                        productName: product.name,
                        unit: product.unit,
                        rate: product.purchaseRate,
                        currentStock: product.currentStock,
                        amount: widget.item.quantity * product.purchaseRate,
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

            // Stock Indicator
            if (widget.item.productId.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.item.currentStock > 0
                      ? Colors.green[50]
                      : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.item.currentStock > 0
                        ? Colors.green[200]!
                        : Colors.red[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.inventory_2,
                      size: 16,
                      color: widget.item.currentStock > 0
                          ? Colors.green[700]
                          : Colors.red[700],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Available Stock: ${widget.item.currentStock} ${widget.item.unit}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: widget.item.currentStock > 0
                            ? Colors.green[700]
                            : Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // Quantity, Rate, Amount
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
                        suffixText: widget.item.unit,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      onChanged: (_) => _updateItem(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final qty = double.tryParse(value);
                        if (qty == null || qty <= 0) {
                          return 'Invalid';
                        }
                        if (qty > widget.item.currentStock) {
                          return 'Exceeds stock';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      initialValue: widget.item.rate.toStringAsFixed(2),
                      decoration: const InputDecoration(
                        labelText: 'Rate',
                        border: OutlineInputBorder(),
                        prefixText: '₹',
                      ),
                      readOnly: true,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      initialValue: currencyFormat.format(widget.item.amount),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
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
                        suffixText: widget.item.unit,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      onChanged: (_) => _updateItem(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final qty = double.tryParse(value);
                        if (qty == null || qty <= 0) {
                          return 'Invalid';
                        }
                        if (qty > widget.item.currentStock) {
                          return 'Exceeds stock';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: widget.item.rate.toStringAsFixed(2),
                      decoration: const InputDecoration(
                        labelText: 'Rate',
                        border: OutlineInputBorder(),
                        prefixText: '₹',
                      ),
                      readOnly: true,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: currencyFormat.format(widget.item.amount),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Batch Number
            TextFormField(
              controller: _batchNoController,
              decoration: const InputDecoration(
                labelText: 'Batch No (Optional)',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _updateItem(),
            ),
          ],
        ),
      ),
    );
  }
}

// Model for line items
class TransferLineItemModel {
  final String productId;
  final String productName;
  final String unit;
  final double quantity;
  final double rate;
  final double amount;
  final String? batchNo;
  final double currentStock;

  TransferLineItemModel({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.rate,
    required this.amount,
    this.batchNo,
    required this.currentStock,
  });

  TransferLineItemModel copyWith({
    String? productId,
    String? productName,
    String? unit,
    double? quantity,
    double? rate,
    double? amount,
    String? batchNo,
    double? currentStock,
  }) {
    return TransferLineItemModel(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      amount: amount ?? this.amount,
      batchNo: batchNo ?? this.batchNo,
      currentStock: currentStock ?? this.currentStock,
    );
  }
}
