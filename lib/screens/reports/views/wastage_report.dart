import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../providers/wastage_provider.dart';
import '../../../db/app_database.dart';
import '../../../config/constants.dart';
import '../../../services/pdf_service.dart';

class WastageReport extends ConsumerStatefulWidget {
  const WastageReport({super.key});

  @override
  ConsumerState<WastageReport> createState() => _WastageReportState();
}

class _WastageReportState extends ConsumerState<WastageReport> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String? _selectedType;
  String? _selectedReason;

  @override
  Widget build(BuildContext context) {
    final wastagesAsync = ref.watch(wastagesProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wastage & Returns Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export to PDF',
            onPressed: () => _exportToPdf(wastagesAsync),
          ),
        ],
      ),
      body: wastagesAsync.when(
        data: (wastages) {
          // Apply filters
          var filteredWastages = wastages.where((wastage) {
            // Date filter
            if (wastage.wastageDate.isBefore(_startDate) ||
                wastage.wastageDate
                    .isAfter(_endDate.add(const Duration(days: 1)))) {
              return false;
            }
            // Type filter
            if (_selectedType != null && wastage.type != _selectedType) {
              return false;
            }
            // Reason filter
            if (_selectedReason != null && wastage.reason != _selectedReason) {
              return false;
            }
            return true;
          }).toList();

          // Sort by date descending
          filteredWastages.sort((a, b) => b.wastageDate.compareTo(a.wastageDate));

          // Calculate totals
          double totalWastageAmount = 0;
          double totalReturnAmount = 0;
          Map<String, double> reasonTotals = {};
          Map<String, int> reasonCounts = {};

          for (final wastage in filteredWastages) {
            if (wastage.type == 'Wastage') {
              totalWastageAmount += wastage.totalAmount;
            } else {
              totalReturnAmount += wastage.totalAmount;
            }

            reasonTotals[wastage.reason] =
                (reasonTotals[wastage.reason] ?? 0) + wastage.totalAmount;
            reasonCounts[wastage.reason] =
                (reasonCounts[wastage.reason] ?? 0) + 1;
          }

          final totalAmount = totalWastageAmount + totalReturnAmount;

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
                          'Wastage & Returns Report',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Period: ${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                        Text(
                          'Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
                              Expanded(child: _buildDateFilter(context, true)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildDateFilter(context, false)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildTypeFilter()),
                              const SizedBox(width: 12),
                              Expanded(child: _buildReasonFilter()),
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
                          Row(
                            children: [
                              Expanded(child: _buildTypeFilter()),
                              const SizedBox(width: 12),
                              Expanded(child: _buildReasonFilter()),
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
                          title: 'Total Records',
                          value: filteredWastages.length.toString(),
                          icon: Icons.receipt_long,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Total Value',
                          value: NumberFormat.currency(symbol: '₹')
                              .format(totalAmount),
                          icon: Icons.attach_money,
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Wastage',
                          value: NumberFormat.currency(symbol: '₹')
                              .format(totalWastageAmount),
                          icon: Icons.delete_outline,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Returns',
                          value: NumberFormat.currency(symbol: '₹')
                              .format(totalReturnAmount),
                          icon: Icons.undo,
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
                          title: 'Records',
                          value: filteredWastages.length.toString(),
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
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          title: 'Wastage',
                          value: NumberFormat.compactCurrency(symbol: '₹')
                              .format(totalWastageAmount),
                          icon: Icons.delete_outline,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Returns',
                          value: NumberFormat.compactCurrency(symbol: '₹')
                              .format(totalReturnAmount),
                          icon: Icons.undo,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                // Wastage Analysis by Reason
                if (reasonTotals.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Analysis by Reason',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          ...reasonTotals.entries.map((entry) {
                            final percentage = totalAmount > 0
                                ? (entry.value / totalAmount) * 100
                                : 0.0;
                            final count = reasonCounts[entry.key] ?? 0;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              entry.key,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              '$count occurrence${count > 1 ? 's' : ''}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        NumberFormat.currency(symbol: '₹')
                                            .format(entry.value),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(
                                    value: percentage / 100,
                                    backgroundColor: Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.red[400]!),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${percentage.toStringAsFixed(1)}% of total',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Wastages List
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wastage & Return Transactions',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        if (filteredWastages.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Text(
                                'No records found for selected filters',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          )
                        else if (isWeb)
                          _buildWebTable(filteredWastages)
                        else
                          _buildMobileList(filteredWastages),
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

  Future<void> _exportToPdf(AsyncValue<List<Wastage>> wastagesAsync) async {
    await wastagesAsync.when(
      data: (wastages) async {
        try {
          final dateFormat = DateFormat('dd MMM yyyy');
          final currencyFormat = NumberFormat.currency(symbol: '₹');

          // Apply same filters as UI
          var filteredWastages = wastages.where((wastage) {
            if (wastage.wastageDate.isBefore(_startDate) ||
                wastage.wastageDate
                    .isAfter(_endDate.add(const Duration(days: 1)))) {
              return false;
            }
            if (_selectedType != null && wastage.type != _selectedType) {
              return false;
            }
            if (_selectedReason != null && wastage.reason != _selectedReason) {
              return false;
            }
            return true;
          }).toList();

          // Sort by date descending
          filteredWastages.sort((a, b) => b.wastageDate.compareTo(a.wastageDate));

          // Calculate summary
          double totalWastageAmount = 0;
          double totalReturnAmount = 0;

          for (final wastage in filteredWastages) {
            if (wastage.type == 'Wastage') {
              totalWastageAmount += wastage.totalAmount;
            } else {
              totalReturnAmount += wastage.totalAmount;
            }
          }

          final totalAmount = totalWastageAmount + totalReturnAmount;

          // Prepare filters list
          List<String> filters = [];
          filters.add(
              'Period: ${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}');
          if (_selectedType != null) {
            filters.add('Type: $_selectedType');
          }
          if (_selectedReason != null) {
            filters.add('Reason: $_selectedReason');
          }

          // Prepare table data
          final tableHeaders = [
            ['Reference No', 'Date', 'Type', 'Reason', 'Amount'],
          ];
          final tableData = filteredWastages.map((wastage) {
            return [
              wastage.referenceNo,
              dateFormat.format(wastage.wastageDate),
              wastage.type,
              wastage.reason,
              currencyFormat.format(wastage.totalAmount),
            ];
          }).toList();

          // Create report config
          final config = ReportConfig(
            title: 'Wastage & Returns Report',
            subtitle: 'Loss Prevention and Return Tracking',
            generatedDate: DateTime.now(),
            filters: filters,
            summaryData: {
              'Total Records': filteredWastages.length.toString(),
              'Total Value': currencyFormat.format(totalAmount),
              'Wastage': currencyFormat.format(totalWastageAmount),
              'Returns': currencyFormat.format(totalReturnAmount),
            },
            tableHeaders: tableHeaders,
            tableData: tableData,
          );

          // Generate PDF
          final pdfService = PdfService();
          final file = await pdfService.generateReport(config);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('PDF saved: ${file.path}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
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
      loading: () async {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loading data...')),
        );
      },
      error: (error, stack) async {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
            backgroundColor: Colors.red,
          ),
        );
      },
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

  Widget _buildTypeFilter() {
    return DropdownButtonFormField<String?>(
      value: _selectedType,
      decoration: const InputDecoration(
        labelText: 'Type',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: null, child: Text('All Types')),
        DropdownMenuItem(value: 'Wastage', child: Text('Wastage')),
        DropdownMenuItem(value: 'Return', child: Text('Return')),
      ],
      onChanged: (value) => setState(() => _selectedType = value),
    );
  }

  Widget _buildReasonFilter() {
    return DropdownButtonFormField<String?>(
      value: _selectedReason,
      decoration: const InputDecoration(
        labelText: 'Reason',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('All Reasons')),
        ...wastageReasons.map((reason) => DropdownMenuItem(
              value: reason,
              child: Text(reason),
            )),
      ],
      onChanged: (value) => setState(() => _selectedReason = value),
    );
  }

  Widget _buildWebTable(List<Wastage> wastages) {
    final currencyFormat = NumberFormat.currency(symbol: '₹');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Reference No')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Reason')),
          DataColumn(label: Text('Amount')),
        ],
        rows: wastages.map((wastage) {
          return DataRow(
            cells: [
              DataCell(Text(wastage.referenceNo)),
              DataCell(
                  Text(DateFormat('dd MMM yyyy').format(wastage.wastageDate))),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: wastage.type == 'Wastage'
                        ? Colors.red[50]
                        : Colors.orange[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    wastage.type,
                    style: TextStyle(
                      color: wastage.type == 'Wastage'
                          ? Colors.red[700]
                          : Colors.orange[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              DataCell(Text(wastage.reason)),
              DataCell(
                Text(
                  currencyFormat.format(wastage.totalAmount),
                  style: TextStyle(
                    color: wastage.type == 'Wastage' ? Colors.red : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileList(List<Wastage> wastages) {
    final currencyFormat = NumberFormat.currency(symbol: '₹');

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: wastages.length,
      itemBuilder: (context, index) {
        final wastage = wastages[index];

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
                      wastage.referenceNo,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: wastage.type == 'Wastage'
                            ? Colors.red[50]
                            : Colors.orange[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        wastage.type,
                        style: TextStyle(
                          color: wastage.type == 'Wastage'
                              ? Colors.red[700]
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
                  wastage.reason,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd MMM yyyy').format(wastage.wastageDate),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                      currencyFormat.format(wastage.totalAmount),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: wastage.type == 'Wastage'
                            ? Colors.red
                            : Colors.orange,
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
