import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../state/providers/relay_provider.dart';

/// Loading overlay widget for connection and loading states
class LoadingOverlay extends StatelessWidget {
  final LoadingState state;

  const LoadingOverlay({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    if (state == LoadingState.ready) {
      return const SizedBox.shrink();
    }

    final (message, icon) = _getStateInfo(state);

    return Container(
      color: NordColors.nord0.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  state == LoadingState.connecting
                      ? NordColors.nord11
                      : NordColors.nord10,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: state == LoadingState.connecting
                      ? NordColors.nord11
                      : NordColors.nord4,
                ),
                const SizedBox(width: 8),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: state == LoadingState.connecting
                        ? NordColors.nord11
                        : NordColors.nord4,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  (String, IconData) _getStateInfo(LoadingState state) {
    switch (state) {
      case LoadingState.connecting:
        return ('Connecting...', Icons.cloud_off);
      case LoadingState.loadingWorkspaces:
        return ('Loading workspaces...', Icons.folder_outlined);
      case LoadingState.ready:
        return ('', Icons.check);
    }
  }
}
