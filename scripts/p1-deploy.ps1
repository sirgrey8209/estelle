# p1-deploy.ps1 - P1 (주도 Pylon) 전체 배포
# git sync → build APK → build EXE → upload → relay deploy
#
# 사용법: .\scripts\p1-deploy.ps1 [-SkipRelay]
# 결과: JSON { success, commit, version, steps, message }

param(
    [string]$Version,
    [switch]$SkipRelay,
    [string]$RepoDir = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 결과 추적
$steps = @{}
$commit = $null

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
    # 1. Git sync
    $gitResult = Invoke-Step "git-sync" {
        $json = & "$ScriptDir\git-sync-p1.ps1" | ConvertFrom-Json
        if (-not $json.success) { throw $json.message }
        return $json
    }
    $commit = $gitResult.commit

    # 버전 결정 (기본값: v0.1)
    if (-not $Version) {
        $Version = "v0.1"
    }

    # 2. Build APK
    Invoke-Step "build-apk" {
        $json = & "$ScriptDir\build-apk.ps1" | ConvertFrom-Json
        if (-not $json.success) { throw $json.message }
        return $json
    }

    # 3. Build EXE
    Invoke-Step "build-exe" {
        $json = & "$ScriptDir\build-exe.ps1" | ConvertFrom-Json
        if (-not $json.success) { throw $json.message }
        return $json
    }

    # 4. Upload to GitHub Release
    Invoke-Step "upload" {
        $json = & "$ScriptDir\upload-release.ps1" -Commit $commit -Version $Version | ConvertFrom-Json
        if (-not $json.success) { throw $json.message }
        return $json
    }

    # 5. Deploy Relay (optional)
    if (-not $SkipRelay) {
        Invoke-Step "relay" {
            $json = & "$ScriptDir\deploy-relay.ps1" | ConvertFrom-Json
            if (-not $json.success) { throw $json.message }
            return $json
        }
    }

    # 6. Copy to release folder
    Invoke-Step "copy-release" {
        $json = & "$ScriptDir\copy-release.ps1" | ConvertFrom-Json
        if (-not $json.success) { throw $json.message }
        return $json
    }

    @{
        success = $true
        commit = $commit
        version = $Version
        steps = $steps
        message = "P1 deploy completed"
    } | ConvertTo-Json -Depth 4

} catch {
    @{
        success = $false
        commit = $commit
        version = $Version
        steps = $steps
        message = $_.Exception.Message
    } | ConvertTo-Json -Depth 4
    exit 1
}
