import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import 'claude_usage_card.dart';
import 'deploy_section.dart';
import 'app_update_section.dart';

/// 설정 화면 메인 위젯
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: NordColors.nord0,
      child: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClaudeUsageCard(),
            SizedBox(height: 16),
            DeploySection(),
            SizedBox(height: 16),
            AppUpdateSection(),
          ],
        ),
      ),
    );
  }
}

/// 설정 화면 내용 (Dialog/Screen 공용)
class SettingsContent extends ConsumerWidget {
  const SettingsContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClaudeUsageCard(),
        SizedBox(height: 16),
        DeploySection(),
        SizedBox(height: 16),
        AppUpdateSection(),
      ],
    );
  }
}
