import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';

class WorkingIndicator extends StatefulWidget {
  final DateTime startTime;

  const WorkingIndicator({super.key, required this.startTime});

  @override
  State<WorkingIndicator> createState() => _WorkingIndicatorState();
}

class _WorkingIndicatorState extends State<WorkingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Timer _timer;
  int _elapsed = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsed = DateTime.now().difference(widget.startTime).inSeconds;
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: NordColors.nord1,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: NordColors.nord13.withOpacity(
                    0.4 + 0.6 * _pulseController.value,
                  ),
                  shape: BoxShape.circle,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Text(
            '${_elapsed}s',
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              color: NordColors.nord4,
            ),
          ),
        ],
      ),
    );
  }
}
