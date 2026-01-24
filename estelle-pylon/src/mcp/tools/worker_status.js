/**
 * worker_status - 워커 상태 조회
 */

import fs from 'fs';
import path from 'path';

const TASK_FOLDER = 'task';

/**
 * Frontmatter 파싱
 */
function parseFrontmatter(content) {
  const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!match) return { meta: {}, body: content };

  const frontmatter = match[1];

  const meta = {};
  for (const line of frontmatter.split('\n')) {
    const colonIdx = line.indexOf(':');
    if (colonIdx > 0) {
      const key = line.slice(0, colonIdx).trim();
      const value = line.slice(colonIdx + 1).trim();
      meta[key] = value === '' ? null : value;
    }
  }

  return { meta };
}

export default {
  definition: {
    name: 'worker_status',
    description: '워커의 현재 상태를 조회합니다. 실행 중인 태스크와 큐 정보를 확인할 수 있습니다.',
    inputSchema: {
      type: 'object',
      properties: {},
    },
  },

  async execute(workingDir, args) {
    const taskPath = path.join(workingDir, TASK_FOLDER);

    if (!fs.existsSync(taskPath)) {
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              success: true,
              status: 'idle',
              currentTask: null,
              queue: {
                pending: 0,
                total: 0,
              },
              message: '워커가 대기 중입니다. 태스크가 없습니다.',
            }, null, 2),
          },
        ],
      };
    }

    try {
      const files = fs.readdirSync(taskPath)
        .filter(f => f.endsWith('.md'));

      let runningTask = null;
      let pendingCount = 0;

      for (const file of files) {
        const filePath = path.join(taskPath, file);
        const content = fs.readFileSync(filePath, 'utf-8');
        const { meta } = parseFrontmatter(content);

        if (meta.status === 'running') {
          runningTask = {
            id: meta.id,
            title: meta.title,
            startedAt: meta.startedAt,
            fileName: file,
          };
        } else if (meta.status === 'pending') {
          pendingCount++;
        }
      }

      const status = runningTask ? 'running' : 'idle';

      let message;
      if (runningTask) {
        message = `워커가 "${runningTask.title}" 태스크를 실행 중입니다.`;
        if (pendingCount > 0) {
          message += ` 대기 중인 태스크가 ${pendingCount}개 있습니다.`;
        }
      } else if (pendingCount > 0) {
        message = `워커가 대기 중입니다. ${pendingCount}개의 태스크가 대기 중입니다.`;
      } else {
        message = '워커가 대기 중입니다. 실행할 태스크가 없습니다.';
      }

      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              success: true,
              status,
              currentTask: runningTask,
              queue: {
                pending: pendingCount,
                total: files.length,
              },
              message,
            }, null, 2),
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text',
            text: `워커 상태 조회 실패: ${error.message}`,
          },
        ],
        isError: true,
      };
    }
  },
};
