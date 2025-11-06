import 'package:drift/drift.dart';
import '../app_database.dart';

part 'reports_dao.g.dart';

@DriftAccessor(tables: [
  Products,
  Purchases,
  PurchaseLineItems,
  IssueVouchers,
  IssueLineItems,
  WastageReturns,
  WastageLineItems,
  Suppliers,
])
class ReportsDao extends DatabaseAccessor<AppDatabase> with _$ReportsDaoMixin {
  ReportsDao(AppDatabase db) : super(db);

  // Dashboard Metrics
  Future<DashboardMetrics> getDashboardMetrics() async {
    // Total inventory value
    final totalValueQuery = selectOnly(products)
      ..addColumns([
        (products.currentStock * products.purchaseRate).sum(),
      ])
      ..where(products.isActive.equals(true));
    final totalValueResult = await totalValueQuery.getSingle();
    final totalInventoryValue =
        totalValueResult.read((products.currentStock * products.purchaseRate).sum()) ?? 0.0;

    // Low stock items count
    final lowStockCount = await (select(products)
          ..where((p) =>
              p.currentStock.isSmallerThanValue(p.minStockLevel) &
              p.isActive.equals(true)))
        .get()
        .then((list) => list.length);

    // Total products count
    final totalProductsCount = await (select(products)
          ..where((p) => p.isActive.equals(true)))
        .get()
        .then((list) => list.length);

    // Pending purchases count
    final pendingPurchasesCount = await (select(purchases)
          ..where((p) => p.status.equals('Pending')))
        .get()
        .then((list) => list.length);

    // Pending issues count
    final pendingIssuesCount = await (select(issueVouchers)
          ..where((iv) => iv.status.equals('Pending')))
        .get()
        .then((list) => list.length);

    // Pending wastages count
    final pendingWastagesCount = await (select(wastageReturns)
          ..where((wr) => wr.status.equals('Pending')))
        .get()
        .then((list) => list.length);

    // This month's purchase value
    final thisMonthStart =
        DateTime(DateTime.now().year, DateTime.now().month, 1);
    final thisMonthPurchaseQuery = selectOnly(purchases)
      ..addColumns([purchases.totalAmount.sum()])
      ..where(purchases.purchaseDate.isBiggerOrEqualValue(thisMonthStart) &
          purchases.status.equals('Approved'));
    final thisMonthPurchaseResult = await thisMonthPurchaseQuery.getSingle();
    final thisMonthPurchaseValue =
        thisMonthPurchaseResult.read(purchases.totalAmount.sum()) ?? 0.0;

    // This month's issue value
    final thisMonthIssueQuery = selectOnly(issueVouchers)
      ..addColumns([issueVouchers.totalAmount.sum()])
      ..where(issueVouchers.issueDate.isBiggerOrEqualValue(thisMonthStart) &
          issueVouchers.status.equals('Approved'));
    final thisMonthIssueResult = await thisMonthIssueQuery.getSingle();
    final thisMonthIssueValue =
        thisMonthIssueResult.read(issueVouchers.totalAmount.sum()) ?? 0.0;

    // This month's wastage value
    final thisMonthWastageQuery = selectOnly(wastageReturns)
      ..addColumns([wastageReturns.totalAmount.sum()])
      ..where(wastageReturns.wastageDate.isBiggerOrEqualValue(thisMonthStart) &
          wastageReturns.status.equals('Approved') &
          wastageReturns.type.equals('Wastage'));
    final thisMonthWastageResult = await thisMonthWastageQuery.getSingle();
    final thisMonthWastageValue =
        thisMonthWastageResult.read(wastageReturns.totalAmount.sum()) ?? 0.0;

    return DashboardMetrics(
      totalInventoryValue: totalInventoryValue,
      lowStockItemsCount: lowStockCount,
      totalProductsCount: totalProductsCount,
      pendingPurchasesCount: pendingPurchasesCount,
      pendingIssuesCount: pendingIssuesCount,
      pendingWastagesCount: pendingWastagesCount,
      thisMonthPurchaseValue: thisMonthPurchaseValue,
      thisMonthIssueValue: thisMonthIssueValue,
      thisMonthWastageValue: thisMonthWastageValue,
    );
  }

  // Get low stock products
  Future<List<Product>> getLowStockProducts({int limit = 10}) async {
    return await (select(products)
          ..where((p) =>
              p.currentStock.isSmallerThanValue(p.minStockLevel) &
              p.isActive.equals(true))
          ..orderBy([
            (p) => OrderingTerm(
                expression: p.currentStock / p.minStockLevel,
                mode: OrderingMode.asc)
          ])
          ..limit(limit))
        .get();
  }

  // Get recent transactions (purchases, issues, wastages)
  Future<List<RecentTransaction>> getRecentTransactions({int limit = 10}) async {
    final List<RecentTransaction> transactions = [];

    // Get recent purchases
    final recentPurchases = await (select(purchases)
          ..orderBy([(p) => OrderingTerm.desc(p.purchaseDate)])
          ..limit(limit))
        .get();

    for (final purchase in recentPurchases) {
      final supplier = await (select(suppliers)
            ..where((s) => s.uuid.equals(purchase.supplierId)))
          .getSingleOrNull();

      transactions.add(RecentTransaction(
        type: 'Purchase',
        documentNo: purchase.invoiceNo,
        date: purchase.purchaseDate,
        amount: purchase.totalAmount,
        status: purchase.status,
        reference: supplier?.name ?? 'Unknown',
      ));
    }

    // Get recent issues
    final recentIssues = await (select(issueVouchers)
          ..orderBy([(iv) => OrderingTerm.desc(iv.issueDate)])
          ..limit(limit))
        .get();

    for (final issue in recentIssues) {
      transactions.add(RecentTransaction(
        type: 'Issue',
        documentNo: issue.issueNo,
        date: issue.issueDate,
        amount: issue.totalAmount,
        status: issue.status,
        reference: issue.issuedTo,
      ));
    }

    // Get recent wastages
    final recentWastages = await (select(wastageReturns)
          ..orderBy([(wr) => OrderingTerm.desc(wr.wastageDate)])
          ..limit(limit))
        .get();

    for (final wastage in recentWastages) {
      transactions.add(RecentTransaction(
        type: wastage.type,
        documentNo: wastage.wastageNo,
        date: wastage.wastageDate,
        amount: wastage.totalAmount,
        status: wastage.status,
        reference: wastage.type,
      ));
    }

    // Sort all transactions by date
    transactions.sort((a, b) => b.date.compareTo(a.date));

    return transactions.take(limit).toList();
  }

  // Stock value by category
  Future<List<CategoryStockValue>> getStockValueByCategory() async {
    final query = selectOnly(products)
      ..addColumns([
        products.category,
        (products.currentStock * products.purchaseRate).sum(),
        products.currentStock.sum(),
      ])
      ..where(products.isActive.equals(true))
      ..groupBy([products.category])
      ..orderBy([
        OrderingTerm.desc((products.currentStock * products.purchaseRate).sum())
      ]);

    final results = await query.get();
    return results.map((row) {
      return CategoryStockValue(
        category: row.read(products.category)!,
        value: row.read((products.currentStock * products.purchaseRate).sum()) ?? 0.0,
        quantity: row.read(products.currentStock.sum()) ?? 0.0,
      );
    }).toList();
  }

  // Top suppliers by purchase value
  Future<List<SupplierPurchaseStats>> getTopSuppliers({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 10,
  }) async {
    final query = selectOnly(purchases)
      ..join([
        innerJoin(suppliers, suppliers.uuid.equalsExp(purchases.supplierId))
      ])
      ..addColumns([
        suppliers.uuid,
        suppliers.name,
        purchases.totalAmount.sum(),
        purchases.id.count(),
      ])
      ..where(purchases.status.equals('Approved'))
      ..groupBy([suppliers.uuid, suppliers.name])
      ..orderBy([OrderingTerm.desc(purchases.totalAmount.sum())])
      ..limit(limit);

    if (startDate != null) {
      query.where(purchases.purchaseDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where(purchases.purchaseDate.isSmallerOrEqualValue(endDate));
    }

    final results = await query.get();
    return results.map((row) {
      return SupplierPurchaseStats(
        supplierId: row.read(suppliers.uuid)!,
        supplierName: row.read(suppliers.name)!,
        totalPurchaseValue: row.read(purchases.totalAmount.sum()) ?? 0.0,
        purchaseCount: row.read(purchases.id.count()) ?? 0,
      );
    }).toList();
  }

  // Department-wise consumption
  Future<List<DepartmentConsumption>> getDepartmentConsumption({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = selectOnly(issueVouchers)
      ..addColumns([
        issueVouchers.issuedTo,
        issueVouchers.totalAmount.sum(),
        issueVouchers.id.count(),
      ])
      ..where(issueVouchers.status.equals('Approved'))
      ..groupBy([issueVouchers.issuedTo])
      ..orderBy([OrderingTerm.desc(issueVouchers.totalAmount.sum())]);

    if (startDate != null) {
      query.where(issueVouchers.issueDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where(issueVouchers.issueDate.isSmallerOrEqualValue(endDate));
    }

    final results = await query.get();
    return results.map((row) {
      return DepartmentConsumption(
        department: row.read(issueVouchers.issuedTo)!,
        totalValue: row.read(issueVouchers.totalAmount.sum()) ?? 0.0,
        issueCount: row.read(issueVouchers.id.count()) ?? 0,
      );
    }).toList();
  }

  // Wastage analysis
  Future<List<WastageAnalysis>> getWastageAnalysis({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = selectOnly(wastageLineItems)
      ..join([
        innerJoin(wastageReturns,
            wastageReturns.uuid.equalsExp(wastageLineItems.wastageId))
      ])
      ..addColumns([
        wastageLineItems.reason,
        wastageLineItems.quantity.sum(),
        wastageLineItems.id.count(),
      ])
      ..where(wastageReturns.status.equals('Approved') &
          wastageReturns.type.equals('Wastage'))
      ..groupBy([wastageLineItems.reason])
      ..orderBy([OrderingTerm.desc(wastageLineItems.quantity.sum())]);

    if (startDate != null) {
      query.where(wastageReturns.wastageDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where(wastageReturns.wastageDate.isSmallerOrEqualValue(endDate));
    }

    final results = await query.get();
    return results.map((row) {
      return WastageAnalysis(
        reason: row.read(wastageLineItems.reason)!,
        totalQuantity: row.read(wastageLineItems.quantity.sum()) ?? 0.0,
        count: row.read(wastageLineItems.id.count()) ?? 0,
      );
    }).toList();
  }

  // Top consumed products
  Future<List<ProductConsumption>> getTopConsumedProducts({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 10,
  }) async {
    final query = selectOnly(issueLineItems)
      ..join([
        innerJoin(issueVouchers,
            issueVouchers.uuid.equalsExp(issueLineItems.issueId)),
        innerJoin(
            products, products.uuid.equalsExp(issueLineItems.productId))
      ])
      ..addColumns([
        products.uuid,
        products.name,
        products.unit,
        issueLineItems.quantity.sum(),
        (issueLineItems.quantity * issueLineItems.rate).sum(),
      ])
      ..where(issueVouchers.status.equals('Approved'))
      ..groupBy([products.uuid, products.name, products.unit])
      ..orderBy([OrderingTerm.desc(issueLineItems.quantity.sum())])
      ..limit(limit);

    if (startDate != null) {
      query.where(issueVouchers.issueDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where(issueVouchers.issueDate.isSmallerOrEqualValue(endDate));
    }

    final results = await query.get();
    return results.map((row) {
      return ProductConsumption(
        productId: row.read(products.uuid)!,
        productName: row.read(products.name)!,
        unit: row.read(products.unit)!,
        totalQuantity: row.read(issueLineItems.quantity.sum()) ?? 0.0,
        totalValue: row.read((issueLineItems.quantity * issueLineItems.rate).sum()) ?? 0.0,
      );
    }).toList();
  }

  // Stock movement report
  Future<List<StockMovement>> getStockMovementReport({
    String? productId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final List<StockMovement> movements = [];

    // Get purchases
    if (productId != null) {
      final purchaseQuery = select(purchaseLineItems).join([
        innerJoin(purchases,
            purchases.uuid.equalsExp(purchaseLineItems.purchaseId)),
        innerJoin(
            products, products.uuid.equalsExp(purchaseLineItems.productId))
      ])
        ..where(purchaseLineItems.productId.equals(productId) &
            purchases.status.equals('Approved'))
        ..orderBy([OrderingTerm.desc(purchases.purchaseDate)]);

      if (startDate != null) {
        purchaseQuery.where(purchases.purchaseDate.isBiggerOrEqualValue(startDate));
      }
      if (endDate != null) {
        purchaseQuery.where(purchases.purchaseDate.isSmallerOrEqualValue(endDate));
      }

      final purchaseResults = await purchaseQuery.get();
      for (final row in purchaseResults) {
        final purchase = row.readTable(purchases);
        final lineItem = row.readTable(purchaseLineItems);
        final product = row.readTable(products);

        movements.add(StockMovement(
          date: purchase.purchaseDate,
          type: 'Purchase',
          documentNo: purchase.invoiceNo,
          productName: product.name,
          quantity: lineItem.quantity,
          rate: lineItem.rate,
          reference: 'Supplier',
        ));
      }
    }

    // Get issues
    if (productId != null) {
      final issueQuery = select(issueLineItems).join([
        innerJoin(
            issueVouchers, issueVouchers.uuid.equalsExp(issueLineItems.issueId)),
        innerJoin(products, products.uuid.equalsExp(issueLineItems.productId))
      ])
        ..where(issueLineItems.productId.equals(productId) &
            issueVouchers.status.equals('Approved'))
        ..orderBy([OrderingTerm.desc(issueVouchers.issueDate)]);

      if (startDate != null) {
        issueQuery.where(issueVouchers.issueDate.isBiggerOrEqualValue(startDate));
      }
      if (endDate != null) {
        issueQuery.where(issueVouchers.issueDate.isSmallerOrEqualValue(endDate));
      }

      final issueResults = await issueQuery.get();
      for (final row in issueResults) {
        final issue = row.readTable(issueVouchers);
        final lineItem = row.readTable(issueLineItems);
        final product = row.readTable(products);

        movements.add(StockMovement(
          date: issue.issueDate,
          type: 'Issue',
          documentNo: issue.issueNo,
          productName: product.name,
          quantity: -lineItem.quantity, // Negative for outward
          rate: lineItem.rate,
          reference: issue.issuedTo,
        ));
      }
    }

    // Get wastages
    if (productId != null) {
      final wastageQuery = select(wastageLineItems).join([
        innerJoin(wastageReturns,
            wastageReturns.uuid.equalsExp(wastageLineItems.wastageId)),
        innerJoin(
            products, products.uuid.equalsExp(wastageLineItems.productId))
      ])
        ..where(wastageLineItems.productId.equals(productId) &
            wastageReturns.status.equals('Approved'))
        ..orderBy([OrderingTerm.desc(wastageReturns.wastageDate)]);

      if (startDate != null) {
        wastageQuery
            .where(wastageReturns.wastageDate.isBiggerOrEqualValue(startDate));
      }
      if (endDate != null) {
        wastageQuery
            .where(wastageReturns.wastageDate.isSmallerOrEqualValue(endDate));
      }

      final wastageResults = await wastageQuery.get();
      for (final row in wastageResults) {
        final wastage = row.readTable(wastageReturns);
        final lineItem = row.readTable(wastageLineItems);
        final product = row.readTable(products);

        movements.add(StockMovement(
          date: wastage.wastageDate,
          type: wastage.type,
          documentNo: wastage.wastageNo,
          productName: product.name,
          quantity: -lineItem.quantity, // Negative for outward
          rate: lineItem.rate,
          reference: lineItem.reason,
        ));
      }
    }

    // Sort all movements by date
    movements.sort((a, b) => b.date.compareTo(a.date));

    return movements;
  }

  // Monthly trend data
  Future<List<MonthlyTrend>> getMonthlyTrend({
    required int months,
  }) async {
    final List<MonthlyTrend> trends = [];
    final now = DateTime.now();

    for (int i = 0; i < months; i++) {
      final monthStart = DateTime(now.year, now.month - i, 1);
      final monthEnd = DateTime(now.year, now.month - i + 1, 0);

      // Purchases
      final purchaseQuery = selectOnly(purchases)
        ..addColumns([purchases.totalAmount.sum()])
        ..where(purchases.purchaseDate.isBiggerOrEqualValue(monthStart) &
            purchases.purchaseDate.isSmallerOrEqualValue(monthEnd) &
            purchases.status.equals('Approved'));
      final purchaseResult = await purchaseQuery.getSingle();
      final purchaseValue =
          purchaseResult.read(purchases.totalAmount.sum()) ?? 0.0;

      // Issues
      final issueQuery = selectOnly(issueVouchers)
        ..addColumns([issueVouchers.totalAmount.sum()])
        ..where(issueVouchers.issueDate.isBiggerOrEqualValue(monthStart) &
            issueVouchers.issueDate.isSmallerOrEqualValue(monthEnd) &
            issueVouchers.status.equals('Approved'));
      final issueResult = await issueQuery.getSingle();
      final issueValue =
          issueResult.read(issueVouchers.totalAmount.sum()) ?? 0.0;

      // Wastages
      final wastageQuery = selectOnly(wastageReturns)
        ..addColumns([wastageReturns.totalAmount.sum()])
        ..where(wastageReturns.wastageDate.isBiggerOrEqualValue(monthStart) &
            wastageReturns.wastageDate.isSmallerOrEqualValue(monthEnd) &
            wastageReturns.status.equals('Approved') &
            wastageReturns.type.equals('Wastage'));
      final wastageResult = await wastageQuery.getSingle();
      final wastageValue =
          wastageResult.read(wastageReturns.totalAmount.sum()) ?? 0.0;

      trends.add(MonthlyTrend(
        month: monthStart,
        purchaseValue: purchaseValue,
        issueValue: issueValue,
        wastageValue: wastageValue,
      ));
    }

    return trends.reversed.toList();
  }
}

// Data models for reports
class DashboardMetrics {
  final double totalInventoryValue;
  final int lowStockItemsCount;
  final int totalProductsCount;
  final int pendingPurchasesCount;
  final int pendingIssuesCount;
  final int pendingWastagesCount;
  final double thisMonthPurchaseValue;
  final double thisMonthIssueValue;
  final double thisMonthWastageValue;

  DashboardMetrics({
    required this.totalInventoryValue,
    required this.lowStockItemsCount,
    required this.totalProductsCount,
    required this.pendingPurchasesCount,
    required this.pendingIssuesCount,
    required this.pendingWastagesCount,
    required this.thisMonthPurchaseValue,
    required this.thisMonthIssueValue,
    required this.thisMonthWastageValue,
  });
}

class RecentTransaction {
  final String type;
  final String documentNo;
  final DateTime date;
  final double amount;
  final String status;
  final String reference;

  RecentTransaction({
    required this.type,
    required this.documentNo,
    required this.date,
    required this.amount,
    required this.status,
    required this.reference,
  });
}

class CategoryStockValue {
  final String category;
  final double value;
  final double quantity;

  CategoryStockValue({
    required this.category,
    required this.value,
    required this.quantity,
  });
}

class SupplierPurchaseStats {
  final String supplierId;
  final String supplierName;
  final double totalPurchaseValue;
  final int purchaseCount;

  SupplierPurchaseStats({
    required this.supplierId,
    required this.supplierName,
    required this.totalPurchaseValue,
    required this.purchaseCount,
  });
}

class DepartmentConsumption {
  final String department;
  final double totalValue;
  final int issueCount;

  DepartmentConsumption({
    required this.department,
    required this.totalValue,
    required this.issueCount,
  });
}

class WastageAnalysis {
  final String reason;
  final double totalQuantity;
  final int count;

  WastageAnalysis({
    required this.reason,
    required this.totalQuantity,
    required this.count,
  });
}

class ProductConsumption {
  final String productId;
  final String productName;
  final String unit;
  final double totalQuantity;
  final double totalValue;

  ProductConsumption({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.totalQuantity,
    required this.totalValue,
  });
}

class StockMovement {
  final DateTime date;
  final String type;
  final String documentNo;
  final String productName;
  final double quantity;
  final double rate;
  final String reference;

  StockMovement({
    required this.date,
    required this.type,
    required this.documentNo,
    required this.productName,
    required this.quantity,
    required this.rate,
    required this.reference,
  });
}

class MonthlyTrend {
  final DateTime month;
  final double purchaseValue;
  final double issueValue;
  final double wastageValue;

  MonthlyTrend({
    required this.month,
    required this.purchaseValue,
    required this.issueValue,
    required this.wastageValue,
  });
}
