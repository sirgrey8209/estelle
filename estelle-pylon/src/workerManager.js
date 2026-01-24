/**
 * Worker Manager - 워커 프로세스 관리
 *
 * 워크스페이스당 워커 1개
 * pending 태스크 자동 시작, FIFO
 */

import taskManager from './taskManager.js';

// 워크스페이스별 워커 상태
const workerStates = new Map();

/**
 * 워커 상태 객체
 */
function createWorkerState() {
  return {
    status: 'idle', // idle / running
    currentTaskId: null,
    currentTaskTitle: null,
    startedAt: null,
    claudeProcess: null, // claudeManager 인스턴스 참조
    conversationId: null // 워커용 대화 ID
  };
}

const workerManager = {
  /**
   * 워커 상태 조회
   */
  getWorkerState(workspaceId) {
    if (!workerStates.has(workspaceId)) {
      workerStates.set(workspaceId, createWorkerState());
    }
    return workerStates.get(workspaceId);
  },

  /**
   * 워커 상태 요약 (API 응답용)
   */
  getWorkerStatus(workspaceId, workingDir) {
    const state = this.getWorkerState(workspaceId);

    // 태스크 큐 정보
    const taskResult = taskManager.listTasks(workingDir);
    const tasks = taskResult.success ? taskResult.tasks : [];

    const pendingCount = tasks.filter(t => t.status === 'pending').length;
    const runningTask = tasks.find(t => t.status === 'running');

    return {
      workspaceId,
      status: state.status,
      currentTask: runningTask ? {
        id: runningTask.id,
        title: runningTask.title,
        startedAt: runningTask.startedAt
      } : null,
      queue: {
        pending: pendingCount,
        total: tasks.length
      }
    };
  },

  /**
   * 워커 시작 가능 여부 확인
   */
  canStartWorker(workspaceId, workingDir) {
    const state = this.getWorkerState(workspaceId);

    // 이미 실행 중이면 불가
    if (state.status === 'running') {
      return { canStart: false, reason: '워커가 이미 실행 중입니다.' };
    }

    // pending 태스크 확인
    const nextTask = taskManager.getNextPendingTask(workingDir);
    if (!nextTask) {
      return { canStart: false, reason: 'pending 태스크가 없습니다.' };
    }

    return { canStart: true, nextTask };
  },

  /**
   * 워커 시작
   *
   * @param {string} workspaceId
   * @param {string} workingDir
   * @param {Function} startClaudeCallback - Claude 프로세스 시작 콜백
   * @returns {Promise<{success: boolean, taskId?: string, error?: string}>}
   */
  async startWorker(workspaceId, workingDir, startClaudeCallback) {
    const check = this.canStartWorker(workspaceId, workingDir);
    if (!check.canStart) {
      return { success: false, error: check.reason };
    }

    const task = check.nextTask;
    const state = this.getWorkerState(workspaceId);

    // 태스크 상태를 running으로 변경
    const updateResult = taskManager.updateTaskStatus(workingDir, task.id, 'running');
    if (!updateResult.success) {
      return { success: false, error: updateResult.error };
    }

    // 워커 상태 업데이트
    state.status = 'running';
    state.currentTaskId = task.id;
    state.currentTaskTitle = task.title;
    state.startedAt = new Date().toISOString();

    // 태스크 파일 경로
    const taskFilePath = taskManager.getTaskFilePath(workingDir, task.id);

    // Claude 프로세스 시작 (콜백으로 위임)
    // 프롬프트: /es-task-worker {path}를 꼼꼼히 구현 부탁해.
    const prompt = `/es-task-worker ${taskFilePath}를 꼼꼼히 구현 부탁해.`;

    try {
      const claudeResult = await startClaudeCallback(workspaceId, workingDir, prompt);
      state.claudeProcess = claudeResult.process;
      state.conversationId = claudeResult.conversationId;

      console.log(`[WorkerManager] Started worker for task: ${task.title}`);
      return { success: true, taskId: task.id, taskTitle: task.title };
    } catch (err) {
      // 시작 실패 시 롤백
      state.status = 'idle';
      state.currentTaskId = null;
      state.currentTaskTitle = null;
      state.startedAt = null;
      taskManager.updateTaskStatus(workingDir, task.id, 'failed', err.message);

      console.error('[WorkerManager] Failed to start worker:', err.message);
      return { success: false, error: err.message };
    }
  },

  /**
   * 워커 완료 처리
   *
   * @param {string} workspaceId
   * @param {string} workingDir
   * @param {'done' | 'failed'} status
   * @param {string?} error
   */
  completeWorker(workspaceId, workingDir, status, error = null) {
    const state = this.getWorkerState(workspaceId);

    if (state.currentTaskId) {
      // 태스크 상태 업데이트
      taskManager.updateTaskStatus(workingDir, state.currentTaskId, status, error);
      console.log(`[WorkerManager] Task ${status}: ${state.currentTaskTitle}`);
    }

    // 워커 상태 초기화
    state.status = 'idle';
    state.currentTaskId = null;
    state.currentTaskTitle = null;
    state.startedAt = null;
    state.claudeProcess = null;
    state.conversationId = null;
  },

  /**
   * 다음 태스크 자동 시작 체크
   *
   * @param {string} workspaceId
   * @param {string} workingDir
   * @param {Function} startClaudeCallback
   * @returns {Promise<boolean>} 시작 여부
   */
  async checkAndStartNext(workspaceId, workingDir, startClaudeCallback) {
    const check = this.canStartWorker(workspaceId, workingDir);

    if (check.canStart) {
      const result = await this.startWorker(workspaceId, workingDir, startClaudeCallback);
      return result.success;
    }

    return false;
  },

  /**
   * 워커 강제 중지
   */
  stopWorker(workspaceId, workingDir) {
    const state = this.getWorkerState(workspaceId);

    if (state.status !== 'running') {
      return { success: false, error: '실행 중인 워커가 없습니다.' };
    }

    // 태스크를 pending으로 되돌리기 (재시도 가능하도록)
    if (state.currentTaskId) {
      taskManager.updateTaskStatus(workingDir, state.currentTaskId, 'pending');
    }

    // 워커 상태 초기화
    state.status = 'idle';
    state.currentTaskId = null;
    state.currentTaskTitle = null;
    state.startedAt = null;
    // claudeProcess 종료는 호출자가 처리

    console.log(`[WorkerManager] Stopped worker for workspace: ${workspaceId}`);
    return { success: true };
  },

  /**
   * 워커 상태 브로드캐스트용 데이터
   */
  getAllWorkerStatuses() {
    const statuses = [];
    for (const [workspaceId, state] of workerStates) {
      statuses.push({
        workspaceId,
        status: state.status,
        currentTaskId: state.currentTaskId,
        currentTaskTitle: state.currentTaskTitle,
        startedAt: state.startedAt
      });
    }
    return statuses;
  }
};

export default workerManager;
