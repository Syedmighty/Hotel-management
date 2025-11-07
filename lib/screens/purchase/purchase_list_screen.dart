import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hotel_inventory_management/config/theme.dart';
import 'package:hotel_inventory_management/providers/purchase_provider.dart';
import 'package:hotel_inventory_management/providers/supplier_provider.dart';
import 'package:hotel_inventory_management/widgets/app_drawer.dart';
import 'package:intl/intl.dart';

class PurchaseListScreen extends ConsumerStatefulWidget {
  const PurchaseListScreen({super.key});

  @override
  ConsumerState<PurchaseListScreen> createState() => _PurchaseListScreenState();
}

class _PurchaseListScreenState extends ConsumerState<PurchaseListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final purchasesAsync = ref.watch(filteredPurchasesProvider);
    final searchQuery = ref.watch(purchaseSearchQueryProvider);
    final selectedStatus = ref.watch(selectedPurchaseStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchases (GRN)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(),
            tooltip: 'Filter',
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by invoice or supplier...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(purchaseSearchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                ref.read(purchaseSearchQueryProvider.notifier).state = value;
              },
            ),
          ),

          // Status Filter Chip
          if (selectedStatus != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Chip(
                    label: Text('Status: $selectedStatus'),
                    onDeleted: () {
                      ref.read(selectedPurchaseStatusProvider.notifier).state = null;
                    },
                  ),
                ],
              ),
            ),

          // Purchases List
          Expanded(
            child: purchasesAsync.when(
              data: (purchases) {
                if (purchases.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: purchases.length,
                  itemBuilder: (context, index) {
                    final purchase = purchases[index];
                    return _PurchaseCard(
                      purchase: purchase,
                      onTap: () => context.go('/purchases/${purchase.uuid}'),
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
        onPressed: () => context.go('/purchases/new'),
        icon: const Icon(Icons.add),
        label: const Text('New Purchase'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No purchases yet',
            style: AppTheme.heading3.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first purchase entry',
            style: AppTheme.bodyMedium.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/purchases/new'),
            icon: const Icon(Icons.add),
            label: const Text('Create Purchase Entry'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Status'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('All Purchases'),
                onTap: () {
                  ref.read(selectedPurchaseStatusProvider.notifier).state = null;
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.pending, color: AppTheme.warningColor),
                title: const Text('Pending'),
                onTap: () {
                  ref.read(selectedPurchaseStatusProvider.notifier).state = 'Pending';
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.check_circle, color: AppTheme.successColor),
                title: const Text('Approved'),
                onTap: () {
                  ref.read(selectedPurchaseStatusProvider.notifier).state = 'Approved';
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurchaseCard extends ConsumerWidget {
  final dynamic purchase;
  final VoidCallback onTap;

  const _PurchaseCard({
    required this.purchase,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormat = NumberFormat.currency(symbol: '₹');
    final dateFormat = DateFormat('dd MMM yyyy');
    final isPending = purchase.status == 'Pending';

    // Get supplier name
    final supplierAsync = ref.watch(supplierByIdProvider(purchase.supplierId));

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
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Invoice: ${purchase.invoiceNo}',
                              style: AppTheme.heading3,
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isPending
                                    ? AppTheme.warningColor.withOpacity(0.1)
                                    : AppTheme.successColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                purchase.status,
                                style: AppTheme.caption.copyWith(
                                  color: isPending
                                      ? AppTheme.warningColor
                                      : AppTheme.successColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        supplierAsync.when(
                          data: (supplier) => Text(
                            supplier?.name ?? 'Unknown Supplier',
                            style: AppTheme.bodyMedium.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          loading: () => const Text('Loading...'),
                          error: (_, __) => const Text('Unknown Supplier'),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    currencyFormat.format(purchase.totalAmount),
                    style: AppTheme.heading3.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _InfoItem(
                    icon: Icons.calendar_today,
                    label: dateFormat.format(purchase.purchaseDate),
                  ),
                  _InfoItem(
                    icon: Icons.payment,
                    label: purchase.paymentMode,
                  ),
                  _InfoItem(
                    icon: Icons.person,
                    label: purchase.receivedBy,
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

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoItem({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTheme.bodyMedium.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }
}
