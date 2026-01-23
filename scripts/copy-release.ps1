# copy-release.ps1 - 릴리즈 폴더로 복사
# EXE 실행 중이면 프로세스 종료 후 복사, 완료 후 재시작
#
# 사용법: .\scripts\copy-release.ps1 [-NoRestart]
# 결과: JSON { success, destination, message, wasRunning, restarted }

param(
    [string]$RepoDir = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)),
    [switch]$NoRestart  # 재시작 안 함
)

$ErrorActionPreference = "Stop"
$AppDir = Join-Path $RepoDir "estelle-app"
$ExeDir = Join-Path $AppDir "build\windows\x64\runner\Release"
$ReleaseDir = Join-Path $AppDir "release"
$ExeName = "estelle_flutter"
$ExePath = Join-Path $ReleaseDir "$ExeName.exe"

$wasRunning = $false
$restarted = $false

try {
    if (-not (Test-Path $ExeDir)) {
        throw "Build directory not found. Run build-exe.ps1 first."
    }

    # EXE 프로세스 확인 및 종료
    $process = Get-Process -Name $ExeName -ErrorAction SilentlyContinue
    if ($process) {
        $wasRunning = $true
        Write-Host "Stopping $ExeName process..." -ForegroundColor Yellow
        Stop-Process -Name $ExeName -Force
        Start-Sleep -Milliseconds 500  # 프로세스 종료 대기
    }

    # release 폴더 생성 (없으면)
    if (-not (Test-Path $ReleaseDir)) {
        New-Item -ItemType Directory -Path $ReleaseDir | Out-Null
    }

    # 기존 파일 삭제
    Get-ChildItem $ReleaseDir -Recurse | ForEach-Object {
        try {
            Remove-Item $_.FullName -Force -Recurse -ErrorAction SilentlyContinue
        } catch {
            # 삭제 실패한 파일은 스킵
        }
    }

    # 복사
    Copy-Item -Path "$ExeDir\*" -Destination $ReleaseDir -Recurse -Force

    # 재시작 (이전에 실행 중이었고 NoRestart가 아닌 경우)
    if ($wasRunning -and -not $NoRestart) {
        Write-Host "Restarting $ExeName..." -ForegroundColor Green
        Start-Process -FilePath $ExePath
        $restarted = $true
    }

    @{
        success = $true
        source = $ExeDir
        destination = $ReleaseDir
        message = "Copied to release folder"
        wasRunning = $wasRunning
        restarted = $restarted
    } | ConvertTo-Json

} catch {
    @{
        success = $false
        message = $_.Exception.Message
        wasRunning = $wasRunning
        restarted = $restarted
    } | ConvertTo-Json
    exit 1
}
