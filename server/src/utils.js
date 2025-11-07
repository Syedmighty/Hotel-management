const winston = require('winston');
const crypto = require('crypto');

/**
 * Logger configuration
 */
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp({
      format: 'YYYY-MM-DD HH:mm:ss'
    }),
    winston.format.errors({ stack: true }),
    winston.format.splat(),
    winston.format.json()
  ),
  defaultMeta: { service: 'hims-sync-server' },
  transports: [
    // Write all logs to console
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.printf(
          info => `${info.timestamp} ${info.level}: ${info.message}`
        )
      )
    }),
    // Write all logs to file
    new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
    new winston.transports.File({ filename: 'logs/combined.log' })
  ]
});

/**
 * Generate a hash for data integrity verification
 */
function generateHash(data) {
  return crypto
    .createHash('sha256')
    .update(JSON.stringify(data))
    .digest('hex');
}

/**
 * Get current ISO timestamp
 */
function getCurrentTimestamp() {
  return new Date().toISOString();
}

/**
 * Parse ISO timestamp
 */
function parseTimestamp(timestamp) {
  return new Date(timestamp);
}

/**
 * Compare timestamps (returns -1, 0, or 1)
 */
function compareTimestamps(ts1, ts2) {
  const date1 = new Date(ts1);
  const date2 = new Date(ts2);

  if (date1 < date2) return -1;
  if (date1 > date2) return 1;
  return 0;
}

/**
 * Validate table name (prevent SQL injection)
 */
function isValidTableName(tableName) {
  const validTables = [
    'stock_items',
    'suppliers',
    'purchases',
    'purchase_items',
    'issues',
    'issue_items',
    'stock_transfers',
    'transfer_items',
    'wastages',
    'wastage_items',
    'recipes',
    'recipe_items'
  ];
  return validTables.includes(tableName);
}

/**
 * Sanitize record data
 */
function sanitizeRecord(record) {
  const sanitized = {};
  for (const [key, value] of Object.entries(record)) {
    // Remove null values
    if (value !== null && value !== undefined) {
      sanitized[key] = value;
    }
  }
  return sanitized;
}

/**
 * Generate a simple JWT token (basic implementation)
 */
function generateToken(deviceUuid) {
  const jwt = require('jsonwebtoken');
  const secret = process.env.JWT_SECRET || 'hims-secret-key-change-in-production';

  return jwt.sign(
    {
      deviceId: deviceUuid,
      timestamp: getCurrentTimestamp()
    },
    secret,
    { expiresIn: '30d' }
  );
}

/**
 * Verify JWT token
 */
function verifyToken(token) {
  const jwt = require('jsonwebtoken');
  const secret = process.env.JWT_SECRET || 'hims-secret-key-change-in-production';

  try {
    return jwt.verify(token, secret);
  } catch (error) {
    return null;
  }
}

/**
 * Format error response
 */
function errorResponse(message, details = null) {
  return {
    error: true,
    message,
    details,
    timestamp: getCurrentTimestamp()
  };
}

/**
 * Format success response
 */
function successResponse(data = null, message = 'Success') {
  return {
    success: true,
    message,
    data,
    timestamp: getCurrentTimestamp()
  };
}

/**
 * Chunk array into smaller arrays
 */
function chunkArray(array, chunkSize) {
  const chunks = [];
  for (let i = 0; i < array.length; i += chunkSize) {
    chunks.push(array.slice(i, i + chunkSize));
  }
  return chunks;
}

/**
 * Get device IP from request
 */
function getClientIP(req) {
  return req.headers['x-forwarded-for'] ||
         req.connection.remoteAddress ||
         req.socket.remoteAddress ||
         req.connection.socket.remoteAddress;
}

module.exports = {
  logger,
  generateHash,
  getCurrentTimestamp,
  parseTimestamp,
  compareTimestamps,
  isValidTableName,
  sanitizeRecord,
  generateToken,
  verifyToken,
  errorResponse,
  successResponse,
  chunkArray,
  getClientIP
};
