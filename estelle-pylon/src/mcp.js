#!/usr/bin/env node
/**
 * Estelle Pylon MCP Server - Deploy Only
 *
 * 배포 기능만 제공하는 간단한 MCP 서버
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import { execSync, exec } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const REPO_DIR = path.resolve(__dirname, '..', '..');

class DeployMcpServer {
  constructor() {
    this.server = new Server(
      { name: 'estelle-deploy', version: '1.0.0' },
      { capabilities: { tools: {} } }
    );
    this.setupHandlers();
  }

  setupHandlers() {
    // 도구 목록
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: 'deploy_status',
          description: 'Git 상태 및 배포 가능 여부 확인',
          inputSchema: { type: 'object', properties: {}, required: [] }
        },
        {
          name: 'deploy_run',
          description: '배포 실행 (git sync, APK/EXE 빌드, release 업로드, relay 배포)',
          inputSchema: {
            type: 'object',
            properties: {
              skipRelay: {
                type: 'boolean',
                description: 'Relay 배포 스킵 여부 (기본: false)'
              }
            },
            required: []
          }
        }
      ]
    }));

    // 도구 실행
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      switch (name) {
        case 'deploy_status':
          return this.handleStatus();
        case 'deploy_run':
          return this.handleDeploy(args?.skipRelay || false);
        default:
          return { content: [{ type: 'text', text: `Unknown tool: ${name}` }], isError: true };
      }
    });
  }

  handleStatus() {
    try {
      const gitStatus = execSync('git status --porcelain', { cwd: REPO_DIR, encoding: 'utf-8' }).trim();
      const currentBranch = execSync('git branch --show-current', { cwd: REPO_DIR, encoding: 'utf-8' }).trim();
      const localCommit = execSync('git rev-parse --short HEAD', { cwd: REPO_DIR, encoding: 'utf-8' }).trim();

      const hasChanges = gitStatus.length > 0;
      const changedFiles = hasChanges ? gitStatus.split('\n').length : 0;

      return {
        content: [{
          type: 'text',
          text: JSON.stringify({
            branch: currentBranch,
            localCommit,
            hasUncommittedChanges: hasChanges,
            changedFiles,
            canDeploy: !hasChanges,
            repoDir: REPO_DIR
          }, null, 2)
        }]
      };
    } catch (err) {
      return { content: [{ type: 'text', text: `Error: ${err.message}` }], isError: true };
    }
  }

  async handleDeploy(skipRelay) {
    try {
      const logs = [];
      const log = (msg) => logs.push(msg);

      // 1. Git status 확인
      const gitStatus = execSync('git status --porcelain', { cwd: REPO_DIR, encoding: 'utf-8' }).trim();
      if (gitStatus.length > 0) {
        return {
          content: [{
            type: 'text',
            text: `배포 불가: 커밋되지 않은 변경사항이 있습니다.\n${gitStatus}`
          }],
          isError: true
        };
      }

      log('✓ Git 상태 확인 완료');

      // 2. p1-deploy.ps1 실행
      const scriptPath = path.join(REPO_DIR, 'scripts', 'p1-deploy.ps1');
      const skipFlag = skipRelay ? '-SkipRelay' : '';

      log(`▶ 배포 스크립트 실행: ${scriptPath} ${skipFlag}`);

      const result = execSync(
        `powershell -ExecutionPolicy Bypass -File "${scriptPath}" ${skipFlag}`,
        { cwd: REPO_DIR, encoding: 'utf-8', timeout: 600000 }
      );

      log('✓ 배포 완료');
      log(result);

      return {
        content: [{
          type: 'text',
          text: logs.join('\n')
        }]
      };
    } catch (err) {
      return {
        content: [{
          type: 'text',
          text: `배포 실패: ${err.message}\n${err.stdout || ''}\n${err.stderr || ''}`
        }],
        isError: true
      };
    }
  }

  async start() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('[MCP] Estelle Deploy MCP Server started');
  }
}

const server = new DeployMcpServer();
server.start().catch((err) => {
  console.error('[MCP] Failed to start:', err);
  process.exit(1);
});
