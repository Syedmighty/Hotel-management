import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/stat_card.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/auth_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final currentUser = ref.watch(currentUserProvider);
    final lowStockProductsAsync = ref.watch(lowStockProductsProvider(5));
    final recentTransactionsAsync = ref.watch(recentTransactionsProvider(5));

    // Determine layout based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 900;
    final isTablet = screenWidth > 600 && screenWidth <= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(dashboardMetricsProvider);
              ref.invalidate(lowStockProductsProvider);
              ref.invalidate(recentTransactionsProvider);
            },
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardMetricsProvider);
          ref.invalidate(lowStockProductsProvider);
          ref.invalidate(recentTransactionsAsync);
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isWeb ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back, ${currentUser?.username ?? "User"}!',
                          style: isWeb
                              ? AppTheme.heading1
                              : AppTheme.heading2,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Here\'s your inventory overview',
                          style: AppTheme.bodyMedium
                              .copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  if (isWeb)
                    Chip(
                      avatar: const Icon(Icons.person, size: 16),
                      label: Text(currentUser?.role ?? 'User'),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Metrics Cards
              metricsAsync.when(
                data: (metrics) => _buildMetricsSection(
                    context, metrics, isWeb, isTablet),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Text('Error loading metrics: $error'),
                ),
              ),

              const SizedBox(height: 32),

              // Two-column layout for web, single column for mobile
              if (isWeb || isTablet)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          _buildLowStockSection(
                              context, ref, lowStockProductsAsync, isWeb),
                          const SizedBox(height: 24),
                          _buildRecentTransactionsSection(context, ref,
                              recentTransactionsAsync, isWeb),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 1,
                      child: _buildQuickActionsSection(context, isWeb),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    _buildLowStockSection(
                        context, ref, lowStockProductsAsync, isWeb),
                    const SizedBox(height: 24),
                    _buildRecentTransactionsSection(
                        context, ref, recentTransactionsAsync, isWeb),
                    const SizedBox(height: 24),
                    _buildQuickActionsSection(context, isWeb),
                  ],
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: screenWidth < 600
          ? FloatingActionButton.extended(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => const _QuickActionSheet(),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Quick Add'),
            )
          : null,
    );
  }

  Widget _buildMetricsSection(BuildContext context, metrics, bool isWeb, bool isTablet) {
    final crossAxisCount = isWeb ? 4 : (isTablet ? 2 : 2);
    final childAspectRatio = isWeb ? 1.8 : (isTablet ? 1.5 : 1.3);
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: isWeb ? 20 : 12,
      mainAxisSpacing: isWeb ? 20 : 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: childAspectRatio,
      children: [
        StatCard(
          title: 'Total Inventory Value',
          value: currencyFormat.format(metrics.totalInventoryValue),
          icon: Icons.account_balance_wallet,
          color: Colors.blue,
          subtitle: '${metrics.totalProductsCount} products',
          onTap: () => context.go('/products'),
        ),
        StatCard(
          title: 'Low Stock Items',
          value: metrics.lowStockItemsCount.toString(),
          icon: Icons.warning,
          color: Colors.orange,
          subtitle: 'Need attention',
          onTap: () => context.go('/reports'),
        ),
        StatCard(
          title: 'Pending Approvals',
          value: (metrics.pendingPurchasesCount +
                  metrics.pendingIssuesCount +
                  metrics.pendingWastagesCount)
              .toString(),
          icon: Icons.pending_actions,
          color: Colors.purple,
          subtitle: 'Awaiting approval',
          onTap: () {},
        ),
        StatCard(
          title: 'Month\'s Purchases',
          value: currencyFormat.format(metrics.thisMonthPurchaseValue),
          icon: Icons.shopping_cart,
          color: Colors.green,
          subtitle: 'This month',
          onTap: () => context.go('/purchases'),
        ),
      ],
    );
  }

  Widget _buildLowStockSection(BuildContext context, WidgetRef ref,
      AsyncValue lowStockProductsAsync, bool isWeb) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isWeb ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Low Stock Alert',
                      style: isWeb ? AppTheme.heading3 : AppTheme.heading3,
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => context.go('/reports'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            lowStockProductsAsync.when(
              data: (products) {
                if (products.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle,
                              size: 48, color: Colors.green[300]),
                          const SizedBox(height: 16),
                          Text(
                            'All stock levels are healthy',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final percentage =
                        (product.currentStock / product.minStockLevel * 100)
                            .toInt();
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange[100],
                        child: Icon(Icons.inventory_2,
                            color: Colors.orange[800]),
                      ),
                      title: Text(product.name),
                      subtitle: Text(
                        'Current: ${product.currentStock} ${product.unit} • Min: ${product.minStockLevel} ${product.unit}',
                      ),
                      trailing: Chip(
                        label: Text('$percentage%'),
                        backgroundColor: percentage < 50
                            ? Colors.red[100]
                            : Colors.orange[100],
                      ),
                      onTap: () => context.push('/products/edit/${product.uuid}'),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Text('Error: $error'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactionsSection(BuildContext context, WidgetRef ref,
      AsyncValue recentTransactionsAsync, bool isWeb) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isWeb ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.history, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Recent Transactions',
                      style: isWeb ? AppTheme.heading3 : AppTheme.heading3,
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => context.go('/reports'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            recentTransactionsAsync.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        'No recent transactions',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transactions.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getTransactionColor(transaction.type)[100],
                        child: Icon(
                          _getTransactionIcon(transaction.type),
                          color: _getTransactionColor(transaction.type)[800],
                        ),
                      ),
                      title: Text(transaction.documentNo),
                      subtitle: Text(
                        '${transaction.type} • ${transaction.reference}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            NumberFormat.currency(symbol: '₹', decimalDigits: 0)
                                .format(transaction.amount),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            DateFormat('MMM dd').format(transaction.date),
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Text('Error: $error'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context, bool isWeb) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isWeb ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flash_on, color: Colors.amber[700]),
                const SizedBox(width: 8),
                Text(
                  'Quick Actions',
                  style: isWeb ? AppTheme.heading3 : AppTheme.heading3,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _QuickActionButton(
              icon: Icons.add_shopping_cart,
              label: 'New Purchase',
              color: Colors.green,
              onTap: () => context.go('/purchases/new'),
            ),
            const SizedBox(height: 12),
            _QuickActionButton(
              icon: Icons.send,
              label: 'New Issue',
              color: Colors.blue,
              onTap: () => context.go('/issues/new'),
            ),
            const SizedBox(height: 12),
            _QuickActionButton(
              icon: Icons.delete_outline,
              label: 'Record Wastage',
              color: Colors.orange,
              onTap: () => context.go('/wastages'),
            ),
            const SizedBox(height: 12),
            _QuickActionButton(
              icon: Icons.assessment,
              label: 'View Reports',
              color: Colors.purple,
              onTap: () => context.go('/reports'),
            ),
          ],
        ),
      ),
    );
  }

  MaterialColor _getTransactionColor(String type) {
    switch (type) {
      case 'Purchase':
        return Colors.green;
      case 'Issue':
        return Colors.blue;
      case 'Wastage':
        return Colors.orange;
      case 'Return':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getTransactionIcon(String type) {
    switch (type) {
      case 'Purchase':
        return Icons.shopping_cart;
      case 'Issue':
        return Icons.send;
      case 'Wastage':
        return Icons.delete_outline;
      case 'Return':
        return Icons.keyboard_return;
      default:
        return Icons.receipt;
    }
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: color[800],
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}

class _QuickActionSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.shopping_cart),
            title: const Text('New Purchase Entry'),
            onTap: () {
              Navigator.pop(context);
              context.go('/purchases/new');
            },
          ),
          ListTile(
            leading: const Icon(Icons.send),
            title: const Text('New Issue Voucher'),
            onTap: () {
              Navigator.pop(context);
              context.go('/issues/new');
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Record Wastage'),
            onTap: () {
              Navigator.pop(context);
              context.go('/wastage');
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory),
            title: const Text('Stock Audit'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to stock audit
            },
          ),
        ],
      ),
    );
  }
}
