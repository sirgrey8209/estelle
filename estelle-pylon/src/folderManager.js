/**
 * Folder Manager - 폴더 탐색/생성/이름변경
 *
 * 새 워크스페이스 다이얼로그에서 사용
 */

import fs from 'fs';
import path from 'path';

const DEFAULT_BASE_PATH = 'C:\\workspace';

const folderManager = {
  /**
   * 폴더 목록 조회
   * @param {string} targetPath - 조회할 경로
   * @returns {{ success: boolean, path: string, folders: string[], error?: string }}
   */
  listFolders(targetPath = DEFAULT_BASE_PATH) {
    try {
      // 경로 정규화
      const normalizedPath = path.normalize(targetPath);

      // 경로 존재 확인
      if (!fs.existsSync(normalizedPath)) {
        return {
          success: false,
          path: normalizedPath,
          folders: [],
          error: '경로가 존재하지 않습니다.'
        };
      }

      // 디렉토리인지 확인
      const stat = fs.statSync(normalizedPath);
      if (!stat.isDirectory()) {
        return {
          success: false,
          path: normalizedPath,
          folders: [],
          error: '디렉토리가 아닙니다.'
        };
      }

      // 폴더 목록 조회
      const entries = fs.readdirSync(normalizedPath, { withFileTypes: true });
      const folders = entries
        .filter(entry => entry.isDirectory())
        .filter(entry => !entry.name.startsWith('.')) // 숨김 폴더 제외
        .filter(entry => !entry.name.startsWith('$')) // 시스템 폴더 제외
        .map(entry => entry.name)
        .sort((a, b) => a.localeCompare(b, 'ko'));

      return {
        success: true,
        path: normalizedPath,
        folders
      };
    } catch (err) {
      console.error('[FolderManager] listFolders error:', err.message);
      return {
        success: false,
        path: targetPath,
        folders: [],
        error: err.message
      };
    }
  },

  /**
   * 폴더 생성
   * @param {string} parentPath - 부모 경로
   * @param {string} folderName - 생성할 폴더 이름
   * @returns {{ success: boolean, path?: string, error?: string }}
   */
  createFolder(parentPath, folderName) {
    try {
      // 폴더명 유효성 검사
      if (!folderName || folderName.trim() === '') {
        return { success: false, error: '폴더 이름이 비어있습니다.' };
      }

      // 특수문자 검사
      const invalidChars = /[<>:"/\\|?*]/;
      if (invalidChars.test(folderName)) {
        return { success: false, error: '폴더 이름에 사용할 수 없는 문자가 포함되어 있습니다.' };
      }

      const normalizedParent = path.normalize(parentPath);
      const newFolderPath = path.join(normalizedParent, folderName.trim());

      // 부모 경로 존재 확인
      if (!fs.existsSync(normalizedParent)) {
        return { success: false, error: '상위 경로가 존재하지 않습니다.' };
      }

      // 이미 존재하는지 확인
      if (fs.existsSync(newFolderPath)) {
        return { success: false, error: '이미 존재하는 폴더입니다.' };
      }

      // 폴더 생성
      fs.mkdirSync(newFolderPath);
      console.log(`[FolderManager] Created folder: ${newFolderPath}`);

      return {
        success: true,
        path: newFolderPath
      };
    } catch (err) {
      console.error('[FolderManager] createFolder error:', err.message);
      return {
        success: false,
        error: err.code === 'EACCES' ? '권한이 없습니다.' : err.message
      };
    }
  },

  /**
   * 폴더 이름 변경
   * @param {string} folderPath - 변경할 폴더 전체 경로
   * @param {string} newName - 새 이름
   * @returns {{ success: boolean, path?: string, error?: string }}
   */
  renameFolder(folderPath, newName) {
    try {
      // 새 이름 유효성 검사
      if (!newName || newName.trim() === '') {
        return { success: false, error: '새 이름이 비어있습니다.' };
      }

      // 특수문자 검사
      const invalidChars = /[<>:"/\\|?*]/;
      if (invalidChars.test(newName)) {
        return { success: false, error: '폴더 이름에 사용할 수 없는 문자가 포함되어 있습니다.' };
      }

      const normalizedPath = path.normalize(folderPath);

      // 경로 존재 확인
      if (!fs.existsSync(normalizedPath)) {
        return { success: false, error: '폴더가 존재하지 않습니다.' };
      }

      // 디렉토리인지 확인
      const stat = fs.statSync(normalizedPath);
      if (!stat.isDirectory()) {
        return { success: false, error: '디렉토리가 아닙니다.' };
      }

      const parentDir = path.dirname(normalizedPath);
      const newPath = path.join(parentDir, newName.trim());

      // 이미 존재하는지 확인
      if (fs.existsSync(newPath)) {
        return { success: false, error: '같은 이름의 폴더가 이미 존재합니다.' };
      }

      // 이름 변경
      fs.renameSync(normalizedPath, newPath);
      console.log(`[FolderManager] Renamed folder: ${normalizedPath} -> ${newPath}`);

      return {
        success: true,
        path: newPath
      };
    } catch (err) {
      console.error('[FolderManager] renameFolder error:', err.message);
      return {
        success: false,
        error: err.code === 'EACCES' ? '권한이 없습니다.' : err.message
      };
    }
  },

  /**
   * 상위 폴더 경로 반환
   * @param {string} currentPath - 현재 경로
   * @returns {string} 상위 경로
   */
  getParentPath(currentPath) {
    const normalizedPath = path.normalize(currentPath);
    const parentPath = path.dirname(normalizedPath);

    // 루트까지 올라갔으면 현재 경로 반환
    if (parentPath === normalizedPath) {
      return normalizedPath;
    }

    return parentPath;
  },

  /**
   * 기본 경로
   */
  getDefaultPath() {
    return DEFAULT_BASE_PATH;
  }
};

export default folderManager;
