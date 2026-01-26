/**
 * Blob Handler - 대용량 파일(이미지) 전송 처리
 */

import fs from 'fs';
import path from 'path';
import crypto from 'crypto';

const UPLOADS_DIR = path.join(process.cwd(), 'uploads');
const CHUNK_SIZE = 65536; // 64KB

// 진행 중인 전송
const activeTransfers = new Map();

/**
 * 업로드 폴더 초기화
 */
export function initUploadsDir() {
  if (!fs.existsSync(UPLOADS_DIR)) {
    fs.mkdirSync(UPLOADS_DIR, { recursive: true });
  }
}

/**
 * Blob 전송 핸들러
 */
export class BlobHandler {
  constructor(sendFn) {
    this.send = sendFn;
    initUploadsDir();
  }

  /**
   * blob_start 처리
   */
  handleBlobStart(message) {
    const { payload, from } = message;
    const {
      blobId,
      filename,
      mimeType,
      totalSize,
      chunkSize,
      totalChunks,
      encoding,
      context,
      sameDevice,
      localPath,
    } = payload;

    console.log(`[BLOB] Start: ${blobId} (${filename}, ${totalSize} bytes, ${totalChunks} chunks)`);

    // 동일 디바이스면 로컬 경로 직접 사용
    if (sameDevice && localPath) {
      console.log(`[BLOB] Same device, using local path: ${localPath}`);

      // 로컬 파일 존재 확인
      if (fs.existsSync(localPath)) {
        activeTransfers.set(blobId, {
          blobId,
          filename,
          mimeType,
          totalSize,
          totalChunks,
          context,
          localPath,
          sameDevice: true,
          completed: true,
        });
        return { success: true, path: localPath, sameDevice: true };
      }
    }

    // 대화별 폴더 생성
    const conversationId = context?.conversationId || 'unknown';
    const conversationDir = path.join(UPLOADS_DIR, conversationId);
    if (!fs.existsSync(conversationDir)) {
      fs.mkdirSync(conversationDir, { recursive: true });
    }

    // 저장 경로
    const timestamp = Date.now();
    const safeFilename = filename.replace(/[^a-zA-Z0-9._-]/g, '_');
    const savePath = path.join(conversationDir, `${timestamp}_${safeFilename}`);

    // 전송 정보 저장
    activeTransfers.set(blobId, {
      blobId,
      filename,
      mimeType,
      totalSize,
      chunkSize,
      totalChunks,
      encoding,
      context,
      from,
      savePath,
      chunks: new Array(totalChunks).fill(null),
      receivedCount: 0,
      completed: false,
    });

    return { success: true };
  }

  /**
   * blob_chunk 처리
   */
  handleBlobChunk(message) {
    const { payload } = message;
    const { blobId, index, data, size } = payload;

    const transfer = activeTransfers.get(blobId);
    if (!transfer) {
      console.error(`[BLOB] Unknown transfer: ${blobId}`);
      return { success: false, error: 'Unknown transfer' };
    }

    if (transfer.sameDevice) {
      // 동일 디바이스면 청크 무시
      return { success: true };
    }

    // Base64 디코딩
    const chunk = Buffer.from(data, 'base64');
    transfer.chunks[index] = chunk;
    transfer.receivedCount++;

    // 진행률 로그 (10% 단위)
    const progress = Math.floor((transfer.receivedCount / transfer.totalChunks) * 10);
    if (transfer.receivedCount === 1 || progress > (transfer.lastProgress || 0)) {
      console.log(`[BLOB] ${blobId}: ${transfer.receivedCount}/${transfer.totalChunks} chunks (${progress * 10}%)`);
      transfer.lastProgress = progress;
    }

    return { success: true, received: transfer.receivedCount };
  }

  /**
   * blob_end 처리
   */
  handleBlobEnd(message) {
    const { payload } = message;
    const { blobId, checksum, totalReceived, skipped } = payload;

    const transfer = activeTransfers.get(blobId);
    if (!transfer) {
      console.error(`[BLOB] Unknown transfer: ${blobId}`);
      return { success: false, error: 'Unknown transfer' };
    }

    // 동일 디바이스면 이미 완료
    if (transfer.sameDevice || skipped) {
      console.log(`[BLOB] Complete (same device): ${blobId} -> ${transfer.localPath}`);
      transfer.completed = true;
      return {
        success: true,
        path: transfer.localPath,
        context: transfer.context,
      };
    }

    // 모든 청크 조합
    const allChunks = transfer.chunks.filter(c => c !== null);
    if (allChunks.length !== transfer.totalChunks) {
      console.error(`[BLOB] Missing chunks: ${allChunks.length}/${transfer.totalChunks}`);
      return {
        success: false,
        error: `Missing chunks: ${allChunks.length}/${transfer.totalChunks}`
      };
    }

    const fileBuffer = Buffer.concat(allChunks);

    // 체크섬 검증 (선택적)
    if (checksum) {
      const hash = crypto.createHash('sha256').update(fileBuffer).digest('hex');
      const expectedHash = checksum.replace('sha256:', '');
      if (hash !== expectedHash) {
        console.error(`[BLOB] Checksum mismatch: ${hash} !== ${expectedHash}`);
        return { success: false, error: 'Checksum mismatch' };
      }
    }

    // 파일 저장
    fs.writeFileSync(transfer.savePath, fileBuffer);
    console.log(`[BLOB] Complete: ${blobId} -> ${transfer.savePath}`);

    transfer.completed = true;

    // 메모리 정리
    transfer.chunks = [];

    return {
      success: true,
      path: transfer.savePath,
      context: transfer.context,
    };
  }

  /**
   * blob_request 처리 (클라이언트가 이미지 요청)
   */
  handleBlobRequest(message) {
    const { payload, from } = message;
    const { blobId, filename, localPath } = payload;

    // 파일 찾기
    let filePath = localPath;

    if (!filePath || !fs.existsSync(filePath)) {
      // uploads 폴더에서 검색
      filePath = this.findFile(filename);
    }

    if (!filePath || !fs.existsSync(filePath)) {
      console.error(`[BLOB] File not found: ${filename}`);
      return { success: false, error: 'File not found' };
    }

    // 파일 읽기 및 청크 전송
    const fileBuffer = fs.readFileSync(filePath);
    const mimeType = this.getMimeType(filename);
    const totalChunks = Math.ceil(fileBuffer.length / CHUNK_SIZE);

    // blob_start 전송
    this.send({
      type: 'blob_start',
      to: from,
      payload: {
        blobId,
        filename,
        mimeType,
        totalSize: fileBuffer.length,
        chunkSize: CHUNK_SIZE,
        totalChunks,
        encoding: 'base64',
        context: { type: 'file_transfer' },
      },
    });

    // 청크 전송
    for (let i = 0; i < totalChunks; i++) {
      const start = i * CHUNK_SIZE;
      const end = Math.min(start + CHUNK_SIZE, fileBuffer.length);
      const chunk = fileBuffer.slice(start, end);

      this.send({
        type: 'blob_chunk',
        to: from,
        payload: {
          blobId,
          index: i,
          data: chunk.toString('base64'),
          size: chunk.length,
        },
      });
    }

    // blob_end 전송
    const checksum = crypto.createHash('sha256').update(fileBuffer).digest('hex');
    this.send({
      type: 'blob_end',
      to: from,
      payload: {
        blobId,
        checksum: `sha256:${checksum}`,
        totalReceived: fileBuffer.length,
      },
    });

    return { success: true };
  }

  /**
   * uploads 폴더에서 파일 검색
   */
  findFile(filename) {
    const searchRecursive = (dir) => {
      if (!fs.existsSync(dir)) return null;

      const entries = fs.readdirSync(dir, { withFileTypes: true });
      for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);
        if (entry.isDirectory()) {
          const found = searchRecursive(fullPath);
          if (found) return found;
        } else if (entry.name.endsWith(filename)) {
          return fullPath;
        }
      }
      return null;
    };

    return searchRecursive(UPLOADS_DIR);
  }

  /**
   * MIME 타입 추정
   */
  getMimeType(filename) {
    const ext = path.extname(filename).toLowerCase();
    const mimeTypes = {
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.gif': 'image/gif',
      '.webp': 'image/webp',
      '.svg': 'image/svg+xml',
      '.bmp': 'image/bmp',
    };
    return mimeTypes[ext] || 'application/octet-stream';
  }

  /**
   * 전송 정보 조회
   */
  getTransfer(blobId) {
    return activeTransfers.get(blobId);
  }

  /**
   * 완료된 전송 정리
   */
  cleanup(blobId) {
    activeTransfers.delete(blobId);
  }
}
