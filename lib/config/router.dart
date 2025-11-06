import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hotel_inventory_management/providers/auth_provider.dart';
import 'package:hotel_inventory_management/screens/auth/login_screen.dart';
import 'package:hotel_inventory_management/screens/dashboard/dashboard_screen.dart';
import 'package:hotel_inventory_management/screens/products/product_list_screen.dart';
import 'package:hotel_inventory_management/screens/products/product_form_screen.dart';
import 'package:hotel_inventory_management/screens/suppliers/supplier_list_screen.dart';
import 'package:hotel_inventory_management/screens/suppliers/supplier_form_screen.dart';
import 'package:hotel_inventory_management/screens/purchase/purchase_list_screen.dart';
import 'package:hotel_inventory_management/screens/purchase/purchase_form_screen.dart';
import 'package:hotel_inventory_management/screens/issue/issue_list_screen.dart';
import 'package:hotel_inventory_management/screens/issue/issue_form_screen.dart';
import 'package:hotel_inventory_management/screens/wastage/wastage_list_screen.dart';
import 'package:hotel_inventory_management/screens/wastage/wastage_form_screen.dart';
import 'package:hotel_inventory_management/screens/physical_count/physical_count_list_screen.dart';
import 'package:hotel_inventory_management/screens/physical_count/physical_count_form_screen.dart';
import 'package:hotel_inventory_management/screens/stock_transfer/stock_transfer_list_screen.dart';
import 'package:hotel_inventory_management/screens/stock_transfer/stock_transfer_form_screen.dart';
import 'package:hotel_inventory_management/screens/reports/reports_screen.dart';
import 'package:hotel_inventory_management/screens/settings/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoginRoute = state.matchedLocation == '/login';

      // If not authenticated and not on login page, redirect to login
      if (!isAuthenticated && !isLoginRoute) {
        return '/login';
      }

      // If authenticated and on login page, redirect to dashboard
      if (isAuthenticated && isLoginRoute) {
        return '/';
      }

      // No redirect needed
      return null;
    },
    routes: [
      // Auth Routes
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      // Dashboard
      GoRoute(
        path: '/',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),

      // Product Routes
      GoRoute(
        path: '/products',
        name: 'products',
        builder: (context, state) => const ProductListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            name: 'new-product',
            builder: (context, state) => const ProductFormScreen(),
          ),
          GoRoute(
            path: ':id',
            name: 'edit-product',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return ProductFormScreen(productId: id);
            },
          ),
        ],
      ),

      // Supplier Routes
      GoRoute(
        path: '/suppliers',
        name: 'suppliers',
        builder: (context, state) => const SupplierListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            name: 'new-supplier',
            builder: (context, state) => const SupplierFormScreen(),
          ),
          GoRoute(
            path: ':id',
            name: 'edit-supplier',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return SupplierFormScreen(supplierId: id);
            },
          ),
        ],
      ),

      // Purchase Routes
      GoRoute(
        path: '/purchases',
        name: 'purchases',
        builder: (context, state) => const PurchaseListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            name: 'new-purchase',
            builder: (context, state) => const PurchaseFormScreen(),
          ),
          GoRoute(
            path: ':id',
            name: 'edit-purchase',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return PurchaseFormScreen(purchaseId: id);
            },
          ),
        ],
      ),

      // Issue Routes
      GoRoute(
        path: '/issues',
        name: 'issues',
        builder: (context, state) => const IssueListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            name: 'new-issue',
            builder: (context, state) => const IssueFormScreen(),
          ),
          GoRoute(
            path: ':id',
            name: 'edit-issue',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return IssueFormScreen(issueId: id);
            },
          ),
        ],
      ),

      // Wastage Routes
      GoRoute(
        path: '/wastage',
        name: 'wastage',
        builder: (context, state) => const WastageListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            name: 'new-wastage',
            builder: (context, state) => const WastageFormScreen(),
          ),
          GoRoute(
            path: 'edit/:id',
            name: 'edit-wastage',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return WastageFormScreen(wastageId: id);
            },
          ),
        ],
      ),

      // Physical Count Routes
      GoRoute(
        path: '/physical-counts',
        name: 'physical-counts',
        builder: (context, state) => const PhysicalCountListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            name: 'new-physical-count',
            builder: (context, state) => const PhysicalCountFormScreen(),
          ),
          GoRoute(
            path: 'edit/:id',
            name: 'edit-physical-count',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return PhysicalCountFormScreen(countId: id);
            },
          ),
        ],
      ),

      // Stock Transfer Routes
      GoRoute(
        path: '/stock-transfers',
        name: 'stock-transfers',
        builder: (context, state) => const StockTransferListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            name: 'new-stock-transfer',
            builder: (context, state) => const StockTransferFormScreen(),
          ),
          GoRoute(
            path: 'edit/:id',
            name: 'edit-stock-transfer',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return StockTransferFormScreen(transferId: id);
            },
          ),
        ],
      ),

      // Reports
      GoRoute(
        path: '/reports',
        name: 'reports',
        builder: (context, state) => const ReportsScreen(),
      ),

      // Settings
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Text('Page not found: ${state.matchedLocation}'),
      ),
    ),
  );
});
