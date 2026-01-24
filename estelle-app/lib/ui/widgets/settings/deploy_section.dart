import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/deploy_status.dart';
import '../../../state/providers/settings_provider.dart';
import '../../../state/providers/desk_provider.dart';

/// 컴팩트 배포 섹션
class DeploySection extends ConsumerWidget {
  const DeploySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(deployStatusProvider);
    final pylons = ref.watch(pylonListProvider);
    final notifier = ref.read(deployStatusProvider.notifier);

    // 외곽선 색상 결정
    final borderColor = _getBorderColor(status.phase);

    return GestureDetector(
      onTap: () {
        // 로그 박스 토글
        notifier.toggleLogExpanded();
      },
      child: Container(
        decoration: BoxDecoration(
          color: NordColors.nord1,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 메인 컨텐츠
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // 헤더: Pylon 선택 드롭다운 + Deploy 버튼
                  _DeployHeader(
                    status: status,
                    pylons: pylons,
                    notifier: notifier,
                  ),
                  const SizedBox(height: 8),
                  // 상태 한줄
                  _StatusLine(status: status),
                ],
              ),
            ),
            // 로그 박스 (확장 시)
            if (status.logExpanded) _LogBox(logs: status.logs),
          ],
        ),
      ),
    );
  }

  Color _getBorderColor(DeployPhase phase) {
    switch (phase) {
      case DeployPhase.building:
      case DeployPhase.preparing:
      case DeployPhase.deploying:
        return NordColors.nord14; // 초록
      case DeployPhase.error:
        return NordColors.nord11; // 빨강
      default:
        return NordColors.nord3; // 기본
    }
  }
}

/// 헤더: Pylon 드롭다운 + 버튼
class _DeployHeader extends StatelessWidget {
  final DeployStatus status;
  final List<dynamic> pylons;
  final DeployTrackingNotifier notifier;

  const _DeployHeader({
    required this.status,
    required this.pylons,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    // 연결된 Pylon만 필터링
    final connectedPylons = pylons.where((p) => p.isConnected).toList();

    // 기본 선택: Stella(deviceId=1) 우선, 없으면 첫 번째
    int? selectedPylonId = status.selectedPylonId;
    if (selectedPylonId == null && connectedPylons.isNotEmpty) {
      final stella = connectedPylons.where((p) => p.deviceId == 1).firstOrNull;
      selectedPylonId = stella?.deviceId ?? connectedPylons.first.deviceId;
      // 자동 선택 (UI에서만, 실제 선택은 빌드 시작할 때)
    }

    return Row(
      children: [
        // Pylon 드롭다운 (idle/error 상태에서만 변경 가능)
        Expanded(
          child: _PylonDropdown(
            selectedPylonId: selectedPylonId,
            pylons: connectedPylons,
            enabled: status.phase == DeployPhase.idle ||
                status.phase == DeployPhase.error,
            onChanged: (id) {
              if (id != null) notifier.selectPylon(id);
            },
          ),
        ),
        const SizedBox(width: 12),
        // 액션 버튼
        _ActionButton(status: status, notifier: notifier, selectedPylonId: selectedPylonId),
      ],
    );
  }
}

/// Pylon 드롭다운
class _PylonDropdown extends StatelessWidget {
  final int? selectedPylonId;
  final List<dynamic> pylons;
  final bool enabled;
  final ValueChanged<int?> onChanged;

  const _PylonDropdown({
    required this.selectedPylonId,
    required this.pylons,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (pylons.isEmpty) {
      return const Text(
        'Pylon 없음',
        style: TextStyle(color: NordColors.nord4, fontSize: 13),
      );
    }

    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: selectedPylonId,
        dropdownColor: NordColors.nord2,
        isDense: true,
        icon: Icon(
          Icons.arrow_drop_down,
          color: enabled ? NordColors.nord5 : NordColors.nord3,
        ),
        items: pylons.map((pylon) {
          return DropdownMenuItem<int>(
            value: pylon.deviceId,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pylon.icon ?? '🖥️',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 6),
                Text(
                  pylon.name ?? 'Pylon ${pylon.deviceId}',
                  style: TextStyle(
                    color: enabled ? NordColors.nord5 : NordColors.nord3,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

/// 액션 버튼 (상태에 따라 다름)
class _ActionButton extends StatelessWidget {
  final DeployStatus status;
  final DeployTrackingNotifier notifier;
  final int? selectedPylonId;

  const _ActionButton({
    required this.status,
    required this.notifier,
    required this.selectedPylonId,
  });

  @override
  Widget build(BuildContext context) {
    switch (status.phase) {
      case DeployPhase.idle:
        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: NordColors.nord10,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            minimumSize: const Size(80, 36),
          ),
          onPressed: selectedPylonId != null
              ? () {
                  notifier.selectPylon(selectedPylonId);
                  notifier.startBuild();
                }
              : null,
          child: const Text('Deploy', style: TextStyle(fontSize: 13)),
        );

      case DeployPhase.building:
      case DeployPhase.buildReady:
        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                status.confirmed ? NordColors.nord12 : NordColors.nord10,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(80, 36),
          ),
          onPressed: notifier.toggleConfirm,
          child: Text(
            status.confirmed
                ? '취소'
                : (status.phase == DeployPhase.building ? '미리승인' : '승인'),
            style: const TextStyle(fontSize: 13),
          ),
        );

      case DeployPhase.ready:
        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: NordColors.nord14,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            minimumSize: const Size(80, 36),
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
        );

      case DeployPhase.error:
        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: NordColors.nord12,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(80, 36),
          ),
          onPressed: () {
            if (selectedPylonId != null) {
              notifier.selectPylon(selectedPylonId);
            }
            notifier.startBuild();
          },
          child: const Text('재시도', style: TextStyle(fontSize: 13)),
        );

      case DeployPhase.preparing:
      case DeployPhase.deploying:
        return const SizedBox(
          width: 80,
          height: 36,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(NordColors.nord10),
              ),
            ),
          ),
        );
    }
  }
}

/// 상태 한줄 표시
class _StatusLine extends StatelessWidget {
  final DeployStatus status;

  const _StatusLine({required this.status});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 상태 아이콘
        _StatusIcon(phase: status.phase),
        const SizedBox(width: 8),
        // 상태 메시지
        Expanded(
          child: Text(
            _buildStatusText(status),
            style: TextStyle(
              fontSize: 12,
              color: status.phase == DeployPhase.error
                  ? NordColors.nord11
                  : NordColors.nord4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // 빌드 태스크 표시
        if (status.buildTasks.isNotEmpty) ...[
          const SizedBox(width: 8),
          _TaskIcons(tasks: status.buildTasks),
        ],
        // 로그 확장 힌트
        Icon(
          status.logExpanded ? Icons.expand_less : Icons.expand_more,
          color: NordColors.nord3,
          size: 18,
        ),
      ],
    );
  }

  String _buildStatusText(DeployStatus status) {
    if (status.phase == DeployPhase.idle) {
      return 'Ready to deploy';
    }
    if (status.errorMessage != null) {
      return status.errorMessage!;
    }
    // 버전/커밋 정보 추가
    String text = status.statusMessage;
    if (status.commitHash != null &&
        (status.phase == DeployPhase.buildReady ||
            status.phase == DeployPhase.ready)) {
      text += ' (${status.commitHash})';
    }
    return text;
  }
}

/// 상태 아이콘
class _StatusIcon extends StatelessWidget {
  final DeployPhase phase;

  const _StatusIcon({required this.phase});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (phase) {
      case DeployPhase.idle:
        icon = Icons.rocket_launch_outlined;
        color = NordColors.nord4;
        break;
      case DeployPhase.building:
      case DeployPhase.preparing:
        icon = Icons.sync;
        color = NordColors.nord13;
        break;
      case DeployPhase.buildReady:
        icon = Icons.check_circle_outline;
        color = NordColors.nord8;
        break;
      case DeployPhase.ready:
        icon = Icons.check_circle;
        color = NordColors.nord14;
        break;
      case DeployPhase.deploying:
        icon = Icons.cloud_upload;
        color = NordColors.nord10;
        break;
      case DeployPhase.error:
        icon = Icons.error_outline;
        color = NordColors.nord11;
        break;
    }

    return Icon(icon, color: color, size: 16);
  }
}

/// 태스크 아이콘들
class _TaskIcons extends StatelessWidget {
  final Map<String, String> tasks;

  const _TaskIcons({required this.tasks});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: tasks.entries.map((e) {
        final taskStatus = e.value;
        Color color;

        if (taskStatus == 'done') {
          color = NordColors.nord14;
        } else if (taskStatus == 'error') {
          color = NordColors.nord11;
        } else if (taskStatus == 'waiting') {
          color = NordColors.nord3;
        } else {
          color = NordColors.nord13;
        }

        return Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// 로그 박스
class _LogBox extends StatelessWidget {
  final List<String> logs;

  const _LogBox({required this.logs});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: const BoxDecoration(
        color: NordColors.nord0,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
      ),
      child: logs.isEmpty
          ? const Center(
              child: Text(
                '로그가 없습니다',
                style: TextStyle(color: NordColors.nord3, fontSize: 12),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final line = logs[index];
                final isError = line.startsWith('[ERR]');
                final isHeader = line.startsWith('▶');

                return Text(
                  line,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: isError
                        ? NordColors.nord11
                        : (isHeader ? NordColors.nord8 : NordColors.nord4),
                  ),
                );
              },
            ),
    );
  }
}
