# git-sync-p1.ps1 - P1 (주도 Pylon)용 Git 동기화
# 로컬이 최신이라고 가정. pull할 내용 있으면 실패.
#
# 사용법: .\scripts\git-sync-p1.ps1
# 결과: JSON { success, commit, message }

param(
    [string]$RepoDir = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)

$ErrorActionPreference = "Stop"

try {
    Push-Location $RepoDir

    # 1. git fetch
    git fetch origin 2>&1 | Out-Null

    # 2. pull할 내용 있는지 확인
    $behind = git log HEAD..origin/master --oneline
    if ($behind) {
        @{
            success = $false
            message = "Remote has new commits. Pull required before deploy."
            behindCommits = ($behind -split "`n").Count
        } | ConvertTo-Json
        exit 1
    }

    # 3. 로컬 커밋 있는지 확인 (push할 내용)
    $ahead = git log origin/master..HEAD --oneline
    if ($ahead) {
        # push
        git push origin master 2>&1 | Out-Null
    }

    # 현재 커밋 해시
    $commit = git rev-parse --short HEAD

    @{
        success = $true
        commit = $commit
        pushed = [bool]$ahead
        message = if ($ahead) { "Pushed local commits" } else { "Already in sync" }
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
