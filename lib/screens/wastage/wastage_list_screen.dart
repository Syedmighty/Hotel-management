import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/wastage_provider.dart';
import '../../db/app_database.dart';
import '../../widgets/app_drawer.dart';

class WastageListScreen extends ConsumerStatefulWidget {
  const WastageListScreen({super.key});

  @override
  ConsumerState<WastageListScreen> createState() => _WastageListScreenState();
}

class _WastageListScreenState extends ConsumerState<WastageListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.orange),
              title: const Text('Record Wastage'),
              subtitle: const Text('Spoilage, breakage, expiry, etc.'),
              onTap: () {
                Navigator.pop(context);
                context.push('/wastages/new?type=Wastage');
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.keyboard_return, color: Colors.blue),
              title: const Text('Return to Supplier'),
              subtitle: const Text('Defective or incorrect items'),
              onTap: () {
                Navigator.pop(context);
                context.push('/wastages/new?type=Return');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredWastagesAsync = ref.watch(filteredWastagesProvider);
    final typeFilter = ref.watch(wastageTypeFilterProvider);
    final statusFilter = ref.watch(wastageStatusFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wastage & Returns'),
        actions: [
          // Type filter dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButton<String?>(
              value: typeFilter,
              underline: const SizedBox(),
              icon: const Icon(Icons.category),
              items: const [
                DropdownMenuItem(value: null, child: Text('All Types')),
                DropdownMenuItem(value: 'Wastage', child: Text('Wastage')),
                DropdownMenuItem(value: 'Return', child: Text('Return')),
              ],
              onChanged: (value) {
                ref.read(wastageTypeFilterProvider.notifier).state = value;
              },
            ),
          ),
          // Status filter dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButton<String?>(
              value: statusFilter,
              underline: const SizedBox(),
              icon: const Icon(Icons.filter_list),
              items: const [
                DropdownMenuItem(value: null, child: Text('All Status')),
                DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                DropdownMenuItem(value: 'Approved', child: Text('Approved')),
              ],
              onChanged: (value) {
                ref.read(wastageStatusFilterProvider.notifier).state = value;
              },
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by wastage/return number...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(wastageSearchQueryProvider.notifier).state =
                              '';
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                ref.read(wastageSearchQueryProvider.notifier).state = value;
              },
            ),
          ),

          // Wastage list
          Expanded(
            child: filteredWastagesAsync.when(
              data: (wastages) {
                if (wastages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No wastage/return records found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Record wastage or returns',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: wastages.length,
                  itemBuilder: (context, index) {
                    final wastage = wastages[index];
                    return _WastageCard(
                      wastage: wastage,
                      onTap: () {
                        context.push('/wastages/edit/${wastage.uuid}');
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Error: $error'),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Record'),
      ),
    );
  }
}

class _WastageCard extends StatelessWidget {
  final WastageReturn wastage;
  final VoidCallback onTap;

  const _WastageCard({
    required this.wastage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final currencyFormat = NumberFormat.currency(symbol: '₹');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              wastage.type == 'Wastage'
                                  ? Icons.delete_outline
                                  : Icons.keyboard_return,
                              size: 20,
                              color: wastage.type == 'Wastage'
                                  ? Colors.orange
                                  : Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              wastage.wastageNo,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFormat.format(wastage.wastageDate),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _StatusBadge(status: wastage.status),
                      const SizedBox(height: 4),
                      _TypeBadge(type: wastage.type),
                    ],
                  ),
                ],
              ),
              if (wastage.remarks != null && wastage.remarks!.isNotEmpty) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Icon(
                      Icons.note,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        wastage.remarks!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Amount',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    currencyFormat.format(wastage.totalAmount),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: wastage.type == 'Wastage'
                          ? Colors.red
                          : Colors.blue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    Color textColor;

    switch (status) {
      case 'Approved':
        badgeColor = Colors.green[100]!;
        textColor = Colors.green[800]!;
        break;
      case 'Pending':
        badgeColor = Colors.orange[100]!;
        textColor = Colors.orange[800]!;
        break;
      default:
        badgeColor = Colors.grey[200]!;
        textColor = Colors.grey[800]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    Color textColor;
    IconData icon;

    switch (type) {
      case 'Wastage':
        badgeColor = Colors.orange[50]!;
        textColor = Colors.orange[800]!;
        icon = Icons.delete_outline;
        break;
      case 'Return':
        badgeColor = Colors.blue[50]!;
        textColor = Colors.blue[800]!;
        icon = Icons.keyboard_return;
        break;
      default:
        badgeColor = Colors.grey[100]!;
        textColor = Colors.grey[800]!;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            type,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
