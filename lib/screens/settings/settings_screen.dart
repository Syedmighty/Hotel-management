import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotel_inventory_management/widgets/app_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: isWeb
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.business), text: 'General'),
                  Tab(icon: Icon(Icons.schedule), text: 'Reports'),
                  Tab(icon: Icon(Icons.palette), text: 'Theme'),
                  Tab(icon: Icon(Icons.notifications), text: 'Notifications'),
                  Tab(icon: Icon(Icons.backup), text: 'Backup'),
                ],
              )
            : null,
      ),
      drawer: const AppDrawer(),
      body: isWeb
          ? TabBarView(
              controller: _tabController,
              children: const [
                _GeneralSettingsTab(),
                _ReportSettingsTab(),
                _ThemeSettingsTab(),
                _NotificationSettingsTab(),
                _BackupSettingsTab(),
              ],
            )
          : ListView(
              children: const [
                _GeneralSettingsSection(),
                Divider(),
                _ReportSettingsSection(),
                Divider(),
                _ThemeSettingsSection(),
                Divider(),
                _NotificationSettingsSection(),
                Divider(),
                _BackupSettingsSection(),
              ],
            ),
    );
  }
}

// General Settings Tab
class _GeneralSettingsTab extends StatelessWidget {
  const _GeneralSettingsTab();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: _GeneralSettingsSection(),
    );
  }
}

class _GeneralSettingsSection extends ConsumerStatefulWidget {
  const _GeneralSettingsSection();

  @override
  ConsumerState<_GeneralSettingsSection> createState() =>
      _GeneralSettingsSectionState();
}

class _GeneralSettingsSectionState
    extends ConsumerState<_GeneralSettingsSection> {
  final _formKey = GlobalKey<FormState>();
  final _hotelNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _gstNoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hotelNameController.text = prefs.getString('hotel_name') ?? '';
      _addressController.text = prefs.getString('hotel_address') ?? '';
      _phoneController.text = prefs.getString('hotel_phone') ?? '';
      _emailController.text = prefs.getString('hotel_email') ?? '';
      _gstNoController.text = prefs.getString('hotel_gst') ?? '';
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hotel_name', _hotelNameController.text);
    await prefs.setString('hotel_address', _addressController.text);
    await prefs.setString('hotel_phone', _phoneController.text);
    await prefs.setString('hotel_email', _emailController.text);
    await prefs.setString('hotel_gst', _gstNoController.text);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _hotelNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _gstNoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Company Information',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _hotelNameController,
                decoration: const InputDecoration(
                  labelText: 'Hotel/Restaurant Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter hotel name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _gstNoController,
                decoration: const InputDecoration(
                  labelText: 'GST Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.receipt_long),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Company Information'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Report Settings Tab
class _ReportSettingsTab extends StatelessWidget {
  const _ReportSettingsTab();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: _ReportSettingsSection(),
    );
  }
}

class _ReportSettingsSection extends StatelessWidget {
  const _ReportSettingsSection();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Auto Report Scheduler',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Configure automatic report generation (Coming Soon)',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            _SettingsTile(
              icon: Icons.schedule,
              title: 'Daily Stock Summary',
              subtitle: 'Generate at 9:00 AM daily',
              trailing: Switch(
                value: false,
                onChanged: null, // Disabled for now
              ),
            ),
            const Divider(),
            _SettingsTile(
              icon: Icons.calendar_today,
              title: 'Weekly Purchase Report',
              subtitle: 'Generate every Monday',
              trailing: Switch(
                value: false,
                onChanged: null,
              ),
            ),
            const Divider(),
            _SettingsTile(
              icon: Icons.calendar_month,
              title: 'Monthly Summary',
              subtitle: 'Generate on 1st of each month',
              trailing: Switch(
                value: false,
                onChanged: null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Theme Settings Tab
class _ThemeSettingsTab extends StatelessWidget {
  const _ThemeSettingsTab();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: _ThemeSettingsSection(),
    );
  }
}

class _ThemeSettingsSection extends ConsumerStatefulWidget {
  const _ThemeSettingsSection();

  @override
  ConsumerState<_ThemeSettingsSection> createState() =>
      _ThemeSettingsSectionState();
}

class _ThemeSettingsSectionState extends ConsumerState<_ThemeSettingsSection> {
  String _selectedTheme = 'system';

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedTheme = prefs.getString('theme_mode') ?? 'system';
    });
  }

  Future<void> _saveTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', theme);
    setState(() {
      _selectedTheme = theme;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Theme changed to $theme mode'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appearance',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            RadioListTile<String>(
              title: const Text('Light Mode'),
              subtitle: const Text('Always use light theme'),
              value: 'light',
              groupValue: _selectedTheme,
              onChanged: (value) => _saveTheme(value!),
            ),
            RadioListTile<String>(
              title: const Text('Dark Mode'),
              subtitle: const Text('Always use dark theme'),
              value: 'dark',
              groupValue: _selectedTheme,
              onChanged: (value) => _saveTheme(value!),
            ),
            RadioListTile<String>(
              title: const Text('System Default'),
              subtitle: const Text('Follow system theme'),
              value: 'system',
              groupValue: _selectedTheme,
              onChanged: (value) => _saveTheme(value!),
            ),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Printer Mode',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Thermal Printer Layout'),
              subtitle: const Text('Optimize for 80mm thermal printers'),
              value: false,
              onChanged: (value) {
                // TODO: Implement thermal printer mode
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Notification Settings Tab
class _NotificationSettingsTab extends StatelessWidget {
  const _NotificationSettingsTab();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: _NotificationSettingsSection(),
    );
  }
}

class _NotificationSettingsSection extends ConsumerStatefulWidget {
  const _NotificationSettingsSection();

  @override
  ConsumerState<_NotificationSettingsSection> createState() =>
      _NotificationSettingsSectionState();
}

class _NotificationSettingsSectionState
    extends ConsumerState<_NotificationSettingsSection> {
  bool _lowStockNotifications = true;
  bool _pendingApprovalsNotifications = true;
  bool _dailySummaryNotifications = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lowStockNotifications =
          prefs.getBool('notif_low_stock') ?? true;
      _pendingApprovalsNotifications =
          prefs.getBool('notif_pending_approvals') ?? true;
      _dailySummaryNotifications =
          prefs.getBool('notif_daily_summary') ?? false;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notification Preferences',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Low Stock Alerts'),
              subtitle: const Text('Notify when stock falls below minimum level'),
              value: _lowStockNotifications,
              onChanged: (value) {
                setState(() => _lowStockNotifications = value);
                _saveSetting('notif_low_stock', value);
              },
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Pending Approvals'),
              subtitle: const Text('Notify about pending purchase/issue approvals'),
              value: _pendingApprovalsNotifications,
              onChanged: (value) {
                setState(() => _pendingApprovalsNotifications = value);
                _saveSetting('notif_pending_approvals', value);
              },
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Daily Summary'),
              subtitle: const Text('Receive daily inventory summary at 9:00 AM'),
              value: _dailySummaryNotifications,
              onChanged: (value) {
                setState(() => _dailySummaryNotifications = value);
                _saveSetting('notif_daily_summary', value);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Backup Settings Tab
class _BackupSettingsTab extends StatelessWidget {
  const _BackupSettingsTab();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: _BackupSettingsSection(),
    );
  }
}

class _BackupSettingsSection extends ConsumerStatefulWidget {
  const _BackupSettingsSection();

  @override
  ConsumerState<_BackupSettingsSection> createState() =>
      _BackupSettingsSectionState();
}

class _BackupSettingsSectionState extends ConsumerState<_BackupSettingsSection> {
  bool _autoBackup = true;
  String _backupFrequency = 'daily';
  bool _isBackingUp = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoBackup = prefs.getBool('auto_backup') ?? true;
      _backupFrequency = prefs.getString('backup_frequency') ?? 'daily';
    });
  }

  Future<void> _saveAutoBackup(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_backup', value);
    setState(() => _autoBackup = value);
  }

  Future<void> _saveBackupFrequency(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backup_frequency', value);
    setState(() => _backupFrequency = value);
  }

  Future<void> _performBackupNow() async {
    setState(() => _isBackingUp = true);

    try {
      // This is a placeholder - actual backup will be implemented
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBackingUp = false);
      }
    }
  }

  Future<void> _viewBackups() async {
    final directory = await getApplicationDocumentsDirectory();
    final backupsDir = Directory('${directory.path}/HIMS_Backups');

    if (!await backupsDir.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No backups found')),
        );
      }
      return;
    }

    final backups = backupsDir.listSync();

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Available Backups'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: backups.length,
              itemBuilder: (context, index) {
                final backup = backups[index];
                return ListTile(
                  leading: const Icon(Icons.folder_zip),
                  title: Text(backup.path.split('/').last),
                  subtitle: Text('Size: ${File(backup.path).lengthSync()} bytes'),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Backup Configuration',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Auto Backup'),
              subtitle: const Text('Automatically backup database'),
              value: _autoBackup,
              onChanged: _saveAutoBackup,
            ),
            const Divider(),
            ListTile(
              title: const Text('Backup Frequency'),
              subtitle: Text(_backupFrequency.toUpperCase()),
              trailing: DropdownButton<String>(
                value: _backupFrequency,
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                ],
                onChanged: _autoBackup
                    ? (value) => _saveBackupFrequency(value!)
                    : null,
              ),
            ),
            const Divider(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isBackingUp ? null : _performBackupNow,
                icon: _isBackingUp
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.backup),
                label: Text(_isBackingUp ? 'Backing up...' : 'Backup Now'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _viewBackups,
                icon: const Icon(Icons.folder),
                label: const Text('View Backups'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper Widgets
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing,
    );
  }
}
