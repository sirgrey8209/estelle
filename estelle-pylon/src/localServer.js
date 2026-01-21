import { WebSocketServer, WebSocket } from 'ws';
import logger from './logger.js';
import packetLogger from './packetLogger.js';

class LocalServer {
  constructor(port) {
    this.port = port;
    this.wss = null;
    this.clients = new Set();
    this.onMessageCallback = null;
    this.onConnectCallback = null;
    this.getRelayStatus = () => false;
  }

  start() {
    this.wss = new WebSocketServer({ port: this.port });

    this.wss.on('listening', () => {
      logger.log(`[${new Date().toISOString()}] Local server started on port ${this.port}`);
    });

    this.wss.on('connection', (ws) => {
      this.clients.add(ws);
      logger.log(`[${new Date().toISOString()}] Desktop connected. Total: ${this.clients.size}`);

      ws.send(JSON.stringify({
        type: 'connected',
        message: 'Connected to Pylon',
        relayStatus: this.getRelayStatus()
      }));

      if (this.onConnectCallback) {
        this.onConnectCallback(ws);
      }

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

  stop() {
    if (this.wss) {
      this.wss.close();
    }
  }

  setRelayStatusCallback(callback) {
    this.getRelayStatus = callback;
  }

  onMessage(callback) {
    this.onMessageCallback = callback;
  }

  onConnect(callback) {
    this.onConnectCallback = callback;
  }

  broadcast(data) {
    if (data.type !== 'relay_status' && data.type !== 'pong') {
      packetLogger.logSend('desktop', data);
    }

    const message = JSON.stringify(data);
    this.clients.forEach((client) => {
      if (client.readyState === WebSocket.OPEN) {
        client.send(message);
      }
    });
  }

  sendRelayStatus(isConnected) {
    this.broadcast({
      type: 'relay_status',
      connected: isConnected
    });
  }
}

export default LocalServer;
