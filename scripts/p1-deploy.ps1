# p1-deploy.ps1 - P1 (주도 Pylon) 전체 배포
# git sync → build APK → build EXE → upload → relay deploy → copy release
#
# 사용법: .\scripts\p1-deploy.ps1 [-Version v0.2] [-SkipRelay]
#   -Version: 앱 버전 (생략시 deploy.json에서 가져옴)
#   -SkipRelay: Relay 배포 생략
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

    # 버전 결정 (입력 없으면 현재 deploy.json에서 가져옴)
    if (-not $Version) {
        try {
            $deployJson = & "C:\Program Files\GitHub CLI\gh.exe" release download deploy -p "deploy.json" --repo sirgrey8209/estelle -O - 2>$null | ConvertFrom-Json
            $Version = $deployJson.version
        } catch {
            $Version = "v0.1"
        }
    }

    # BuildTime 생성 (APK와 EXE가 동일한 값 사용)
    $BuildTime = Get-Date -Format "yyyyMMddHHmmss"

    # 2. Build APK
    Invoke-Step "build-apk" {
        $json = & "$ScriptDir\build-apk.ps1" -BuildTime $BuildTime -Version $Version | ConvertFrom-Json
        if (-not $json.success) { throw $json.message }
        return $json
    }

    # 3. Build EXE
    Invoke-Step "build-exe" {
        $json = & "$ScriptDir\build-exe.ps1" -BuildTime $BuildTime -Version $Version | ConvertFrom-Json
        if (-not $json.success) { throw $json.message }
        return $json
    }

    # 4. Upload to GitHub Release
    Invoke-Step "upload" {
        $json = & "$ScriptDir\upload-release.ps1" -Commit $commit -Version $Version -BuildTime $BuildTime | ConvertFrom-Json
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
