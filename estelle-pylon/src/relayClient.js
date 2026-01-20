const WebSocket = require('ws');

class RelayClient {
  constructor(url, deviceId) {
    this.url = url;
    this.deviceId = deviceId;
    this.ws = null;
    this.reconnectInterval = 3000;
    this.isConnected = false;
    this.onMessageCallback = null;
    this.onStatusChangeCallback = null;
  }

  connect() {
    console.log(`[${new Date().toISOString()}] Connecting to Relay: ${this.url}`);

    this.ws = new WebSocket(this.url);

    this.ws.on('open', () => {
      this.isConnected = true;
      console.log(`[${new Date().toISOString()}] Connected to Relay`);

      if (this.onStatusChangeCallback) {
        this.onStatusChangeCallback(true);
      }

      // 식별 메시지 전송
      this.send({
        type: 'identify',
        deviceId: this.deviceId,
        deviceType: 'pylon'
      });
    });

    this.ws.on('message', (message) => {
      try {
        const data = JSON.parse(message.toString());
        console.log(`[${new Date().toISOString()}] From Relay:`, data);

        if (this.onMessageCallback) {
          this.onMessageCallback(data);
        }
      } catch (err) {
        console.error(`[${new Date().toISOString()}] Invalid message:`, message.toString());
      }
    });

    this.ws.on('close', () => {
      this.isConnected = false;
      console.log(`[${new Date().toISOString()}] Disconnected from Relay`);

      if (this.onStatusChangeCallback) {
        this.onStatusChangeCallback(false);
      }

      // 재연결
      console.log(`[${new Date().toISOString()}] Reconnecting in ${this.reconnectInterval}ms...`);
      setTimeout(() => this.connect(), this.reconnectInterval);
    });

    this.ws.on('error', (err) => {
      console.error(`[${new Date().toISOString()}] Relay connection error:`, err.message);
    });
  }

  send(data) {
    if (this.ws && this.isConnected) {
      this.ws.send(JSON.stringify(data));
    } else {
      console.warn(`[${new Date().toISOString()}] Cannot send, not connected to Relay`);
    }
  }

  onMessage(callback) {
    this.onMessageCallback = callback;
  }

  onStatusChange(callback) {
    this.onStatusChangeCallback = callback;
  }

  getStatus() {
    return this.isConnected;
  }
}

module.exports = RelayClient;
