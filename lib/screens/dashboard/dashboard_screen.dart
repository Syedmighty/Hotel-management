import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hotel_inventory_management/config/theme.dart';
import 'package:hotel_inventory_management/widgets/app_drawer.dart';
import 'package:hotel_inventory_management/widgets/stat_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () {
              // TODO: Implement sync
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sync started...')),
              );
            },
            tooltip: 'Sync Data',
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // TODO: Show notifications
            },
            tooltip: 'Notifications',
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Text(
              'Welcome back!',
              style: AppTheme.heading2,
            ),
            const SizedBox(height: 8),
            Text(
              'Here\'s your inventory overview',
              style: AppTheme.bodyMedium.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            // Stats Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 900
                    ? 4
                    : constraints.maxWidth > 600
                        ? 2
                        : 1;

                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.5,
                  children: [
                    StatCard(
                      title: 'Total Products',
                      value: '0',
                      icon: Icons.inventory_2,
                      color: Colors.blue,
                      onTap: () => context.go('/products'),
                    ),
                    StatCard(
                      title: 'Low Stock Items',
                      value: '0',
                      icon: Icons.warning,
                      color: Colors.orange,
                      onTap: () {},
                    ),
                    StatCard(
                      title: 'Pending Purchases',
                      value: '0',
                      icon: Icons.shopping_cart,
                      color: Colors.green,
                      onTap: () => context.go('/purchases'),
                    ),
                    StatCard(
                      title: 'Pending Issues',
                      value: '0',
                      icon: Icons.assignment,
                      color: Colors.purple,
                      onTap: () => context.go('/issues'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Recent Activities Section
            Text(
              'Recent Activities',
              style: AppTheme.heading3,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.shopping_bag),
                      ),
                      title: const Text('Purchase Entry - INV001'),
                      subtitle: const Text('Received from FreshFoods'),
                      trailing: const Text('2 hours ago'),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.assignment_turned_in),
                      ),
                      title: const Text('Issue Voucher - ISS001'),
                      subtitle: const Text('Issued to Chinese Kitchen'),
                      trailing: const Text('5 hours ago'),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.warning_amber),
                      ),
                      title: const Text('Low Stock Alert'),
                      subtitle: const Text('Chicken Breast below reorder level'),
                      trailing: const Text('1 day ago'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Quick Actions
            Text(
              'Quick Actions',
              style: AppTheme.heading3,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: () => context.go('/purchases/new'),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('New Purchase'),
                ),
                ElevatedButton.icon(
                  onPressed: () => context.go('/issues/new'),
                  icon: const Icon(Icons.send),
                  label: const Text('New Issue'),
                ),
                ElevatedButton.icon(
                  onPressed: () => context.go('/reports'),
                  icon: const Icon(Icons.assessment),
                  label: const Text('View Reports'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement barcode scanner
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan Barcode'),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => _QuickActionSheet(),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Quick Add'),
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
