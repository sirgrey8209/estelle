/**
 * Task Manager - 태스크 파일 관리
 *
 * task/ 폴더의 MD 파일을 스캔하고 관리
 *
 * 태스크 파일 형식:
 * ---
 * id: 550e8400-e29b-41d4-a716-446655440000
 * title: 버튼 색상 변경
 * status: pending
 * createdAt: 2026-01-24T10:00:00Z
 * startedAt:
 * completedAt:
 * error:
 * ---
 *
 * ## 목표
 * ...
 */

import fs from 'fs';
import path from 'path';
import { randomUUID } from 'crypto';

const TASK_FOLDER = 'task';
const MAX_CONTENT_LENGTH = 10000; // truncate 기준

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

const taskManager = {
  /**
   * 워크스페이스의 task 폴더 경로
   */
  getTaskFolderPath(workingDir) {
    return path.join(workingDir, TASK_FOLDER);
  },

  /**
   * task 폴더 확인/생성
   */
  ensureTaskFolder(workingDir) {
    const taskPath = this.getTaskFolderPath(workingDir);
    if (!fs.existsSync(taskPath)) {
      fs.mkdirSync(taskPath, { recursive: true });
      console.log(`[TaskManager] Created task folder: ${taskPath}`);
    }
    return taskPath;
  },

  /**
   * 태스크 목록 조회 (메타데이터만)
   */
  listTasks(workingDir) {
    const taskPath = this.getTaskFolderPath(workingDir);

    if (!fs.existsSync(taskPath)) {
      return { success: true, tasks: [] };
    }

    try {
      const files = fs.readdirSync(taskPath)
        .filter(f => f.endsWith('.md'))
        .sort((a, b) => b.localeCompare(a)); // 최신순 (날짜 내림차순)

      const tasks = [];
      for (const file of files) {
        const filePath = path.join(taskPath, file);
        const content = fs.readFileSync(filePath, 'utf-8');
        const { meta } = parseFrontmatter(content);

        tasks.push({
          id: meta.id,
          title: meta.title,
          status: meta.status || 'pending',
          createdAt: meta.createdAt,
          startedAt: meta.startedAt,
          completedAt: meta.completedAt,
          error: meta.error,
          fileName: file
        });
      }

      return { success: true, tasks };
    } catch (err) {
      console.error('[TaskManager] listTasks error:', err.message);
      return { success: false, tasks: [], error: err.message };
    }
  },

  /**
   * 태스크 상세 조회 (본문 포함)
   */
  getTask(workingDir, taskId) {
    const taskPath = this.getTaskFolderPath(workingDir);

    if (!fs.existsSync(taskPath)) {
      return { success: false, error: '태스크 폴더가 없습니다.' };
    }

    try {
      // taskId로 파일 찾기
      const files = fs.readdirSync(taskPath).filter(f => f.endsWith('.md'));

      for (const file of files) {
        const filePath = path.join(taskPath, file);
        const content = fs.readFileSync(filePath, 'utf-8');
        const { meta, body } = parseFrontmatter(content);

        if (meta.id === taskId) {
          // 긴 내용은 truncate
          const truncated = body.length > MAX_CONTENT_LENGTH;
          const displayBody = truncated
            ? body.slice(0, MAX_CONTENT_LENGTH) + '\n\n... (내용이 잘렸습니다)'
            : body;

          return {
            success: true,
            task: {
              id: meta.id,
              title: meta.title,
              status: meta.status || 'pending',
              createdAt: meta.createdAt,
              startedAt: meta.startedAt,
              completedAt: meta.completedAt,
              error: meta.error,
              fileName: file,
              content: displayBody,
              truncated
            }
          };
        }
      }

      return { success: false, error: '태스크를 찾을 수 없습니다.' };
    } catch (err) {
      console.error('[TaskManager] getTask error:', err.message);
      return { success: false, error: err.message };
    }
  },

  /**
   * 태스크 생성
   */
  createTask(workingDir, title, body) {
    const taskPath = this.ensureTaskFolder(workingDir);

    try {
      const id = randomUUID();
      const now = new Date().toISOString();

      const meta = {
        id,
        title,
        status: 'pending',
        createdAt: now,
        startedAt: null,
        completedAt: null,
        error: null
      };

      const content = buildFrontmatter(meta) + '\n\n' + body;
      const fileName = generateFileName(title);
      const filePath = path.join(taskPath, fileName);

      fs.writeFileSync(filePath, content, 'utf-8');
      console.log(`[TaskManager] Created task: ${title} (${id})`);

      return {
        success: true,
        task: {
          id,
          title,
          status: 'pending',
          createdAt: now,
          fileName,
          filePath
        }
      };
    } catch (err) {
      console.error('[TaskManager] createTask error:', err.message);
      return { success: false, error: err.message };
    }
  },

  /**
   * 태스크 상태 업데이트
   */
  updateTaskStatus(workingDir, taskId, status, error = null) {
    const taskPath = this.getTaskFolderPath(workingDir);

    if (!fs.existsSync(taskPath)) {
      return { success: false, error: '태스크 폴더가 없습니다.' };
    }

    try {
      const files = fs.readdirSync(taskPath).filter(f => f.endsWith('.md'));

      for (const file of files) {
        const filePath = path.join(taskPath, file);
        const content = fs.readFileSync(filePath, 'utf-8');
        const { meta, body } = parseFrontmatter(content);

        if (meta.id === taskId) {
          const now = new Date().toISOString();

          meta.status = status;

          if (status === 'running' && !meta.startedAt) {
            meta.startedAt = now;
          }

          if (status === 'done' || status === 'failed') {
            meta.completedAt = now;
          }

          if (error) {
            meta.error = error;
          }

          const newContent = buildFrontmatter(meta) + '\n\n' + body;
          fs.writeFileSync(filePath, newContent, 'utf-8');

          console.log(`[TaskManager] Updated task status: ${meta.title} -> ${status}`);
          return { success: true, task: { ...meta, fileName: file } };
        }
      }

      return { success: false, error: '태스크를 찾을 수 없습니다.' };
    } catch (err) {
      console.error('[TaskManager] updateTaskStatus error:', err.message);
      return { success: false, error: err.message };
    }
  },

  /**
   * pending 태스크 조회 (FIFO)
   */
  getNextPendingTask(workingDir) {
    const result = this.listTasks(workingDir);
    if (!result.success) return null;

    // pending 상태 태스크 중 가장 오래된 것 (파일명 기준)
    const pendingTasks = result.tasks
      .filter(t => t.status === 'pending')
      .sort((a, b) => a.fileName.localeCompare(b.fileName));

    return pendingTasks[0] || null;
  },

  /**
   * running 태스크 조회
   */
  getRunningTask(workingDir) {
    const result = this.listTasks(workingDir);
    if (!result.success) return null;

    return result.tasks.find(t => t.status === 'running') || null;
  },

  /**
   * 태스크 파일 경로 조회
   */
  getTaskFilePath(workingDir, taskId) {
    const taskPath = this.getTaskFolderPath(workingDir);

    if (!fs.existsSync(taskPath)) return null;

    const files = fs.readdirSync(taskPath).filter(f => f.endsWith('.md'));

    for (const file of files) {
      const filePath = path.join(taskPath, file);
      const content = fs.readFileSync(filePath, 'utf-8');
      const { meta } = parseFrontmatter(content);

      if (meta.id === taskId) {
        return filePath;
      }
    }

    return null;
  }
};

export default taskManager;
