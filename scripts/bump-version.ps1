# Estelle 버전 업데이트 스크립트
# 사용법: .\scripts\bump-version.ps1 -Component relay|pylon|desktop|mobile

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("relay", "pylon", "desktop", "mobile")]
    [string]$Component
)

$ErrorActionPreference = "Stop"

# 경로 설정
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir = Split-Path -Parent $ScriptDir
$VersionFile = Join-Path $RepoDir "version.json"

# version.json 읽기
$Version = Get-Content $VersionFile | ConvertFrom-Json

Write-Host ""
Write-Host "Estelle Version Bump" -ForegroundColor Cyan
Write-Host "====================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Current versions:" -ForegroundColor Gray
Write-Host "  Relay:   v$($Version.relay)" -ForegroundColor Gray
Write-Host "  Pylon:   v$($Version.relay).$($Version.pylon)" -ForegroundColor Gray
Write-Host "  Desktop: v$($Version.relay).$($Version.pylon).$($Version.desktop)" -ForegroundColor Gray
Write-Host "  Mobile:  v$($Version.relay).$($Version.pylon).m$($Version.mobile)" -ForegroundColor Gray
Write-Host ""

# 버전 업데이트
switch ($Component) {
    "relay" {
        $Version.relay++
        $Version.pylon = 0
        $Version.desktop = 0
        $Version.mobile = 0
        Write-Host "Bumping Relay: v$($Version.relay) (resetting all downstream)" -ForegroundColor Yellow
    }
    "pylon" {
        $Version.pylon++
        $Version.desktop = 0
        $Version.mobile = 0
        Write-Host "Bumping Pylon: v$($Version.relay).$($Version.pylon) (resetting downstream)" -ForegroundColor Yellow
    }
    "desktop" {
        $Version.desktop++
        Write-Host "Bumping Desktop: v$($Version.relay).$($Version.pylon).$($Version.desktop)" -ForegroundColor Yellow
    }
    "mobile" {
        $Version.mobile++
        Write-Host "Bumping Mobile: v$($Version.relay).$($Version.pylon).m$($Version.mobile)" -ForegroundColor Yellow
    }
}

# version.json 업데이트
$Version | ConvertTo-Json | Set-Content $VersionFile
Write-Host "Updated version.json" -ForegroundColor Green

# 개별 패키지 버전 업데이트
$RelayVersion = "$($Version.relay)"
$PylonVersion = "$($Version.relay).$($Version.pylon)"
$DesktopVersion = "$($Version.relay).$($Version.pylon).$($Version.desktop)"
$MobileVersion = "$($Version.relay).$($Version.pylon).m$($Version.mobile)"

# Relay package.json
$RelayPkg = Join-Path $RepoDir "estelle-relay\package.json"
if (Test-Path $RelayPkg) {
    $pkg = Get-Content $RelayPkg | ConvertFrom-Json
    $pkg.version = $RelayVersion
    $pkg | ConvertTo-Json -Depth 10 | Set-Content $RelayPkg
    Write-Host "Updated estelle-relay/package.json: v$RelayVersion" -ForegroundColor Green
}

# Pylon package.json
$PylonPkg = Join-Path $RepoDir "estelle-pylon\package.json"
if (Test-Path $PylonPkg) {
    $pkg = Get-Content $PylonPkg | ConvertFrom-Json
    $pkg.version = $PylonVersion
    $pkg | ConvertTo-Json -Depth 10 | Set-Content $PylonPkg
    Write-Host "Updated estelle-pylon/package.json: v$PylonVersion" -ForegroundColor Green
}

# Desktop package.json
$DesktopPkg = Join-Path $RepoDir "estelle-desktop\package.json"
if (Test-Path $DesktopPkg) {
    $pkg = Get-Content $DesktopPkg | ConvertFrom-Json
    $pkg.version = $DesktopVersion
    $pkg | ConvertTo-Json -Depth 10 | Set-Content $DesktopPkg
    Write-Host "Updated estelle-desktop/package.json: v$DesktopVersion" -ForegroundColor Green
}

# Mobile build.gradle.kts
$MobileGradle = Join-Path $RepoDir "estelle-mobile\app\build.gradle.kts"
if (Test-Path $MobileGradle) {
    $content = Get-Content $MobileGradle -Raw
    $content = $content -replace 'versionName = "[^"]*"', "versionName = `"$MobileVersion`""
    $content = $content -replace 'versionCode = \d+', "versionCode = $($Version.relay * 10000 + $Version.pylon * 100 + $Version.mobile + 1)"
    Set-Content $MobileGradle $content
    Write-Host "Updated estelle-mobile/app/build.gradle.kts: v$MobileVersion" -ForegroundColor Green
}

Write-Host ""
Write-Host "New versions:" -ForegroundColor Cyan
Write-Host "  Relay:   v$RelayVersion" -ForegroundColor White
Write-Host "  Pylon:   v$PylonVersion" -ForegroundColor White
Write-Host "  Desktop: v$DesktopVersion" -ForegroundColor White
Write-Host "  Mobile:  v$MobileVersion" -ForegroundColor White
Write-Host ""

# Git 작업
Write-Host "Creating git commit and tag..." -ForegroundColor Yellow

Set-Location $RepoDir

# 변경된 파일 스테이징
git add version.json
git add estelle-relay/package.json
git add estelle-pylon/package.json
git add estelle-desktop/package.json
git add estelle-mobile/app/build.gradle.kts

# 태그 결정
switch ($Component) {
    "relay" { $Tag = "v$RelayVersion" }
    "pylon" { $Tag = "v$PylonVersion" }
    "desktop" { $Tag = "v$DesktopVersion" }
    "mobile" { $Tag = "v$MobileVersion" }
}

# 커밋 생성
git commit -m "Bump $Component version to $Tag"

# 태그 생성
git tag $Tag

Write-Host ""
Write-Host "Created commit and tag: $Tag" -ForegroundColor Green
Write-Host ""
Write-Host "To push changes:" -ForegroundColor Yellow
Write-Host "  git push origin main" -ForegroundColor White
Write-Host "  git push origin $Tag" -ForegroundColor White
Write-Host ""

# Mobile인 경우 APK 빌드 안내
if ($Component -eq "mobile") {
    Write-Host "Push the tag to trigger APK build:" -ForegroundColor Cyan
    Write-Host "  git push origin $Tag" -ForegroundColor White
    Write-Host ""
    Write-Host "APK will be available at:" -ForegroundColor Gray
    Write-Host "  https://github.com/sirgrey8209/estelle/releases/latest" -ForegroundColor White
}
