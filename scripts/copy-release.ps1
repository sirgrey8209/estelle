# copy-release.ps1 - 릴리즈 폴더로 복사
# EXE 실행 중에도 빌드 가능하도록 별도 경로에서 실행
#
# 사용법: .\scripts\copy-release.ps1
# 결과: JSON { success, destination, message }

param(
    [string]$RepoDir = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)

$ErrorActionPreference = "Stop"
$AppDir = Join-Path $RepoDir "estelle-app"
$ExeDir = Join-Path $AppDir "build\windows\x64\runner\Release"
$ReleaseDir = Join-Path $AppDir "release"

try {
    if (-not (Test-Path $ExeDir)) {
        throw "Build directory not found. Run build-exe.ps1 first."
    }

    # release 폴더 생성 (없으면)
    if (-not (Test-Path $ReleaseDir)) {
        New-Item -ItemType Directory -Path $ReleaseDir | Out-Null
    }

    # 기존 파일 삭제 (실행 중인 EXE 제외하고 시도)
    Get-ChildItem $ReleaseDir -Recurse | ForEach-Object {
        try {
            Remove-Item $_.FullName -Force -Recurse -ErrorAction SilentlyContinue
        } catch {
            # 실행 중인 파일은 스킵
        }
    }

    # 복사
    Copy-Item -Path "$ExeDir\*" -Destination $ReleaseDir -Recurse -Force

    @{
        success = $true
        source = $ExeDir
        destination = $ReleaseDir
        message = "Copied to release folder"
    } | ConvertTo-Json

} catch {
    @{
        success = $false
        message = $_.Exception.Message
    } | ConvertTo-Json
    exit 1
}
