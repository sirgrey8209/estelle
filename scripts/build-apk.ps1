# build-apk.ps1 - Flutter APK 빌드
#
# 사용법: .\scripts\build-apk.ps1
# 결과: JSON { success, path, size, message }

param(
    [string]$RepoDir = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)

$ErrorActionPreference = "Stop"
$FlutterExe = "C:\flutter\bin\flutter.bat"
$AppDir = Join-Path $RepoDir "estelle-app"

try {
    Push-Location $AppDir

    # Flutter build
    & $FlutterExe build apk --release 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter APK build failed"
    }

    $apkPath = Join-Path $AppDir "build\app\outputs\flutter-apk\app-release.apk"

    if (-not (Test-Path $apkPath)) {
        throw "APK file not found"
    }

    $size = (Get-Item $apkPath).Length
    $sizeMB = [math]::Round($size / 1MB, 1)

    @{
        success = $true
        path = $apkPath
        size = "$($sizeMB)MB"
        message = "APK build completed"
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
