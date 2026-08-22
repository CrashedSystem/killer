# Windows Terminal Miku + Iosevka Term 폰트 자동 적용 스크립트
$ErrorActionPreference = "Stop"

Write-Host "=== Iosevka Term 폰트 및 미쿠 테마 자동 설치 시작 ===" -ForegroundColor Cyan

# 1. 경로 설정
$LocalDir = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
$AssetDir = "$LocalDir\miku_assets"

if (!(Test-Path $LocalDir)) {
    Write-Host "[오류] Windows Terminal이 설치되어 있지 않거나 실행 기록이 없습니다. 터미널을 먼저 한 번 켜주세요." -ForegroundColor Red
    exit
}

if (!(Test-Path $AssetDir)) {
    New-Item -ItemType Directory -Force -Path $AssetDir | Out-Null
}

# 2. Iosevka Term 폰트 다운로드 및 등록 (GitHub 최신 릴리스 패키지 활용)
Write-Host "Iosevka Term 폰트 다운로드 및 설치 중..." -ForegroundColor Green
$FontZipPath = "$AssetDir\iosevka.zip"
try {
    # Iosevka Term 폰트 패키지 Direct 링크 (TTF 세트)
    Invoke-WebRequest -Uri "https://github.com/be5invis/Iosevka/releases/download/v32.0.0/PkgTtf-IosevkaTerm-32.0.0.zip" -OutFile $FontZipPath
    Expand-Archive -Path $FontZipPath -DestinationPath "$AssetDir\font_temp" -Force
    
    $UserFontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
    if (!(Test-Path $UserFontDir)) { New-Item -ItemType Directory -Force -Path $UserFontDir | Out-Null }
    
    Get-ChildItem -Path "$AssetDir\font_temp" -Filter "*.ttf" -Recurse | ForEach-Object {
        Copy-Item $_.FullName -Destination $UserFontDir -Force
        $FontName = $_.Name
        New-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" -Name "$FontName (TrueType)" -Value "$UserFontDir\$FontName" -PropertyType String -Force | Out-Null
    }
    Write-Host "Iosevka Term 폰트 설치 완료!" -ForegroundColor Green
} catch {
    Write-Host "[경고] 폰트 자동 다운로드 실패, 시스템 기본 폰트로 대체됩니다." -ForegroundColor Yellow
}

# 3. 미쿠 배경 이미지 다운로드
Write-Host "미쿠 테마 리소스 다운로드 중..." -ForegroundColor Green
$BgPath = "$AssetDir\miku.png"
try {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DamourYouKnow/windows-terminal-miku/master/demo.png" -OutFile $BgPath
} catch {
    Write-Host "[경고] 배경 이미지 다운로드 실패, 색상 테마만 적용됩니다." -ForegroundColor Yellow
}

# 4. settings.json 설정 병합
$SettingsPath = "$LocalDir\settings.json"
if (!(Test-Path $SettingsPath)) { "{}" | Out-File -Encoding utf8 $SettingsPath }

$JsonContent = Get-Content $SettingsPath -Raw -Encoding utf8
if ([string]::IsNullOrWhiteSpace($JsonContent)) { $JsonContent = "{}" }
$JsonObject = $JsonContent | ConvertFrom-Json

if ($null -eq $JsonObject.schemes) {
    $JsonObject | Add-Member -MemberType NoteProperty -Name "schemes" -Value @()
}

# 미쿠 컬러 스킴 정의
$MikuScheme = [PSCustomObject]@{
    name = "Miku"
    background = "#121212"
    black = "#2b2b2b"
    blue = "#6ca4dc"
    cyan = "#8ad7f8"
    green = "#8ae234"
    purple = "#ad7fa8"
    red = "#ef2929"
    white = "#eeeeec"
    yellow = "#fce94f"
    brightBlack = "#555753"
    brightBlue = "#729fcf"
    brightCyan = "#34e2e2"
    brightGreen = "#73d216"
    brightPurple = "#75507b"
    brightRed = "#ef2929"
    brightWhite = "#ffffff"
    brightYellow = "#edd400"
    foreground = "#c5c8c6"
}

if (-not ($JsonObject.schemes | Where-Object { $_.name -eq "Miku" })) {
    $JsonObject.schemes += $MikuScheme
}

# 프로필 기본값에 테마, Iosevka Term 폰트, 배경 이미지 지정
if ($null -eq $JsonObject.profiles) {
    $JsonObject | Add-Member -MemberType NoteProperty -Name "profiles" -Value @([PSCustomObject]@{ defaults = @{} })
}
if ($null -eq $JsonObject.profiles.defaults) {
    $JsonObject.profiles | Add-Member -MemberType NoteProperty -Name "defaults" -Value @{}
}

$JsonObject.profiles.defaults | Add-Member -Force -MemberType NoteProperty -Name "colorScheme" -Value "Miku"
$JsonObject.profiles.defaults | Add-Member -Force -MemberType NoteProperty -Name "font" -Value @{ "face" = "Iosevka Term" }

if (Test-Path $BgPath) {
    $NormalizedBgPath = $BgPath -replace '\\', '\\'
    $JsonObject.profiles.defaults | Add-Member -Force -MemberType NoteProperty -Name "backgroundImage" -Value $NormalizedBgPath
    $JsonObject.profiles.defaults | Add-Member -Force -MemberType NoteProperty -Name "backgroundImageOpacity" -Value 0.35
    $JsonObject.profiles.defaults | Add-Member -Force -MemberType NoteProperty -Name "backgroundImageStretchMode" -Value "uniformToFill"
}

# 5. 저장
$JsonObject | ConvertTo-Json -Depth 10 | Out-File -Encoding utf8 $SettingsPath

Write-Host "=== 모든 설정 완료! Windows Terminal을 재시작하세요. ===" -ForegroundColor Cyan
