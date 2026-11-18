# 개발 폴더(D:\Dev\MimQoL)의 애드온 파일을 게임 AddOns 폴더로 복사한다.
#   .\deploy.ps1        게임 폴더로 복사 (테스트용)
# 배포용 zip은 D:Dev 폴더의 pack_addons.bat 으로 만든다.

$ErrorActionPreference = "Stop"
$Src = $PSScriptRoot
$Dst = "D:\Games\World of Warcraft\_retail_\Interface\AddOns\MimQoL"

# 배포본에 넣지 않을 개발 파일 (pack_addons.ps1 제외 목록과 맞춘다)
$ExcludeDirs  = @(".git", ".vscode", ".claude", ".agents", "tests")
$ExcludeFiles = @(".gitignore", ".luarc.json", "*.md", "*.bat", "*.zip", "deploy.ps1")

# /MIR: 게임 폴더를 배포본과 똑같이 맞춘다 (남는 파일은 지운다)
robocopy $Src $Dst /MIR /R:1 /W:1 /NFL /NDL /NP /NJH /XD $ExcludeDirs /XF $ExcludeFiles | Out-Null
if ($LASTEXITCODE -ge 8) { throw "복사 실패 (robocopy 코드 $LASTEXITCODE)" }
# 제외 목록은 /MIR 삭제에서도 빠지므로, 게임 폴더에 남은 개발 파일은 직접 지운다
foreach ($name in $ExcludeDirs + $ExcludeFiles) {
    Get-ChildItem -Path $Dst -Filter $name -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -Confirm:$false
}
Write-Host "게임 폴더로 복사했습니다: $Dst"
