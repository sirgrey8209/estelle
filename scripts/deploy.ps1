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

# GitHub 설정
$GitHubRepo = "sirgrey8209/nexus"
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

# 이전 시간코드 추출
$PrevTimeCode = ""
if ($DeployedInfo -and $DeployedInfo.relay -match "-(\d+)$") {
    $PrevTimeCode = $Matches[1]
}

$TimeCode = Get-TimeCode -PrevTimeCode $PrevTimeCode

# 새 버전 생성
$NewRelayVersion = "$RelayVersion-$TimeCode"
$NewPylonVersion = "$PylonVersion-$TimeCode"
$NewDesktopVersion = "$DesktopVersion-$TimeCode"
$NewMobileVersion = "$MobileVersion-$TimeCode"

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

# 3. Android APK 빌드 (GitHub Actions)
Write-Host ""
Write-Host "Triggering Android APK build..." -ForegroundColor Yellow
& $GhExe workflow run build-android.yml --repo $GitHubRepo -f version=$NewMobileVersion
Write-Host "Android build triggered (check GitHub Actions for progress)" -ForegroundColor Green

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
