# git-restore-p2.ps1 - P2 복구 (stash pop)
# 빌드 완료 후 stash한 내용 복구
#
# 사용법: .\scripts\git-restore-p2.ps1 -StashId "estelle-deploy-20260123-121500"
# 결과: JSON { success, restored, message }

param(
    [string]$StashId,
    [string]$RepoDir = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)

$ErrorActionPreference = "Stop"

try {
    Push-Location $RepoDir

    # stash 목록에서 찾기
    $stashList = git stash list
    $stashIndex = $null

    if ($StashId) {
        $lineNum = 0
        foreach ($line in ($stashList -split "`n")) {
            if ($line -match $StashId) {
                $stashIndex = $lineNum
                break
            }
            $lineNum++
        }
    }

    if ($null -eq $stashIndex) {
        @{
            success = $true
            restored = $false
            message = "No matching stash found"
        } | ConvertTo-Json
        exit 0
    }

    # stash pop
    git stash pop "stash@{$stashIndex}" 2>&1 | Out-Null

    @{
        success = $true
        restored = $true
        stashId = $StashId
        message = "Stash restored successfully"
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
