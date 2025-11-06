import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hotel_inventory_management/screens/auth/login_screen.dart';
import 'package:hotel_inventory_management/screens/dashboard/dashboard_screen.dart';
import 'package:hotel_inventory_management/screens/purchase/purchase_list_screen.dart';
import 'package:hotel_inventory_management/screens/purchase/purchase_form_screen.dart';
import 'package:hotel_inventory_management/screens/issue/issue_list_screen.dart';
import 'package:hotel_inventory_management/screens/issue/issue_form_screen.dart';
import 'package:hotel_inventory_management/screens/wastage/wastage_list_screen.dart';
import 'package:hotel_inventory_management/screens/reports/reports_screen.dart';
import 'package:hotel_inventory_management/screens/settings/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
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
