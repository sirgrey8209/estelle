# generate-build-info.ps1 - build_info.dart 생성
# 사용법: .\scripts\generate-build-info.ps1 -BuildTime 20260123113000 [-Version v0.1]
# 결과: JSON { success, buildTime, commit, version, message }

param(
    [Parameter(Mandatory=$true)]
    [string]$BuildTime,
    [string]$Version,
    [string]$RepoDir = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)

$ErrorActionPreference = "Stop"
$GhExe = "C:\Program Files\GitHub CLI\gh.exe"
$GitHubRepo = "sirgrey8209/estelle"

try {
    Push-Location $RepoDir

    # Git commit 가져오기
    $commit = git rev-parse --short HEAD

    # 버전 결정 (입력 없으면 deploy.json에서 가져옴)
    if (-not $Version) {
        try {
            $currentDeploy = & $GhExe release download deploy -p "deploy.json" --repo $GitHubRepo -O - 2>$null | ConvertFrom-Json
            $Version = $currentDeploy.version
        } catch {
            $Version = "v0.1"
        }
    }

    # build_info.dart 경로
    $buildInfoPath = Join-Path $RepoDir "estelle-app\lib\core\constants\build_info.dart"

    # 파일 생성
    $content = @"
/// 빌드 정보 (빌드 스크립트에서 자동 생성)
class BuildInfo {
  /// 앱 버전 (deploy.json에서 가져옴)
  static const String version = '$Version';

  /// 빌드 타임스탬프 (YYYYMMDDHHmmss)
  /// deploy_prepare 시점에 생성되어 모든 빌드에 동일하게 적용
  static const String buildTime = '$BuildTime';

  /// 빌드 시점의 git commit hash
  static const String commit = '$commit';
}
"@

    Set-Content -Path $buildInfoPath -Value $content -Encoding UTF8

    @{
        success = $true
        buildTime = $BuildTime
        commit = $commit
        version = $Version
        message = "build_info.dart generated"
    } | ConvertTo-Json

} catch {
    @{
        success = $false
        message = $_.Exception.Message
    } | ConvertTo-Json
    exit 1
} finally {
    Pop-Location
}
