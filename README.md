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

Write-Host "[*] 1. 필수 VCLibs 프레임워크 설치 중..." -ForegroundColor Cyan
Invoke-WebRequest -Uri "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" -OutFile "$wDir\VCLibs.appx"
Add-AppxPackage -Path "$wDir\VCLibs.appx"

Write-Host "[*] 2. Microsoft.UI.Xaml 의존성 설치 중..." -ForegroundColor Cyan
Invoke-WebRequest -Uri "https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.8.6" -OutFile "$wDir\Xaml.zip"
Expand-Archive -Path "$wDir\Xaml.zip" -DestinationPath "$wDir\Xaml" -Force
Add-AppxPackage -Path "$wDir\Xaml\tools\AppX\x64\Release\Microsoft.UI.Xaml.2.8.appx"

Write-Host "[*] 3. Winget 본체(App Installer) 설치 중..." -ForegroundColor Cyan
Invoke-WebRequest -Uri "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -OutFile "$wDir\winget.msixbundle"
Add-AppxPackage -Path "$wDir\winget.msixbundle"

Write-Host "[+] Winget 설치 완료! 환경 변수 갱신 후 개발 도구를 설치합니다." -ForegroundColor Green

# 4. 환경 변수 갱신 및 도구 일괄 설치
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

winget install --id Microsoft.WindowsTerminal -e --accept-source-agreements --accept-package-agreements
winget install --id Python.Python.3 -e --accept-source-agreements --accept-package-agreements
winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements
