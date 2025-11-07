import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:go_router/go_router.dart';
import 'package:hotel_inventory_management/config/theme.dart';
import 'package:hotel_inventory_management/db/app_database.dart';
import 'package:hotel_inventory_management/providers/supplier_provider.dart';
import 'package:uuid/uuid.dart';

class SupplierFormScreen extends ConsumerStatefulWidget {
  final String? supplierId;

  const SupplierFormScreen({super.key, this.supplierId});

  @override
  ConsumerState<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends ConsumerState<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _gstinController = TextEditingController();
  final _addressController = TextEditingController();
  final _balanceController = TextEditingController(text: '0');

  bool _isLoading = false;
  Supplier? _existingSupplier;

  @override
  void initState() {
    super.initState();
    if (widget.supplierId != null) {
      _loadSupplier();
    }
  }

  Future<void> _loadSupplier() async {
    setState(() => _isLoading = true);
    final supplierDao = ref.read(supplierDaoProvider);
    final supplier = await supplierDao.getSupplierById(widget.supplierId!);

    if (supplier != null && mounted) {
      setState(() {
        _existingSupplier = supplier;
        _nameController.text = supplier.name;
        _contactController.text = supplier.contact;
        _gstinController.text = supplier.gstin ?? '';
        _addressController.text = supplier.address;
        _balanceController.text = supplier.balance.toString();
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _gstinController.dispose();
    _addressController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supplierNotifier = ref.read(supplierNotifierProvider.notifier);

      if (_existingSupplier == null) {
        // Create new supplier
        final supplier = SuppliersCompanion(
          uuid: drift.Value(const Uuid().v4()),
          name: drift.Value(_nameController.text.trim()),
          contact: drift.Value(_contactController.text.trim()),
          gstin: drift.Value(_gstinController.text.trim().isEmpty
              ? null
              : _gstinController.text.trim()),
          address: drift.Value(_addressController.text.trim()),
          balance: drift.Value(double.parse(_balanceController.text)),
          lastModified: drift.Value(DateTime.now()),
          isSynced: const drift.Value(false),
          sourceDevice: const drift.Value('local'),
          isActive: const drift.Value(true),
        );

        await supplierNotifier.createSupplier(supplier);
      } else {
        // Update existing supplier
        final updatedSupplier = _existingSupplier!.copyWith(
          name: _nameController.text.trim(),
          contact: _contactController.text.trim(),
          gstin: _gstinController.text.trim().isEmpty
              ? null
              : _gstinController.text.trim(),
          address: _addressController.text.trim(),
          balance: double.parse(_balanceController.text),
          lastModified: DateTime.now(),
          isSynced: false,
        );

        await supplierNotifier.updateSupplier(updatedSupplier);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _existingSupplier == null
                  ? 'Supplier created successfully'
                  : 'Supplier updated successfully',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.go('/suppliers');
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
    final isEdit = _existingSupplier != null;

    if (_isLoading && _existingSupplier == null && widget.supplierId != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Supplier' : 'New Supplier'),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _showDeleteDialog,
              tooltip: 'Delete Supplier',
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
              // Supplier Information Section
              Text(
                'Supplier Information',
                style: AppTheme.heading3,
              ),
              const SizedBox(height: 16),

              // Supplier Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Supplier Name *',
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter supplier name';
                  }
                  return null;
                },
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),

              // Contact
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(
                  labelText: 'Contact *',
                  prefixIcon: Icon(Icons.phone),
                  hintText: 'Phone or Email',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter contact information';
                  }
                  return null;
                },
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),

              // GSTIN
              TextFormField(
                controller: _gstinController,
                decoration: const InputDecoration(
                  labelText: 'GSTIN',
                  prefixIcon: Icon(Icons.credit_card),
                  hintText: 'GST Identification Number',
                ),
                textCapitalization: TextCapitalization.characters,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),

              // Address
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address *',
                  prefixIcon: Icon(Icons.location_on),
                  hintText: 'Full Address',
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter address';
                  }
                  return null;
                },
                enabled: !_isLoading,
              ),
              const SizedBox(height: 24),

              // Balance Section
              Text(
                'Account Balance',
                style: AppTheme.heading3,
              ),
              const SizedBox(height: 16),

              // Opening Balance
              TextFormField(
                controller: _balanceController,
                decoration: const InputDecoration(
                  labelText: 'Opening Balance',
                  prefixIcon: Icon(Icons.account_balance_wallet),
                  hintText: 'Outstanding dues',
                  helperText: 'Enter 0 if no outstanding balance',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  final balance = double.tryParse(value);
                  if (balance == null || balance < 0) {
                    return 'Invalid balance';
                  }
                  return null;
                },
                enabled: !_isLoading && !isEdit,
              ),

              if (isEdit && _existingSupplier != null && _existingSupplier!.balance > 0) ...[
                const SizedBox(height: 16),
                Card(
                  color: AppTheme.warningColor.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.warning_amber,
                              color: AppTheme.warningColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Outstanding Balance: ₹${_existingSupplier!.balance.toStringAsFixed(2)}',
                                style: AppTheme.bodyLarge.copyWith(
                                  color: AppTheme.warningColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _showPaymentDialog,
                          icon: const Icon(Icons.payment),
                          label: const Text('Record Payment'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveSupplier,
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
                        isEdit ? 'Update Supplier' : 'Create Supplier',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentDialog() {
    final paymentController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Record Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Outstanding Balance: ₹${_existingSupplier!.balance.toStringAsFixed(2)}',
              style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: paymentController,
              decoration: const InputDecoration(
                labelText: 'Payment Amount',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(paymentController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid amount'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
                return;
              }

              Navigator.pop(dialogContext);

              final supplierNotifier = ref.read(supplierNotifierProvider.notifier);
              await supplierNotifier.addPayment(_existingSupplier!.uuid, amount);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Payment recorded successfully'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
                _loadSupplier(); // Reload to show updated balance
              }
            },
            child: const Text('Record'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Supplier'),
        content: const Text(
          'Are you sure you want to delete this supplier? This action cannot be undone.',
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
              await _deleteSupplier();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSupplier() async {
    if (_existingSupplier == null) return;

    setState(() => _isLoading = true);

    try {
      final supplierNotifier = ref.read(supplierNotifierProvider.notifier);
      await supplierNotifier.deleteSupplier(_existingSupplier!.uuid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Supplier deleted successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.go('/suppliers');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting supplier: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }
}
