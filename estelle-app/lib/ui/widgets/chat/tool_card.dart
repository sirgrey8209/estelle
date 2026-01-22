import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/claude_message.dart';

class ToolCard extends StatefulWidget {
  final ToolCallMessage message;

  const ToolCard({super.key, required this.message});

  @override
  State<ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<ToolCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final parsed = ToolInputParser.parse(m.toolName, m.toolInput);
    final hasOutput = m.output != null && m.output!.trim().isNotEmpty;
    final hasError = m.error != null && m.error!.trim().isNotEmpty;

    Color borderColor;
    String statusIcon;
    Color statusColor;

    if (!m.isComplete) {
      borderColor = NordColors.nord13;
      statusIcon = '⋯';
      statusColor = NordColors.nord13;
    } else if (m.success == true) {
      borderColor = NordColors.nord14;
      statusIcon = '✓';
      statusColor = NordColors.nord14;
    } else {
      borderColor = NordColors.nord11;
      statusIcon = '✗';
      statusColor = NordColors.nord11;
    }

    return GestureDetector(
      onTap: hasOutput || hasError ? () => setState(() => _expanded = !_expanded) : null,
      child: Container(
        decoration: BoxDecoration(
          color: NordColors.nord1,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    statusIcon,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    m.toolName,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: NordColors.nord9,
                    ),
                  ),
                  if (parsed.desc.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        parsed.desc,
                        style: TextStyle(
                          fontSize: 10,
                          color: NordColors.nord4.withOpacity(0.8),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Command
            if (parsed.cmd.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 18, right: 6, bottom: 3),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: NordColors.nord0,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    parsed.cmd,
                    style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: NordColors.nord4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

            // Expanded output
            if (_expanded && hasOutput)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: NordColors.nord0,
                  border: Border(
                    top: BorderSide(color: NordColors.nord2),
                  ),
                ),
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(
                  child: SelectableText(
                    m.output!,
                    style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: NordColors.nord4,
                    ),
                  ),
                ),
              ),

            // Error
            if (m.isComplete && hasError)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: NordColors.nord11.withOpacity(0.15),
                ),
                child: SelectableText(
                  m.error!,
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: NordColors.nord11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
