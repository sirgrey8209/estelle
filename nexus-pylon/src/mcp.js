#!/usr/bin/env node
/**
 * Nexus Pylon MCP Server
 * 클로드 코드에서 이 파일을 MCP 서버로 등록하여 사용
 */

require('dotenv').config();
const Pylon = require('./index');
const McpServer = require('./mcpServer');

// Pylon 인스턴스 생성 및 시작
const pylon = new Pylon();
pylon.start();

// MCP 서버 시작
const mcpServer = new McpServer(pylon);
mcpServer.start().catch((err) => {
  console.error('[MCP] Failed to start:', err);
  process.exit(1);
});
