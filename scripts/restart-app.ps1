# restart-app.ps1 - Desktop 앱 재시작
# 기존 EXE 종료 후 새 EXE 실행
#
# 사용법: .\scripts\restart-app.ps1
# 결과: JSON { success, exePath, message }

param(
    [string]$RepoDir = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)

$ErrorActionPreference = "Stop"
$AppDir = Join-Path $RepoDir "estelle-app"
$ReleaseDir = Join-Path $AppDir "release"
$ExeName = "estelle_flutter.exe"
$ExePath = Join-Path $ReleaseDir $ExeName

try {
    # 1. EXE 존재 확인
    if (-not (Test-Path $ExePath)) {
        throw "EXE not found: $ExePath"
    }

    # 2. 실행 중인 프로세스 종료
    $running = Get-Process -Name "estelle_flutter" -ErrorAction SilentlyContinue
    if ($running) {
        $running | Stop-Process -Force
        Start-Sleep -Milliseconds 500
    }

    # 3. 새 EXE 실행
    Start-Process -FilePath $ExePath -WorkingDirectory $ReleaseDir

    @{
        success = $true
        exePath = $ExePath
        wasRunning = [bool]$running
        message = "App restarted"
    } | ConvertTo-Json

} catch {
    @{
        success = $false
        message = $_.Exception.Message
    } | ConvertTo-Json
    exit 1
}
