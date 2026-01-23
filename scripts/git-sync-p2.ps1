# git-sync-p2.ps1 - P2 (다른 Pylon)용 Git 동기화
# 로컬 변경사항을 stash하고 특정 커밋으로 checkout
#
# 사용법: .\scripts\git-sync-p2.ps1 -Commit abc1234
# 결과: JSON { success, commit, stashed, stashId, message }

param(
    [Parameter(Mandatory=$true)]
    [string]$Commit,
    [string]$RepoDir = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)

$ErrorActionPreference = "Stop"

try {
    Push-Location $RepoDir

    $stashed = $false
    $stashId = $null
    $stashMessage = "estelle-deploy-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

    # 1. git fetch
    git fetch origin 2>&1 | Out-Null

    # 2. uncommitted 변경사항 확인
    $status = git status --porcelain
    $hasUncommitted = [bool]$status

    # 3. 로컬 커밋 확인 (push 안 한 것)
    $localCommits = git log origin/master..HEAD --oneline
    $hasLocalCommits = [bool]$localCommits

    # 4. stash 필요한 경우
    if ($hasLocalCommits) {
        # soft reset으로 커밋을 unstaged로 되돌림
        git reset --soft origin/master 2>&1 | Out-Null

        # 이제 모든 변경사항이 staged 상태
        git stash push -m $stashMessage --include-untracked 2>&1 | Out-Null
        $stashed = $true
        $stashId = $stashMessage
    } elseif ($hasUncommitted) {
        # uncommitted만 있는 경우
        git stash push -m $stashMessage --include-untracked 2>&1 | Out-Null
        $stashed = $true
        $stashId = $stashMessage
    }

    # 5. checkout
    git checkout $Commit 2>&1 | Out-Null

    @{
        success = $true
        commit = $Commit
        stashed = $stashed
        stashId = $stashId
        hadLocalCommits = $hasLocalCommits
        hadUncommitted = $hasUncommitted
        message = "Checked out to $Commit"
    } | ConvertTo-Json

} catch {
    @{
        success = $false
        commit = $Commit
        message = $_.Exception.Message
    } | ConvertTo-Json
    exit 1
} finally {
    Pop-Location
}
