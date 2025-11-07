import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotel_inventory_management/db/app_database.dart';
import 'package:hotel_inventory_management/providers/sync_provider.dart';

/// Screen for viewing and resolving sync conflicts
class ConflictsScreen extends ConsumerWidget {
  const ConflictsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflictsAsync = ref.watch(unresolvedConflictsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Conflicts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(unresolvedConflictsProvider);
            },
          ),
        ],
      ),
      body: conflictsAsync.when(
        data: (conflicts) {
          if (conflicts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text(
                    'No conflicts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('All data is in sync'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: conflicts.length,
            itemBuilder: (context, index) {
              final conflict = conflicts[index];
              return ConflictCard(conflict: conflict);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading conflicts: $error'),
        ),
      ),
    );
  }
}

/// Card widget for displaying a single conflict
class ConflictCard extends ConsumerWidget {
  final ConflictLog conflict;

  const ConflictCard({required this.conflict, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientData = _parseJson(conflict.clientData);
    final serverData = _parseJson(conflict.serverData);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatTableName(conflict.tableName),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Chip(
                  label: const Text('Conflict'),
                  backgroundColor: Colors.orange.shade100,
                  avatar: const Icon(Icons.warning, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Record ID
            Text(
              'Record ID: ${conflict.recordId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),

            // Conflict time
            Text(
              'Detected: ${_formatDate(conflict.conflictDate)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 32),

            // Data comparison
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Device version
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Device',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDataPreview(clientData),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Server version
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Server',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDataPreview(serverData),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _resolveConflict(
                      context,
                      ref,
                      conflict.id,
                      'keep_device',
                    ),
                    icon: const Icon(Icons.phone_android),
                    label: const Text('Keep Mine'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _resolveConflict(
                      context,
                      ref,
                      conflict.id,
                      'use_server',
                    ),
                    icon: const Icon(Icons.cloud),
                    label: const Text('Use Server'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _parseJson(String jsonString) {
    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  Widget _buildDataPreview(Map<String, dynamic> data) {
    if (data.isEmpty) {
      return const Text('No data');
    }

    final displayKeys = data.keys.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: displayKeys.map((key) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            '$key: ${_formatValue(data[key])}',
            style: const TextStyle(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return value;
    if (value is num) return value.toString();
    if (value is bool) return value.toString();
    return value.toString();
  }

  String _formatTableName(String tableName) {
    // Convert snake_case to Title Case
    return tableName
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _resolveConflict(
    BuildContext context,
    WidgetRef ref,
    int conflictId,
    String resolution,
  ) async {
    try {
      final syncDao = ref.read(syncDaoProvider);
      await syncDao.resolveConflict(
        conflictId: conflictId,
        resolution: resolution,
        resolvedBy: 'user', // TODO: Get actual user from auth
      );

      // Refresh the conflicts list
      ref.invalidate(unresolvedConflictsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conflict resolved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resolving conflict: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
