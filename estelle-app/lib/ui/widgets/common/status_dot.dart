import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 상태 표시 점
///
/// 상태 종류:
/// - idle: 표시 안 함
/// - working: 노란색 점멸 (작업 중)
/// - waiting: 빨간색 점멸 (대기 중 - 권한 요청 등)
/// - permission: 빨간색 점멸 (권한 요청)
/// - error: 빨간색 고정 (에러)
/// - unread: 초록색 고정 (읽지 않음)
/// - done: 초록색 고정 (완료)
class StatusDot extends StatefulWidget {
  final String status;
  final double size;
  final EdgeInsets margin;

  const StatusDot({
    super.key,
    required this.status,
    this.size = 8,
    this.margin = const EdgeInsets.only(left: 4),
  });

  /// 상태 문자열에서 색상 반환 (null이면 표시 안 함)
  static Color? getStatusColor(String status) {
    switch (status) {
      case 'error':
        return AppColors.statusError;
      case 'permission':
      case 'waiting':
        return AppColors.statusError;
      case 'working':
        return AppColors.statusWorking;
      case 'unread':
      case 'done':
        return AppColors.statusSuccess;
      default:
        return null;
    }
  }

  /// 점멸 여부
  static bool shouldBlink(String status) {
    return status == 'working' ||
        status == 'waiting' ||
        status == 'permission';
  }

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  bool get _shouldBlink => StatusDot.shouldBlink(widget.status);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    if (_shouldBlink) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = StatusDot.getStatusColor(widget.status);
    if (color == null) return const SizedBox.shrink();

    if (_shouldBlink) {
      return AnimatedBuilder(
        animation: _animation,
        builder: (context, child) => Container(
          width: widget.size,
          height: widget.size,
          margin: widget.margin,
          decoration: BoxDecoration(
            color: color.withOpacity(_animation.value),
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    return Container(
      width: widget.size,
      height: widget.size,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

