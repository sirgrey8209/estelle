import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/deploy_status.dart';
import '../../../state/providers/settings_provider.dart';
import '../../../state/providers/workspace_provider.dart';

/// 배포 상태 카드
class DeployStatusCard extends ConsumerWidget {
  const DeployStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(deployStatusProvider);
    final pylons = ref.watch(pylonListWorkspacesProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NordColors.nord0,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.rocket_launch, color: NordColors.nord13, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Deploy',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: NordColors.nord5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Status
          Text(
            'Status: ${_phaseToString(status.phase)}',
            style: TextStyle(
              fontSize: 13,
              color: _phaseToColor(status.phase),
            ),
          ),
          const SizedBox(height: 8),

          // 빌드 태스크 상태
          if (status.buildTasks.isNotEmpty) ...[
            _BuildTasksStatus(tasks: status.buildTasks),
            const SizedBox(height: 8),
          ],

          // 상태 메시지
          if (status.phase != DeployPhase.idle) ...[
            Text(
              status.statusMessage,
              style: TextStyle(
                fontSize: 12,
                color: status.phase == DeployPhase.error
                    ? NordColors.nord11
                    : NordColors.nord4,
              ),
            ),
          ],

          // 버전/커밋 정보
          if (status.commitHash != null && status.version != null) ...[
            const SizedBox(height: 4),
            Text(
              'v${status.version} (${status.commitHash})',
              style: const TextStyle(color: NordColors.nord4, fontSize: 11),
            ),
          ],

          // 에러 메시지
          if (status.errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: NordColors.nord11.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status.errorMessage!,
                style: const TextStyle(color: NordColors.nord11, fontSize: 11),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // 액션 버튼
          _DeployActions(status: status, pylons: pylons),
        ],
      ),
    );
  }

  String _phaseToString(DeployPhase phase) {
    switch (phase) {
      case DeployPhase.idle:
        return 'Idle';
      case DeployPhase.building:
        return 'Building...';
      case DeployPhase.buildReady:
        return 'Build Ready';
      case DeployPhase.preparing:
        return 'Preparing...';
      case DeployPhase.ready:
        return 'Ready';
      case DeployPhase.deploying:
        return 'Deploying...';
      case DeployPhase.error:
        return 'Error';
    }
  }

  Color _phaseToColor(DeployPhase phase) {
    switch (phase) {
      case DeployPhase.idle:
        return NordColors.nord4;
      case DeployPhase.building:
      case DeployPhase.preparing:
        return NordColors.nord13;
      case DeployPhase.buildReady:
        return NordColors.nord8;
      case DeployPhase.ready:
        return NordColors.nord14;
      case DeployPhase.deploying:
        return NordColors.nord10;
      case DeployPhase.error:
        return NordColors.nord11;
    }
  }
}

class _BuildTasksStatus extends StatelessWidget {
  final Map<String, String> tasks;

  const _BuildTasksStatus({required this.tasks});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: NordColors.nord1,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: tasks.entries.map((e) {
          final status = e.value;
          Color color;
          IconData icon;

          if (status == 'done') {
            color = NordColors.nord14;
            icon = Icons.check_circle;
          } else if (status == 'error') {
            color = NordColors.nord11;
            icon = Icons.error;
          } else if (status == 'waiting') {
            color = NordColors.nord4;
            icon = Icons.schedule;
          } else {
            color = NordColors.nord13;
            icon = Icons.sync;
          }

          return Tooltip(
            message: e.key.toUpperCase(),
            child: Icon(icon, color: color, size: 16),
          );
        }).toList(),
      ),
    );
  }
}

class _DeployActions extends ConsumerWidget {
  final DeployStatus status;
  final List<dynamic> pylons;

  const _DeployActions({
    required this.status,
    required this.pylons,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(deployStatusProvider.notifier);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Pylon 선택 (idle 상태)
        if (status.phase == DeployPhase.idle && pylons.isNotEmpty) ...[
          Expanded(
            child: DropdownButton<int>(
              value: status.selectedPylonId,
              hint: const Text(
                'Pylon 선택',
                style: TextStyle(color: NordColors.nord4, fontSize: 13),
              ),
              dropdownColor: NordColors.nord1,
              isExpanded: true,
              underline: Container(
                height: 1,
                color: NordColors.nord3,
              ),
              items: pylons.map((pylon) {
                return DropdownMenuItem<int>(
                  value: pylon.deviceId,
                  child: Text(
                    '${pylon.icon} ${pylon.name}',
                    style: const TextStyle(color: NordColors.nord5, fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  notifier.selectPylon(value);
                }
              },
            ),
          ),
          const SizedBox(width: 12),
        ],

        // 확인 버튼 (빌드 중 / 빌드 완료 상태)
        if (status.phase == DeployPhase.building ||
            status.phase == DeployPhase.buildReady)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  status.confirmed ? NordColors.nord12 : NordColors.nord10,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: notifier.toggleConfirm,
            child: Text(
              status.confirmed
                  ? '승인 취소'
                  : (status.phase == DeployPhase.building ? '미리 승인' : '승인'),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),

        // 배포 시작 버튼 (idle 상태)
        if (status.phase == DeployPhase.idle)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: NordColors.nord10,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed:
                status.selectedPylonId != null ? notifier.startBuild : null,
            child: const Text('Deploy...', style: TextStyle(fontSize: 12)),
          ),

        // GO 버튼 (ready 상태)
        if (status.phase == DeployPhase.ready)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: NordColors.nord14,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            ),
            onPressed: notifier.executeDeploy,
            child: const Text(
              'GO',
              style: TextStyle(
                color: NordColors.nord0,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),

        // 재시도 버튼 (error 상태)
        if (status.phase == DeployPhase.error)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: NordColors.nord12,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: notifier.startBuild,
            child: const Text('재시도', style: TextStyle(fontSize: 12)),
          ),

        // 배포 중 로딩
        if (status.phase == DeployPhase.deploying ||
            status.phase == DeployPhase.preparing)
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(NordColors.nord10),
            ),
          ),
      ],
    );
  }
}
