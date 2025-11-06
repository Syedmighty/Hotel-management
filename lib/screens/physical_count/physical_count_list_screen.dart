import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/physical_count_provider.dart';
import '../../db/app_database.dart';
import '../../widgets/app_drawer.dart';

class PhysicalCountListScreen extends ConsumerStatefulWidget {
  const PhysicalCountListScreen({super.key});

  @override
  ConsumerState<PhysicalCountListScreen> createState() =>
      _PhysicalCountListScreenState();
}

class _PhysicalCountListScreenState
    extends ConsumerState<PhysicalCountListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredCountsAsync = ref.watch(filteredPhysicalCountsProvider);
    final statusFilter = ref.watch(physicalCountStatusFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Audit / Physical Count'),
        actions: [
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
                ref.read(physicalCountStatusFilterProvider.notifier).state =
                    value;
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
                hintText: 'Search by count no or counted by...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(physicalCountSearchQueryProvider.notifier)
                              .state = '';
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                ref.read(physicalCountSearchQueryProvider.notifier).state =
                    value;
              },
            ),
          ),

          // Physical counts list
          Expanded(
            child: filteredCountsAsync.when(
              data: (counts) {
                if (counts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No physical counts found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start a stock audit to verify inventory',
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
                  itemCount: counts.length,
                  itemBuilder: (context, index) {
                    final count = counts[index];
                    return _PhysicalCountCard(
                      count: count,
                      onTap: () {
                        context.push('/physical-counts/edit/${count.uuid}');
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
        onPressed: () {
          context.push('/physical-counts/new');
        },
        icon: const Icon(Icons.add),
        label: const Text('New Count'),
      ),
    );
  }
}

class _PhysicalCountCard extends StatelessWidget {
  final PhysicalCount count;
  final VoidCallback onTap;

  const _PhysicalCountCard({
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

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
                              Icons.inventory,
                              size: 20,
                              color: Colors.blue[700],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                count.countNo,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFormat.format(count.countDate),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(status: count.status),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Counted By: ',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  Expanded(
                    child: Text(
                      count.countedBy,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              if (count.remarks != null && count.remarks!.isNotEmpty) ...[
                const SizedBox(height: 8),
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
                        count.remarks!,
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
