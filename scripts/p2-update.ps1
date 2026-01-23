# p2-update.ps1 - P2 (다른 Pylon) 업데이트
# git sync → build pylon → build exe → copy release → restart app → restore
#
# 사용법: .\scripts\p2-update.ps1 -Commit abc1234
# 결과: JSON { success, commit, steps, stashId, message }

param(
    [Parameter(Mandatory=$true)]
    [string]$Commit,
    [string]$RepoDir = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 결과 추적
$steps = @{}
$stashId = $null

function Invoke-Step {
    param([string]$Name, [scriptblock]$Action)

    try {
        $result = & $Action
        $steps[$Name] = @{ success = $true; result = $result }
        return $result
    } catch {
        $steps[$Name] = @{ success = $false; error = $_.Exception.Message }
        throw
    }
}

try {
    # 0. GitHub에서 deploy.json 가져오기 (Version, BuildTime)
    $GhExe = "C:\Program Files\GitHub CLI\gh.exe"
    $deployInfo = & $GhExe release download deploy -p "deploy.json" --repo sirgrey8209/estelle -O - 2>$null | ConvertFrom-Json
    $Version = $deployInfo.version
    $BuildTime = $deployInfo.buildTime

    # 1. Git sync (stash + checkout)
    $gitResult = Invoke-Step "git-sync" {
        $json = & "$ScriptDir\git-sync-p2.ps1" -Commit $Commit | ConvertFrom-Json
        if (-not $json.success) { throw $json.message }
        return $json
    }
    $stashId = $gitResult.stashId

    # 2. Pylon build (npm ci)
    Invoke-Step "build-pylon" {
        $json = & "$ScriptDir\build-pylon.ps1" | ConvertFrom-Json
        if (-not $json.success) { throw $json.message }
        return $json
    }

    # 3. EXE build (P1과 동일한 Version, BuildTime 사용)
    Invoke-Step "build-exe" {
        $json = & "$ScriptDir\build-exe.ps1" -Version $Version -BuildTime $BuildTime | ConvertFrom-Json
        if (-not $json.success) { throw $json.message }
        return $json
    }

    # 4. Copy to release folder
    Invoke-Step "copy-release" {
        $json = & "$ScriptDir\copy-release.ps1" | ConvertFrom-Json
        if (-not $json.success) { throw $json.message }
        return $json
    }

    # 5. Restart app
    Invoke-Step "restart-app" {
        $json = & "$ScriptDir\restart-app.ps1" | ConvertFrom-Json
        if (-not $json.success) { throw $json.message }
        return $json
    }

    # 6. Restore stash (optional)
    if ($stashId) {
        Invoke-Step "restore" {
            $json = & "$ScriptDir\git-restore-p2.ps1" -StashId $stashId | ConvertFrom-Json
            return $json
        }
    }

    @{
        success = $true
        commit = $Commit
        steps = $steps
        stashId = $stashId
        message = "P2 update completed"
    } | ConvertTo-Json -Depth 4

} catch {
    @{
        success = $false
        commit = $Commit
        steps = $steps
        stashId = $stashId
        message = $_.Exception.Message
    } | ConvertTo-Json -Depth 4
    exit 1
}
