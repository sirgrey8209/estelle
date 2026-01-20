# Estelle Pylon Task Scheduler 제거 스크립트
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

Write-Host "Estelle Pylon Task Scheduler 제거" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Task 목록
$Tasks = @("EstellePylon", "EstellePylonUpdater")

foreach ($TaskName in $Tasks) {
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Write-Host "$TaskName Task 중지 중..." -ForegroundColor Yellow
        Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

        Write-Host "$TaskName Task 삭제 중..." -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "$TaskName Task 삭제 완료" -ForegroundColor Green
    } else {
        Write-Host "$TaskName Task가 존재하지 않습니다" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "제거 완료!" -ForegroundColor Green
