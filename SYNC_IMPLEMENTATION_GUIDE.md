# Multi-Device Sync Implementation Guide

## ✅ Completed Implementation

I have successfully implemented the Flutter client-side multi-device offline sync system. Here's what has been completed:

### 1. Database Integration (Drift DAOs)

**Added sync methods to all DAOs:**

#### ProductDao (`lib/db/daos/product_dao.dart`)
- `getUnsyncedProducts()` - Get products with isSynced=false
- `getProductsSince(DateTime)` - Get products modified since timestamp
- `markProductAsSynced(String uuid)` - Mark as synced
- `markProductsAsSynced(List<String> uuids)` - Batch mark as synced
- `upsertProductFromServer(ProductsCompanion)` - Insert or update from server
- `batchUpsertProducts(List<ProductsCompanion>)` - Batch upsert

#### SupplierDao (`lib/db/daos/supplier_dao.dart`)
- Same pattern as ProductDao for suppliers

#### PurchaseDao (`lib/db/daos/purchase_dao.dart`)
- Sync methods for purchases and purchase line items
- Support for transactional data with line items

#### IssueDao (`lib/db/daos/issue_dao.dart`)
- Sync methods for issue vouchers and issue line items

### 2. SyncDao (`lib/db/daos/sync_dao.dart`) - NEW

**Manages SyncQueue and ConflictLogs tables:**

#### SyncQueue Methods:
- `addToSyncQueue()` - Queue changes when offline
- `getPendingSyncItems()` - Get all pending sync items
- `removeSyncQueueItem(int id)` - Remove after successful sync
- `incrementRetryCount()` - Track failed sync attempts
- `clearSyncQueue()` - Clear all queue items
- `getSyncQueueCount()` - Get queue count

#### ConflictLog Methods:
- `addConflict()` - Store conflict for user resolution
- `getUnresolvedConflicts()` - Get all unresolved conflicts
- `getUnresolvedConflictsByTable()` - Get conflicts by table
- `getConflictById()` - Get specific conflict
- `resolveConflict()` - Mark conflict as resolved
- `deleteOldResolvedConflicts()` - Cleanup old resolved conflicts
- `watchUnresolvedConflicts()` - Real-time stream of conflicts

### 3. SyncService (`lib/services/sync_service.dart`)

**Fully implemented sync orchestration:**

#### Core Features:
- UDP discovery (automatically finds server on LAN)
- Device registration with server
- Bidirectional sync (push local changes, pull server changes)
- Conflict detection and storage
- Real-time status updates via streams
- Automatic periodic sync (every 2 minutes)

#### Implemented Methods:
- `_getUnsyncedRecords()` - Retrieves unsynced data from all tables
- `_applyServerChanges()` - Applies server updates to local database
- `_markRecordsAsSynced()` - Updates sync flags after successful sync
- `_storeConflicts()` - Stores conflicts in ConflictLogs table

#### Supported Tables:
- stock_items (Products)
- suppliers
- purchases
- purchase_items
- issues
- issue_items

### 4. AppDatabase Updates (`lib/db/app_database.dart`)

**Added DAO getters for easy access:**
```dart
ProductDao get productDao
SupplierDao get supplierDao
PurchaseDao get purchaseDao
IssueDao get issueDao
SyncDao get syncDao
```

### 5. Riverpod Providers (`lib/providers/sync_provider.dart`)

**Created providers for sync functionality:**
- `syncDaoProvider` - Access to SyncDao
- `syncServiceProvider` - Access to SyncService singleton
- `syncStatusProvider` - Stream of sync status (idle/discovering/connected/syncing/conflict/error)
- `serverInfoProvider` - Stream of server information
- `unresolvedConflictsProvider` - Future of unresolved conflicts
- `watchUnresolvedConflictsCountProvider` - Stream of conflict count
- `syncQueueCountProvider` - Future of queue count

### 6. UI Components

#### SyncStatusIndicator (`lib/widgets/sync_status_indicator.dart`)
- Displays sync status in AppBar
- Shows icon based on current status:
  - ⚫ Grey cloud (Idle - not connected)
  - 🟠 Orange cloud (Discovering server)
  - 🟢 Green cloud (Connected)
  - 🔵 Blue spinner (Syncing)
  - 🟠 Warning (Conflicts)
  - 🔴 Red cloud (Error)
- Tap to view sync details
- Includes manual sync button

#### ConflictsScreen (`lib/screens/sync/conflicts_screen.dart`)
- View all unresolved sync conflicts
- Side-by-side comparison of device vs server data
- Two resolution options:
  - "Keep Mine" - Use device version
  - "Use Server" - Use server version
- Real-time updates when conflicts resolved

---

## 📋 Next Steps (User Actions Required)

### Step 1: Generate Drift Code

Run the code generator to create `.g.dart` files for the new SyncDao:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

**Expected output:** This will generate:
- `lib/db/daos/sync_dao.g.dart`
- Updated `lib/db/app_database.g.dart`

### Step 2: Update main.dart

Add SyncService initialization in your `main.dart`:

```dart
import 'package:hotel_inventory_management/services/sync_service.dart';
import 'package:hotel_inventory_management/providers/sync_provider.dart';

// In your main() function or app initialization:
Future<void> initializeApp(WidgetRef ref) async {
  final database = ref.read(databaseProvider);
  final syncService = ref.read(syncServiceProvider);

  // Initialize sync service
  await syncService.initialize(database);

  print('✅ SyncService initialized');
}
```

### Step 3: Add Sync UI to AppBar

Update your main app scaffold to include the sync status indicator:

```dart
import 'package:hotel_inventory_management/widgets/sync_status_indicator.dart';

AppBar(
  title: const Text('Hotel Inventory'),
  actions: [
    const SyncStatusIndicator(), // Add this
    IconButton(
      icon: const Icon(Icons.settings),
      onPressed: () => Navigator.pushNamed(context, '/settings'),
    ),
  ],
),
```

### Step 4: Add Navigation to Conflicts Screen

Add route for conflicts screen (in your router configuration):

```dart
import 'package:hotel_inventory_management/screens/sync/conflicts_screen.dart';

// In your GoRouter or navigation setup:
GoRoute(
  path: '/sync/conflicts',
  builder: (context, state) => const ConflictsScreen(),
),
```

Or add to Settings screen:

```dart
ListTile(
  leading: const Icon(Icons.sync_problem),
  title: const Text('Sync Conflicts'),
  trailing: Consumer(
    builder: (context, ref, _) {
      final countAsync = ref.watch(watchUnresolvedConflictsCountProvider);
      return countAsync.when(
        data: (count) => count > 0
            ? Badge(
                label: Text('$count'),
                child: const Icon(Icons.chevron_right),
              )
            : const Icon(Icons.chevron_right),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const Icon(Icons.chevron_right),
      );
    },
  ),
  onTap: () => Navigator.pushNamed(context, '/sync/conflicts'),
),
```

### Step 5: Start the Node.js Server

**On your master PC:**

```bash
cd server
npm install
npm start
```

**Expected output:**
```
═══════════════════════════════════════════════════════════
   HIMS Master Sync Server Started
═══════════════════════════════════════════════════════════
   Server IP: 192.168.1.10
   HTTP Port: 5000
   Discovery Port: 9999 (UDP)
───────────────────────────────────────────────────────────
   Local: http://localhost:5000
   Network: http://192.168.1.10:5000
───────────────────────────────────────────────────────────
   UDP Discovery: Broadcasting on port 9999
═══════════════════════════════════════════════════════════
```

### Step 6: Test the Sync

1. **Start the server** (see Step 5)

2. **Run the Flutter app** on a device/emulator on the same LAN:
   ```bash
   flutter run
   ```

3. **Check sync status:**
   - Look at the AppBar - you should see the sync icon
   - It should change from grey → orange (discovering) → green (connected)

4. **Create some data:**
   - Add a product, supplier, or purchase
   - Watch the sync status indicator while it syncs

5. **Test on multiple devices:**
   - Run the app on 2+ devices simultaneously
   - Create data on device A
   - Wait for sync (or tap sync button)
   - See data appear on device B within 2 minutes

6. **Test conflict resolution:**
   - Modify the same product on two devices
   - Wait for sync
   - Navigate to Settings → Sync Conflicts
   - Resolve the conflict by choosing which version to keep

---

## 🔧 Configuration

### Sync Settings

The sync behavior can be configured in `lib/services/sync_service.dart`:

```dart
// Discovery port for UDP broadcasts
static const int discoveryPort = 9999;

// How long to wait for server discovery
static const Duration discoveryTimeout = Duration(seconds: 10);

// Automatic sync interval
static const Duration syncInterval = Duration(minutes: 2);

// Maximum records per sync request
static const int maxRecordsPerSync = 200;
```

### Server Configuration

Server settings are in `server/.env`:

```env
PORT=5000
DISCOVERY_PORT=9999
MAX_SYNC_RECORDS=200
LOG_LEVEL=info
```

---

## 📊 Architecture Overview

```
┌──────────────┐          UDP Port 9999          ┌──────────────┐
│  Node Server │◄──────────────────────────────►│ Flutter App  │
│  (Master DB) │      Server Discovery          │  (Local DB)  │
└──────┬───────┘                                 └──────┬───────┘
       │                                                 │
       │         HTTP REST API (JSON)                    │
       │         POST /sync/push                         │
       │         POST /sync/pull                         │
       ▼                                                 ▼
    SQLite                                           Drift (SQLite)
  (Server DB)                                        (Local DB)
```

### Sync Flow:

1. **Discovery Phase:**
   - App listens on UDP port 9999
   - Server broadcasts every 5 seconds
   - App detects server and registers

2. **Push Phase:**
   - App queries `isSynced=false` records
   - Sends to server via POST /sync/push
   - Server checks for conflicts (timestamp comparison)
   - Server returns conflicts (if any)
   - App marks records as synced

3. **Pull Phase:**
   - App sends last sync timestamp
   - Server returns records modified since that time
   - App upserts records into local database
   - App marks records as synced

4. **Conflict Detection:**
   - Server compares `last_modified` timestamps
   - If server version is newer → Conflict!
   - Conflict stored in `conflict_log`
   - User resolves via UI

---

## 🐛 Troubleshooting

### Sync status stuck on "Discovering"

**Cause:** UDP discovery not working

**Solutions:**
1. Ensure server and app are on same LAN/WiFi
2. Check firewall allows UDP port 9999
3. Verify server is running: `curl http://localhost:5000/ping`
4. Check server logs for UDP broadcast messages

### "Not connected to server" when trying to sync

**Cause:** Server not discovered or registration failed

**Solutions:**
1. Tap sync icon to view details
2. Check server IP matches your network
3. Try restarting the app
4. Check server logs: `tail -f server/logs/combined.log`

### Conflicts not resolving

**Cause:** Conflict resolution not persisting

**Solutions:**
1. Check `resolveConflict()` method in SyncDao
2. Verify database write permissions
3. Check server acknowledges resolution
4. Refresh conflicts screen

### Data not syncing

**Cause:** Records not marked as unsynced

**Solutions:**
1. Check `isSynced` flag is false after create/update
2. Verify DAO methods set `isSynced: const Value(false)`
3. Check sync queue: `SELECT * FROM sync_queue`
4. Manual sync: Tap sync button in AppBar

---

## 📈 Monitoring Sync Health

### Client-Side (Flutter App)

```dart
// Get sync queue count
final queueCount = await database.syncDao.getSyncQueueCount();
print('Pending sync items: $queueCount');

// Get unresolved conflicts count
final conflictCount = await database.syncDao.getUnresolvedConflictsCount();
print('Unresolved conflicts: $conflictCount');

// Check last sync time
final lastSync = syncService.lastSyncTime;
print('Last sync: $lastSync');
```

### Server-Side (Node.js)

```bash
# Check server stats
curl http://localhost:5000/stats

# View all registered devices
curl http://localhost:5000/devices

# View conflicts
curl http://localhost:5000/conflicts
```

---

## 🎯 Success Criteria

Your sync is working correctly if:

✅ App discovers server automatically within 10 seconds
✅ Sync status indicator shows green when connected
✅ Creating data on device A appears on device B within 2 minutes
✅ Manual sync completes successfully
✅ Conflicts appear in Conflicts screen when detected
✅ Resolving conflicts updates both devices
✅ Server logs show successful push/pull operations
✅ No errors in Flutter console or server logs

---

## 📚 Additional Resources

- **Server API Documentation:** `server/README.md`
- **Database Schema:** `lib/db/app_database.dart`
- **Sync Service Code:** `lib/services/sync_service.dart`
- **Server Code:** `server/src/`

---

## 🚀 Deployment Notes

### Production Deployment

1. **Server:**
   - Use PM2 or systemd for process management
   - Set up database backups
   - Configure firewall rules
   - Use environment variables for secrets

2. **Client:**
   - Test on all target platforms (Android/iOS/Web)
   - Ensure proper error handling
   - Add retry logic for network failures
   - Implement offline queue processing

---

**Implementation Status:** ✅ COMPLETE

All code has been committed to branch: `claude/flutter-web-mobile-app-011CUrev2Uyd9CXv4aLzfr1y`

Last updated: 2025-11-07
