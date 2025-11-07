require('dotenv').config();
const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const compression = require('compression');
const fs = require('fs');
const path = require('path');

const { logger, errorResponse, successResponse, getClientIP } = require('./utils');
const { registerDevice, getDevice, getAllActiveDevices } = require('./db');
const { handlePull, handlePush, getUnresolvedConflicts, resolveConflict, getDeviceConflicts } = require('./sync');
const { startDiscovery, getLocalIP } = require('./discovery');

// Create Express app
const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors({
  origin: '*', // Allow all origins in LAN
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(bodyParser.json({ limit: '10mb' }));
app.use(bodyParser.urlencoded({ extended: true, limit: '10mb' }));
app.use(compression()); // Gzip compression

// Request logging middleware
app.use((req, res, next) => {
  const clientIP = getClientIP(req);
  logger.info(`${req.method} ${req.path} from ${clientIP}`);
  next();
});

// Ensure logs directory exists
const logsDir = path.join(__dirname, '../logs');
if (!fs.existsSync(logsDir)) {
  fs.mkdirSync(logsDir, { recursive: true });
}

/**
 * Health check endpoint
 */
app.get('/ping', (req, res) => {
  res.json({
    success: true,
    message: 'HIMS Sync Server is running',
    serverIP: getLocalIP(),
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
});

/**
 * Get server info
 */
app.get('/info', (req, res) => {
  const deviceCount = getAllActiveDevices().length;

  res.json({
    success: true,
    data: {
      name: 'HIMS Master Server',
      version: '1.0.0',
      serverIP: getLocalIP(),
      port: PORT,
      activeDevices: deviceCount,
      uptime: process.uptime(),
      timestamp: new Date().toISOString()
    }
  });
});

/**
 * Register a new device
 */
app.post('/devices/register', (req, res) => {
  try {
    const { uuid, name, role } = req.body;

    if (!uuid || !name) {
      return res.status(400).json(errorResponse('Device UUID and name are required'));
    }

    const ipAddress = getClientIP(req);

    // Register device
    registerDevice({
      uuid,
      name,
      ipAddress,
      role: role || 'client',
      syncToken: null // JWT token will be added later if needed
    });

    logger.info(`Device registered: ${name} (${uuid}) from ${ipAddress}`);

    res.json(successResponse({
      uuid,
      name,
      ipAddress,
      registered: true
    }, 'Device registered successfully'));
  } catch (error) {
    logger.error(`Device registration error: ${error.message}`);
    res.status(500).json(errorResponse('Failed to register device', error.message));
  }
});

/**
 * Get all registered devices
 */
app.get('/devices', (req, res) => {
  try {
    const devices = getAllActiveDevices();
    res.json(successResponse(devices, `Found ${devices.length} active devices`));
  } catch (error) {
    logger.error(`Error fetching devices: ${error.message}`);
    res.status(500).json(errorResponse('Failed to fetch devices', error.message));
  }
});

/**
 * Get a specific device
 */
app.get('/devices/:uuid', (req, res) => {
  try {
    const { uuid } = req.params;
    const device = getDevice(uuid);

    if (!device) {
      return res.status(404).json(errorResponse('Device not found'));
    }

    res.json(successResponse(device));
  } catch (error) {
    logger.error(`Error fetching device: ${error.message}`);
    res.status(500).json(errorResponse('Failed to fetch device', error.message));
  }
});

/**
 * Sync pull endpoint - client requests updated records
 */
app.post('/sync/pull', handlePull);

/**
 * Sync push endpoint - client sends updated records
 */
app.post('/sync/push', handlePush);

/**
 * Get all unresolved conflicts
 */
app.get('/conflicts', (req, res) => {
  try {
    const conflicts = getUnresolvedConflicts();
    res.json(successResponse(conflicts, `Found ${conflicts.length} unresolved conflicts`));
  } catch (error) {
    logger.error(`Error fetching conflicts: ${error.message}`);
    res.status(500).json(errorResponse('Failed to fetch conflicts', error.message));
  }
});

/**
 * Get conflicts for a specific device
 */
app.get('/conflicts/:deviceUuid', (req, res) => {
  try {
    const { deviceUuid } = req.params;
    const conflicts = getDeviceConflicts(deviceUuid);
    res.json(successResponse(conflicts, `Found ${conflicts.length} conflicts for device`));
  } catch (error) {
    logger.error(`Error fetching device conflicts: ${error.message}`);
    res.status(500).json(errorResponse('Failed to fetch device conflicts', error.message));
  }
});

/**
 * Resolve a conflict
 */
app.post('/conflicts/:conflictId/resolve', (req, res) => {
  try {
    const { conflictId } = req.params;
    const { resolution, resolvedBy } = req.body;

    if (!resolution) {
      return res.status(400).json(errorResponse('Resolution strategy is required'));
    }

    const validResolutions = ['keep_device', 'use_server', 'manual_merge'];
    if (!validResolutions.includes(resolution)) {
      return res.status(400).json(errorResponse('Invalid resolution strategy'));
    }

    resolveConflict(conflictId, resolution, resolvedBy || 'system');

    logger.info(`Conflict ${conflictId} resolved: ${resolution} by ${resolvedBy}`);

    res.json(successResponse({ conflictId, resolution }, 'Conflict resolved successfully'));
  } catch (error) {
    logger.error(`Error resolving conflict: ${error.message}`);
    res.status(500).json(errorResponse('Failed to resolve conflict', error.message));
  }
});

/**
 * Get sync statistics
 */
app.get('/stats', (req, res) => {
  try {
    const db = require('./db').db;

    // Get sync stats
    const syncStats = db.prepare(`
      SELECT
        COUNT(*) as total_syncs,
        SUM(CASE WHEN success = 1 THEN 1 ELSE 0 END) as successful_syncs,
        SUM(CASE WHEN success = 0 THEN 1 ELSE 0 END) as failed_syncs
      FROM sync_log
      WHERE timestamp > datetime('now', '-24 hours')
    `).get();

    // Get conflict stats
    const conflictStats = db.prepare(`
      SELECT
        COUNT(*) as total_conflicts,
        SUM(CASE WHEN resolution IS NULL THEN 1 ELSE 0 END) as unresolved,
        SUM(CASE WHEN resolution IS NOT NULL THEN 1 ELSE 0 END) as resolved
      FROM conflict_log
    `).get();

    res.json(successResponse({
      sync: syncStats,
      conflicts: conflictStats,
      devices: getAllActiveDevices().length
    }));
  } catch (error) {
    logger.error(`Error fetching stats: ${error.message}`);
    res.status(500).json(errorResponse('Failed to fetch statistics', error.message));
  }
});

/**
 * Error handling middleware
 */
app.use((err, req, res, next) => {
  logger.error(`Unhandled error: ${err.message}`);
  res.status(500).json(errorResponse('Internal server error', err.message));
});

/**
 * 404 handler
 */
app.use((req, res) => {
  res.status(404).json(errorResponse('Endpoint not found'));
});

/**
 * Start server
 */
app.listen(PORT, '0.0.0.0', () => {
  const serverIP = getLocalIP();
  logger.info('═══════════════════════════════════════════════════════════');
  logger.info('   HIMS Master Sync Server Started');
  logger.info('═══════════════════════════════════════════════════════════');
  logger.info(`   Server IP: ${serverIP}`);
  logger.info(`   HTTP Port: ${PORT}`);
  logger.info(`   Discovery Port: 9999 (UDP)`);
  logger.info('───────────────────────────────────────────────────────────');
  logger.info(`   Local: http://localhost:${PORT}`);
  logger.info(`   Network: http://${serverIP}:${PORT}`);
  logger.info('───────────────────────────────────────────────────────────');
  logger.info(`   Health Check: http://${serverIP}:${PORT}/ping`);
  logger.info(`   Device Registration: POST http://${serverIP}:${PORT}/devices/register`);
  logger.info(`   Sync Pull: POST http://${serverIP}:${PORT}/sync/pull`);
  logger.info(`   Sync Push: POST http://${serverIP}:${PORT}/sync/push`);
  logger.info('═══════════════════════════════════════════════════════════');

  // Start UDP discovery broadcast
  startDiscovery(PORT, 'HIMS Master Server');
  logger.info('   UDP Discovery: Broadcasting on port 9999');
  logger.info('═══════════════════════════════════════════════════════════');
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM signal received: closing HTTP server');
  server.close(() => {
    logger.info('HTTP server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  logger.info('SIGINT signal received: closing HTTP server');
  process.exit(0);
});

module.exports = app;
