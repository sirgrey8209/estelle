# Estelle PC 자동 세팅 스크립트
# 관리자 권한으로 실행 권장

param(
    [string]$DeviceId = ""
)

$ErrorActionPreference = "Stop"

# 색상 출력 함수
function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host ">>> $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "    $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "    $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "    $Message" -ForegroundColor Red
}

# 헤더
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Estelle PC Setup Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 경로 설정
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir = Split-Path -Parent $ScriptDir
$PylonDir = Join-Path $RepoDir "estelle-pylon"
$DesktopDir = Join-Path $RepoDir "estelle-desktop"

Write-Host "Repository: $RepoDir" -ForegroundColor Gray

# 1. Node.js 확인
Write-Step "Node.js 버전 확인"
try {
    $NodeVersion = node --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Node.js $NodeVersion"

        # 버전 체크 (20.x 이상)
        $VersionNum = [int]($NodeVersion -replace 'v(\d+).*', '$1')
        if ($VersionNum -lt 20) {
            Write-Warning "Node.js 20+ 권장 (현재: $NodeVersion)"
        }
    } else {
        throw "Node.js not found"
    }
} catch {
    Write-Error "Node.js가 설치되어 있지 않습니다."
    Write-Host "    https://nodejs.org/ 에서 설치 후 다시 실행하세요." -ForegroundColor Gray
    exit 1
}

# 2. Git 확인
Write-Step "Git 버전 확인"
try {
    $GitVersion = git --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success $GitVersion
    } else {
        throw "Git not found"
    }
} catch {
    Write-Error "Git이 설치되어 있지 않습니다."
    Write-Host "    https://git-scm.com/ 에서 설치 후 다시 실행하세요." -ForegroundColor Gray
    exit 1
}

# 3. Pylon npm install
Write-Step "Pylon 의존성 설치"
Set-Location $PylonDir
npm install 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Success "npm install 완료"
} else {
    Write-Error "npm install 실패"
    exit 1
}

# 4. .env 파일 생성
Write-Step ".env 파일 설정"
$EnvFile = Join-Path $PylonDir ".env"
$EnvExample = Join-Path $PylonDir ".env.example"

if (-not $DeviceId) {
    Write-Host ""
    $DeviceId = Read-Host "    Device ID 입력 (예: office-pc, home-pc)"
    if (-not $DeviceId) {
        $DeviceId = "pc-$env:COMPUTERNAME".ToLower()
        Write-Warning "기본값 사용: $DeviceId"
    }
}

$EnvContent = @"
# Estelle Pylon 설정

# Relay 서버 URL
RELAY_URL=wss://estelle-relay.fly.dev

# 로컬 서버 포트 (Desktop 통신용)
LOCAL_PORT=9000

# 이 PC의 식별자
DEVICE_ID=$DeviceId
"@

$EnvContent | Out-File -FilePath $EnvFile -Encoding utf8
Write-Success ".env 파일 생성 (DEVICE_ID=$DeviceId)"

# 5. Task Scheduler 등록 (관리자 권한 필요)
Write-Step "Task Scheduler 등록"

$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if ($IsAdmin) {
    $InstallScript = Join-Path $PylonDir "scripts\install-service.ps1"
    & $InstallScript
    Write-Success "Task Scheduler 등록 완료"
} else {
    Write-Warning "관리자 권한이 없어 Task Scheduler 등록을 건너뜁니다."
    Write-Host "    관리자 권한으로 다음 명령어를 실행하세요:" -ForegroundColor Gray
    Write-Host "    powershell -ExecutionPolicy Bypass -File `"$PylonDir\scripts\install-service.ps1`"" -ForegroundColor White
}

# 6. Desktop 설치 (선택)
Write-Step "Desktop 의존성 설치"
if (Test-Path $DesktopDir) {
    Set-Location $DesktopDir
    npm install 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Desktop npm install 완료"
    } else {
        Write-Warning "Desktop npm install 실패 (선택 사항)"
    }
} else {
    Write-Warning "Desktop 폴더가 없습니다"
}

# 완료
Set-Location $RepoDir
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "다음 단계:" -ForegroundColor Cyan
Write-Host "  1. PC 재시작하면 Pylon이 자동으로 시작됩니다"
Write-Host "  2. 또는 즉시 시작: Start-ScheduledTask -TaskName EstellePylon"
Write-Host ""
Write-Host "Desktop 실행:"
Write-Host "  cd estelle-desktop"
Write-Host "  npm start"
Write-Host ""
