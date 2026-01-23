import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../state/providers/settings_provider.dart';
import 'claude_usage_card.dart';
import 'deploy_status_card.dart';

/// 설정 화면 메인 위젯
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // 화면 진입 시 사용량 요청
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(claudeUsageProvider.notifier).requestUsage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: NordColors.nord0,
      child: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClaudeUsageCard(),
            SizedBox(height: 16),
            DeployStatusCard(),
          ],
        ),
      ),
    );
  }
}

/// 설정 화면 내용 (Dialog/Screen 공용)
class SettingsContent extends ConsumerStatefulWidget {
  const SettingsContent({super.key});

  @override
  ConsumerState<SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends ConsumerState<SettingsContent> {
  @override
  void initState() {
    super.initState();
    // 화면 진입 시 사용량 요청
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(claudeUsageProvider.notifier).requestUsage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClaudeUsageCard(),
        SizedBox(height: 16),
        DeployStatusCard(),
      ],
    );
  }
}
