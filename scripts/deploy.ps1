# Estelle Deploy Script (Manual)
# 수동 배포용 스크립트 - 로컬에서 빌드 후 배포
# P2는 Relay 재접속 시 자동 업데이트됨
#
# 사용법:
#   .\scripts\deploy.ps1                    # 자동 버전 (현재 커밋, version.json 기반)
#   .\scripts\deploy.ps1 -Commit abc1234    # 특정 커밋
#   .\scripts\deploy.ps1 -Version 1.2.3     # 특정 버전
#   .\scripts\deploy.ps1 -Force             # 동일 버전이어도 재배포

param(
    [string]$Commit,      # 특정 커밋 (생략 시 현재 HEAD)
    [string]$Version,     # 특정 버전 (생략 시 version.json 기반)
    [switch]$Force,       # 동일 버전 재배포
    [switch]$SkipRelay    # Relay 배포 스킵
)

$ErrorActionPreference = "Stop"

# 경로 설정
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir = Split-Path -Parent $ScriptDir
$VersionFile = Join-Path $RepoDir "version.json"
$AppDir = Join-Path $RepoDir "estelle-app"
$RelayDir = Join-Path $RepoDir "estelle-relay"
$PylonDir = Join-Path $RepoDir "estelle-pylon"

# 도구 경로
$FlyExe = Join-Path $env:USERPROFILE ".fly\bin\fly.exe"
$GhExe = "C:\Program Files\GitHub CLI\gh.exe"
$FlutterExe = "C:\flutter\bin\flutter.bat"

# GitHub 설정
$GitHubRepo = "sirgrey8209/estelle"
$ReleaseName = "deploy"

Write-Host ""
Write-Host "Estelle Deploy (Manual)" -ForegroundColor Cyan
Write-Host "=======================" -ForegroundColor Cyan
Write-Host ""

# 현재/지정 Git 커밋
if ($Commit) {
    $GitCommit = $Commit
    Write-Host "Using specified commit: $GitCommit" -ForegroundColor Yellow
} else {
    $GitCommit = git -C $RepoDir rev-parse --short HEAD
    Write-Host "Current Git Commit: $GitCommit" -ForegroundColor Gray
}

# 버전 결정
if ($Version) {
    $DeployVersion = $Version
    Write-Host "Using specified version: $DeployVersion" -ForegroundColor Yellow
} else {
    # version.json에서 읽기
    $VersionJson = Get-Content $VersionFile | ConvertFrom-Json
    $DeployVersion = "$($VersionJson.relay).$($VersionJson.pylon).$($VersionJson.desktop)"
    Write-Host "Version from version.json: $DeployVersion" -ForegroundColor Gray
}

# GitHub Release에서 현재 deploy.json 확인
Write-Host ""
Write-Host "Checking current deployment..." -ForegroundColor Yellow
$DeployedInfo = $null
try {
    $TempFile = Join-Path $env:TEMP "deploy.json"
    & $GhExe release download $ReleaseName --repo $GitHubRepo --pattern "deploy.json" --output $TempFile --clobber 2>$null
    if (Test-Path $TempFile) {
        $DeployedInfo = Get-Content $TempFile | ConvertFrom-Json
        Remove-Item $TempFile -Force

        Write-Host "Deployed Version:" -ForegroundColor Gray
        Write-Host "  Commit:  $($DeployedInfo.commit)" -ForegroundColor Gray
        Write-Host "  Version: $($DeployedInfo.version)" -ForegroundColor Gray
    }
} catch {
    Write-Host "No existing deployment found" -ForegroundColor Gray
}

# 동일 버전 체크
if ($DeployedInfo -and $GitCommit -eq $DeployedInfo.commit -and -not $Force) {
    Write-Host ""
    Write-Host "Already deployed with same commit!" -ForegroundColor Green
    $Confirm = Read-Host "Redeploy anyway? (y/N)"
    if ($Confirm -ne "y" -and $Confirm -ne "Y") {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host ""
Write-Host "Deploy Info:" -ForegroundColor Cyan
Write-Host "  Commit:  $GitCommit" -ForegroundColor White
Write-Host "  Version: $DeployVersion" -ForegroundColor White
Write-Host ""

# 1. Flutter APK 빌드
Write-Host "Building APK..." -ForegroundColor Yellow
Push-Location $AppDir
try {
    & $FlutterExe build apk --release
    if ($LASTEXITCODE -ne 0) { throw "APK build failed" }
} finally {
    Pop-Location
}
Write-Host "APK build completed" -ForegroundColor Green

# 2. Flutter Windows EXE 빌드
Write-Host ""
Write-Host "Building Windows EXE..." -ForegroundColor Yellow
Push-Location $AppDir
try {
    & $FlutterExe build windows --release
    if ($LASTEXITCODE -ne 0) { throw "Windows build failed" }
} finally {
    Pop-Location
}
Write-Host "Windows build completed" -ForegroundColor Green

# 3. Relay 배포 (옵션)
if (-not $SkipRelay) {
    Write-Host ""
    Write-Host "Deploying Relay..." -ForegroundColor Yellow
    Push-Location $RelayDir
    try {
        & $FlyExe deploy
        if ($LASTEXITCODE -ne 0) { throw "Relay deploy failed" }
    } finally {
        Pop-Location
    }
    Write-Host "Relay deployed" -ForegroundColor Green
}

# 4. deploy.json 생성
Write-Host ""
Write-Host "Creating deploy.json..." -ForegroundColor Yellow

$DeployJson = @{
    commit = $GitCommit
    version = $DeployVersion
    deployedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

$DeployJsonPath = Join-Path $RepoDir "deploy.json"
$DeployJson | ConvertTo-Json | Set-Content $DeployJsonPath
Write-Host "Created deploy.json" -ForegroundColor Green

# 5. GitHub Release 업로드
Write-Host ""
Write-Host "Uploading to GitHub Release..." -ForegroundColor Yellow

# deploy.json 업로드
& $GhExe release upload $ReleaseName $DeployJsonPath --repo $GitHubRepo --clobber
Write-Host "  deploy.json uploaded" -ForegroundColor Green

# APK 업로드
$ApkPath = Join-Path $AppDir "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $ApkPath) {
    & $GhExe release upload $ReleaseName $ApkPath --repo $GitHubRepo --clobber
    Write-Host "  APK uploaded" -ForegroundColor Green
}

# Windows EXE ZIP 생성 및 업로드
$ExeDir = Join-Path $AppDir "build\windows\x64\runner\Release"
$ZipPath = Join-Path $AppDir "build\estelle-windows.zip"
if (Test-Path $ExeDir) {
    Write-Host "  Creating Windows ZIP..." -ForegroundColor Gray
    Compress-Archive -Path "$ExeDir\*" -DestinationPath $ZipPath -Force
    & $GhExe release upload $ReleaseName $ZipPath --repo $GitHubRepo --clobber
    Write-Host "  Windows ZIP uploaded" -ForegroundColor Green
}

# 로컬 deploy.json 삭제
Remove-Item $DeployJsonPath -Force

Write-Host ""
Write-Host "Deploy Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  Commit:  $GitCommit" -ForegroundColor White
Write-Host "  Version: $DeployVersion" -ForegroundColor White
Write-Host ""
Write-Host "Other Pylons will auto-update on Relay reconnect." -ForegroundColor Gray
Write-Host ""
