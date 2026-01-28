/**
 * send_file - 사용자에게 파일 전송
 *
 * Claude가 사용자에게 파일을 보여줄 때 사용
 * 이미지, 마크다운, 텍스트 파일 지원
 */

import fs from 'fs';
import path from 'path';

/**
 * MIME 타입 판별
 */
function getMimeType(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  const mimeTypes = {
    // 이미지
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.gif': 'image/gif',
    '.webp': 'image/webp',
    '.svg': 'image/svg+xml',
    '.bmp': 'image/bmp',
    '.ico': 'image/x-icon',
    // 마크다운
    '.md': 'text/markdown',
    '.markdown': 'text/markdown',
    // 텍스트
    '.txt': 'text/plain',
    '.log': 'text/plain',
    '.csv': 'text/csv',
    // 코드 (텍스트로 처리)
    '.json': 'application/json',
    '.xml': 'text/xml',
    '.yaml': 'text/yaml',
    '.yml': 'text/yaml',
    '.html': 'text/html',
    '.css': 'text/css',
    '.js': 'text/javascript',
    '.ts': 'text/typescript',
    '.dart': 'text/x-dart',
    '.py': 'text/x-python',
    '.java': 'text/x-java',
    '.c': 'text/x-c',
    '.cpp': 'text/x-c++',
    '.h': 'text/x-c',
    '.go': 'text/x-go',
    '.rs': 'text/x-rust',
    '.sh': 'text/x-shellscript',
    '.bat': 'text/x-batch',
    '.ps1': 'text/x-powershell',
  };
  return mimeTypes[ext] || 'application/octet-stream';
}

/**
 * 파일 타입 분류
 */
function getFileType(mimeType) {
  if (mimeType.startsWith('image/')) return 'image';
  if (mimeType === 'text/markdown') return 'markdown';
  if (mimeType.startsWith('text/')) return 'text';
  return 'binary';
}

export default {
  definition: {
    name: 'send_file',
    description: '사용자에게 파일을 전송합니다. 이미지, 마크다운, 텍스트 파일을 사용자 화면에 표시할 수 있습니다.',
    inputSchema: {
      type: 'object',
      properties: {
        path: {
          type: 'string',
          description: '전송할 파일의 절대 경로',
        },
        description: {
          type: 'string',
          description: '파일에 대한 간단한 설명 (선택)',
        },
      },
      required: ['path'],
    },
  },

  async execute(workingDir, args, notifyCallback) {
    const { path: filePath, description } = args;

    if (!filePath) {
      return {
        content: [
          {
            type: 'text',
            text: 'path는 필수입니다.',
          },
        ],
        isError: true,
      };
    }

    // 절대 경로 또는 상대 경로 처리
    const absolutePath = path.isAbsolute(filePath)
      ? filePath
      : path.join(workingDir, filePath);

    try {
      // 파일 존재 확인
      if (!fs.existsSync(absolutePath)) {
        return {
          content: [
            {
              type: 'text',
              text: `파일을 찾을 수 없습니다: ${absolutePath}`,
            },
          ],
          isError: true,
        };
      }

      // 파일 정보 수집
      const stats = fs.statSync(absolutePath);
      const filename = path.basename(absolutePath);
      const mimeType = getMimeType(absolutePath);
      const fileType = getFileType(mimeType);

      // Pylon에 알림 전송
      if (notifyCallback) {
        notifyCallback('file_send', {
          path: absolutePath,
          filename,
          mimeType,
          fileType,
          size: stats.size,
          description: description || null,
        });
      }

      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              success: true,
              file: {
                path: absolutePath,
                filename,
                mimeType,
                fileType,
                size: stats.size,
                description: description || null,
              },
              message: `파일 "${filename}"을(를) 사용자에게 전송했습니다.`,
            }, null, 2),
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text',
            text: `파일 전송 실패: ${error.message}`,
          },
        ],
        isError: true,
      };
    }
  },
};
