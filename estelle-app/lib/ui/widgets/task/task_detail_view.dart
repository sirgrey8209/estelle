import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/workspace_info.dart';
import '../../../state/providers/workspace_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/relay_service.dart';

/// 태스크 상세 뷰 ([MD] / [채팅] 탭)
class TaskDetailView extends ConsumerStatefulWidget {
  const TaskDetailView({super.key});

  @override
  ConsumerState<TaskDetailView> createState() => _TaskDetailViewState();
}

class _TaskDetailViewState extends ConsumerState<TaskDetailView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TaskInfo? _fullTask; // 전체 내용 포함
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadTaskContent(TaskInfo task, SelectedItem selectedItem) {
    if (_fullTask?.id == task.id && _fullTask?.content != null) return;
    if (_isLoading) return;

    setState(() => _isLoading = true);

    relayService.requestTaskGet(
      selectedItem.deviceId,
      selectedItem.workspaceId,
      task.id,
    );

    // 응답은 Provider에서 처리
    relayService.messageStream.listen((data) {
      if (data['type'] == 'task_get_result') {
        final payload = data['payload'] as Map<String, dynamic>?;
        if (payload?['task'] != null) {
          final taskData = payload!['task'] as Map<String, dynamic>;
          if (taskData['id'] == task.id) {
            setState(() {
              _fullTask = TaskInfo.fromJson(taskData);
              _isLoading = false;
            });
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = ref.watch(selectedItemProvider);
    final selectedTask = ref.watch(selectedTaskProvider);
    final workspace = ref.watch(selectedWorkspaceProvider);

    if (selectedItem == null || selectedTask == null || !selectedItem.isTask) {
      return const _EmptyState(message: '태스크를 선택하세요');
    }

    // 태스크 내용 로드
    if (_fullTask?.id != selectedTask.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadTaskContent(selectedTask, selectedItem);
      });
    }

    return Column(
      children: [
        // 헤더
        _TaskHeader(task: selectedTask, workspace: workspace),

        // 탭 바
        Container(
          color: AppColors.sidebarBg,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.accent,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textMuted,
            tabs: const [
              Tab(text: 'MD'),
              Tab(text: '채팅'),
            ],
          ),
        ),

        // 탭 내용
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // MD 탭
              _MarkdownTab(
                task: _fullTask ?? selectedTask,
                isLoading: _isLoading,
              ),

              // 채팅 탭
              _ChatTab(task: selectedTask, workspace: workspace),
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskHeader extends StatelessWidget {
  final TaskInfo task;
  final WorkspaceInfo? workspace;

  const _TaskHeader({required this.task, this.workspace});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.sidebarBg,
      child: Row(
        children: [
          // 상태 아이콘
          _StatusIcon(status: task.status),
          const SizedBox(width: 12),

          // 제목
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (workspace != null)
                  Text(
                    workspace!.name,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),

          // 상태 배지
          _StatusBadge(status: task.status),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final String status;

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (status) {
      case 'running':
        icon = Icons.play_circle;
        color = AppColors.statusWorking;
        break;
      case 'done':
        icon = Icons.check_circle;
        color = AppColors.statusSuccess;
        break;
      case 'failed':
        icon = Icons.error;
        color = AppColors.statusError;
        break;
      default: // pending
        icon = Icons.schedule;
        color = AppColors.textMuted;
    }

    return Icon(icon, color: color, size: 24);
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    String label;
    Color bgColor;
    Color textColor;

    switch (status) {
      case 'running':
        label = '실행 중';
        bgColor = AppColors.statusWorking.withOpacity(0.2);
        textColor = AppColors.statusWorking;
        break;
      case 'done':
        label = '완료';
        bgColor = AppColors.statusSuccess.withOpacity(0.2);
        textColor = AppColors.statusSuccess;
        break;
      case 'failed':
        label = '실패';
        bgColor = AppColors.statusError.withOpacity(0.2);
        textColor = AppColors.statusError;
        break;
      default: // pending
        label = '대기 중';
        bgColor = AppColors.textMuted.withOpacity(0.2);
        textColor = AppColors.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}

class _MarkdownTab extends StatelessWidget {
  final TaskInfo task;
  final bool isLoading;

  const _MarkdownTab({required this.task, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final content = task.content;
    if (content == null || content.isEmpty) {
      return const _EmptyState(message: '내용을 불러오는 중...');
    }

    return Container(
      color: AppColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          content,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _ChatTab extends ConsumerWidget {
  final TaskInfo task;
  final WorkspaceInfo? workspace;

  const _ChatTab({required this.task, this.workspace});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedItem = ref.watch(selectedItemProvider);

    // 상태별 표시
    switch (task.status) {
      case 'pending':
        return _PendingTaskView(
          task: task,
          workspace: workspace,
          deviceId: selectedItem?.deviceId ?? 0,
          workspaceId: selectedItem?.workspaceId ?? '',
        );

      case 'running':
        // 실시간 채팅 - 워커 대화를 일반 채팅처럼 표시
        return _RunningTaskView(task: task);

      case 'done':
      case 'failed':
        return _CompletedChatView(task: task);

      default:
        return const _EmptyState(message: '알 수 없는 상태');
    }
  }
}

/// pending 상태 - 워커 시작 버튼 표시
class _PendingTaskView extends ConsumerWidget {
  final TaskInfo task;
  final WorkspaceInfo? workspace;
  final int deviceId;
  final String workspaceId;

  const _PendingTaskView({
    required this.task,
    this.workspace,
    required this.deviceId,
    required this.workspaceId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.play_circle_outline,
              size: 64,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              '대기 중인 태스크',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              task.title,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _startWorker(ref),
              icon: const Icon(Icons.play_arrow),
              label: const Text('워커 시작'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startWorker(WidgetRef ref) {
    if (deviceId > 0 && workspaceId.isNotEmpty) {
      relayService.startWorker(deviceId, workspaceId);
    }
  }
}

/// running 상태 - 실시간 채팅 표시
class _RunningTaskView extends StatelessWidget {
  final TaskInfo task;

  const _RunningTaskView({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // 진행 상태 표시
          Container(
            padding: const EdgeInsets.all(12),
            color: AppColors.statusWorking.withOpacity(0.1),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.statusWorking,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '워커가 "${task.title}" 작업 중...',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.statusWorking,
                  ),
                ),
              ],
            ),
          ),

          // 채팅 영역 - 워커 대화 (추후 ChatArea 통합)
          const Expanded(
            child: Center(
              child: Text(
                '실시간 대화가 여기에 표시됩니다.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedChatView extends StatelessWidget {
  final TaskInfo task;

  const _CompletedChatView({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    task.status == 'done' ? Icons.check_circle : Icons.error,
                    size: 48,
                    color: task.status == 'done'
                        ? AppColors.statusSuccess
                        : AppColors.statusError,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    task.status == 'done' ? '작업이 완료되었습니다' : '작업이 실패했습니다',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (task.error != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.statusError.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        task.error!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.statusError,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  if (task.completedAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '완료: ${_formatDateTime(task.completedAt!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 입력 비활성화 표시
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.sidebarBg,
              border: Border(
                top: BorderSide(color: AppColors.divider),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock, size: 16, color: AppColors.textMuted),
                SizedBox(width: 8),
                Text(
                  '작업이 종료되었습니다',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final String? subtitle;
  final bool showProgress;

  const _EmptyState({
    required this.message,
    this.subtitle,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showProgress) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
            ],
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
