import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/build_info.dart';
import '../../../core/services/apk_installer.dart';
import '../../../state/providers/settings_provider.dart';
import '../../../state/providers/workspace_provider.dart';

/// 앱 업데이트 섹션
class AppUpdateSection extends ConsumerStatefulWidget {
  const AppUpdateSection({super.key});

  @override
  ConsumerState<AppUpdateSection> createState() => _AppUpdateSectionState();
}

class _AppUpdateSectionState extends ConsumerState<AppUpdateSection> {
  // 다운로드 상태
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = '';

  @override
  void initState() {
    super.initState();
    // 화면 진입 시 버전 체크 요청
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deployVersionProvider.notifier).requestVersionCheck();
    });
  }

  @override
  Widget build(BuildContext context) {
    final versionInfo = ref.watch(deployVersionProvider);
    final pylons = ref.watch(pylonListWorkspacesProvider);

    // 현재 플랫폼 확인 (웹 안전)
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

    // 버전 비교
    final hasUpdate = versionInfo.version != null &&
        versionInfo.version != BuildInfo.version;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NordColors.nord1,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NordColors.nord3, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Icon(
                hasUpdate ? Icons.system_update : Icons.check_circle_outline,
                color: hasUpdate ? NordColors.nord13 : NordColors.nord14,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'App Update',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: NordColors.nord5,
                ),
              ),
              const Spacer(),
              // 새로고침 버튼
              IconButton(
                onPressed: versionInfo.isLoading
                    ? null
                    : () {
                        ref
                            .read(deployVersionProvider.notifier)
                            .requestVersionCheck();
                      },
                icon: versionInfo.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(NordColors.nord4),
                        ),
                      )
                    : const Icon(Icons.refresh, size: 18),
                color: NordColors.nord4,
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 버전 정보
          Row(
            children: [
              // 배포 버전
              Expanded(
                child: _VersionInfo(
                  label: '배포',
                  version: versionInfo.version ?? '-',
                  commit: versionInfo.commit,
                  isLoading: versionInfo.isLoading,
                ),
              ),
              const SizedBox(width: 16),
              // 앱 버전
              Expanded(
                child: _VersionInfo(
                  label: '앱',
                  version: BuildInfo.version,
                  commit: BuildInfo.commit,
                  isLoading: false,
                ),
              ),
            ],
          ),

          // 다운로드 진행률 (Android만)
          if (_isDownloading && isAndroid) ...[
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _downloadProgress,
                          backgroundColor: NordColors.nord3,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            NordColors.nord8,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(_downloadProgress * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 11,
                        color: NordColors.nord4,
                      ),
                    ),
                  ],
                ),
                if (_downloadStatus.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _downloadStatus,
                    style: const TextStyle(
                      fontSize: 10,
                      color: NordColors.nord4,
                    ),
                  ),
                ],
              ],
            ),
          ],

          // 업데이트 버튼
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 업데이트 상태 텍스트
              if (!_isDownloading && hasUpdate)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Text(
                    '새 버전 있음',
                    style: TextStyle(
                      fontSize: 11,
                      color: NordColors.nord13,
                    ),
                  ),
                )
              else if (!_isDownloading && versionInfo.version != null)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Text(
                    '최신 버전',
                    style: TextStyle(
                      fontSize: 11,
                      color: NordColors.nord14,
                    ),
                  ),
                ),

              // 업데이트 버튼
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      hasUpdate ? NordColors.nord13 : NordColors.nord3,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(100, 36),
                ),
                onPressed: pylons.isEmpty || versionInfo.isUpdating || _isDownloading
                    ? null
                    : () => _handleUpdate(
                          context,
                          pylons.first.deviceId,
                          isAndroid,
                          isWindows,
                          versionInfo,
                        ),
                icon: (versionInfo.isUpdating || _isDownloading)
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        isAndroid ? Icons.android : Icons.desktop_windows,
                        size: 16,
                      ),
                label: Text(
                  _isDownloading
                      ? '다운로드 중...'
                      : (versionInfo.isUpdating ? '준비중...' : '업데이트'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),

          // 에러 메시지
          if (versionInfo.error != null) ...[
            const SizedBox(height: 8),
            Text(
              versionInfo.error!,
              style: const TextStyle(
                fontSize: 11,
                color: NordColors.nord11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _handleUpdate(
    BuildContext context,
    int pylonDeviceId,
    bool isAndroid,
    bool isWindows,
    DeployVersionInfo versionInfo,
  ) async {
    // GitHub Release 직접 열기
    final baseUrl =
        'https://github.com/sirgrey8209/estelle/releases/download/deploy';

    String url;
    if (isAndroid) {
      url = '$baseUrl/app-release.apk';
    } else if (isWindows) {
      url = '$baseUrl/estelle-windows.zip';
    } else {
      // 기타 플랫폼은 Release 페이지로
      url = 'https://github.com/sirgrey8209/estelle/releases/tag/deploy';
    }

    // Android: 다운로드 후 자동 설치
    if (isAndroid) {
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
        _downloadStatus = '';
      });

      try {
        final success = await ApkInstaller.downloadAndInstall(
          url: url,
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _downloadProgress = progress;
              });
            }
          },
          onStatusChange: (status) {
            if (mounted) {
              setState(() {
                _downloadStatus = status;
              });
            }
          },
        );

        if (mounted) {
          setState(() {
            _isDownloading = false;
          });

          if (!success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_downloadStatus.isNotEmpty
                    ? _downloadStatus
                    : '설치를 완료하려면 다운로드된 APK를 실행하세요'),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _downloadStatus = '오류: $e';
          });
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('다운로드 실패: $e')),
            );
          }
        }
      }
      return;
    }

    // Windows/기타: 브라우저에서 열기
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('URL을 열 수 없습니다')),
        );
      }
    }
  }
}

/// 버전 정보 표시 위젯
class _VersionInfo extends StatelessWidget {
  final String label;
  final String version;
  final String? commit;
  final bool isLoading;

  const _VersionInfo({
    required this.label,
    required this.version,
    this.commit,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: NordColors.nord4,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            if (isLoading)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(NordColors.nord4),
                ),
              )
            else
              Text(
                version,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: NordColors.nord5,
                ),
              ),
            if (commit != null) ...[
              const SizedBox(width: 4),
              Text(
                '($commit)',
                style: const TextStyle(
                  fontSize: 10,
                  color: NordColors.nord4,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
