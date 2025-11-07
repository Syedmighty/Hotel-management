import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotel_inventory_management/providers/sync_provider.dart';
import 'package:hotel_inventory_management/services/sync_service.dart';

/// Widget that displays the current sync status in the AppBar
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatusAsync = ref.watch(syncStatusProvider);
    final serverInfoAsync = ref.watch(serverInfoProvider);

    return syncStatusAsync.when(
      data: (status) {
        return _buildStatusIcon(context, status, serverInfoAsync.value);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const Icon(Icons.sync_problem, color: Colors.red),
    );
  }

  Widget _buildStatusIcon(BuildContext context, SyncStatus status, ServerInfo? serverInfo) {
    IconData icon;
    Color color;
    String tooltip;

    switch (status) {
      case SyncStatus.idle:
        icon = Icons.cloud_off;
        color = Colors.grey;
        tooltip = 'Not connected to server';
        break;
      case SyncStatus.discovering:
        icon = Icons.cloud_sync;
        color = Colors.orange;
        tooltip = 'Searching for server...';
        break;
      case SyncStatus.connected:
        icon = Icons.cloud_done;
        color = Colors.green;
        tooltip = 'Connected to ${serverInfo?.name ?? "server"}';
        break;
      case SyncStatus.syncing:
        icon = Icons.sync;
        color = Colors.blue;
        tooltip = 'Syncing...';
        break;
      case SyncStatus.conflict:
        icon = Icons.sync_problem;
        color = Colors.orange;
        tooltip = 'Sync conflicts detected';
        break;
      case SyncStatus.error:
        icon = Icons.cloud_off;
        color = Colors.red;
        tooltip = 'Sync error';
        break;
    }

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          // Show sync details dialog
          _showSyncDetailsDialog(context, status, serverInfo);
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: status == SyncStatus.syncing
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              : Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }

  void _showSyncDetailsDialog(BuildContext context, SyncStatus status, ServerInfo? serverInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Status', _getStatusText(status)),
            const SizedBox(height: 8),
            if (serverInfo != null) ...[
              _buildInfoRow('Server', serverInfo.name),
              _buildInfoRow('IP', serverInfo.serverIP),
              _buildInfoRow('Port', serverInfo.port.toString()),
            ] else
              _buildInfoRow('Server', 'Not connected'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }

  String _getStatusText(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return 'Idle';
      case SyncStatus.discovering:
        return 'Discovering';
      case SyncStatus.connected:
        return 'Connected';
      case SyncStatus.syncing:
        return 'Syncing';
      case SyncStatus.conflict:
        return 'Conflict';
      case SyncStatus.error:
        return 'Error';
    }
  }
}

/// Floating action button for manual sync
class SyncFloatingActionButton extends ConsumerWidget {
  const SyncFloatingActionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncService = ref.watch(syncServiceProvider);

    return FloatingActionButton(
      onPressed: () async {
        if (!syncService.isConnected) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Not connected to server'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Trigger manual sync
        final database = ref.read(databaseProvider);
        final success = await syncService.syncAll(database);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? 'Sync completed successfully' : 'Sync failed'),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );
        }
      },
      tooltip: 'Sync Now',
      child: const Icon(Icons.sync),
    );
  }
}
