/**
 * task_list - 태스크 목록 조회
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
  const body = content.slice(match[0].length).trim();

  const meta = {};
  for (const line of frontmatter.split('\n')) {
    const colonIdx = line.indexOf(':');
    if (colonIdx > 0) {
      const key = line.slice(0, colonIdx).trim();
      const value = line.slice(colonIdx + 1).trim();
      meta[key] = value === '' ? null : value;
    }
  }

  return { meta, body };
}

export default {
  definition: {
    name: 'task_list',
    description: '현재 워크스페이스의 태스크 목록을 조회합니다.',
    inputSchema: {
      type: 'object',
      properties: {
        status: {
          type: 'string',
          description: '필터링할 상태 (pending, running, done, failed). 생략하면 전체 조회.',
          enum: ['pending', 'running', 'done', 'failed'],
        },
      },
    },
  },

  async execute(workingDir, args) {
    const { status: filterStatus } = args || {};
    const taskPath = path.join(workingDir, TASK_FOLDER);

    if (!fs.existsSync(taskPath)) {
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              success: true,
              tasks: [],
              message: '태스크가 없습니다.',
            }, null, 2),
          },
        ],
      };
    }

    try {
      const files = fs.readdirSync(taskPath)
        .filter(f => f.endsWith('.md'))
        .sort((a, b) => b.localeCompare(a)); // 최신순

      const tasks = [];
      for (const file of files) {
        const filePath = path.join(taskPath, file);
        const content = fs.readFileSync(filePath, 'utf-8');
        const { meta } = parseFrontmatter(content);

        const task = {
          id: meta.id,
          title: meta.title,
          status: meta.status || 'pending',
          createdAt: meta.createdAt,
          startedAt: meta.startedAt,
          completedAt: meta.completedAt,
          error: meta.error,
          fileName: file,
        };

        // 필터 적용
        if (!filterStatus || task.status === filterStatus) {
          tasks.push(task);
        }
      }

      // 상태별 카운트
      const summary = {
        total: files.length,
        pending: tasks.filter(t => t.status === 'pending').length,
        running: tasks.filter(t => t.status === 'running').length,
        done: tasks.filter(t => t.status === 'done').length,
        failed: tasks.filter(t => t.status === 'failed').length,
      };

      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              success: true,
              tasks,
              summary,
              message: `${tasks.length}개의 태스크가 있습니다.`,
            }, null, 2),
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text',
            text: `태스크 목록 조회 실패: ${error.message}`,
          },
        ],
        isError: true,
      };
    }
  },
};
