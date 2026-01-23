# upload-release.ps1 - GitHub Release 업로드
# deploy.json, APK 업로드
#
# 사용법: .\scripts\upload-release.ps1 -Commit abc1234 -Version v0.1 -BuildTime 20260123113000
# 결과: JSON { success, commit, version, buildTime, uploaded, message }

param(
    [Parameter(Mandatory=$true)]
    [string]$Commit,
    [Parameter(Mandatory=$true)]
    [string]$Version,
    [Parameter(Mandatory=$true)]
    [string]$BuildTime,
    [string]$RepoDir = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)

$ErrorActionPreference = "Stop"
$GhExe = "C:\Program Files\GitHub CLI\gh.exe"
$GitHubRepo = "sirgrey8209/estelle"
$ReleaseName = "deploy"
$AppDir = Join-Path $RepoDir "estelle-app"

try {
    $uploaded = @()

    # 1. deploy.json 생성
    $deployJson = @{
        commit = $Commit
        version = $Version
        buildTime = $BuildTime
        deployedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
    $deployJsonPath = Join-Path $RepoDir "deploy.json"
    $deployJson | ConvertTo-Json | Set-Content $deployJsonPath

    # 2. deploy.json 업로드
    & $GhExe release upload $ReleaseName $deployJsonPath --repo $GitHubRepo --clobber 2>&1 | Out-Null
    $uploaded += "deploy.json"

    # 3. APK 업로드
    $apkPath = Join-Path $AppDir "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $apkPath) {
        & $GhExe release upload $ReleaseName $apkPath --repo $GitHubRepo --clobber 2>&1 | Out-Null
        $uploaded += "app-release.apk"
    }

    # 로컬 deploy.json 삭제
    Remove-Item $deployJsonPath -Force

    @{
        success = $true
        commit = $Commit
        version = $Version
        uploaded = $uploaded
        message = "Uploaded to GitHub Release"
    } | ConvertTo-Json

} catch {
    @{
        success = $false
        message = $_.Exception.Message
    } | ConvertTo-Json
    exit 1
}
