const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} = require('@modelcontextprotocol/sdk/types.js');

class McpServer {
  constructor(pylon) {
    this.pylon = pylon;
    this.server = new Server(
      {
        name: 'estelle-pylon',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.setupHandlers();
  }

  setupHandlers() {
    // 도구 목록
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      return {
        tools: [
          {
            name: 'estelle_status',
            description: 'Estelle 연결 상태 확인 (Relay, Desktop 연결 여부)',
            inputSchema: {
              type: 'object',
              properties: {},
              required: [],
            },
          },
          {
            name: 'estelle_send',
            description: 'Relay를 통해 메시지 전송',
            inputSchema: {
              type: 'object',
              properties: {
                message: {
                  type: 'string',
                  description: '전송할 메시지',
                },
              },
              required: ['message'],
            },
          },
          {
            name: 'estelle_echo',
            description: 'Echo 테스트 (Relay 왕복 확인)',
            inputSchema: {
              type: 'object',
              properties: {
                payload: {
                  type: 'string',
                  description: 'Echo 테스트할 내용',
                },
              },
              required: ['payload'],
            },
          },
          {
            name: 'estelle_desktop_notify',
            description: 'Desktop 앱에 알림 전송',
            inputSchema: {
              type: 'object',
              properties: {
                title: {
                  type: 'string',
                  description: '알림 제목',
                },
                message: {
                  type: 'string',
                  description: '알림 내용',
                },
              },
              required: ['message'],
            },
          },
        ],
      };
    });

    // 도구 실행
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      switch (name) {
        case 'estelle_status':
          return this.handleStatus();

        case 'estelle_send':
          return this.handleSend(args.message);

        case 'estelle_echo':
          return this.handleEcho(args.payload);

        case 'estelle_desktop_notify':
          return this.handleDesktopNotify(args.title, args.message);

        default:
          return {
            content: [
              {
                type: 'text',
                text: `Unknown tool: ${name}`,
              },
            ],
            isError: true,
          };
      }
    });
  }

  handleStatus() {
    const relayStatus = this.pylon.relayClient?.getStatus() || false;
    const desktopCount = this.pylon.localServer?.clients?.size || 0;

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            relay: relayStatus ? 'connected' : 'disconnected',
            desktopClients: desktopCount,
            deviceId: this.pylon.deviceId,
          }, null, 2),
        },
      ],
    };
  }

  handleSend(message) {
    if (!this.pylon.relayClient?.getStatus()) {
      return {
        content: [
          {
            type: 'text',
            text: 'Error: Not connected to Relay',
          },
        ],
        isError: true,
      };
    }

    this.pylon.relayClient.send({
      type: 'message',
      from: this.pylon.deviceId,
      payload: message,
    });

    return {
      content: [
        {
          type: 'text',
          text: `Message sent: ${message}`,
        },
      ],
    };
  }

  handleEcho(payload) {
    if (!this.pylon.relayClient?.getStatus()) {
      return {
        content: [
          {
            type: 'text',
            text: 'Error: Not connected to Relay',
          },
        ],
        isError: true,
      };
    }

    this.pylon.relayClient.send({
      type: 'echo',
      from: this.pylon.deviceId,
      payload: payload,
    });

    return {
      content: [
        {
          type: 'text',
          text: `Echo request sent: ${payload}`,
        },
      ],
    };
  }

  handleDesktopNotify(title, message) {
    const desktopCount = this.pylon.localServer?.clients?.size || 0;

    if (desktopCount === 0) {
      return {
        content: [
          {
            type: 'text',
            text: 'Error: No Desktop clients connected',
          },
        ],
        isError: true,
      };
    }

    this.pylon.localServer.broadcast({
      type: 'notification',
      title: title || 'Estelle',
      message: message,
    });

    return {
      content: [
        {
          type: 'text',
          text: `Notification sent to ${desktopCount} client(s)`,
        },
      ],
    };
  }

  async start() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('[MCP] Estelle Pylon MCP Server started');
  }
}

module.exports = McpServer;
