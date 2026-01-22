import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';

class StreamingBubble extends StatefulWidget {
  final String content;

  const StreamingBubble({super.key, required this.content});

  @override
  State<StreamingBubble> createState() => _StreamingBubbleState();
}

class _StreamingBubbleState extends State<StreamingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: NordColors.nord2,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: [
          SelectableText(
            widget.content,
            style: const TextStyle(
              fontSize: 13,
              color: NordColors.nord4,
              height: 1.4,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.5 + 0.5 * (1 - _controller.value),
                  child: const Text(
                    '●',
                    style: TextStyle(
                      color: NordColors.nord8,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
