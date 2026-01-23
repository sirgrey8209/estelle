# build-pylon.ps1 - Pylon npm install
#
# 사용법: .\scripts\build-pylon.ps1
# 결과: JSON { success, message }

param(
    [string]$RepoDir = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)

$ErrorActionPreference = "Stop"
$PylonDir = Join-Path $RepoDir "estelle-pylon"

try {
    Push-Location $PylonDir

    npm install 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "npm install failed"
    }

    @{
        success = $true
        path = $PylonDir
        message = "Pylon build completed"
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
