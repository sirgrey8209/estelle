# Estelle Pylon Task Scheduler 등록 스크립트
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

# 경로 설정 (현재 스크립트 기준 상위 폴더)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PylonDir = Split-Path -Parent $ScriptDir
$RepoDir = Split-Path -Parent $PylonDir

Write-Host "Estelle Pylon Task Scheduler 설치" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Pylon 경로: $PylonDir" -ForegroundColor Gray
Write-Host ""

# Task 1: EstellePylon - PC 시작 시 서비스 실행
$TaskName1 = "EstellePylon"
$Action1 = New-ScheduledTaskAction -Execute "node" -Argument "src/index.js" -WorkingDirectory $PylonDir
$Trigger1 = New-ScheduledTaskTrigger -AtStartup
$Principal1 = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$Settings1 = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

# 기존 Task 삭제 (있으면)
if (Get-ScheduledTask -TaskName $TaskName1 -ErrorAction SilentlyContinue) {
    Write-Host "기존 $TaskName1 Task 삭제 중..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $TaskName1 -Confirm:$false
}

Write-Host "$TaskName1 Task 등록 중..." -ForegroundColor Green
Register-ScheduledTask -TaskName $TaskName1 -Action $Action1 -Trigger $Trigger1 -Principal $Principal1 -Settings $Settings1 -Description "Estelle Pylon - PC 시작 시 자동 실행"

# Task 2: EstellePylonUpdater - 5분마다 업데이트 체크
$TaskName2 = "EstellePylonUpdater"
$UpdaterScript = Join-Path $ScriptDir "updater.ps1"
$Action2 = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$UpdaterScript`"" -WorkingDirectory $RepoDir
$Trigger2 = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)
$Principal2 = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$Settings2 = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

# 기존 Task 삭제 (있으면)
if (Get-ScheduledTask -TaskName $TaskName2 -ErrorAction SilentlyContinue) {
    Write-Host "기존 $TaskName2 Task 삭제 중..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $TaskName2 -Confirm:$false
}

Write-Host "$TaskName2 Task 등록 중..." -ForegroundColor Green
Register-ScheduledTask -TaskName $TaskName2 -Action $Action2 -Trigger $Trigger2 -Principal $Principal2 -Settings $Settings2 -Description "Estelle Pylon - 5분마다 업데이트 체크"

Write-Host ""
Write-Host "설치 완료!" -ForegroundColor Green
Write-Host ""
Write-Host "등록된 Task:" -ForegroundColor Cyan
Get-ScheduledTask -TaskName "EstellePylon*" | Format-Table TaskName, State, TaskPath

Write-Host ""
Write-Host "Pylon을 즉시 시작하려면:" -ForegroundColor Yellow
Write-Host "  Start-ScheduledTask -TaskName EstellePylon" -ForegroundColor White
