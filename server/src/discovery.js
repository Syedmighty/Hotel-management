const dgram = require('dgram');
const os = require('os');
const { logger } = require('./utils');

const DISCOVERY_PORT = 9999;
const BROADCAST_INTERVAL = 5000; // 5 seconds

/**
 * Get server's LAN IP address
 */
function getLocalIP() {
  const interfaces = os.networkInterfaces();
  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name]) {
      // Skip internal (loopback) and non-IPv4 addresses
      if (iface.family === 'IPv4' && !iface.internal) {
        return iface.address;
      }
    }
  }
  return '0.0.0.0';
}

/**
 * Start UDP discovery broadcast
 */
function startDiscovery(serverPort = 5000, serverName = 'HIMS Master') {
  const server = dgram.createSocket('udp4');
  const serverIP = getLocalIP();

  server.on('error', (err) => {
    logger.error(`Discovery server error: ${err.message}`);
    server.close();
  });

  server.on('listening', () => {
    server.setBroadcast(true);
    const address = server.address();
    logger.info(`UDP Discovery server listening on ${address.address}:${address.port}`);

    // Broadcast server info every 5 seconds
    const broadcastMessage = JSON.stringify({
      serverIP,
      port: serverPort,
      name: serverName,
      version: '1.0.0',
      timestamp: new Date().toISOString()
    });

    setInterval(() => {
      server.send(
        broadcastMessage,
        0,
        broadcastMessage.length,
        DISCOVERY_PORT,
        '255.255.255.255',
        (err) => {
          if (err) {
            logger.error(`Broadcast error: ${err.message}`);
          } else {
            logger.debug(`Broadcast sent: ${broadcastMessage}`);
          }
        }
      );
    }, BROADCAST_INTERVAL);
  });

  // Listen for client discovery requests
  server.on('message', (msg, rinfo) => {
    try {
      const message = JSON.parse(msg.toString());
      logger.debug(`Discovery request from ${rinfo.address}:${rinfo.port} - ${JSON.stringify(message)}`);

      // If client is requesting server info, send immediate response
      if (message.type === 'discover') {
        const responseMessage = JSON.stringify({
          serverIP,
          port: serverPort,
          name: serverName,
          version: '1.0.0',
          timestamp: new Date().toISOString()
        });

        server.send(
          responseMessage,
          0,
          responseMessage.length,
          rinfo.port,
          rinfo.address,
          (err) => {
            if (err) {
              logger.error(`Response error: ${err.message}`);
            } else {
              logger.info(`Sent discovery response to ${rinfo.address}:${rinfo.port}`);
            }
          }
        );
      }
    } catch (error) {
      logger.debug(`Non-JSON message from ${rinfo.address}: ${msg.toString()}`);
    }
  });

  // Bind to discovery port
  server.bind(DISCOVERY_PORT);

  return server;
}

/**
 * Stop discovery broadcast
 */
function stopDiscovery(server) {
  if (server) {
    server.close(() => {
      logger.info('UDP Discovery server closed');
    });
  }
}

module.exports = {
  startDiscovery,
  stopDiscovery,
  getLocalIP,
  DISCOVERY_PORT
};
