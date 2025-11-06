import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/app_database.dart';
import '../db/daos/reports_dao.dart';
import 'database_provider.dart';

// Reports DAO provider
final reportsDaoProvider = Provider<ReportsDao>((ref) {
  final database = ref.watch(databaseProvider);
  return ReportsDao(database);
});

// Dashboard metrics provider
final dashboardMetricsProvider =
    FutureProvider<DashboardMetrics>((ref) async {
  final reportsDao = ref.watch(reportsDaoProvider);
  return await reportsDao.getDashboardMetrics();
});

// Low stock products provider
final lowStockProductsProvider =
    FutureProvider.family<List<Product>, int>((ref, limit) async {
  final reportsDao = ref.watch(reportsDaoProvider);
  return await reportsDao.getLowStockProducts(limit: limit);
});

// Recent transactions provider
final recentTransactionsProvider =
    FutureProvider.family<List<RecentTransaction>, int>((ref, limit) async {
  final reportsDao = ref.watch(reportsDaoProvider);
  return await reportsDao.getRecentTransactions(limit: limit);
});

// Stock value by category provider
final stockValueByCategoryProvider =
    FutureProvider<List<CategoryStockValue>>((ref) async {
  final reportsDao = ref.watch(reportsDaoProvider);
  return await reportsDao.getStockValueByCategory();
});

// Top suppliers provider
final topSuppliersProvider = FutureProvider.family<List<SupplierPurchaseStats>,
    DateRangeFilter>((ref, filter) async {
  final reportsDao = ref.watch(reportsDaoProvider);
  return await reportsDao.getTopSuppliers(
    startDate: filter.startDate,
    endDate: filter.endDate,
    limit: filter.limit ?? 10,
  );
});

// Department consumption provider
final departmentConsumptionProvider = FutureProvider.family<
    List<DepartmentConsumption>, DateRangeFilter>((ref, filter) async {
  final reportsDao = ref.watch(reportsDaoProvider);
  return await reportsDao.getDepartmentConsumption(
    startDate: filter.startDate,
    endDate: filter.endDate,
  );
});

// Wastage analysis provider
final wastageAnalysisProvider =
    FutureProvider.family<List<WastageAnalysis>, DateRangeFilter>(
        (ref, filter) async {
  final reportsDao = ref.watch(reportsDaoProvider);
  return await reportsDao.getWastageAnalysis(
    startDate: filter.startDate,
    endDate: filter.endDate,
  );
});

// Top consumed products provider
final topConsumedProductsProvider = FutureProvider.family<
    List<ProductConsumption>, DateRangeFilter>((ref, filter) async {
  final reportsDao = ref.watch(reportsDaoProvider);
  return await reportsDao.getTopConsumedProducts(
    startDate: filter.startDate,
    endDate: filter.endDate,
    limit: filter.limit ?? 10,
  );
});

// Stock movement report provider
final stockMovementReportProvider = FutureProvider.family<List<StockMovement>,
    StockMovementFilter>((ref, filter) async {
  final reportsDao = ref.watch(reportsDaoProvider);
  return await reportsDao.getStockMovementReport(
    productId: filter.productId,
    startDate: filter.startDate,
    endDate: filter.endDate,
  );
});

// Monthly trend provider
final monthlyTrendProvider =
    FutureProvider.family<List<MonthlyTrend>, int>((ref, months) async {
  final reportsDao = ref.watch(reportsDaoProvider);
  return await reportsDao.getMonthlyTrend(months: months);
});

// Filter models
class DateRangeFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final int? limit;

  DateRangeFilter({
    this.startDate,
    this.endDate,
    this.limit,
  });

  DateRangeFilter copyWith({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) {
    return DateRangeFilter(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      limit: limit ?? this.limit,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DateRangeFilter &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(startDate, endDate, limit);
}

class StockMovementFilter {
  final String? productId;
  final DateTime? startDate;
  final DateTime? endDate;

  StockMovementFilter({
    this.productId,
    this.startDate,
    this.endDate,
  });

  StockMovementFilter copyWith({
    String? productId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return StockMovementFilter(
      productId: productId ?? this.productId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is StockMovementFilter &&
        other.productId == productId &&
        other.startDate == startDate &&
        other.endDate == endDate;
  }

  @override
  int get hashCode => Object.hash(productId, startDate, endDate);
}
