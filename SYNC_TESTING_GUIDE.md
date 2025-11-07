# Sync Testing Guide

Complete guide for testing the multi-device sync functionality.

---

## 🎯 Testing Objectives

1. Verify UDP server discovery works correctly
2. Test bidirectional sync (push & pull)
3. Validate conflict detection and resolution
4. Test offline queue processing
5. Verify data integrity across devices
6. Test error handling and recovery

---

## 📋 Prerequisites

### Server Setup
```bash
cd server
npm install
npm start
```

**Verify server is running:**
```bash
curl http://localhost:5000/ping
# Expected: {"status":"ok","timestamp":"..."}
```

### Client Setup
1. Generate Drift code:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

2. Run on multiple devices:
   ```bash
   # Device 1 (Android Emulator)
   flutter run -d emulator-5554

   # Device 2 (Physical device)
   flutter run -d <device-id>

   # Device 3 (iOS Simulator)
   flutter run -d iPhone

   # Device 4 (Web)
   flutter run -d chrome
   ```

---

## 🧪 Test Scenarios

### Test 1: Server Discovery
**Objective:** Verify app discovers server automatically

**Steps:**
1. Start server on master PC
2. Launch app on test device
3. Check sync status indicator in AppBar

**Expected Results:**
- ✅ Status changes from grey (idle) → orange (discovering) → green (connected)
- ✅ Happens within 10 seconds
- ✅ Tap status icon shows correct server IP and name

**Troubleshooting:**
- Stuck on "Discovering"? Check both devices are on same WiFi
- No connection? Verify firewall allows UDP port 9999
- Check server logs: `tail -f server/logs/combined.log`

---

### Test 2: Basic Sync (Single Device)
**Objective:** Test push sync from device to server

**Steps:**
1. Ensure device is connected (green status)
2. Create a new product:
   - Name: "Test Product 1"
   - Category: "Test"
   - Stock: 100
3. Tap "Sync Now" button in Settings → Sync Settings
4. Check server database:
   ```bash
   sqlite3 server/database.sqlite
   SELECT name, currentStock FROM stock_items WHERE name LIKE 'Test%';
   ```

**Expected Results:**
- ✅ Sync completes successfully (green toast message)
- ✅ Product appears in server database
- ✅ Product's `isSynced` flag is true

---

### Test 3: Multi-Device Sync
**Objective:** Test data syncs across multiple devices

**Setup:**
- Device A: Android emulator
- Device B: Physical phone
- Both connected to same server

**Steps:**
1. **On Device A:** Create "Product A" with stock 50
2. Wait 2 minutes (automatic sync) OR tap "Sync Now"
3. **On Device B:** Pull down to refresh Products screen
4. **On Device B:** Create "Product B" with stock 75
5. Wait for sync
6. **On Device A:** Refresh Products screen

**Expected Results:**
- ✅ "Product A" appears on Device B
- ✅ "Product B" appears on Device A
- ✅ Both products show correct stock levels
- ✅ Last sync time updates on both devices

---

### Test 4: Conflict Detection
**Objective:** Test conflict detection when same record modified on multiple devices

**Steps:**
1. **On Device A:** Create "Conflict Product", stock = 100, sync
2. **Turn OFF WiFi on both devices** (go offline)
3. **On Device A:** Edit "Conflict Product", stock = 80
4. **On Device B:** Edit "Conflict Product", stock = 120
5. **Turn ON WiFi on both devices**
6. Wait for automatic sync OR tap "Sync Now"
7. **On both devices:** Navigate to Settings → Sync Settings
8. Check for conflict notification (orange warning icon)
9. Tap "View Conflicts"

**Expected Results:**
- ✅ Conflict detected and logged
- ✅ Conflict appears in Conflicts screen
- ✅ Shows both versions side-by-side:
  - Device version: stock = 80 or 120 (depending on device)
  - Server version: stock = 100 (original)
- ✅ Can resolve by choosing "Keep Mine" or "Use Server"

---

### Test 5: Offline Queue
**Objective:** Test changes queue when offline and sync when online

**Steps:**
1. **Turn OFF WiFi** on test device
2. Verify sync status shows grey (disconnected)
3. Create 3 products:
   - "Offline Product 1"
   - "Offline Product 2"
   - "Offline Product 3"
4. Navigate to Settings → Sync Settings
5. Check "Pending Sync" count (should show 3)
6. **Turn ON WiFi**
7. Wait for automatic sync OR tap "Sync Now"
8. Check "Pending Sync" count again

**Expected Results:**
- ✅ Changes are queued while offline
- ✅ Pending count shows correct number
- ✅ All changes sync when connection restored
- ✅ Pending count returns to 0 after sync
- ✅ All products appear on other devices

---

### Test 6: Concurrent Updates
**Objective:** Test handling of rapid concurrent updates

**Steps:**
1. **On Device A:**
   - Create "Concurrent Product", stock = 100
   - Sync
2. **On Device A & B simultaneously:**
   - Start editing the same product
   - Device A: Change stock to 90
   - Device B: Change stock to 110
   - Save both quickly (within 1 second)
3. Wait for sync on both devices
4. Check Conflicts screen

**Expected Results:**
- ✅ Conflict detected
- ✅ Both versions preserved
- ✅ User prompted to resolve
- ✅ After resolution, both devices show same value

---

### Test 7: Large Dataset Sync
**Objective:** Test sync performance with many records

**Preparation:**
Create test data using the test utility:
```dart
import 'test/sync_test_utils.dart';

// In your test or debug code:
await SyncTestUtils.createUnsyncedProducts(database, 100);
```

**Steps:**
1. Create 100+ products on Device A
2. Trigger sync
3. Monitor sync time
4. Check server database count:
   ```bash
   sqlite3 server/database.sqlite
   SELECT COUNT(*) FROM stock_items;
   ```
5. On Device B, wait for auto-sync
6. Check products count

**Expected Results:**
- ✅ Sync completes successfully
- ✅ Takes < 10 seconds for 100 records
- ✅ All 100 products appear on Device B
- ✅ No data loss
- ✅ No duplicate records

**Performance Benchmark:**
- 100 records: < 10 seconds
- 500 records: < 30 seconds
- 1000 records: < 60 seconds

---

### Test 8: Network Interruption Recovery
**Objective:** Test sync resumes gracefully after network interruption

**Steps:**
1. Start syncing a large dataset (50+ records)
2. **Midway through sync, turn OFF WiFi**
3. Wait 5 seconds
4. **Turn WiFi back ON**
5. Check sync status
6. Verify data integrity

**Expected Results:**
- ✅ Sync fails gracefully (no crash)
- ✅ Error logged but app remains functional
- ✅ Sync retries automatically
- ✅ All data eventually syncs
- ✅ No partial/corrupted records

---

### Test 9: Conflict Resolution Workflows
**Objective:** Test all conflict resolution options

**Test 9a: Keep Mine**
1. Create conflict (see Test 4)
2. In Conflicts screen, tap "Keep Mine"
3. Verify Device version is kept
4. Check other device receives the Device version

**Test 9b: Use Server**
1. Create conflict
2. In Conflicts screen, tap "Use Server"
3. Verify Server version is applied
4. Check device data matches server

**Expected Results:**
- ✅ "Keep Mine" overwrites server with device data
- ✅ "Use Server" overwrites device with server data
- ✅ Resolution syncs to all devices
- ✅ Conflict marked as resolved
- ✅ Conflict disappears from Conflicts screen

---

### Test 10: Server Restart
**Objective:** Test client handles server restart gracefully

**Steps:**
1. Device connected and syncing normally
2. **Stop server:** Ctrl+C in server terminal
3. On device, try to sync
4. Check sync status (should show error/disconnected)
5. **Restart server:** `npm start`
6. Wait 10 seconds
7. Check sync status

**Expected Results:**
- ✅ Device detects server is down (grey/red status)
- ✅ Sync fails gracefully with error message
- ✅ Device automatically rediscovers server
- ✅ Sync resumes automatically
- ✅ No data loss

---

## 🔬 Automated Tests

### Running Unit Tests

```bash
# Run all tests
flutter test

# Run sync tests only
flutter test test/sync_test_utils.dart

# Run with coverage
flutter test --coverage
```

### Using Test Utilities

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_inventory_management/db/app_database.dart';
import 'test/sync_test_utils.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase();
  });

  tearDown(() async {
    await SyncTestUtils.clearTestData(database);
    await database.close();
  });

  test('Basic sync flow', () async {
    await SyncTestScenarios.testBasicSync(database);
  });

  test('Conflict detection', () async {
    await SyncTestScenarios.testConflictDetection(database);
  });

  test('Sync queue', () async {
    await SyncTestScenarios.testSyncQueue(database);
  });
}
```

### Run All Test Scenarios

```dart
// In a test file or debug screen
await SyncTestScenarios.runAllTests(database);
```

---

## 📊 Monitoring & Debugging

### Check Sync Status (Client)

```dart
// In your app code or debug console
import 'package:hotel_inventory_management/test/sync_test_utils.dart';

await SyncTestUtils.printSyncStats(database);
```

**Output:**
```
=== Sync Statistics ===
Unsynced Products: 5
Unsynced Suppliers: 2
Unsynced Purchases: 3
Unsynced Issues: 1
Unresolved Conflicts: 0
Pending Queue Items: 0
======================
```

### Check Server Status

```bash
# Server stats
curl http://localhost:5000/stats

# Registered devices
curl http://localhost:5000/devices

# Recent sync operations
sqlite3 server/database.sqlite
SELECT * FROM sync_log ORDER BY sync_time DESC LIMIT 10;

# Conflicts
curl http://localhost:5000/conflicts
```

### View Logs

**Client Logs:**
- Open Flutter DevTools
- Navigate to Logging tab
- Filter for "SyncService" or "Sync"

**Server Logs:**
```bash
# All logs
tail -f server/logs/combined.log

# Error logs only
tail -f server/logs/error.log

# Filter for specific device
grep "device-uuid" server/logs/combined.log
```

---

## ✅ Test Checklist

Use this checklist to ensure comprehensive testing:

### Discovery & Connection
- [ ] Server auto-discovery works
- [ ] Connection established within 10 seconds
- [ ] Status indicator shows correct state
- [ ] Server info displayed correctly
- [ ] Multiple devices can connect simultaneously

### Data Sync
- [ ] Create record on Device A → appears on Device B
- [ ] Update record on Device A → updates on Device B
- [ ] Delete record on Device A → deleted on Device B (if soft delete)
- [ ] Sync works for all entity types (Products, Suppliers, Purchases, Issues)
- [ ] Line items sync with parent records

### Conflict Handling
- [ ] Conflicts detected correctly
- [ ] Conflict details shown accurately
- [ ] "Keep Mine" resolution works
- [ ] "Use Server" resolution works
- [ ] Resolved conflicts sync to all devices

### Offline Behavior
- [ ] Changes queued when offline
- [ ] Queue count displayed correctly
- [ ] Queued changes sync when online
- [ ] No data loss during offline period
- [ ] App remains functional while offline

### Performance
- [ ] 100 records sync in < 10 seconds
- [ ] UI remains responsive during sync
- [ ] No memory leaks during continuous operation
- [ ] Battery usage reasonable

### Error Handling
- [ ] Network errors handled gracefully
- [ ] Server down scenario handled
- [ ] Invalid data rejected
- [ ] Error messages user-friendly
- [ ] App doesn't crash on sync errors

### UI/UX
- [ ] Sync status indicator visible
- [ ] Manual sync button works
- [ ] Conflicts screen navigation works
- [ ] Loading indicators show during sync
- [ ] Toast messages appear for sync events

---

## 🐛 Common Issues & Solutions

### Issue: Sync stuck on "Discovering"
**Cause:** UDP broadcast not reaching device
**Solution:**
1. Verify same WiFi/LAN
2. Check firewall settings
3. Restart server
4. Restart app

### Issue: "Conflicts" never get resolved
**Cause:** Resolution not persisting or not syncing back
**Solution:**
1. Check `resolveConflict()` in SyncDao
2. Verify server `/conflicts/:id/resolve` endpoint
3. Check database write permissions

### Issue: Data missing after sync
**Cause:** Upsert logic or JSON serialization error
**Solution:**
1. Check `_applyServerChanges()` in SyncService
2. Verify JSON mapping in DAO methods
3. Check server logs for errors
4. Verify all fields are being serialized

### Issue: Duplicate records
**Cause:** UUID collision or improper upsert
**Solution:**
1. Verify UUID generation is unique
2. Check `insertOnConflictUpdate` in DAOs
3. Ensure primary key (uuid) is being used

---

## 📈 Success Metrics

Your sync implementation is working correctly if:

| Metric | Target | Status |
|--------|--------|--------|
| Discovery time | < 10 seconds | ⏱️ |
| Sync time (100 records) | < 10 seconds | ⏱️ |
| Conflict detection rate | 100% | ⏱️ |
| Data integrity | 100% (no loss) | ⏱️ |
| Offline queue success | 100% | ⏱️ |
| Error recovery rate | 100% | ⏱️ |
| Multi-device consistency | 100% | ⏱️ |

---

## 📝 Test Report Template

```markdown
# Sync Test Report

**Date:** YYYY-MM-DD
**Tester:** [Name]
**Environment:**
- Server: [IP Address]
- Devices: [List of devices tested]
- Network: [WiFi name/type]

## Test Results

### Discovery & Connection
- [x] Auto-discovery: PASS
- [ ] Connection time: 8 seconds (PASS < 10s)
- [x] Multiple devices: PASS (tested 3 devices)

### Data Sync
- [x] Products sync: PASS
- [x] Suppliers sync: PASS
- [x] Purchases sync: PASS
- [x] Issues sync: PASS

### Conflict Handling
- [x] Detection: PASS
- [x] Resolution: PASS
- [ ] Issue: Conflict #123 not resolving (bug filed)

### Performance
- Sync time (100 records): 7.5 seconds (PASS)
- Memory usage: Normal
- Battery impact: Low

## Issues Found
1. [Issue description]
   - Severity: High/Medium/Low
   - Steps to reproduce: ...
   - Expected: ...
   - Actual: ...

## Overall Result
✅ PASS / ❌ FAIL

## Notes
[Any additional observations]
```

---

## 🚀 Next Steps

After successful testing:

1. **Deploy to Production:**
   - Set up production server
   - Configure firewall rules
   - Set up monitoring & alerts

2. **User Training:**
   - Train hotel staff on sync functionality
   - Explain conflict resolution
   - Provide troubleshooting guide

3. **Monitoring:**
   - Set up server monitoring
   - Track sync success rates
   - Monitor for conflicts

4. **Optimization:**
   - Tune sync intervals based on usage
   - Optimize batch sizes
   - Implement compression if needed

---

**Happy Testing! 🧪✨**
