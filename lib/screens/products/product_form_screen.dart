import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:go_router/go_router.dart';
import 'package:hotel_inventory_management/config/constants.dart';
import 'package:hotel_inventory_management/config/theme.dart';
import 'package:hotel_inventory_management/db/app_database.dart';
import 'package:hotel_inventory_management/providers/product_provider.dart';
import 'package:uuid/uuid.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final String? productId;

  const ProductFormScreen({super.key, this.productId});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _gstController = TextEditingController(text: '0');
  final _purchaseRateController = TextEditingController(text: '0');
  final _sellingRateController = TextEditingController(text: '0');
  final _openingStockController = TextEditingController(text: '0');
  final _reorderLevelController = TextEditingController(text: '0');
  final _unitConversionController = TextEditingController(text: '1');

  String _selectedCategory = AppConstants.productCategories.first;
  String _selectedUnit = AppConstants.units.first;
  bool _batchTracking = false;
  DateTime? _expiryDate;
  bool _isLoading = false;
  Product? _existingProduct;

  @override
  void initState() {
    super.initState();
    if (widget.productId != null) {
      _loadProduct();
    }
  }

  Future<void> _loadProduct() async {
    setState(() => _isLoading = true);
    final productDao = ref.read(productDaoProvider);
    final product = await productDao.getProductById(widget.productId!);

    if (product != null && mounted) {
      setState(() {
        _existingProduct = product;
        _nameController.text = product.name;
        _barcodeController.text = product.barcode ?? '';
        _selectedCategory = product.category;
        _selectedUnit = product.unit;
        _gstController.text = product.gstPercent.toString();
        _purchaseRateController.text = product.purchaseRate.toString();
        _sellingRateController.text = product.sellingRate.toString();
        _openingStockController.text = product.openingStock.toString();
        _reorderLevelController.text = product.reorderLevel.toString();
        _unitConversionController.text = product.unitConversion.toString();
        _batchTracking = product.batchTracking;
        _expiryDate = product.expiryDate;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _gstController.dispose();
    _purchaseRateController.dispose();
    _sellingRateController.dispose();
    _openingStockController.dispose();
    _reorderLevelController.dispose();
    _unitConversionController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final productNotifier = ref.read(productNotifierProvider.notifier);

      if (_existingProduct == null) {
        // Create new product
        final product = ProductsCompanion(
          uuid: drift.Value(const Uuid().v4()),
          name: drift.Value(_nameController.text.trim()),
          category: drift.Value(_selectedCategory),
          unit: drift.Value(_selectedUnit),
          unitConversion: drift.Value(double.parse(_unitConversionController.text)),
          gstPercent: drift.Value(double.parse(_gstController.text)),
          purchaseRate: drift.Value(double.parse(_purchaseRateController.text)),
          sellingRate: drift.Value(double.parse(_sellingRateController.text)),
          openingStock: drift.Value(double.parse(_openingStockController.text)),
          currentStock: drift.Value(double.parse(_openingStockController.text)),
          reorderLevel: drift.Value(double.parse(_reorderLevelController.text)),
          batchTracking: drift.Value(_batchTracking),
          barcode: drift.Value(_barcodeController.text.trim().isEmpty
              ? null
              : _barcodeController.text.trim()),
          expiryDate: drift.Value(_expiryDate),
          lastModified: drift.Value(DateTime.now()),
          isSynced: const drift.Value(false),
          sourceDevice: const drift.Value('local'),
          isActive: const drift.Value(true),
        );

        await productNotifier.createProduct(product);
      } else {
        // Update existing product
        final updatedProduct = _existingProduct!.copyWith(
          name: _nameController.text.trim(),
          category: _selectedCategory,
          unit: _selectedUnit,
          unitConversion: double.parse(_unitConversionController.text),
          gstPercent: double.parse(_gstController.text),
          purchaseRate: double.parse(_purchaseRateController.text),
          sellingRate: double.parse(_sellingRateController.text),
          reorderLevel: double.parse(_reorderLevelController.text),
          batchTracking: _batchTracking,
          barcode: _barcodeController.text.trim().isEmpty
              ? null
              : _barcodeController.text.trim(),
          expiryDate: _expiryDate,
          lastModified: DateTime.now(),
          isSynced: false,
        );

        await productNotifier.updateProduct(updatedProduct);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _existingProduct == null
                  ? 'Product created successfully'
                  : 'Product updated successfully',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.go('/products');
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
    final isEdit = _existingProduct != null;

    if (_isLoading && _existingProduct == null && widget.productId != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Product' : 'New Product'),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _showDeleteDialog,
              tooltip: 'Delete Product',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Basic Information Section
              Text(
                'Basic Information',
                style: AppTheme.heading3,
              ),
              const SizedBox(height: 16),

              // Product Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name *',
                  prefixIcon: Icon(Icons.inventory_2),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter product name';
                  }
                  return null;
                },
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),

              // Category Dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  prefixIcon: Icon(Icons.category),
                ),
                items: AppConstants.productCategories
                    .map((category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ))
                    .toList(),
                onChanged: _isLoading
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _selectedCategory = value);
                        }
                      },
              ),
              const SizedBox(height: 16),

              // Unit Dropdown
              DropdownButtonFormField<String>(
                value: _selectedUnit,
                decoration: const InputDecoration(
                  labelText: 'Unit *',
                  prefixIcon: Icon(Icons.straighten),
                ),
                items: AppConstants.units
                    .map((unit) => DropdownMenuItem(
                          value: unit,
                          child: Text(unit),
                        ))
                    .toList(),
                onChanged: _isLoading
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _selectedUnit = value);
                        }
                      },
              ),
              const SizedBox(height: 16),

              // Barcode
              TextFormField(
                controller: _barcodeController,
                decoration: InputDecoration(
                  labelText: 'Barcode',
                  prefixIcon: const Icon(Icons.qr_code),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _scanBarcode,
                  ),
                ),
                enabled: !_isLoading,
              ),
              const SizedBox(height: 24),

              // Pricing Section
              Text(
                'Pricing & GST',
                style: AppTheme.heading3,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _gstController,
                      decoration: const InputDecoration(
                        labelText: 'GST %',
                        prefixIcon: Icon(Icons.percent),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        final gst = double.tryParse(value);
                        if (gst == null || gst < 0 || gst > 100) {
                          return 'Invalid GST';
                        }
                        return null;
                      },
                      enabled: !_isLoading,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _unitConversionController,
                      decoration: const InputDecoration(
                        labelText: 'Unit Conversion',
                        prefixIcon: Icon(Icons.compare_arrows),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        final conv = double.tryParse(value);
                        if (conv == null || conv <= 0) {
                          return 'Invalid value';
                        }
                        return null;
                      },
                      enabled: !_isLoading,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _purchaseRateController,
                      decoration: const InputDecoration(
                        labelText: 'Purchase Rate *',
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        final rate = double.tryParse(value);
                        if (rate == null || rate < 0) {
                          return 'Invalid rate';
                        }
                        return null;
                      },
                      enabled: !_isLoading,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _sellingRateController,
                      decoration: const InputDecoration(
                        labelText: 'Selling Rate *',
                        prefixIcon: Icon(Icons.sell),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        final rate = double.tryParse(value);
                        if (rate == null || rate < 0) {
                          return 'Invalid rate';
                        }
                        return null;
                      },
                      enabled: !_isLoading,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Stock Section
              Text(
                'Stock Information',
                style: AppTheme.heading3,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _openingStockController,
                      decoration: const InputDecoration(
                        labelText: 'Opening Stock',
                        prefixIcon: Icon(Icons.inventory),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        final stock = double.tryParse(value);
                        if (stock == null || stock < 0) {
                          return 'Invalid stock';
                        }
                        return null;
                      },
                      enabled: !_isLoading && !isEdit,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _reorderLevelController,
                      decoration: const InputDecoration(
                        labelText: 'Reorder Level',
                        prefixIcon: Icon(Icons.warning_amber),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        final level = double.tryParse(value);
                        if (level == null || level < 0) {
                          return 'Invalid level';
                        }
                        return null;
                      },
                      enabled: !_isLoading,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Batch Tracking
              SwitchListTile(
                title: const Text('Enable Batch Tracking'),
                subtitle: const Text('Track items by batch number and expiry'),
                value: _batchTracking,
                onChanged: _isLoading
                    ? null
                    : (value) {
                        setState(() => _batchTracking = value);
                      },
              ),

              if (_batchTracking) ...[
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Expiry Date'),
                  subtitle: Text(
                    _expiryDate == null
                        ? 'Not set'
                        : 'Expires on ${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}',
                  ),
                  trailing: const Icon(Icons.edit),
                  onTap: _isLoading ? null : _selectExpiryDate,
                ),
              ],

              const SizedBox(height: 32),

              // Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProduct,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        isEdit ? 'Update Product' : 'Create Product',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectExpiryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (date != null) {
      setState(() => _expiryDate = date);
    }
  }

  Future<void> _scanBarcode() async {
    // TODO: Implement barcode scanning
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Barcode scanning will be implemented soon'),
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text(
          'Are you sure you want to delete this product? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _deleteProduct();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduct() async {
    if (_existingProduct == null) return;

    setState(() => _isLoading = true);

    try {
      final productNotifier = ref.read(productNotifierProvider.notifier);
      await productNotifier.deleteProduct(_existingProduct!.uuid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product deleted successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.go('/products');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting product: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }
}
