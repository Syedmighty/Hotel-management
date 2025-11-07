const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs');
const logger = require('./utils').logger;

// Database path
const DB_DIR = path.join(__dirname, '../data');
const DB_PATH = path.join(DB_DIR, 'hims_master.db');

// Ensure data directory exists
if (!fs.existsSync(DB_DIR)) {
  fs.mkdirSync(DB_DIR, { recursive: true });
}

// Initialize database
const db = new Database(DB_PATH, {
  verbose: (message) => logger.debug(`SQLite: ${message}`)
});

// Enable WAL mode for better concurrency
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

/**
 * Initialize database schema
 */
function initializeSchema() {
  logger.info('Initializing database schema...');

  // Devices table - track all connected devices
  db.exec(`
    CREATE TABLE IF NOT EXISTS devices (
      uuid TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      ip_address TEXT,
      role TEXT DEFAULT 'client',
      last_seen TEXT DEFAULT CURRENT_TIMESTAMP,
      is_active INTEGER DEFAULT 1,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      sync_token TEXT
    )
  `);

  // Sync log - track all sync operations
  db.exec(`
    CREATE TABLE IF NOT EXISTS sync_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      device_uuid TEXT NOT NULL,
      table_name TEXT NOT NULL,
      operation TEXT NOT NULL,
      record_uuid TEXT,
      timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
      success INTEGER DEFAULT 1,
      error_message TEXT,
      FOREIGN KEY (device_uuid) REFERENCES devices(uuid)
    )
  `);

  // Conflict log - track all conflicts
  db.exec(`
    CREATE TABLE IF NOT EXISTS conflict_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      table_name TEXT NOT NULL,
      record_uuid TEXT NOT NULL,
      device_uuid TEXT NOT NULL,
      device_timestamp TEXT NOT NULL,
      server_timestamp TEXT NOT NULL,
      device_payload TEXT,
      server_payload TEXT,
      resolution TEXT,
      resolved_at TEXT,
      resolved_by TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // Stock Items table - master data
  db.exec(`
    CREATE TABLE IF NOT EXISTS stock_items (
      uuid TEXT PRIMARY KEY,
      item_name TEXT NOT NULL,
      category TEXT,
      location TEXT,
      unit TEXT NOT NULL,
      current_stock REAL DEFAULT 0,
      min_stock REAL DEFAULT 0,
      max_stock REAL DEFAULT 0,
      reorder_level REAL DEFAULT 0,
      is_active INTEGER DEFAULT 1,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      last_modified TEXT DEFAULT CURRENT_TIMESTAMP,
      modified_by TEXT,
      is_synced INTEGER DEFAULT 1,
      source_device TEXT
    )
  `);

  // Suppliers table
  db.exec(`
    CREATE TABLE IF NOT EXISTS suppliers (
      uuid TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      contact_person TEXT,
      phone TEXT,
      email TEXT,
      address TEXT,
      gst_no TEXT,
      pan_no TEXT,
      current_balance REAL DEFAULT 0,
      is_active INTEGER DEFAULT 1,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      last_modified TEXT DEFAULT CURRENT_TIMESTAMP,
      modified_by TEXT,
      is_synced INTEGER DEFAULT 1,
      source_device TEXT
    )
  `);

  // Purchases table
  db.exec(`
    CREATE TABLE IF NOT EXISTS purchases (
      uuid TEXT PRIMARY KEY,
      purchase_no TEXT NOT NULL UNIQUE,
      supplier_id TEXT NOT NULL,
      purchase_date TEXT NOT NULL,
      invoice_no TEXT,
      payment_mode TEXT NOT NULL,
      status TEXT DEFAULT 'Pending',
      subtotal REAL DEFAULT 0,
      discount REAL DEFAULT 0,
      total_amount REAL DEFAULT 0,
      approved_by TEXT,
      approved_at TEXT,
      notes TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      last_modified TEXT DEFAULT CURRENT_TIMESTAMP,
      modified_by TEXT,
      is_synced INTEGER DEFAULT 1,
      source_device TEXT,
      FOREIGN KEY (supplier_id) REFERENCES suppliers(uuid)
    )
  `);

  // Purchase Items table
  db.exec(`
    CREATE TABLE IF NOT EXISTS purchase_items (
      uuid TEXT PRIMARY KEY,
      purchase_id TEXT NOT NULL,
      stock_item_id TEXT NOT NULL,
      quantity REAL NOT NULL,
      rate REAL NOT NULL,
      amount REAL NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      last_modified TEXT DEFAULT CURRENT_TIMESTAMP,
      is_synced INTEGER DEFAULT 1,
      source_device TEXT,
      FOREIGN KEY (purchase_id) REFERENCES purchases(uuid),
      FOREIGN KEY (stock_item_id) REFERENCES stock_items(uuid)
    )
  `);

  // Issues table
  db.exec(`
    CREATE TABLE IF NOT EXISTS issues (
      uuid TEXT PRIMARY KEY,
      issue_no TEXT NOT NULL UNIQUE,
      department TEXT NOT NULL,
      issue_date TEXT NOT NULL,
      issued_by TEXT NOT NULL,
      purpose TEXT,
      status TEXT DEFAULT 'Pending',
      total_amount REAL DEFAULT 0,
      approved_by TEXT,
      approved_at TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      last_modified TEXT DEFAULT CURRENT_TIMESTAMP,
      modified_by TEXT,
      is_synced INTEGER DEFAULT 1,
      source_device TEXT
    )
  `);

  // Issue Items table
  db.exec(`
    CREATE TABLE IF NOT EXISTS issue_items (
      uuid TEXT PRIMARY KEY,
      issue_id TEXT NOT NULL,
      stock_item_id TEXT NOT NULL,
      quantity REAL NOT NULL,
      rate REAL NOT NULL,
      amount REAL NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      last_modified TEXT DEFAULT CURRENT_TIMESTAMP,
      is_synced INTEGER DEFAULT 1,
      source_device TEXT,
      FOREIGN KEY (issue_id) REFERENCES issues(uuid),
      FOREIGN KEY (stock_item_id) REFERENCES stock_items(uuid)
    )
  `);

  // Create indexes for performance
  db.exec(`
    CREATE INDEX IF NOT EXISTS idx_stock_items_last_modified ON stock_items(last_modified);
    CREATE INDEX IF NOT EXISTS idx_suppliers_last_modified ON suppliers(last_modified);
    CREATE INDEX IF NOT EXISTS idx_purchases_last_modified ON purchases(last_modified);
    CREATE INDEX IF NOT EXISTS idx_issues_last_modified ON issues(last_modified);
    CREATE INDEX IF NOT EXISTS idx_sync_log_device ON sync_log(device_uuid);
    CREATE INDEX IF NOT EXISTS idx_conflict_log_table_record ON conflict_log(table_name, record_uuid);
  `);

  logger.info('Database schema initialized successfully');
}

/**
 * Get all records from a table modified after a timestamp
 */
function getRecordsSince(tableName, sinceTimestamp) {
  const stmt = db.prepare(`
    SELECT * FROM ${tableName}
    WHERE last_modified > ?
    ORDER BY last_modified ASC
  `);
  return stmt.all(sinceTimestamp);
}

/**
 * Insert or update a record
 */
function upsertRecord(tableName, record) {
  const columns = Object.keys(record);
  const placeholders = columns.map(() => '?').join(', ');
  const updates = columns.map(col => `${col} = excluded.${col}`).join(', ');

  const stmt = db.prepare(`
    INSERT INTO ${tableName} (${columns.join(', ')})
    VALUES (${placeholders})
    ON CONFLICT(uuid) DO UPDATE SET ${updates}
  `);

  return stmt.run(...Object.values(record));
}

/**
 * Get a single record by UUID
 */
function getRecordByUuid(tableName, uuid) {
  const stmt = db.prepare(`SELECT * FROM ${tableName} WHERE uuid = ?`);
  return stmt.get(uuid);
}

/**
 * Register a device
 */
function registerDevice(deviceData) {
  const { uuid, name, ipAddress, role = 'client', syncToken } = deviceData;

  const stmt = db.prepare(`
    INSERT INTO devices (uuid, name, ip_address, role, sync_token, last_seen)
    VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
    ON CONFLICT(uuid) DO UPDATE SET
      name = excluded.name,
      ip_address = excluded.ip_address,
      last_seen = CURRENT_TIMESTAMP,
      is_active = 1
  `);

  return stmt.run(uuid, name, ipAddress, role, syncToken);
}

/**
 * Log a sync operation
 */
function logSync(deviceUuid, tableName, operation, recordUuid, success, errorMessage = null) {
  const stmt = db.prepare(`
    INSERT INTO sync_log (device_uuid, table_name, operation, record_uuid, success, error_message)
    VALUES (?, ?, ?, ?, ?, ?)
  `);

  return stmt.run(deviceUuid, tableName, operation, recordUuid, success ? 1 : 0, errorMessage);
}

/**
 * Log a conflict
 */
function logConflict(tableName, recordUuid, deviceUuid, deviceTimestamp, serverTimestamp, devicePayload, serverPayload) {
  const stmt = db.prepare(`
    INSERT INTO conflict_log (table_name, record_uuid, device_uuid, device_timestamp, server_timestamp, device_payload, server_payload)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `);

  return stmt.run(
    tableName,
    recordUuid,
    deviceUuid,
    deviceTimestamp,
    serverTimestamp,
    JSON.stringify(devicePayload),
    JSON.stringify(serverPayload)
  );
}

/**
 * Get device by UUID
 */
function getDevice(uuid) {
  const stmt = db.prepare('SELECT * FROM devices WHERE uuid = ?');
  return stmt.get(uuid);
}

/**
 * Get all active devices
 */
function getAllActiveDevices() {
  const stmt = db.prepare('SELECT * FROM devices WHERE is_active = 1 ORDER BY last_seen DESC');
  return stmt.all();
}

/**
 * Run multiple operations in a transaction
 */
function transaction(operations) {
  const trans = db.transaction(() => {
    for (const op of operations) {
      op();
    }
  });
  return trans();
}

// Initialize schema on module load
initializeSchema();

module.exports = {
  db,
  getRecordsSince,
  upsertRecord,
  getRecordByUuid,
  registerDevice,
  logSync,
  logConflict,
  getDevice,
  getAllActiveDevices,
  transaction
};
