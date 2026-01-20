const WebSocket = require('ws');
const logger = require('./logger');

class LocalServer {
  constructor(port) {
    this.port = port;
    this.wss = null;
    this.clients = new Set();
    this.onMessageCallback = null;
    this.relayClient = null;
  }

  start() {
    this.wss = new WebSocket.Server({ port: this.port });

    this.wss.on('listening', () => {
      logger.log(`[${new Date().toISOString()}] Local server started on port ${this.port}`);
    });

    this.wss.on('connection', (ws) => {
      this.clients.add(ws);
      logger.log(`[${new Date().toISOString()}] Desktop connected. Total: ${this.clients.size}`);

      // 연결 확인 및 현재 상태 전송
      ws.send(JSON.stringify({
        type: 'connected',
        message: 'Connected to Pylon',
        relayStatus: this.relayClient ? this.relayClient.getStatus() : false
      }));

      ws.on('message', (message) => {
        try {
          const data = JSON.parse(message.toString());
          logger.log(`[${new Date().toISOString()}] From Desktop:`, data);

          if (this.onMessageCallback) {
            this.onMessageCallback(data, ws);
          }
        } catch (err) {
          logger.error(`[${new Date().toISOString()}] Invalid message from Desktop:`, message.toString());
        }
      });

      ws.on('close', () => {
        this.clients.delete(ws);
        logger.log(`[${new Date().toISOString()}] Desktop disconnected. Total: ${this.clients.size}`);
      });

      ws.on('error', (err) => {
        logger.error(`[${new Date().toISOString()}] Desktop connection error:`, err.message);
      });
    });

    this.wss.on('error', (err) => {
      logger.error(`[${new Date().toISOString()}] Local server error:`, err.message);
    });
  }

  setRelayClient(relayClient) {
    this.relayClient = relayClient;
  }

  onMessage(callback) {
    this.onMessageCallback = callback;
  }

  broadcast(data) {
    const message = JSON.stringify(data);
    this.clients.forEach((client) => {
      if (client.readyState === WebSocket.OPEN) {
        client.send(message);
      }
    });
  }

  sendRelayStatus(isConnected) {
    this.broadcast({
      type: 'relayStatus',
      connected: isConnected
    });
  }
}

module.exports = LocalServer;
