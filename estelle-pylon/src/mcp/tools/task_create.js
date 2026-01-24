/**
 * task_create - 새 태스크 생성
 */

import fs from 'fs';
import path from 'path';
import { randomUUID } from 'crypto';

const TASK_FOLDER = 'task';

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
 * 파일명 생성 (YYYYMMDD-title-kebab.md)
 */
function generateFileName(title) {
  const date = new Date();
  const dateStr = date.toISOString().slice(0, 10).replace(/-/g, '');

  // 한글 포함 kebab-case 변환
  const kebab = title
    .toLowerCase()
    .replace(/\s+/g, '-')
    .replace(/[^a-z0-9가-힣-]/g, '')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');

  return `${dateStr}-${kebab}.md`;
}

/**
 * task 폴더 확인/생성
 */
function ensureTaskFolder(workingDir) {
  const taskPath = path.join(workingDir, TASK_FOLDER);
  if (!fs.existsSync(taskPath)) {
    fs.mkdirSync(taskPath, { recursive: true });
  }
  return taskPath;
}

export default {
  definition: {
    name: 'task_create',
    description: '새 태스크를 생성합니다. 태스크는 워커가 자동으로 실행할 작업 단위입니다.',
    inputSchema: {
      type: 'object',
      properties: {
        title: {
          type: 'string',
          description: '태스크 제목 (한글 8~10자 이내 권장)',
        },
        content: {
          type: 'string',
          description: '태스크 본문 (마크다운 형식). 목표와 플랜을 포함해야 합니다.',
        },
      },
      required: ['title', 'content'],
    },
  },

  async execute(workingDir, args) {
    const { title, content } = args;

    if (!title || !content) {
      return {
        content: [
          {
            type: 'text',
            text: 'title과 content는 필수입니다.',
          },
        ],
        isError: true,
      };
    }

    try {
      const taskPath = ensureTaskFolder(workingDir);
      const id = randomUUID();
      const now = new Date().toISOString();

      const meta = {
        id,
        title,
        status: 'pending',
        createdAt: now,
        startedAt: null,
        completedAt: null,
        error: null,
      };

      const fileContent = buildFrontmatter(meta) + '\n\n' + content;
      const fileName = generateFileName(title);
      const filePath = path.join(taskPath, fileName);

      fs.writeFileSync(filePath, fileContent, 'utf-8');

      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              success: true,
              task: {
                id,
                title,
                status: 'pending',
                createdAt: now,
                fileName,
                filePath,
              },
              message: `태스크 "${title}"가 생성되었습니다. 워커가 자동으로 실행합니다.`,
            }, null, 2),
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text',
            text: `태스크 생성 실패: ${error.message}`,
          },
        ],
        isError: true,
      };
    }
  },
};
