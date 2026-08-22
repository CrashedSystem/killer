$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Write-Host "=== 시스템 전역 폰트 강제 주입 및 터미널 최종 연동 ===" -ForegroundColor Cyan

# 1. 시스템 관리자 권한 체크
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[오류] 반드시 PowerShell을 '관리자 권한'으로 실행해야 합니다." -ForegroundColor Red
    exit
}

# 2. PC 내 모든 곳에서 Iosevka 관련 폰트(.ttf) 탐색 후 수집
$SearchPaths = @(
    "$env:USERPROFILE\Downloads",
    "$env:LOCALAPPDATA\Microsoft\Windows\Fonts",
    "$env:TEMP"
)

$FontFiles = @()
foreach ($path in $SearchPaths) {
    if (Test-Path $path) {
        $found = Get-ChildItem -Path $path -Filter "*iosevka*.ttf" -Recurse -ErrorAction SilentlyContinue
        if ($found) { $FontFiles += $found }
    }
}

if ($FontFiles.Count -eq 0) {
    Write-Host "[오류] Iosevka 폰트 파일(.ttf)을 찾을 수 없습니다. 다운로드 폴더나 경로를 확인해주세요." -ForegroundColor Red
    exit
}

# 3. C:\Windows\Fonts (시스템 전역)로 강제 이동 및 레지스트리 등록
$SysFontDir = "$env:SystemRoot\Fonts"
$RegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"

foreach ($Font in $FontFiles) {
    $Target = Join-Path $SysFontDir $Font.Name
    
    # 파일 강제 복사
    Copy-Item -Path $Font.FullName -Destination $Target -Force
    
    # 레지스트리 키 등록 (이게 핵심: 터미널이 이걸 읽습니다)
    $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($Font.Name)
    $RegName = "$BaseName (TrueType)"
    Set-ItemProperty -Path $RegistryPath -Name $RegName -Value $Font.Name -Force
    Write-Host "등록 완료: $($Font.Name)" -ForegroundColor Green
}

# 4. Windows Terminal settings.json 강제 갱신
$L = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
$S = "$L\settings.json"

if (Test-Path $S) {
    $JsonText = [System.IO.File]::ReadAllText($S, [System.Text.Encoding]::UTF8)
    $O = $JsonText | ConvertFrom-Json

    if ($null -eq $O.profiles) { $O | Add-Member -NotePropertyName "profiles" -NotePropertyValue ([PSCustomObject]@{}) -Force }
    if ($null -eq $O.profiles.defaults) { $O.profiles | Add-Member -NotePropertyName "defaults" -NotePropertyValue ([PSCustomObject]@{}) -Force }

    # 터미널이 가장 안정적으로 인식하는 표기법 적용
    $O.profiles.defaults | Add-Member -NotePropertyName "fontFace" -NotePropertyValue "Iosevka Term" -Force
    $O.profiles.defaults | Add-Member -NotePropertyName "fontSize" -NotePropertyValue 11 -Force
    $O.profiles.defaults | Add-Member -NotePropertyName "backgroundImageStretchMode" -NotePropertyValue "none" -Force
    $O.profiles.defaults | Add-Member -NotePropertyName "backgroundImageAlignment" -NotePropertyValue "bottomRight" -Force

    $JsonFinal = $O | ConvertTo-Json -Depth 100
    [System.IO.File]::WriteAllText($S, $JsonFinal, [System.Text.UTF8Encoding]::new($true))
    Write-Host "터미널 설정 파일 매핑 완료!" -ForegroundColor Green
}

Write-Host "=== 모든 작업 완료! 터미널을 완전히 종료 후 다시 켜세요. ===" -ForegroundColor Cyan
