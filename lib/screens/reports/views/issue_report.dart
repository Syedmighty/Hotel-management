import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../providers/issue_provider.dart';
import '../../../db/app_database.dart';
import '../../../config/constants.dart';

class IssueReport extends ConsumerStatefulWidget {
  const IssueReport({super.key});

  @override
  ConsumerState<IssueReport> createState() => _IssueReportState();
}

class _IssueReportState extends ConsumerState<IssueReport> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String? _selectedDepartment;
  String? _selectedIssuedBy;
  String? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final issuesAsync = ref.watch(issuesProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Issue Report'),
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
      body: issuesAsync.when(
        data: (issues) {
          // Apply filters
          var filteredIssues = issues.where((issue) {
            // Date filter
            if (issue.issueDate.isBefore(_startDate) ||
                issue.issueDate.isAfter(_endDate.add(const Duration(days: 1)))) {
              return false;
            }
            // Department filter
            if (_selectedDepartment != null &&
                issue.department != _selectedDepartment) {
              return false;
            }
            // Issued by filter
            if (_selectedIssuedBy != null &&
                issue.issuedBy != _selectedIssuedBy) {
              return false;
            }
            // Status filter
            if (_selectedStatus != null && issue.status != _selectedStatus) {
              return false;
            }
            return true;
          }).toList();

          // Sort by date descending
          filteredIssues.sort((a, b) => b.issueDate.compareTo(a.issueDate));

          // Calculate totals
          double totalAmount = 0;
          Map<String, double> departmentTotals = {};
          int approvedCount = 0;
          int pendingCount = 0;

          for (final issue in filteredIssues) {
            totalAmount += issue.totalAmount;
            departmentTotals[issue.department] =
                (departmentTotals[issue.department] ?? 0) + issue.totalAmount;
            if (issue.status == 'Approved') {
              approvedCount++;
            } else {
              pendingCount++;
            }
          }

          // Get unique issued by users
          final issuedByUsers =
              issues.map((i) => i.issuedBy).toSet().toList();

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
                          'Issue Report',
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
                              Expanded(child: _buildDepartmentFilter()),
                              const SizedBox(width: 12),
                              Expanded(child: _buildIssuedByFilter(issuedByUsers)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildStatusFilter()),
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
                          _buildDepartmentFilter(),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _buildIssuedByFilter(issuedByUsers)),
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
                          title: 'Total Issues',
                          value: filteredIssues.length.toString(),
                          icon: Icons.send,
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
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Approved',
                          value: approvedCount.toString(),
                          icon: Icons.check_circle,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Pending',
                          value: pendingCount.toString(),
                          icon: Icons.pending,
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
                          title: 'Issues',
                          value: filteredIssues.length.toString(),
                          icon: Icons.send,
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
                          title: 'Approved',
                          value: approvedCount.toString(),
                          icon: Icons.check_circle,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Pending',
                          value: pendingCount.toString(),
                          icon: Icons.pending,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                // Department Breakdown
                if (departmentTotals.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Department Consumption',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          ...departmentTotals.entries.map((entry) {
                            final percentage = (entry.value / totalAmount) * 100;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        entry.key,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        NumberFormat.currency(symbol: '₹')
                                            .format(entry.value),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(
                                    value: percentage / 100,
                                    backgroundColor: Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.blue[400]!),
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

                // Issues List
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Issue Transactions',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        if (filteredIssues.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Text(
                                'No issues found for selected filters',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          )
                        else if (isWeb)
                          _buildWebTable(filteredIssues)
                        else
                          _buildMobileList(filteredIssues),
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

  Widget _buildDepartmentFilter() {
    return DropdownButtonFormField<String?>(
      value: _selectedDepartment,
      decoration: const InputDecoration(
        labelText: 'Department',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('All Departments')),
        ...departments.map((dept) => DropdownMenuItem(
              value: dept,
              child: Text(dept),
            )),
      ],
      onChanged: (value) => setState(() => _selectedDepartment = value),
    );
  }

  Widget _buildIssuedByFilter(List<String> users) {
    return DropdownButtonFormField<String?>(
      value: _selectedIssuedBy,
      decoration: const InputDecoration(
        labelText: 'Issued By',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('All Users')),
        ...users.map((user) => DropdownMenuItem(
              value: user,
              child: Text(user),
            )),
      ],
      onChanged: (value) => setState(() => _selectedIssuedBy = value),
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

  Widget _buildWebTable(List<Issue> issues) {
    final currencyFormat = NumberFormat.currency(symbol: '₹');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Issue No')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Department')),
          DataColumn(label: Text('Issued By')),
          DataColumn(label: Text('Amount')),
          DataColumn(label: Text('Status')),
        ],
        rows: issues.map((issue) {
          return DataRow(
            cells: [
              DataCell(Text(issue.issueNo)),
              DataCell(Text(DateFormat('dd MMM yyyy').format(issue.issueDate))),
              DataCell(Text(issue.department)),
              DataCell(Text(issue.issuedBy)),
              DataCell(Text(currencyFormat.format(issue.totalAmount))),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: issue.status == 'Approved'
                        ? Colors.green[50]
                        : Colors.orange[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    issue.status,
                    style: TextStyle(
                      color: issue.status == 'Approved'
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

  Widget _buildMobileList(List<Issue> issues) {
    final currencyFormat = NumberFormat.currency(symbol: '₹');

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: issues.length,
      itemBuilder: (context, index) {
        final issue = issues[index];

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
                      issue.issueNo,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: issue.status == 'Approved'
                            ? Colors.green[50]
                            : Colors.orange[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        issue.status,
                        style: TextStyle(
                          color: issue.status == 'Approved'
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
                  issue.department,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('dd MMM yyyy').format(issue.issueDate),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      'By: ${issue.issuedBy}',
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
                      currencyFormat.format(issue.totalAmount),
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
