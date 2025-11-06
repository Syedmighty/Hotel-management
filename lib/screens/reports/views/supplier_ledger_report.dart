import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../providers/purchase_provider.dart';
import '../../../providers/supplier_provider.dart';
import '../../../db/app_database.dart';

class SupplierLedgerReport extends ConsumerStatefulWidget {
  const SupplierLedgerReport({super.key});

  @override
  ConsumerState<SupplierLedgerReport> createState() =>
      _SupplierLedgerReportState();
}

class _SupplierLedgerReportState extends ConsumerState<SupplierLedgerReport> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 90));
  DateTime _endDate = DateTime.now();
  String? _selectedSupplier;

  @override
  Widget build(BuildContext context) {
    final purchasesAsync = ref.watch(purchasesProvider);
    final suppliersAsync = ref.watch(suppliersProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier Ledger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export to PDF',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDF export coming soon')),
              );
            },
          ),
        ],
      ),
      body: suppliersAsync.when(
        data: (suppliers) {
          return purchasesAsync.when(
            data: (purchases) {
              // Apply filters
              var filteredPurchases = purchases.where((p) {
                // Date filter
                if (p.purchaseDate.isBefore(_startDate) ||
                    p.purchaseDate
                        .isAfter(_endDate.add(const Duration(days: 1)))) {
                  return false;
                }
                // Supplier filter
                if (_selectedSupplier != null &&
                    p.supplierId != _selectedSupplier) {
                  return false;
                }
                return true;
              }).toList();

              // Group purchases by supplier
              Map<String, List<Purchase>> purchasesBySupplier = {};
              for (final purchase in filteredPurchases) {
                if (!purchasesBySupplier.containsKey(purchase.supplierId)) {
                  purchasesBySupplier[purchase.supplierId] = [];
                }
                purchasesBySupplier[purchase.supplierId]!.add(purchase);
              }

              // Calculate supplier totals
              Map<String, _SupplierData> supplierData = {};
              for (final entry in purchasesBySupplier.entries) {
                final supplier = suppliers.firstWhere(
                  (s) => s.uuid == entry.key,
                  orElse: () => Supplier(
                    uuid: entry.key,
                    name: 'Unknown',
                    contactPerson: '',
                    phone: '',
                    email: '',
                    address: '',
                    gstNo: '',
                    panNo: '',
                    currentBalance: 0,
                    isActive: true,
                    createdAt: DateTime.now(),
                    lastModified: DateTime.now(),
                    isSynced: false,
                    sourceDevice: '',
                  ),
                );

                double totalPurchases = 0;
                double creditAmount = 0;
                int purchaseCount = entry.value.length;

                for (final purchase in entry.value) {
                  totalPurchases += purchase.totalAmount;
                  if (purchase.paymentMode == 'Credit') {
                    creditAmount += purchase.totalAmount;
                  }
                }

                supplierData[entry.key] = _SupplierData(
                  supplier: supplier,
                  totalPurchases: totalPurchases,
                  creditAmount: creditAmount,
                  purchaseCount: purchaseCount,
                  currentBalance: supplier.currentBalance,
                );
              }

              // Calculate overall totals
              double grandTotal = 0;
              double totalCredit = 0;
              double totalOutstanding = 0;
              int totalSuppliers = supplierData.length;

              for (final data in supplierData.values) {
                grandTotal += data.totalPurchases;
                totalCredit += data.creditAmount;
                totalOutstanding += data.currentBalance;
              }

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
                              'Supplier Ledger Report',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Period: ${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[600]),
                            ),
                            Text(
                              'Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[600]),
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
                                  Expanded(
                                      child: _buildDateFilter(context, true)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: _buildDateFilter(context, false)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: _buildSupplierFilter(suppliers)),
                                ],
                              )
                            else ...[
                              Row(
                                children: [
                                  Expanded(
                                      child: _buildDateFilter(context, true)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: _buildDateFilter(context, false)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildSupplierFilter(suppliers),
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
                              title: 'Active Suppliers',
                              value: totalSuppliers.toString(),
                              icon: Icons.business,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SummaryCard(
                              title: 'Total Purchases',
                              value: NumberFormat.currency(symbol: '₹')
                                  .format(grandTotal),
                              icon: Icons.shopping_cart,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SummaryCard(
                              title: 'Credit Purchases',
                              value: NumberFormat.currency(symbol: '₹')
                                  .format(totalCredit),
                              icon: Icons.credit_card,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SummaryCard(
                              title: 'Outstanding',
                              value: NumberFormat.currency(symbol: '₹')
                                  .format(totalOutstanding),
                              icon: Icons.account_balance_wallet,
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
                              title: 'Suppliers',
                              value: totalSuppliers.toString(),
                              icon: Icons.business,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SummaryCard(
                              title: 'Purchases',
                              value: NumberFormat.compactCurrency(symbol: '₹')
                                  .format(grandTotal),
                              icon: Icons.shopping_cart,
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
                              title: 'Credit',
                              value: NumberFormat.compactCurrency(symbol: '₹')
                                  .format(totalCredit),
                              icon: Icons.credit_card,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SummaryCard(
                              title: 'Outstanding',
                              value: NumberFormat.compactCurrency(symbol: '₹')
                                  .format(totalOutstanding),
                              icon: Icons.account_balance_wallet,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Supplier Breakdown
                    if (supplierData.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Center(
                            child: Text(
                              'No supplier data found for selected filters',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      ...supplierData.values.map((data) {
                        return _SupplierLedgerCard(
                          data: data,
                          purchases: purchasesBySupplier[data.supplier.uuid]!,
                          isWeb: isWeb,
                        );
                      }),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildDateFilter(BuildContext context, bool isStart) {
    final date = isStart ? _startDate : _endDate;
    final label = isStart ? 'From Date' : 'To Date';

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) {
          setState(() {
            if (isStart) {
              _startDate = picked;
            } else {
              _endDate = picked;
            }
          });
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(DateFormat('dd MMM yyyy').format(date)),
      ),
    );
  }

  Widget _buildSupplierFilter(List<Supplier> suppliers) {
    return DropdownButtonFormField<String?>(
      value: _selectedSupplier,
      decoration: const InputDecoration(
        labelText: 'Supplier',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('All Suppliers')),
        ...suppliers.map((s) => DropdownMenuItem(
              value: s.uuid,
              child: Text(s.name),
            )),
      ],
      onChanged: (value) => setState(() => _selectedSupplier = value),
    );
  }
}

class _SupplierLedgerCard extends StatelessWidget {
  final _SupplierData data;
  final List<Purchase> purchases;
  final bool isWeb;

  const _SupplierLedgerCard({
    required this.data,
    required this.purchases,
    required this.isWeb,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text(
          data.supplier.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${data.purchaseCount} purchases • ${currencyFormat.format(data.totalPurchases)}',
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Balance',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              currencyFormat.format(data.currentBalance),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: data.currentBalance > 0 ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Supplier Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _InfoItem(
                      label: 'Contact',
                      value: data.supplier.contactPerson,
                      icon: Icons.person,
                    ),
                    _InfoItem(
                      label: 'Phone',
                      value: data.supplier.phone,
                      icon: Icons.phone,
                    ),
                    if (isWeb)
                      _InfoItem(
                        label: 'Email',
                        value: data.supplier.email,
                        icon: Icons.email,
                      ),
                  ],
                ),
                const Divider(height: 24),

                // Purchase Transactions
                Text(
                  'Purchase Transactions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ...purchases.map((purchase) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: Colors.grey[50],
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.receipt,
                        color: purchase.status == 'Approved'
                            ? Colors.green
                            : Colors.orange,
                      ),
                      title: Text(
                        purchase.purchaseNo,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${DateFormat('dd MMM yyyy').format(purchase.purchaseDate)} • ${purchase.paymentMode}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currencyFormat.format(purchase.totalAmount),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: purchase.status == 'Approved'
                                  ? Colors.green[50]
                                  : Colors.orange[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              purchase.status,
                              style: TextStyle(
                                fontSize: 10,
                                color: purchase.status == 'Approved'
                                    ? Colors.green[700]
                                    : Colors.orange[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplierData {
  final Supplier supplier;
  final double totalPurchases;
  final double creditAmount;
  final int purchaseCount;
  final double currentBalance;

  _SupplierData({
    required this.supplier,
    required this.totalPurchases,
    required this.creditAmount,
    required this.purchaseCount,
    required this.currentBalance,
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

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
