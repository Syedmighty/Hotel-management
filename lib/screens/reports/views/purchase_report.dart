import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../providers/purchase_provider.dart';
import '../../../providers/supplier_provider.dart';
import '../../../db/app_database.dart';
import '../../../config/constants.dart';

class PurchaseReport extends ConsumerStatefulWidget {
  const PurchaseReport({super.key});

  @override
  ConsumerState<PurchaseReport> createState() => _PurchaseReportState();
}

class _PurchaseReportState extends ConsumerState<PurchaseReport> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String? _selectedSupplier;
  String? _selectedPaymentMode;
  String? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final purchasesAsync = ref.watch(purchasesProvider);
    final suppliersAsync = ref.watch(suppliersProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export to PDF',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('PDF export coming soon'),
                ),
              );
            },
          ),
        ],
      ),
      body: purchasesAsync.when(
        data: (purchases) {
          // Apply filters
          var filteredPurchases = purchases.where((p) {
            // Date filter
            if (p.purchaseDate.isBefore(_startDate) ||
                p.purchaseDate.isAfter(_endDate.add(const Duration(days: 1)))) {
              return false;
            }
            // Supplier filter
            if (_selectedSupplier != null && p.supplierId != _selectedSupplier) {
              return false;
            }
            // Payment mode filter
            if (_selectedPaymentMode != null &&
                p.paymentMode != _selectedPaymentMode) {
              return false;
            }
            // Status filter
            if (_selectedStatus != null && p.status != _selectedStatus) {
              return false;
            }
            return true;
          }).toList();

          // Sort by date descending
          filteredPurchases.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));

          // Calculate totals
          double totalAmount = 0;
          double paidAmount = 0;
          double creditAmount = 0;
          int approvedCount = 0;
          int pendingCount = 0;

          for (final purchase in filteredPurchases) {
            totalAmount += purchase.totalAmount;
            if (purchase.paymentMode == 'Cash' || purchase.paymentMode == 'Card') {
              paidAmount += purchase.totalAmount;
            } else if (purchase.paymentMode == 'Credit') {
              creditAmount += purchase.totalAmount;
            }
            if (purchase.status == 'Approved') {
              approvedCount++;
            } else {
              pendingCount++;
            }
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
                          'Purchase Report',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Period: ${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          'Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
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

                // Filters
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filters',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        if (isWeb)
                          Row(
                            children: [
                              Expanded(
                                child: _buildDateFilter(context, true),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildDateFilter(context, false),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSupplierFilter(suppliersAsync),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildPaymentModeFilter(),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatusFilter(),
                              ),
                            ],
                          )
                        else ...[
                          Row(
                            children: [
                              Expanded(child: _buildDateFilter(context, true)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildDateFilter(context, false)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildSupplierFilter(suppliersAsync),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _buildPaymentModeFilter()),
                              const SizedBox(width: 12),
                              Expanded(child: _buildStatusFilter()),
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
                          title: 'Total Purchases',
                          value: filteredPurchases.length.toString(),
                          icon: Icons.receipt_long,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Total Amount',
                          value: NumberFormat.currency(symbol: '₹')
                              .format(totalAmount),
                          icon: Icons.attach_money,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Paid',
                          value:
                              NumberFormat.currency(symbol: '₹').format(paidAmount),
                          icon: Icons.payment,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Credit',
                          value: NumberFormat.currency(symbol: '₹')
                              .format(creditAmount),
                          icon: Icons.credit_card,
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
                          title: 'Purchases',
                          value: filteredPurchases.length.toString(),
                          icon: Icons.receipt_long,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Total',
                          value: NumberFormat.compactCurrency(symbol: '₹')
                              .format(totalAmount),
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
                          title: 'Paid',
                          value: NumberFormat.compactCurrency(symbol: '₹')
                              .format(paidAmount),
                          icon: Icons.payment,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Credit',
                          value: NumberFormat.compactCurrency(symbol: '₹')
                              .format(creditAmount),
                          icon: Icons.credit_card,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                // Purchases List
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Purchase Transactions',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        if (filteredPurchases.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Text(
                                'No purchases found for selected filters',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          )
                        else if (isWeb)
                          _buildWebTable(filteredPurchases, suppliersAsync)
                        else
                          _buildMobileList(filteredPurchases, suppliersAsync),
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

  Widget _buildSupplierFilter(AsyncValue<List<Supplier>> suppliersAsync) {
    return suppliersAsync.when(
      data: (suppliers) {
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
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const Text('Error loading suppliers'),
    );
  }

  Widget _buildPaymentModeFilter() {
    return DropdownButtonFormField<String?>(
      value: _selectedPaymentMode,
      decoration: const InputDecoration(
        labelText: 'Payment Mode',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('All Modes')),
        ...paymentModes.map((mode) => DropdownMenuItem(
              value: mode,
              child: Text(mode),
            )),
      ],
      onChanged: (value) => setState(() => _selectedPaymentMode = value),
    );
  }

  Widget _buildStatusFilter() {
    return DropdownButtonFormField<String?>(
      value: _selectedStatus,
      decoration: const InputDecoration(
        labelText: 'Status',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: null, child: Text('All Status')),
        DropdownMenuItem(value: 'Pending', child: Text('Pending')),
        DropdownMenuItem(value: 'Approved', child: Text('Approved')),
      ],
      onChanged: (value) => setState(() => _selectedStatus = value),
    );
  }

  Widget _buildWebTable(
      List<Purchase> purchases, AsyncValue<List<Supplier>> suppliersAsync) {
    final currencyFormat = NumberFormat.currency(symbol: '₹');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Purchase No')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Supplier')),
          DataColumn(label: Text('Payment Mode')),
          DataColumn(label: Text('Amount')),
          DataColumn(label: Text('Status')),
        ],
        rows: purchases.map((purchase) {
          final supplierName = suppliersAsync.when(
            data: (suppliers) {
              final supplier =
                  suppliers.firstWhere((s) => s.uuid == purchase.supplierId);
              return supplier.name;
            },
            loading: () => 'Loading...',
            error: (_, __) => 'Unknown',
          );

          return DataRow(
            cells: [
              DataCell(Text(purchase.purchaseNo)),
              DataCell(Text(DateFormat('dd MMM yyyy').format(purchase.purchaseDate))),
              DataCell(Text(supplierName)),
              DataCell(Text(purchase.paymentMode)),
              DataCell(Text(currencyFormat.format(purchase.totalAmount))),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: purchase.status == 'Approved'
                        ? Colors.green[50]
                        : Colors.orange[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    purchase.status,
                    style: TextStyle(
                      color: purchase.status == 'Approved'
                          ? Colors.green[700]
                          : Colors.orange[700],
                      fontWeight: FontWeight.w600,
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

  Widget _buildMobileList(
      List<Purchase> purchases, AsyncValue<List<Supplier>> suppliersAsync) {
    final currencyFormat = NumberFormat.currency(symbol: '₹');

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: purchases.length,
      itemBuilder: (context, index) {
        final purchase = purchases[index];
        final supplierName = suppliersAsync.when(
          data: (suppliers) {
            final supplier =
                suppliers.firstWhere((s) => s.uuid == purchase.supplierId);
            return supplier.name;
          },
          loading: () => 'Loading...',
          error: (_, __) => 'Unknown',
        );

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
                    Text(
                      purchase.purchaseNo,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: purchase.status == 'Approved'
                            ? Colors.green[50]
                            : Colors.orange[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        purchase.status,
                        style: TextStyle(
                          color: purchase.status == 'Approved'
                              ? Colors.green[700]
                              : Colors.orange[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  supplierName,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('dd MMM yyyy').format(purchase.purchaseDate),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      purchase.paymentMode,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Amount:',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    Text(
                      currencyFormat.format(purchase.totalAmount),
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
          ),
        );
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
