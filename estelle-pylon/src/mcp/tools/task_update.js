/**
 * task_update - 태스크 상태 업데이트
 * 워커가 태스크 완료/실패 시 호출
 */

import fs from 'fs';
import path from 'path';

const TASK_FOLDER = 'task';

/**
 * Frontmatter 파싱
 */
function parseFrontmatter(content) {
  const match = content.match(/^---\n([\s\S]*?)\n---\n?([\s\S]*)$/);
  if (!match) return { meta: {}, body: content };

  const metaStr = match[1];
  const body = match[2];
  const meta = {};

  metaStr.split('\n').forEach(line => {
    const idx = line.indexOf(':');
    if (idx !== -1) {
      const key = line.slice(0, idx).trim();
      let value = line.slice(idx + 1).trim();
      // null 문자열 처리
      if (value === '' || value === 'null') value = null;
      meta[key] = value;
    }
  });

  return { meta, body };
}

/**
 * Frontmatter 생성
 */
function buildFrontmatter(meta) {
  const lines = ['---'];
  for (const [key, value] of Object.entries(meta)) {
    lines.push(`${key}: ${value ?? ''}`);
  }
  lines.push('---');
  return lines.join('\n');
}

/**
 * task 폴더에서 ID로 파일 찾기
 */
function findTaskFile(workingDir, taskId) {
  const taskPath = path.join(workingDir, TASK_FOLDER);
  if (!fs.existsSync(taskPath)) return null;

  const files = fs.readdirSync(taskPath).filter(f => f.endsWith('.md'));

  for (const file of files) {
    const filePath = path.join(taskPath, file);
    const content = fs.readFileSync(filePath, 'utf-8');
    const { meta } = parseFrontmatter(content);

    if (meta.id === taskId) {
      return { filePath, content, meta };
    }
  }

  return null;
}

export default {
  definition: {
    name: 'task_update',
    description: '태스크 상태를 업데이트합니다. 워커가 태스크 완료/실패 시 호출합니다.',
    inputSchema: {
      type: 'object',
      properties: {
        taskId: {
          type: 'string',
          description: '태스크 ID (UUID)',
        },
        status: {
          type: 'string',
          enum: ['pending', 'running', 'done', 'failed'],
          description: '새 상태',
        },
        error: {
          type: 'string',
          description: '실패 시 에러 메시지 (status가 failed일 때)',
        },
      },
      required: ['taskId', 'status'],
    },
  },

  async execute(workingDir, args, notifyCallback) {
    const { taskId, status, error } = args;

    if (!taskId || !status) {
      return {
        content: [
          {
            type: 'text',
            text: 'taskId와 status는 필수입니다.',
          },
        ],
        isError: true,
      };
    }

    if (!['pending', 'running', 'done', 'failed'].includes(status)) {
      return {
        content: [
          {
            type: 'text',
            text: 'status는 pending, running, done, failed 중 하나여야 합니다.',
          },
        ],
        isError: true,
      };
    }

    try {
      const taskFile = findTaskFile(workingDir, taskId);

      if (!taskFile) {
        return {
          content: [
            {
              type: 'text',
              text: `태스크를 찾을 수 없습니다: ${taskId}`,
            },
          ],
          isError: true,
        };
      }

      const { filePath, content, meta } = taskFile;
      const { body } = parseFrontmatter(content);
      const now = new Date().toISOString();

      // 상태별 시간 업데이트
      const newMeta = { ...meta, status };

      if (status === 'running' && !meta.startedAt) {
        newMeta.startedAt = now;
      }

      if (status === 'done' || status === 'failed') {
        newMeta.completedAt = now;
      }

      if (status === 'failed' && error) {
        newMeta.error = error;
      } else if (status !== 'failed') {
        newMeta.error = null;
      }

      // 파일 업데이트
      const newContent = buildFrontmatter(newMeta) + '\n\n' + body;
      fs.writeFileSync(filePath, newContent, 'utf-8');

      // Pylon에 알림 (콜백이 있으면)
      if (notifyCallback) {
        notifyCallback('task_updated', {
          taskId,
          status,
          error: newMeta.error,
          startedAt: newMeta.startedAt,
          completedAt: newMeta.completedAt,
        });
      }

      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              success: true,
              task: {
                id: taskId,
                title: meta.title,
                status,
                startedAt: newMeta.startedAt,
                completedAt: newMeta.completedAt,
                error: newMeta.error,
              },
              message: `태스크 상태가 "${status}"로 업데이트되었습니다.`,
            }, null, 2),
          },
        ],
      };
    } catch (err) {
      return {
        content: [
          {
            type: 'text',
            text: `태스크 업데이트 실패: ${err.message}`,
          },
        ],
        isError: true,
      };
    }
  },
};
