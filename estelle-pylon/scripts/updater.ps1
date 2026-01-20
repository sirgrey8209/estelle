# Estelle Pylon 자동 업데이트 스크립트
# 5분마다 Task Scheduler에서 실행됨

$ErrorActionPreference = "SilentlyContinue"

# 경로 설정
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PylonDir = Split-Path -Parent $ScriptDir
$RepoDir = Split-Path -Parent $PylonDir

# 로그 파일
$LogFile = Join-Path $PylonDir "logs\updater.log"
$LogDir = Split-Path -Parent $LogFile
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] $Message"
    Add-Content -Path $LogFile -Value $LogEntry
    Write-Host $LogEntry
}

# 로그 파일 크기 제한 (1MB 초과 시 초기화)
if (Test-Path $LogFile) {
    $LogSize = (Get-Item $LogFile).Length
    if ($LogSize -gt 1MB) {
        Remove-Item $LogFile -Force
        Write-Log "Log file rotated"
    }
}

Write-Log "Updater started"

# Git 리포지토리로 이동
Set-Location $RepoDir

# 현재 브랜치 확인
$CurrentBranch = git rev-parse --abbrev-ref HEAD 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Log "ERROR: Not a git repository or git not installed"
    exit 1
}

Write-Log "Current branch: $CurrentBranch"

# 원격 변경사항 확인
Write-Log "Fetching from origin..."
git fetch origin $CurrentBranch 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Log "ERROR: Failed to fetch from origin"
    exit 1
}

# 로컬과 원격 비교
$LocalCommit = git rev-parse HEAD
$RemoteCommit = git rev-parse "origin/$CurrentBranch"

if ($LocalCommit -eq $RemoteCommit) {
    Write-Log "Already up to date"
    exit 0
}

Write-Log "Updates available: $LocalCommit -> $RemoteCommit"

# 변경 파일 확인
$ChangedFiles = git diff HEAD "origin/$CurrentBranch" --name-only 2>&1
Write-Log "Changed files: $($ChangedFiles -join ', ')"

# Pull 수행
Write-Log "Pulling changes..."
$PullResult = git pull origin $CurrentBranch 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Log "ERROR: Failed to pull changes: $PullResult"
    exit 1
}

Write-Log "Pull successful"

# package-lock.json 변경 확인 → npm install 실행
$PackageLockChanged = $ChangedFiles | Where-Object { $_ -like "*package-lock.json" -or $_ -like "*package.json" }

if ($PackageLockChanged) {
    Write-Log "Package changes detected, running npm install..."

    # estelle-pylon npm install
    Set-Location $PylonDir
    $NpmResult = npm install 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Log "ERROR: npm install failed: $NpmResult"
    } else {
        Write-Log "npm install completed"
    }

    Set-Location $RepoDir
}

# Pylon 재시작
Write-Log "Restarting EstellePylon..."
Stop-ScheduledTask -TaskName "EstellePylon" -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Start-ScheduledTask -TaskName "EstellePylon"

if ($LASTEXITCODE -eq 0) {
    Write-Log "EstellePylon restarted successfully"
} else {
    Write-Log "WARNING: Failed to restart EstellePylon"
}

Write-Log "Updater completed"
