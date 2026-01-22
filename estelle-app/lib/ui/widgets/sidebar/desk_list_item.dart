import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/desk_info.dart';

class DeskListItem extends StatelessWidget {
  final DeskInfo desk;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onSettingsTap;

  const DeskListItem({
    super.key,
    required this.desk,
    required this.isSelected,
    required this.onTap,
    this.onSettingsTap,
  });

  Color _getTextColor() {
    if (desk.status == 'working') return NordColors.nord13;
    if (desk.status == 'waiting') return NordColors.nord12;
    if (desk.status == 'error') return NordColors.nord11;
    return isSelected ? NordColors.nord6 : NordColors.nord4;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? NordColors.nord10 : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  desk.deskName,
                  style: TextStyle(
                    fontSize: 13,
                    color: _getTextColor(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusIndicator(status: desk.status),
              // 선택된 경우 설정 버튼 표시
              if (isSelected && onSettingsTap != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onSettingsTap,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: const Icon(
                      Icons.more_vert,
                      size: 16,
                      color: NordColors.nord4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 데스크 상태 표시
/// idle: 🟢 초록색, working: 🟡 노란색 점멸, waiting: 🔴 붉은색, error: ❌
class _StatusIndicator extends StatelessWidget {
  final String status;

  const _StatusIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'working':
        return const _BlinkingDot(color: NordColors.nord13); // 노란색 점멸
      case 'waiting':
        return const _StaticDot(color: NordColors.nord11); // 붉은색
      case 'error':
        return const Icon(Icons.close, size: 12, color: NordColors.nord11);
      case 'idle':
      default:
        return const _StaticDot(color: NordColors.nord14); // 초록색
    }
  }
}

class _StaticDot extends StatelessWidget {
  final Color color;

  const _StaticDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  final Color color;

  const _BlinkingDot({required this.color});

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color.withOpacity(_animation.value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
