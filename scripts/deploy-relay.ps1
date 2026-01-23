# deploy-relay.ps1 - Relay fly deploy
#
# 사용법: .\scripts\deploy-relay.ps1
# 결과: JSON { success, message }

param(
    [string]$RepoDir = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)

$ErrorActionPreference = "Stop"
$FlyExe = Join-Path $env:USERPROFILE ".fly\bin\fly.exe"
$RelayDir = Join-Path $RepoDir "estelle-relay"

try {
    Push-Location $RelayDir

    & $FlyExe deploy 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Fly deploy failed"
    }

    @{
        success = $true
        message = "Relay deployed"
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
