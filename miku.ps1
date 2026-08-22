pwsh.exe -NoProfile -ExecutionPolicy Bypass -Command "& {
$ErrorActionPreference = 'Stop';
Write-Host '=== 미쿠 테마 및 폰트 재적용 중 ===' -ForegroundColor Cyan;
$L = \"$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\";
$A = \"$L\miku_assets\";
if(!(Test-Path $L)){ mkdir $L -Force | Out-Null };
if(!(Test-Path $A)){ mkdir $A -Force | Out-Null };

# 1. 원본 Iosevka Term 폰트 정확히 다운로드 및 레지스트리 등록
try {
    Invoke-WebRequest -Uri 'https://github.com/be5invis/Iosevka/releases/download/v32.0.0/PkgTtf-IosevkaTerm-32.0.0.zip' -OutFile \"$A\iosevka.zip\";
    Expand-Archive \"$A\iosevka.zip\" -DestinationPath \"$A\font_temp\" -Force;
    $U = \"$env:LOCALAPPDATA\Microsoft\Windows\Fonts\";
    if(!(Test-Path $U)){ mkdir $U -Force | Out-Null };
    Get-ChildItem \"$A\font_temp\" -Filter '*.ttf' -Recurse | ForEach-Object {
        Copy-Item $_.FullName $U -Force;
        New-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' -Name \"$($_.Name) (TrueType)\" -Value \"$U\$($_.Name)\" -PropertyType String -Force | Out-Null
    };
    Write-Host '폰트 설치 완료' -ForegroundColor Green;
} catch { Write-Host '폰트 설치 건너뜀' -ForegroundColor Yellow };

# 2. 원본 레포지토리의 정확한 미쿠 배경 이미지(.jpg) 다운로드
try {
    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/DamourYouKnow/windows-terminal-miku/master/profile/miku.jpg' -OutFile \"$A\miku.jpg\";
    Write-Host '배경 이미지 다운로드 완료' -ForegroundColor Green;
} catch { Write-Host '배경 이미지 다운로드 실패' -ForegroundColor Yellow };

# 3. settings.json 설정 반영
$S = \"$L\settings.json\";
if(!(Test-Path $S)){ '{}' | Out-File -Encoding utf8 $S };
$J = (Get-Content $S -Raw -Encoding utf8);
if([string]::IsNullOrWhiteSpace($J)){ $J = '{}' };
$O = $J | ConvertFrom-Json;

if($null -eq $O.schemes){ $O | Add-Member NoteProperty schemes @() };
$M = [PSCustomObject]@{
    name='Miku'; background='#121212'; black='#2b2b2b'; blue='#6ca4dc'; cyan='#8ad7f8'; green='#8ae234';
    purple='#ad7fa8'; red='#ef2929'; white='#eeeeec'; yellow='#fce94f'; brightBlack='#555753';
    brightBlue='#729fcf'; brightCyan='#34e2e2'; brightGreen='#73d216'; brightPurple='#75507b';
    brightRed='#ef2929'; brightWhite='#ffffff'; brightYellow='#edd400'; foreground='#c5c8c6'
};
if(-not ($O.schemes | Where-Object { $_.name  -eq  'Miku' })){ $O.schemes += $M };

if($null -eq $O.profiles){ $O | Add-Member NoteProperty profiles @([PSCustomObject]@{defaults=@{}}) };
if($null -eq $O.profiles.defaults){ $O.profiles | Add-Member NoteProperty defaults @{} };

# 테마 및 폰트 설정 (Windows Terminal 최신 규격 반영)
$O.profiles.defaults | Add-Member Force NoteProperty colorScheme 'Miku';
$O.profiles.defaults | Add-Member Force NoteProperty font @{ face = 'Iosevka Term' };

$Bg = \"$A\miku.jpg\";
if(Test-Path $Bg){
    $O.profiles.defaults | Add-Member Force NoteProperty backgroundImage ($Bg -replace '\\','\\');
    $O.profiles.defaults | Add-Member Force NoteProperty backgroundImageOpacity 0.35;
    $O.profiles.defaults | Add-Member Force NoteProperty backgroundImageStretchMode 'uniformToFill';
};

$O | ConvertTo-Json -Depth 10 | Out-File -Encoding utf8 $S;
Write-Host '=== 재설정 완료! 터미널을 완전히 껐다 켜주세요. ===' -ForegroundColor Cyan;
}"
