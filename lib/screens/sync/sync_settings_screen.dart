import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotel_inventory_management/providers/sync_provider.dart';
import 'package:hotel_inventory_management/services/sync_service.dart';
import 'package:hotel_inventory_management/main.dart';
import 'package:intl/intl.dart';

/// Comprehensive sync settings and management screen
class SyncSettingsScreen extends ConsumerStatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  ConsumerState<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends ConsumerState<SyncSettingsScreen> {
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    final syncStatusAsync = ref.watch(syncStatusProvider);
    final serverInfoAsync = ref.watch(serverInfoProvider);
    final conflictsCountAsync = ref.watch(unresolvedConflictsCountProvider);
    final queueCountAsync = ref.watch(syncQueueCountProvider);
    final syncService = ref.watch(syncServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
            tooltip: 'About Sync',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(syncStatusProvider);
          ref.invalidate(serverInfoProvider);
          ref.invalidate(unresolvedConflictsCountProvider);
          ref.invalidate(syncQueueCountProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Card
              _buildStatusCard(
                syncStatusAsync.value ?? SyncStatus.idle,
                serverInfoAsync.value,
                syncService,
              ),
              const SizedBox(height: 16),

              // Sync Actions
              _buildSyncActions(context, syncService),
              const SizedBox(height: 16),

              // Statistics Card
              _buildStatisticsCard(
                conflictsCountAsync.value ?? 0,
                queueCountAsync.value ?? 0,
                syncService,
              ),
              const SizedBox(height: 16),

              // Sync Info
              _buildSyncInfo(syncService),
              const SizedBox(height: 16),

              // Advanced Options
              _buildAdvancedOptions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(
    SyncStatus status,
    ServerInfo? serverInfo,
    SyncService syncService,
  ) {
    IconData icon;
    Color color;
    String statusText;
    String description;

    switch (status) {
      case SyncStatus.idle:
        icon = Icons.cloud_off;
        color = Colors.grey;
        statusText = 'Disconnected';
        description = 'Not connected to sync server';
        break;
      case SyncStatus.discovering:
        icon = Icons.search;
        color = Colors.orange;
        statusText = 'Discovering';
        description = 'Searching for sync server on network...';
        break;
      case SyncStatus.connected:
        icon = Icons.cloud_done;
        color = Colors.green;
        statusText = 'Connected';
        description = 'Connected to ${serverInfo?.name ?? "server"}';
        break;
      case SyncStatus.syncing:
        icon = Icons.sync;
        color = Colors.blue;
        statusText = 'Syncing';
        description = 'Synchronizing data...';
        break;
      case SyncStatus.conflict:
        icon = Icons.sync_problem;
        color = Colors.orange;
        statusText = 'Conflicts Detected';
        description = 'Some data needs your attention';
        break;
      case SyncStatus.error:
        icon = Icons.error_outline;
        color = Colors.red;
        statusText = 'Error';
        description = 'Sync encountered an error';
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusText,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (serverInfo != null) ...[
              const Divider(height: 24),
              _buildInfoRow('Server', serverInfo.name),
              _buildInfoRow('IP Address', serverInfo.serverIP),
              _buildInfoRow('Port', serverInfo.port.toString()),
              _buildInfoRow('Version', serverInfo.version),
            ],
            if (syncService.lastSyncTime != null) ...[
              const Divider(height: 24),
              _buildInfoRow(
                'Last Sync',
                _formatLastSync(syncService.lastSyncTime!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSyncActions(BuildContext context, SyncService syncService) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSyncing || !syncService.isConnected
                        ? null
                        : () => _performManualSync(context),
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/sync/conflicts');
                    },
                    icon: const Icon(Icons.sync_problem),
                    label: const Text('View Conflicts'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildStatisticsCard(
    int conflictsCount,
    int queueCount,
    SyncService syncService,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Pending Sync',
                    queueCount.toString(),
                    Icons.pending_actions,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Conflicts',
                    conflictsCount.toString(),
                    Icons.warning_amber,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncInfo(SyncService syncService) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sync Configuration',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Sync Interval', '${SyncService.syncInterval.inMinutes} minutes'),
            _buildInfoRow('Discovery Port', '${SyncService.discoveryPort} (UDP)'),
            _buildInfoRow('Max Records/Sync', '${SyncService.maxRecordsPerSync}'),
            _buildInfoRow('Auto Sync', 'Enabled'),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedOptions(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Sync History'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sync history coming soon')),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.devices),
            title: const Text('Connected Devices'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Device management coming soon')),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: const Text('Sync Diagnostics'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showDiagnostics(context),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  String _formatLastSync(DateTime lastSync) {
    final now = DateTime.now();
    final difference = now.difference(lastSync);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return DateFormat('MMM d, HH:mm').format(lastSync);
    }
  }

  Future<void> _performManualSync(BuildContext context) async {
    setState(() => _isSyncing = true);

    try {
      final database = ref.read(databaseProvider);
      final syncService = ref.read(syncServiceProvider);

      final success = await syncService.syncAll(database);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '✓ Sync completed successfully' : '✗ Sync failed'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );

        // Refresh providers
        ref.invalidate(syncQueueCountProvider);
        ref.invalidate(unresolvedConflictsCountProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Sync error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Multi-Device Sync'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How It Works',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '• The app automatically discovers the sync server on your local network using UDP broadcast\n\n'
                '• Data syncs automatically every 2 minutes when connected\n\n'
                '• You can also trigger manual sync anytime\n\n'
                '• Conflicts are detected when the same data is modified on multiple devices\n\n'
                '• All data is synced via secure HTTP connection',
              ),
              SizedBox(height: 16),
              Text(
                'Requirements',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '• All devices must be on the same WiFi/LAN\n\n'
                '• Sync server must be running on master PC\n\n'
                '• UDP port 9999 and HTTP port 5000 must be open',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showDiagnostics(BuildContext context) {
    final syncService = ref.read(syncServiceProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Diagnostics'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDiagnosticItem('Status', syncService.status.toString()),
              _buildDiagnosticItem('Connected', syncService.isConnected.toString()),
              _buildDiagnosticItem('Discovering', syncService.isDiscovering.toString()),
              _buildDiagnosticItem(
                'Server IP',
                syncService.serverInfo?.serverIP ?? 'N/A',
              ),
              _buildDiagnosticItem(
                'Last Sync',
                syncService.lastSyncTime?.toIso8601String() ?? 'Never',
              ),
            ],
          ),
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

  Widget _buildDiagnosticItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          Flexible(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}
