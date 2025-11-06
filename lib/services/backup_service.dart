import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// Service for managing database backups
class BackupService {
  static const int maxBackupsToKeep = 7;
  static const String backupDirName = 'HIMS_Backups';

  /// Get the backups directory
  Future<Directory> _getBackupsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupsDir = Directory('${appDir.path}/$backupDirName');

    if (!await backupsDir.exists()) {
      await backupsDir.create(recursive: true);
    }

    return backupsDir;
  }

  /// Get the database file path
  Future<File> _getDatabaseFile() async {
    final appDir = await getApplicationDocumentsDirectory();
    // Drift typically saves the database as 'db.sqlite'
    return File('${appDir.path}/db.sqlite');
  }

  /// Create a backup of the database
  Future<File> createBackup() async {
    try {
      // Get database file
      final dbFile = await _getDatabaseFile();

      if (!await dbFile.exists()) {
        throw Exception('Database file not found at ${dbFile.path}');
      }

      // Get backups directory
      final backupsDir = await _getBackupsDirectory();

      // Create backup filename with timestamp
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupFileName = 'HIMS_Backup_$timestamp.zip';
      final backupFile = File('${backupsDir.path}/$backupFileName');

      // Create ZIP archive
      final encoder = ZipFileEncoder();
      encoder.create(backupFile.path);

      // Add database file to archive
      await encoder.addFile(dbFile);

      // Add backup metadata
      final metadata = '''
Backup Date: ${DateFormat('dd MMM yyyy HH:mm:ss').format(DateTime.now())}
Database Size: ${await dbFile.length()} bytes
HIMS Version: 1.1.0
''';
      encoder.addArchiveFile(ArchiveFile(
        'backup_info.txt',
        metadata.length,
        metadata.codeUnits,
      ));

      encoder.close();

      // Purge old backups
      await _purgeOldBackups();

      return backupFile;
    } catch (e) {
      throw Exception('Backup failed: $e');
    }
  }

  /// Get all available backups
  Future<List<BackupInfo>> getBackups() async {
    final backupsDir = await _getBackupsDirectory();

    if (!await backupsDir.exists()) {
      return [];
    }

    final backups = <BackupInfo>[];
    final entities = backupsDir.listSync();

    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.zip')) {
        final stat = await entity.stat();
        final fileName = entity.path.split('/').last;

        backups.add(BackupInfo(
          file: entity,
          fileName: fileName,
          size: stat.size,
          createdDate: stat.modified,
        ));
      }
    }

    // Sort by date descending (newest first)
    backups.sort((a, b) => b.createdDate.compareTo(a.createdDate));

    return backups;
  }

  /// Delete old backups, keeping only the most recent ones
  Future<void> _purgeOldBackups() async {
    final backups = await getBackups();

    if (backups.length <= maxBackupsToKeep) {
      return;
    }

    // Delete backups beyond the limit
    final backupsToDelete = backups.skip(maxBackupsToKeep);

    for (final backup in backupsToDelete) {
      try {
        await backup.file.delete();
      } catch (e) {
        // Log error but continue
        print('Failed to delete old backup ${backup.fileName}: $e');
      }
    }
  }

  /// Restore a backup
  Future<void> restoreBackup(File backupFile) async {
    try {
      // Extract ZIP archive
      final bytes = await backupFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find the database file in the archive
      ArchiveFile? dbArchiveFile;
      for (final file in archive) {
        if (file.name.endsWith('.sqlite') || file.name == 'db.sqlite') {
          dbArchiveFile = file;
          break;
        }
      }

      if (dbArchiveFile == null) {
        throw Exception('Database file not found in backup archive');
      }

      // Get current database file
      final dbFile = await _getDatabaseFile();

      // Create backup of current database before restoring
      await createBackup();

      // Write restored data to database file
      final outputStream = OutputFileStream(dbFile.path);
      dbArchiveFile.writeContent(outputStream);
      await outputStream.close();
    } catch (e) {
      throw Exception('Restore failed: $e');
    }
  }

  /// Delete a specific backup
  Future<void> deleteBackup(File backupFile) async {
    try {
      if (await backupFile.exists()) {
        await backupFile.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete backup: $e');
    }
  }

  /// Get total size of all backups
  Future<int> getTotalBackupsSize() async {
    final backups = await getBackups();
    return backups.fold(0, (sum, backup) => sum + backup.size);
  }

  /// Check if auto backup is due
  Future<bool> isAutoBackupDue(String frequency) async {
    final backups = await getBackups();

    if (backups.isEmpty) {
      return true; // No backups exist, backup is due
    }

    final lastBackup = backups.first;
    final now = DateTime.now();
    final daysSinceLastBackup = now.difference(lastBackup.createdDate).inDays;

    switch (frequency) {
      case 'daily':
        return daysSinceLastBackup >= 1;
      case 'weekly':
        return daysSinceLastBackup >= 7;
      case 'monthly':
        return daysSinceLastBackup >= 30;
      default:
        return false;
    }
  }

  /// Perform auto backup if due
  Future<File?> performAutoBackupIfDue(
    bool autoBackupEnabled,
    String frequency,
  ) async {
    if (!autoBackupEnabled) {
      return null;
    }

    final isDue = await isAutoBackupDue(frequency);

    if (isDue) {
      return await createBackup();
    }

    return null;
  }
}

/// Information about a backup file
class BackupInfo {
  final File file;
  final String fileName;
  final int size;
  final DateTime createdDate;

  BackupInfo({
    required this.file,
    required this.fileName,
    required this.size,
    required this.createdDate,
  });

  String get formattedSize {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  String get formattedDate {
    return DateFormat('dd MMM yyyy HH:mm').format(createdDate);
  }
}
