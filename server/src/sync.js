const {
  getRecordsSince,
  upsertRecord,
  getRecordByUuid,
  logSync,
  logConflict,
  transaction
} = require('./db');
const {
  logger,
  isValidTableName,
  compareTimestamps,
  getCurrentTimestamp,
  sanitizeRecord
} = require('./utils');

/**
 * Handle pull request - send records newer than client's timestamp
 */
function handlePull(req, res) {
  try {
    const { tables, since, deviceUuid } = req.body;

    if (!tables || !Array.isArray(tables)) {
      return res.status(400).json({
        error: true,
        message: 'Invalid request: tables array is required'
      });
    }

    if (!since) {
      return res.status(400).json({
        error: true,
        message: 'Invalid request: since timestamp is required'
      });
    }

    if (!deviceUuid) {
      return res.status(400).json({
        error: true,
        message: 'Invalid request: deviceUuid is required'
      });
    }

    const response = {};
    let totalRecords = 0;

    // Get records for each table
    for (const tableName of tables) {
      // Validate table name to prevent SQL injection
      if (!isValidTableName(tableName)) {
        logger.warn(`Invalid table name requested: ${tableName}`);
        continue;
      }

      try {
        const records = getRecordsSince(tableName, since);
        response[tableName] = records;
        totalRecords += records.length;

        logger.info(`Pull: ${records.length} records from ${tableName} for device ${deviceUuid}`);
      } catch (error) {
        logger.error(`Error pulling from ${tableName}: ${error.message}`);
        response[tableName] = [];
      }
    }

    // Log the sync operation
    logSync(deviceUuid, 'multiple', 'pull', null, true);

    res.json({
      success: true,
      data: response,
      totalRecords,
      timestamp: getCurrentTimestamp()
    });
  } catch (error) {
    logger.error(`Pull error: ${error.message}`);
    res.status(500).json({
      error: true,
      message: 'Internal server error during pull',
      details: error.message
    });
  }
}

/**
 * Handle push request - receive and merge records from client
 */
function handlePush(req, res) {
  try {
    const { data, deviceUuid } = req.body;

    if (!data || typeof data !== 'object') {
      return res.status(400).json({
        error: true,
        message: 'Invalid request: data object is required'
      });
    }

    if (!deviceUuid) {
      return res.status(400).json({
        error: true,
        message: 'Invalid request: deviceUuid is required'
      });
    }

    const conflicts = [];
    const processed = {
      inserted: 0,
      updated: 0,
      conflicts: 0,
      errors: 0
    };

    // Process each table's data
    for (const [tableName, records] of Object.entries(data)) {
      // Validate table name
      if (!isValidTableName(tableName)) {
        logger.warn(`Invalid table name in push: ${tableName}`);
        continue;
      }

      if (!Array.isArray(records)) {
        logger.warn(`Records for ${tableName} is not an array`);
        continue;
      }

      // Process each record
      for (const record of records) {
        try {
          const result = mergeRecord(tableName, record, deviceUuid);

          if (result.conflict) {
            conflicts.push(result.conflict);
            processed.conflicts++;
          } else if (result.inserted) {
            processed.inserted++;
          } else if (result.updated) {
            processed.updated++;
          }

          // Log successful sync
          logSync(deviceUuid, tableName, result.operation, record.uuid, true);
        } catch (error) {
          logger.error(`Error pushing record to ${tableName}: ${error.message}`);
          processed.errors++;

          // Log failed sync
          logSync(deviceUuid, tableName, 'push', record.uuid, false, error.message);
        }
      }
    }

    logger.info(`Push complete for device ${deviceUuid}: ${JSON.stringify(processed)}`);

    res.json({
      success: true,
      processed,
      conflicts,
      timestamp: getCurrentTimestamp()
    });
  } catch (error) {
    logger.error(`Push error: ${error.message}`);
    res.status(500).json({
      error: true,
      message: 'Internal server error during push',
      details: error.message
    });
  }
}

/**
 * Merge a single record with conflict detection
 */
function mergeRecord(tableName, clientRecord, deviceUuid) {
  const uuid = clientRecord.uuid;

  if (!uuid) {
    throw new Error('Record must have a uuid field');
  }

  // Get existing record from server
  const serverRecord = getRecordByUuid(tableName, uuid);

  // Set metadata
  const mergedRecord = {
    ...clientRecord,
    source_device: deviceUuid,
    last_modified: getCurrentTimestamp()
  };

  if (!serverRecord) {
    // New record - insert it
    upsertRecord(tableName, sanitizeRecord(mergedRecord));
    logger.debug(`Inserted new record ${uuid} into ${tableName}`);
    return { inserted: true, operation: 'insert' };
  }

  // Record exists - check for conflicts
  const serverTimestamp = serverRecord.last_modified;
  const clientTimestamp = clientRecord.last_modified;

  const comparison = compareTimestamps(clientTimestamp, serverTimestamp);

  if (comparison > 0) {
    // Client version is newer - update server
    upsertRecord(tableName, sanitizeRecord(mergedRecord));
    logger.debug(`Updated record ${uuid} in ${tableName} (client newer)`);
    return { updated: true, operation: 'update' };
  } else if (comparison < 0) {
    // Server version is newer - conflict!
    logger.warn(`Conflict detected for ${uuid} in ${tableName}`);

    // Log the conflict
    logConflict(
      tableName,
      uuid,
      deviceUuid,
      clientTimestamp,
      serverTimestamp,
      clientRecord,
      serverRecord
    );

    return {
      conflict: {
        table: tableName,
        uuid,
        deviceTimestamp: clientTimestamp,
        serverTimestamp,
        message: 'Server has newer version'
      },
      operation: 'conflict'
    };
  } else {
    // Same timestamp - no changes needed
    logger.debug(`Record ${uuid} in ${tableName} already up to date`);
    return { operation: 'skip' };
  }
}

/**
 * Get conflict resolution strategies
 */
function getConflictStrategies() {
  return {
    // Master data: Prompt user
    stock_items: 'prompt',
    suppliers: 'prompt',

    // Transactions: Latest wins
    purchases: 'latest_wins',
    purchase_items: 'latest_wins',
    issues: 'latest_wins',
    issue_items: 'latest_wins',

    // Settings: Server authoritative
    devices: 'server_wins'
  };
}

/**
 * Apply conflict resolution
 */
function resolveConflict(conflictId, resolution, resolvedBy) {
  const db = require('./db').db;

  const updateStmt = db.prepare(`
    UPDATE conflict_log
    SET resolution = ?, resolved_at = CURRENT_TIMESTAMP, resolved_by = ?
    WHERE id = ?
  `);

  return updateStmt.run(resolution, resolvedBy, conflictId);
}

/**
 * Get all unresolved conflicts
 */
function getUnresolvedConflicts() {
  const db = require('./db').db;

  const stmt = db.prepare(`
    SELECT * FROM conflict_log
    WHERE resolution IS NULL
    ORDER BY created_at DESC
  `);

  return stmt.all();
}

/**
 * Get conflicts for a specific device
 */
function getDeviceConflicts(deviceUuid) {
  const db = require('./db').db;

  const stmt = db.prepare(`
    SELECT * FROM conflict_log
    WHERE device_uuid = ? AND resolution IS NULL
    ORDER BY created_at DESC
  `);

  return stmt.all(deviceUuid);
}

module.exports = {
  handlePull,
  handlePush,
  mergeRecord,
  getConflictStrategies,
  resolveConflict,
  getUnresolvedConflicts,
  getDeviceConflicts
};
