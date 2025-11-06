import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotel_inventory_management/widgets/app_drawer.dart';
import 'package:hotel_inventory_management/screens/reports/views/stock_summary_report.dart';
import 'package:hotel_inventory_management/screens/reports/views/purchase_report.dart';
import 'package:hotel_inventory_management/screens/reports/views/issue_report.dart';
import 'package:hotel_inventory_management/screens/reports/views/wastage_report.dart';
import 'package:hotel_inventory_management/screens/reports/views/recipe_costing_report.dart';
import 'package:hotel_inventory_management/screens/reports/views/supplier_ledger_report.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      drawer: const AppDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ReportCard(
            title: 'Stock Summary Report',
            description: 'Current stock levels and valuations',
            icon: Icons.inventory,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StockSummaryReport(),
                ),
              );
            },
          ),
          _ReportCard(
            title: 'Purchase Report',
            description: 'All purchase transactions',
            icon: Icons.shopping_cart,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PurchaseReport(),
                ),
              );
            },
          ),
          _ReportCard(
            title: 'Issue Report',
            description: 'All issue vouchers',
            icon: Icons.send,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const IssueReport(),
                ),
              );
            },
          ),
          _ReportCard(
            title: 'Wastage Report',
            description: 'Wastage and returns summary',
            icon: Icons.delete,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WastageReport(),
                ),
              );
            },
          ),
          _ReportCard(
            title: 'Recipe Costing Report',
            description: 'Menu item costs and margins',
            icon: Icons.restaurant_menu,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RecipeCostingReport(),
                ),
              );
            },
          ),
          _ReportCard(
            title: 'Supplier Ledger',
            description: 'Supplier-wise purchase history',
            icon: Icons.business,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SupplierLedgerReport(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _ReportCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(icon),
        ),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
