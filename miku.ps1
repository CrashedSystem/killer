$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "=== Windows Terminal Miku Theme All-in-One Installer (Fixed) ===" -ForegroundColor Cyan

# 1. 관리자 권한 확인
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[오류] 이 스크립트는 반드시 '관리자 권한'으로 실행해야 합니다." -ForegroundColor Red
    exit
}

# 2. Iosevka 폰트 동적 다운로드 및 시스템 전역 등록 (개선된 방식)
Write-Host "[1/4] Iosevka 폰트 최신 버전 다운로드 및 시스템 등록 중..." -ForegroundColor Yellow
$apiUrl = "https://api.github.com/repos/be5invis/Iosevka/releases/latest"
$headers = @{ "User-Agent" = "PowerShell-Script" }
$release = Invoke-RestMethod -Uri $apiUrl -Headers $headers

# TTF 포맷 또는 SuperTTC 포맷 중 안전하게 다운로드 가능하도록 패키지 필터링 완화
$asset = $release.assets | Where-Object { $_.name -match "ttf-iosevka-term-.*\.zip$" -or $_.name -match "super-ttc-iosevka-term" } | Select-Object -First 1
if (-not $asset) {
    # 대체재로 이름에 iosevka와 term, zip이 들어가는 첫 번째 에셋 선택
    $asset = $release.assets | Where-Object { $_.name -match "iosevka" -and $_.name -match "term" -and $_.name -match "\.zip$" } | Select-Object -First 1
}

if (-not $asset) {
    Write-Host "[오류] GitHub에서 Iosevka 폰트 패키지를 찾지 못했습니다. 인터넷 연결을 확인해주세요." -ForegroundColor Red
    exit
}

$ZipPath = "$env:TEMP\$($asset.name)"
$ExtractPath = "$env:TEMP\iosevka_extracted"
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
if (Test-Path $ExtractPath) { Remove-Item $ExtractPath -Recurse -Force }

Write-Host "-> 다운로드 대상: $($asset.name)" -ForegroundColor DarkGray
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $ZipPath
Expand-Archive -Path $ZipPath -DestinationPath $ExtractPath -Force

# TTF 또는 TTC 파일 모두 지원하도록 확장자 검색 확장
$FontFiles = Get-ChildItem -Path $ExtractPath -Include "*.ttf", "*.ttc" -Recurse
if ($FontFiles.Count -eq 0) {
    Write-Host "[오류] 압축 해제된 폴더에서 폰트 파일(.ttf 또는 .ttc)을 찾을 수 없습니다." -ForegroundColor Red
    exit
}

$SysFontDir = "$env:SystemRoot\Fonts"
$RegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"

foreach ($Font in $FontFiles) {
    $Target = Join-Path $SysFontDir $Font.Name
    Copy-Item -Path $Font.FullName -Destination $Target -Force
    $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($Font.Name)
    Set-ItemProperty -Path $RegistryPath -Name "$BaseName (TrueType)" -Value $Font.Name -Force
}
Write-Host "-> 폰트 시스템 등록 완료! ($($FontFiles.Count)개 파일)" -ForegroundColor Green

# 3. 미쿠 배경 이미지 다운로드 및 배치
Write-Host "[2/4] 미쿠 테마 이미지 다운로드 중..." -ForegroundColor Yellow
$L = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
$A = "$L\miku_assets"
if (!(Test-Path $A)) { mkdir $A -Force | Out-Null }
$ImgPath = "$A\miku.png"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DamourYouKnow/windows-terminal-miku/master/profile/miku.png" -OutFile $ImgPath
Write-Host "-> 이미지 배치 완료!" -ForegroundColor Green

# 4. settings.json 조작 및 설정 주입
Write-Host "[3/4] Windows Terminal 설정 파일(settings.json) 구성 중..." -ForegroundColor Yellow
$S = "$L\settings.json"
if (!(Test-Path $S)) {
    Write-Host "[오류] settings.json이 없습니다. Windows Terminal을 한 번 실행한 후 다시 시도하세요." -ForegroundColor Red
    exit
}

$JsonText = [System.IO.File]::ReadAllText($S, [System.Text.Encoding]::UTF8)
$O = $JsonText | ConvertFrom-Json

# 미쿠 컬러 스킴 정의
$MikuScheme = [PSCustomObject]@{
    name = 'Miku'
    background = '#121212'
    black = '#2b2b2b'
    blue = '#6ca4dc'
    cyan = '#8ad7f8'
    green = '#8ae234'
    purple = '#ad7fa8'
    red = '#ef2929'
    white = '#eeeeec'
    yellow = '#fce94f'
    brightBlack = '#555753'
    brightBlue = '#729fcf'
    brightCyan = '#34e2e2'
    brightGreen = '#73d216'
    brightPurple = '#75507b'
    brightRed = '#ef2929'
    brightWhite = '#ffffff'
    brightYellow = '#edd400'
    foreground = '#c5c8c6'
}

if ($null -eq $O.schemes) { $O | Add-Member -NotePropertyName "schemes" -NotePropertyValue @() -Force }
$O.schemes = @($O.schemes | Where-Object { $_.name -ne 'Miku' })
$O.schemes += $MikuScheme

if ($null -eq $O.profiles) { $O | Add-Member -NotePropertyName "profiles" -NotePropertyValue ([PSCustomObject]@{}) -Force }
if ($null -eq $O.profiles.defaults) { $O.profiles | Add-Member -NotePropertyName "defaults" -NotePropertyValue ([PSCustomObject]@{}) -Force }

# 폰트 이름 안전장치 (실제 설치된 폰트 파일명 기반으로 적용)
$AppliedFontFace = "Iosevka Term"
if ($FontFiles[0].Name -match "Term") {
    $AppliedFontFace = "Iosevka Term"
} else {
    $AppliedFontFace = [System.IO.Path]::GetFileNameWithoutExtension($FontFiles[0].Name)
}

$MasterSettings = @{
    "fontFace" = $AppliedFontFace
    "fontSize" = 11
    "colorScheme" = "Miku"
    "backgroundImage" = "ms-appdata:///local/miku_assets/miku.png"
    "backgroundImageAlignment" = "bottomRight"
    "backgroundImageStretchMode" = "uniform"
    "backgroundImageOpacity" = 0.35
    "useAcrylic" = $true
    "acrylicOpacity" = 0.85
}

foreach ($key in $MasterSettings.Keys) {
    if ($O.profiles.defaults.PSObject.Properties[$key]) {
        $O.profiles.defaults.$key = $MasterSettings[$key]
    } else {
        $O.profiles.defaults | Add-Member -NotePropertyName $key -NotePropertyValue $MasterSettings[$key] -Force
    }
}

if ($O.profiles.list) {
    foreach ($p in $O.profiles.list) {
        foreach ($key in $MasterSettings.Keys) {
            if ($p.PSObject.Properties[$key]) {
                $p.$key = $MasterSettings[$key]
            } else {
                $p | Add-Member -NotePropertyName $key -NotePropertyValue $MasterSettings[$key] -Force
            }
        }
    }
}

# 5. 저장 (UTF-8 BOM 강제)
Write-Host "[4/4] 설정 파일 저장 중..." -ForegroundColor Yellow
$JsonFinal = $O | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($S, $JsonFinal, [System.Text.UTF8Encoding]::new($true))

Write-Host "=== 모든 세팅이 완벽하게 끝났습니다! 터미널을 완전히 껐다 켜주세요. ===" -ForegroundColor Cyan
