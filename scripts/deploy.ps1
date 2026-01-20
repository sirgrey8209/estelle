# Estelle Deploy Script
# 사용법: .\scripts\deploy.ps1

param(
    [switch]$Force  # Synced 상태에서 재배포 시 사용
)

$ErrorActionPreference = "Stop"

# 경로 설정
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir = Split-Path -Parent $ScriptDir
$VersionFile = Join-Path $RepoDir "version.json"

# 도구 경로
$FlyExe = Join-Path $env:USERPROFILE ".fly\bin\fly.exe"
$GhExe = "C:\Program Files\GitHub CLI\gh.exe"

# Java 자동 감지 (JAVA_HOME이 없는 경우)
if (-not $env:JAVA_HOME) {
    $JavaPaths = @(
        "C:\Program Files\Microsoft\jdk-17*",
        "C:\Program Files\Eclipse Adoptium\jdk-17*",
        "C:\Program Files\Java\jdk-17*",
        "C:\Program Files\Android\Android Studio\jbr"
    )
    foreach ($pattern in $JavaPaths) {
        $found = Get-Item $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $env:JAVA_HOME = $found.FullName
            Write-Host "Auto-detected JAVA_HOME: $env:JAVA_HOME" -ForegroundColor Gray
            break
        }
    }
}
if (-not $env:JAVA_HOME) {
    Write-Host "ERROR: JAVA_HOME not found. Install JDK 17." -ForegroundColor Red
    exit 1
}
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"

# Android SDK 자동 감지 (ANDROID_HOME이 없는 경우)
if (-not $env:ANDROID_HOME) {
    $SdkPaths = @(
        "$env:LOCALAPPDATA\Android\Sdk",
        "$env:USERPROFILE\AppData\Local\Android\Sdk"
    )
    foreach ($path in $SdkPaths) {
        if (Test-Path $path) {
            $env:ANDROID_HOME = $path
            Write-Host "Auto-detected ANDROID_HOME: $env:ANDROID_HOME" -ForegroundColor Gray
            break
        }
    }
}
if (-not $env:ANDROID_HOME) {
    Write-Host "ERROR: ANDROID_HOME not found. Install Android SDK." -ForegroundColor Red
    exit 1
}

# GitHub 설정
$GitHubRepo = "sirgrey8209/estelle"
$ReleaseName = "deploy"

Write-Host ""
Write-Host "Estelle Deploy" -ForegroundColor Cyan
Write-Host "==============" -ForegroundColor Cyan
Write-Host ""

# 현재 Git 커밋 해시
$GitCommit = git -C $RepoDir rev-parse --short HEAD
Write-Host "Current Git Commit: $GitCommit" -ForegroundColor Gray

# version.json 읽기
$Version = Get-Content $VersionFile | ConvertFrom-Json
$RelayVersion = "$($Version.relay)"
$PylonVersion = "$($Version.relay).$($Version.pylon)"
$DesktopVersion = "$($Version.relay).$($Version.pylon).$($Version.desktop)"
$MobileVersion = "$($Version.relay).$($Version.pylon).m$($Version.mobile)"

Write-Host "Current Versions:" -ForegroundColor Gray
Write-Host "  Relay:   $RelayVersion" -ForegroundColor Gray
Write-Host "  Pylon:   $PylonVersion" -ForegroundColor Gray
Write-Host "  Desktop: $DesktopVersion" -ForegroundColor Gray
Write-Host "  Mobile:  $MobileVersion" -ForegroundColor Gray
Write-Host ""

# GitHub Release에서 현재 deploy.json 가져오기
Write-Host "Checking current deployment..." -ForegroundColor Yellow
$DeployedInfo = $null
try {
    $ReleaseInfo = & $GhExe release view $ReleaseName --repo $GitHubRepo --json assets,body 2>$null | ConvertFrom-Json
    if ($ReleaseInfo) {
        # deploy.json 다운로드
        $TempFile = Join-Path $env:TEMP "deploy.json"
        & $GhExe release download $ReleaseName --repo $GitHubRepo --pattern "deploy.json" --output $TempFile --clobber 2>$null
        if (Test-Path $TempFile) {
            $DeployedInfo = Get-Content $TempFile | ConvertFrom-Json
            Remove-Item $TempFile -Force
        }
    }
} catch {
    Write-Host "No existing deployment found" -ForegroundColor Gray
}

# 상태 판단
$Status = "Deploy"  # 기본: 새 배포
$NeedsUpdate = $false

if ($DeployedInfo) {
    Write-Host "Deployed Version:" -ForegroundColor Gray
    Write-Host "  Commit:  $($DeployedInfo.commit)" -ForegroundColor Gray
    Write-Host "  Relay:   $($DeployedInfo.relay)" -ForegroundColor Gray
    Write-Host "  Pylon:   $($DeployedInfo.pylon)" -ForegroundColor Gray
    Write-Host "  Desktop: $($DeployedInfo.desktop)" -ForegroundColor Gray
    Write-Host "  Mobile:  $($DeployedInfo.mobile)" -ForegroundColor Gray
    Write-Host ""

    if ($GitCommit -eq $DeployedInfo.commit) {
        $Status = "Synced"
        Write-Host "Status: Synced (Git commit matches deployed)" -ForegroundColor Green

        if (-not $Force) {
            $Confirm = Read-Host "Versions are identical. Redeploy? (y/N)"
            if ($Confirm -ne "y" -and $Confirm -ne "Y") {
                Write-Host "Cancelled." -ForegroundColor Yellow
                exit 0
            }
        }
    } else {
        Write-Host "Status: Deploy (New commits available)" -ForegroundColor Yellow
    }
} else {
    Write-Host "Status: Deploy (First deployment)" -ForegroundColor Yellow
}

Write-Host ""

# 시간코드 생성 함수
function Get-TimeCode {
    param([string]$PrevTimeCode)

    $Now = Get-Date
    $DateCode = $Now.ToString("MMdd")

    if (-not $PrevTimeCode -or -not $PrevTimeCode.StartsWith($DateCode)) {
        return $DateCode
    }

    $HourCode = $Now.ToString("MMddHH")
    if (-not $PrevTimeCode.StartsWith($HourCode.Substring(0, 6))) {
        return $HourCode
    }

    $MinCode = $Now.ToString("MMddHHmm")
    if (-not $PrevTimeCode.StartsWith($MinCode.Substring(0, 8))) {
        return $MinCode
    }

    return $Now.ToString("MMddHHmmss")
}

# 버전 비교: 이전 배포와 기본 버전이 같은지 확인
$NeedTimeCode = $false
if ($DeployedInfo) {
    # 이전 배포의 기본 버전 추출 (타임코드 제외)
    $PrevRelayBase = ($DeployedInfo.relay -split "-")[0]

    # 기본 버전이 같으면 타임코드 필요
    if ($PrevRelayBase -eq $RelayVersion) {
        $NeedTimeCode = $true
    }
}

# 새 버전 생성
if ($NeedTimeCode) {
    # 이전 시간코드 추출
    $PrevTimeCode = ""
    if ($DeployedInfo.relay -match "-(\d+)$") {
        $PrevTimeCode = $Matches[1]
    }
    $TimeCode = Get-TimeCode -PrevTimeCode $PrevTimeCode

    $NewRelayVersion = "$RelayVersion-$TimeCode"
    $NewPylonVersion = "$PylonVersion-$TimeCode"
    $NewDesktopVersion = "$DesktopVersion-$TimeCode"
    $NewMobileVersion = "$MobileVersion-$TimeCode"
} else {
    # 첫 배포 또는 버전 업 → 타임코드 없이
    $NewRelayVersion = $RelayVersion
    $NewPylonVersion = $PylonVersion
    $NewDesktopVersion = $DesktopVersion
    $NewMobileVersion = $MobileVersion
}

Write-Host "New Deploy Versions:" -ForegroundColor Cyan
Write-Host "  Relay:   $NewRelayVersion" -ForegroundColor White
Write-Host "  Pylon:   $NewPylonVersion" -ForegroundColor White
Write-Host "  Desktop: $NewDesktopVersion" -ForegroundColor White
Write-Host "  Mobile:  $NewMobileVersion" -ForegroundColor White
Write-Host ""

# deploy.json 생성
$DeployJson = @{
    commit = $GitCommit
    deployedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    relay = $NewRelayVersion
    pylon = $NewPylonVersion
    desktop = $NewDesktopVersion
    mobile = $NewMobileVersion
}

$DeployJsonPath = Join-Path $RepoDir "deploy.json"
$DeployJson | ConvertTo-Json | Set-Content $DeployJsonPath
Write-Host "Created deploy.json" -ForegroundColor Green

# 1. Relay 배포
Write-Host ""
Write-Host "Deploying Relay..." -ForegroundColor Yellow
Push-Location (Join-Path $RepoDir "estelle-relay")
& $FlyExe deploy
Pop-Location
Write-Host "Relay deployed" -ForegroundColor Green

# 2. GitHub Release 생성/업데이트
Write-Host ""
Write-Host "Creating GitHub Release..." -ForegroundColor Yellow

# 기존 릴리스 삭제 (있으면)
$ErrorActionPreference = "SilentlyContinue"
& $GhExe release delete $ReleaseName --repo $GitHubRepo --yes 2>&1 | Out-Null
$ErrorActionPreference = "Stop"

# 새 릴리스 생성
& $GhExe release create $ReleaseName `
    --repo $GitHubRepo `
    --title "Estelle Deploy" `
    --notes "Deployed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`nCommit: $GitCommit" `
    $DeployJsonPath

Write-Host "GitHub Release created" -ForegroundColor Green

# deploy.json 로컬 파일 삭제
Remove-Item $DeployJsonPath -Force

# 3. Android APK 로컬 빌드
Write-Host ""
Write-Host "Building Android APK locally..." -ForegroundColor Yellow

$MobileDir = Join-Path $RepoDir "estelle-mobile"
$GradleWrapper = Join-Path $MobileDir "gradlew.bat"

# version.properties 업데이트
$VersionPropsPath = Join-Path $MobileDir "version.properties"
@"
VERSION_NAME=$NewMobileVersion
VERSION_CODE=$((Get-Date -UFormat %s) -replace '\..*', '')
"@ | Set-Content $VersionPropsPath

# Gradle 빌드
Push-Location $MobileDir
try {
    & $GradleWrapper assembleRelease --no-daemon
    if ($LASTEXITCODE -ne 0) {
        throw "Gradle build failed"
    }
} finally {
    Pop-Location
}

# APK 파일 찾기
$ApkPath = Get-ChildItem -Path "$MobileDir\app\build\outputs\apk\release\*.apk" | Select-Object -First 1
if (-not $ApkPath) {
    Write-Host "APK not found!" -ForegroundColor Red
    exit 1
}

Write-Host "APK built: $($ApkPath.Name)" -ForegroundColor Green

# GitHub Release에 APK 업로드
Write-Host "Uploading APK to GitHub Release..." -ForegroundColor Yellow
& $GhExe release upload $ReleaseName $ApkPath.FullName --repo $GitHubRepo --clobber
Write-Host "APK uploaded" -ForegroundColor Green

Write-Host ""
Write-Host "Deploy Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Deployed versions:" -ForegroundColor Cyan
Write-Host "  Relay:   $NewRelayVersion" -ForegroundColor White
Write-Host "  Pylon:   $NewPylonVersion" -ForegroundColor White
Write-Host "  Desktop: $NewDesktopVersion" -ForegroundColor White
Write-Host "  Mobile:  $NewMobileVersion" -ForegroundColor White
Write-Host ""
Write-Host "Clients will auto-update on next start or receive update notification." -ForegroundColor Gray
