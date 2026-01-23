/// 빌드 정보 (빌드 스크립트에서 자동 생성)
class BuildInfo {
  /// 빌드 타임스탬프 (YYYYMMDDHHmmss)
  /// deploy_prepare 시점에 생성되어 모든 빌드에 동일하게 적용
  static const String buildTime = '00000000000000';

  /// 빌드 시점의 git commit hash
  static const String commit = 'dev';
}
