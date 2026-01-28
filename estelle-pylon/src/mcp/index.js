/**
 * Estelle MCP Server
 *
 * Pylon에 내장되는 MCP 서버
 * Claude가 대화에서 태스크를 생성하고 관리할 수 있게 해줌
 *
 * 사용법:
 * Claude 설정에서 MCP 서버로 등록:
 * {
 *   "mcpServers": {
 *     "estelle": {
 *       "command": "node",
 *       "args": ["path/to/estelle-pylon/src/mcp/index.js"],
 *       "env": {
 *         "ESTELLE_WORKING_DIR": "C:\\workspace\\project"
 *       }
 *     }
 *   }
 * }
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';

import taskCreate from './tools/task_create.js';
import taskList from './tools/task_list.js';
import taskUpdate from './tools/task_update.js';
import workerStatus from './tools/worker_status.js';
import sendFile from './tools/send_file.js';

const WORKING_DIR = process.env.ESTELLE_WORKING_DIR || process.cwd();

class EstelleMcpServer {
  constructor() {
    this.server = new Server(
      {
        name: 'estelle-mcp',
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
    // 도구 목록 반환
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      return {
        tools: [
          taskCreate.definition,
          taskList.definition,
          taskUpdate.definition,
          workerStatus.definition,
          sendFile.definition,
        ],
      };
    });

    // 알림 콜백 (stderr로 JSON 출력 → Pylon이 감지)
    const notifyCallback = (type, data) => {
      console.error(JSON.stringify({ _estelle_notify: true, type, data }));
    };

    // 도구 실행
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case 'task_create': {
            const result = await taskCreate.execute(WORKING_DIR, args);
            // 태스크 생성 알림
            notifyCallback('task_created', args);
            return result;
          }
          case 'task_list':
            return await taskList.execute(WORKING_DIR, args);
          case 'task_update': {
            const result = await taskUpdate.execute(WORKING_DIR, args, notifyCallback);
            return result;
          }
          case 'worker_status':
            return await workerStatus.execute(WORKING_DIR, args);
          case 'send_file':
            return await sendFile.execute(WORKING_DIR, args, notifyCallback);
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
      } catch (error) {
        return {
          content: [
            {
              type: 'text',
              text: `Error executing ${name}: ${error.message}`,
            },
          ],
          isError: true,
        };
      }
    });
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('[Estelle MCP] Server started');
  }
}

// 실행
const server = new EstelleMcpServer();
server.run().catch(console.error);
