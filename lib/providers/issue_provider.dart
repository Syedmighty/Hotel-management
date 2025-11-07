import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/app_database.dart';
import '../db/daos/issue_dao.dart';
import 'database_provider.dart';

// Issue DAO provider
final issueDaoProvider = Provider<IssueDao>((ref) {
  final database = ref.watch(databaseProvider);
  return IssueDao(database);
});

// All issues stream provider
final issuesProvider = StreamProvider<List<IssueVoucher>>((ref) {
  final issueDao = ref.watch(issueDaoProvider);
  return issueDao.watchAllIssues();
});

// Pending issues stream provider
final pendingIssuesProvider = StreamProvider<List<IssueVoucher>>((ref) {
  final issueDao = ref.watch(issueDaoProvider);
  return issueDao.watchPendingIssues();
});

// Search query state provider
final issueSearchQueryProvider = StateProvider<String>((ref) => '');

// Status filter provider
final issueStatusFilterProvider =
    StateProvider<String?>((ref) => null); // null = all, 'Pending', 'Approved'

// Filtered issues provider (combines search and status filter)
final filteredIssuesProvider = StreamProvider<List<IssueVoucher>>((ref) {
  final issuesAsync = ref.watch(issuesProvider);
  final searchQuery = ref.watch(issueSearchQueryProvider);
  final statusFilter = ref.watch(issueStatusFilterProvider);

  return issuesAsync.when(
    data: (issues) async* {
      var filtered = issues;

      // Apply status filter
      if (statusFilter != null) {
        filtered = filtered.where((i) => i.status == statusFilter).toList();
      }

      // Apply search query
      if (searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        filtered = filtered.where((i) {
          return i.issueNo.toLowerCase().contains(lowerQuery) ||
              i.issuedTo.toLowerCase().contains(lowerQuery) ||
              i.requestedBy.toLowerCase().contains(lowerQuery) ||
              i.purpose.toLowerCase().contains(lowerQuery);
        }).toList();
      }

      yield filtered;
    },
    loading: () async* {
      yield [];
    },
    error: (error, stack) async* {
      yield [];
    },
  );
});

// Issue line items stream provider
final issueLineItemsProvider =
    StreamProvider.family<List<IssueLineItem>, String>((ref, issueId) {
  final issueDao = ref.watch(issueDaoProvider);
  return issueDao.watchIssueLineItems(issueId);
});

// Issue notifier for CRUD operations
final issueNotifierProvider =
    StateNotifierProvider<IssueNotifier, AsyncValue<void>>((ref) {
  final issueDao = ref.watch(issueDaoProvider);
  return IssueNotifier(issueDao);
});

class IssueNotifier extends StateNotifier<AsyncValue<void>> {
  final IssueDao _issueDao;

  IssueNotifier(this._issueDao) : super(const AsyncValue.data(null));

  // Create issue with line items
  Future<String?> createIssue({
    required String issueNo,
    required DateTime issueDate,
    required String issuedTo,
    required String requestedBy,
    required String purpose,
    required double totalAmount,
    required List<IssueLineItemsCompanion> lineItems,
    String? remarks,
  }) async {
    state = const AsyncValue.loading();
    try {
      final issueId = await _issueDao.createIssueWithItems(
        issueNo: issueNo,
        issueDate: issueDate,
        issuedTo: issuedTo,
        requestedBy: requestedBy,
        purpose: purpose,
        totalAmount: totalAmount,
        lineItems: lineItems,
        remarks: remarks,
      );
      state = const AsyncValue.data(null);
      return issueId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  // Update issue with line items
  Future<bool> updateIssue({
    required String issueId,
    required String issueNo,
    required DateTime issueDate,
    required String issuedTo,
    required String requestedBy,
    required String purpose,
    required double totalAmount,
    required List<IssueLineItemsCompanion> lineItems,
    String? remarks,
  }) async {
    state = const AsyncValue.loading();
    try {
      final success = await _issueDao.updateIssueWithItems(
        issueId: issueId,
        issueNo: issueNo,
        issueDate: issueDate,
        issuedTo: issuedTo,
        requestedBy: requestedBy,
        purpose: purpose,
        totalAmount: totalAmount,
        lineItems: lineItems,
        remarks: remarks,
      );
      state = const AsyncValue.data(null);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  // Approve issue (deduct stock)
  Future<bool> approveIssue(String issueId) async {
    state = const AsyncValue.loading();
    try {
      await _issueDao.approveIssue(issueId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  // Delete issue
  Future<bool> deleteIssue(String issueId) async {
    state = const AsyncValue.loading();
    try {
      final success = await _issueDao.deleteIssue(issueId);
      state = const AsyncValue.data(null);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  // Get next issue number
  Future<String> getNextIssueNo() async {
    try {
      return await _issueDao.getNextIssueNo();
    } catch (e) {
      return 'ISS-0001';
    }
  }
}
