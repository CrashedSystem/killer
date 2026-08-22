$ErrorActionPreference = 'Stop'
Write-Host "=== Miku 테마, 이미지, 폰트 최종 적용 시작 ===" -ForegroundColor Cyan

# 1. 경로 및 Asset 설정
$L = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
$A = "$L\miku_assets"
if(!(Test-Path $A)){ mkdir $A -Force | Out-Null }

# 2. 폰트 설치 (Iosevka Term)
try {
    Invoke-WebRequest -Uri "https://github.com/be5invis/Iosevka/releases/download/v32.0.0/PkgTtf-IosevkaTerm-32.0.0.zip" -OutFile "$A\iosevka.zip"
    Expand-Archive "$A\iosevka.zip" -DestinationPath "$A\font_temp" -Force
    $U = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
    if(!(Test-Path $U)){ mkdir $U -Force | Out-Null }
    Get-ChildItem "$A\font_temp" -Filter "*.ttf" -Recurse | ForEach-Object {
        Copy-Item $_.FullName $U -Force
        New-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" -Name $_.Name -Value "$U\$($_.Name)" -PropertyType String -Force | Out-Null
    }
} catch { Write-Host "폰트 설치 실패" -ForegroundColor Yellow }

# 3. 이미지 다운로드 (GitHub 정확한 경로)
$ImgPath = "$A\miku.png"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/DamourYouKnow/windows-terminal-miku/master/profile/miku.png" -OutFile $ImgPath

# 4. settings.json 설정
$S = "$L\settings.json"
if(!(Test-Path $S)){ "{}" | Out-File -Encoding utf8 $S }
$J = (Get-Content $S -Raw -Encoding utf8)
if([string]::IsNullOrWhiteSpace($J)){ $J = "{}" }
$O = $J | ConvertFrom-Json

# 스킴 추가
if($null -eq $O.schemes){ $O | Add-Member -NotePropertyName "schemes" -NotePropertyValue @() -Force }
$M = [PSCustomObject]@{
    name='Miku'; background='#121212'; black='#2b2b2b'; blue='#6ca4dc'; cyan='#8ad7f8'; green='#8ae234';
    purple='#ad7fa8'; red='#ef2929'; white='#eeeeec'; yellow='#fce94f'; brightBlack='#555753';
    brightBlue='#729fcf'; brightCyan='#34e2e2'; brightGreen='#73d216'; brightPurple='#75507b';
    brightRed='#ef2929'; brightWhite='#ffffff'; brightYellow='#edd400'; foreground='#c5c8c6'
}
if(-not ($O.schemes | Where-Object { $_.name -eq 'Miku' })){ $O.schemes += $M }

# 프로필 기본값 설정
if($null -eq $O.profiles){ $O | Add-Member -NotePropertyName "profiles" -NotePropertyValue ([PSCustomObject]@{defaults=@{}}) -Force }
if($null -eq $O.profiles.defaults){ $O.profiles | Add-Member -NotePropertyName "defaults" -NotePropertyValue @{} -Force }

# 테마, 폰트, 배경 이미지 적용
$O.profiles.defaults | Add-Member -NotePropertyName "colorScheme" -NotePropertyValue "Miku" -Force
$O.profiles.defaults | Add-Member -NotePropertyName "font" -NotePropertyValue @{ face = "Iosevka Term" } -Force
$O.profiles.defaults | Add-Member -NotePropertyName "backgroundImage" -NotePropertyValue $ImgPath -Force
$O.profiles.defaults | Add-Member -NotePropertyName "backgroundImageOpacity" -NotePropertyValue 0.35 -Force
$O.profiles.defaults | Add-Member -NotePropertyName "backgroundImageStretchMode" -NotePropertyValue "uniformToFill" -Force

$O | ConvertTo-Json -Depth 10 | Out-File -Encoding utf8 $S
Write-Host "=== 모든 세팅 완료! 터미널을 다시 켜세요. ===" -ForegroundColor Cyan
