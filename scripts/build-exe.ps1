# build-exe.ps1 - Flutter Windows EXE 빌드
#
# 사용법: .\scripts\build-exe.ps1 [-BuildTime 20260123113000]
# 결과: JSON { success, path, buildTime, message }

param(
    [string]$BuildTime,
    [string]$RepoDir = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)

$ErrorActionPreference = "Stop"
$FlutterExe = "C:\flutter\bin\flutter.bat"
$AppDir = Join-Path $RepoDir "estelle-app"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ScriptDir) { $ScriptDir = Join-Path $RepoDir "scripts" }

try {
    # BuildTime 없으면 생성
    if (-not $BuildTime) {
        $BuildTime = Get-Date -Format "yyyyMMddHHmmss"
    }

    # build_info.dart 생성
    $buildInfoResult = & "$ScriptDir\generate-build-info.ps1" -BuildTime $BuildTime -RepoDir $RepoDir | ConvertFrom-Json
    if (-not $buildInfoResult.success) {
        throw $buildInfoResult.message
    }

    Push-Location $AppDir

    # Flutter build
    & $FlutterExe build windows --release 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter Windows build failed"
    }

    $exeDir = Join-Path $AppDir "build\windows\x64\runner\Release"
    $exePath = Join-Path $exeDir "estelle_flutter.exe"

    if (-not (Test-Path $exePath)) {
        throw "EXE file not found"
    }

    @{
        success = $true
        path = $exeDir
        exePath = $exePath
        buildTime = $BuildTime
        message = "Windows build completed"
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
