```powershell
cd C:\Users\CKIRUser\Downloads
pwsh.exe -ExecutionPolicy Bypass -File .\Unblock-Shells.ps1
pwsh.exe -ep bypass
Import-Module .\Autokiller.ps1
Pause-JnessProcesses

```powershell
# 0. 작업 디렉토리 생성
$wDir = "$env:TEMP\winget_install"
New-Item -ItemType Directory -Force -Path $wDir | Out-Null
Set-Location $wDir

Write-Host "[*] 1. 필수 프레임워크(VCLibs 및 WindowsAppRuntime 1.8) 다운로드 및 설치 중..." -ForegroundColor Cyan

# VCLibs x64 다운로드 및 등록
Invoke-WebRequest -Uri "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" -OutFile "$wDir\VCLibs.appx"
Add-AppxPackage -Path "$wDir\VCLibs.appx"

# WindowsAppRuntime 1.8 다운로드 및 등록 (MS 공식 릴리스 링크)
Invoke-WebRequest -Uri "https://www.nuget.org/api/v2/package/Microsoft.WindowsAppRuntime/1.8.250219003" -OutFile "$wDir\AppRuntime.zip"
Expand-Archive -Path "$wDir\AppRuntime.zip" -DestinationPath "$wDir\AppRuntime" -Force
$runtimeAppx = Get-ChildItem -Path "$wDir\AppRuntime" -Filter "*.appx" -Recurse | Where-Object { $_.FullName -match "x64" } | Select-Object -First 1
if ($runtimeAppx) {
    Add-AppxPackage -Path $runtimeAppx.FullName
}

Write-Host "[*] 2. Winget 본체 다운로드 및 설치 중..." -ForegroundColor Cyan
Invoke-WebRequest -Uri "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -OutFile "$wDir\winget.msixbundle"
Add-AppxPackage -Path "$wDir\winget.msixbundle"

Write-Host "[+] Winget 설치 완료! 환경 변수 갱신 후 개발 도구를 설치합니다." -ForegroundColor Green

# 3. 환경 변수 강제 갱신 후 개발 도구 일괄 설치
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

Write-Host "[*] 3. Windows Terminal, Python, Git 설치 시작..." -ForegroundColor Cyan
winget install --id Microsoft.WindowsTerminal -e --accept-source-agreements --accept-package-agreements
winget install --id Python.Python.3 -e --accept-source-agreements --accept-package-agreements
winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements

Write-Host "[+] 모든 작업이 성공적으로 끝났습니다!" -ForegroundColor Green
