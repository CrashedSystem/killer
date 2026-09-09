```powershell
cd C:\Users\CKIRUser\Downloads
pwsh.exe -ExecutionPolicy Bypass -File .\Unblock-Shells.ps1
pwsh.exe -ep bypass
Import-Module .\Autokiller.ps1
Pause-JnessProcesses
```

```powershell
$wDir = "$env:TEMP\winget_install"
New-Item -ItemType Directory -Force -Path $wDir | Out-Null
Set-Location $wDir

Write-Host "[1/4] VCLibs 프레임워크 설치 중..." -ForegroundColor Cyan
Invoke-WebRequest -Uri "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" -OutFile "$wDir\VCLibs.appx"
Add-AppxPackage -Path "$wDir\VCLibs.appx"

Write-Host "[2/4] Microsoft.UI.Xaml 프레임워크 설치 중..." -ForegroundColor Cyan
Invoke-WebRequest -Uri "https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.8.6" -OutFile "$wDir\Xaml.zip"
Expand-Archive -Path "$wDir\Xaml.zip" -DestinationPath "$wDir\Xaml" -Force
Add-AppxPackage -Path "$wDir\Xaml\tools\AppX\x64\Release\Microsoft.UI.Xaml.2.8.appx"

Write-Host "[3/4] WindowsAppRuntime 1.8 패키지 및 윙겟 종속성 다운로드 중..." -ForegroundColor Cyan
Invoke-WebRequest -Uri "https://github.com/microsoft/winget-cli/releases/download/v1.12.350/DesktopAppInstaller_Dependencies.zip" -OutFile "$wDir\Deps.zip"
Expand-Archive -Path "$wDir\Deps.zip" -DestinationPath "$wDir\Deps" -Force

# x64 폴더 내의 필수 종속성(.appx) 일괄 등록
$x64Path = Get-ChildItem -Path "$wDir\Deps" -Recurse -Filter "x64" | Select-Object -ExpandProperty FullName
Get-ChildItem -Path $x64Path -Filter "*.appx" | ForEach-Object {
    Write-Host "-> 등록 중: $($_.Name)" -ForegroundColor DarkCyan
    Add-AppxPackage -Path $_.FullName
}

Write-Host "[4/4] Winget(App Installer) 본체 및 라이선스 설치 중..." -ForegroundColor Cyan
Invoke-WebRequest -Uri "https://github.com/microsoft/winget-cli/releases/download/v1.12.350/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -OutFile "$wDir\winget.msixbundle"
Invoke-WebRequest -Uri "https://github.com/microsoft/winget-cli/releases/download/v1.12.350/e53e159d00e04f729cc2180cffd1c02e_License1.xml" -OutFile "$wDir\license.xml"

Add-AppxProvisionedPackage -Online -PackagePath "$wDir\winget.msixbundle" -LicensePath "$wDir\license.xml" -ErrorAction SilentlyContinue
Add-AppxPackage -Path "$wDir\winget.msixbundle"

Write-Host "[+] Winget 설치 완료! 터미널 창을 닫고 새로 연 뒤 아래 명령어를 실행하세요." -ForegroundColor Green
```

```
winget install --id Microsoft.WindowsTerminal -e --accept-source-agreements --accept-package-agreements
winget install --id Python.Python.3.12 -e --accept-source-agreements --accept-package-agreements
winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements
winget install --id sst.opencode -e --accept-source-agreements --accept-package-agreements

Write-Host "[+] 모든 개발 도구 설치 완료!" -ForegroundColor Green
```

## WinKeyFix — LUCOMS K667 윈도우키 리매핑

물리 윈도우키가 `VK 0xFF / Scan 0x00`(무효 키) 신호를 보내는 키보드에서, 전역 LL 키보드 훅으로 이를 가로채 정상 `VK_LWIN`으로 바꿔 주는 도구입니다. 설치 불필요(PowerShell + C# Add-Type), 관리자 권한 불필요, 재부팅 불필요.

> 코드는 `WinKeyFix/` 폴더 안에 `WinKeyFix.ps1` / `WinKeyFix.cmd`로 들어 있습니다.

```powershell
# 1) 수동 실행 — 즉시 윈도우키 동작 (더블클릭으로 실행해도 됨)
.\WinKeyFix\WinKeyFix.cmd

#     PowerShell로 직접 실행
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\WinKeyFix\WinKeyFix.ps1

# 2) 로그온 시 자동 실행 예약 (다음 재로그인부터 적용)
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\WinKeyFix\WinKeyFix.ps1 -Install

# 3) 예약 작업 제거
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\WinKeyFix\WinKeyFix.ps1 -Uninstall

# 4) 자가 진단 — 0xFF -> VK_LWIN 변환이 잘 도는지 확인
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\WinKeyFix\WinKeyFix.ps1 -SelfTest
```

```
SelfTest 출력 예시:
PASS: 0xFF -> VK_LWIN 변환 정상 동작합니다.
```
