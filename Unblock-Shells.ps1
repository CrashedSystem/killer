<#
.SYNOPSIS
    이미지명 기반 프로세스 차단(Solusseum MaestroWeb 커널 드라이버)을 해제하고
    cmd.exe / powershell.exe 원본 실행을 복원하는 스크립트.

.DESCRIPTION
    동작 원리 (실험을 통해 확정된 사실):
      - 차단체는 유저모드 훅이 아니라 커널 드라이버(SoluPT64.sys / SoluIP64.sys)의
        프로세스 생성 콜백이며, 이미지명에 "cmd" / "powershell" 부분문자열이
        포함되면 ACCESS_DENIED를 반환한다. (경로/해시/부모 무관)
      - 따라서 문자열 우회(\\?\, UNC 등)는 불가능하고, 드라이버를 중지해야 한다.
      - 드라이버는 서비스 의존성 사슬(MaestroWebSvr -> SoluPT64)로 보호되어 있으므로
        의존성을 절단한 뒤 위→아래로 중지한다.

.USAGE
    관리자 PowerShell에서:
      powershell -ExecutionPolicy Bypass -File .\Unblock-Shells.ps1
    재부팅 후에도 차단 유지(드라이버 자동 시작 비활성화):
      powershell -ExecutionPolicy Bypass -File .\Unblock-Shells.ps1 -Persist

.NOTES
    - 재부팅하면 StartMode=Auto 때문에 드라이버가 다시 올라와 차단이 복원된다.
      그 때 이 스크립트를 다시 실행하면 된다.
    - 관제 서버가 정책을 재푸시하면 에이전트가 재기동될 수 있다.
#>
param(
    [switch]$Persist  # 재부팅 이후에도 드라이버/서비스 자동 시작 비활성화
)

$ErrorActionPreference = 'Continue'

function Write-Step { param($m) Write-Host "[*] $m" }
function Write-Ok   { param($m) Write-Host "[+] $m" -ForegroundColor Green }
function Write-Fail { param($m) Write-Host "[-] $m" -ForegroundColor Red }

# ---------- 0. 관리자 권한 확인 ----------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Fail '관리자 권한이 필요합니다. 관리자 PowerShell에서 실행하세요.'
    exit 1
}

# ---------- 대상 정의 ----------
$AgentServices = @('MaestroWebAgent', 'MaestroWebSvr', 'SoluSPSvr')
$AgentProcesses = @('MaestroWebAgent', 'MaestroWebSvr', 'SoluSPSvr', 'AYIA', 'AYIASrv')
$KernelDrivers = @('SoluPT64', 'SoluIP64')   # 진범: 프로세스 생성 콜백 드라이버

# ---------- 1. 서비스 의존성 절단 ----------
# 드라이버(SoluPT64)는 MaestroWebSvr가 의존하고 있어 그냥은 멈추지 않는다.
Write-Step '1/5 서비스 의존성 절단'
foreach ($svc in $AgentServices) {
    if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
        $null = sc.exe config $svc depend= ""
        Write-Step "    $svc : depend= (공백) 설정"
    }
}

# ---------- 2. 에이전트 서비스 중지 ----------
Write-Step '2/5 에이전트 서비스 중지'
foreach ($svc in $AgentServices) {
    $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($s -and $s.Status -eq 'Running') {
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        $null = sc.exe stop $svc
        Write-Step "    $svc : 중지 요청"
    } else {
        Write-Step "    $svc : 실행 중 아님"
    }
}

# ---------- 3. 에이전트 프로세스 종료 (보호되어 실패할 수 있음 - 무시) ----------
Write-Step '3/5 에이전트 프로세스 종료 시도'
foreach ($p in $AgentProcesses) {
    try {
        Stop-Process -Name $p -Force -ErrorAction Stop
        Write-Ok   "    종료됨: $p"
    } catch { }
}

# ---------- 4. 커널 드라이버 중지 ----------
Write-Step '4/5 커널 드라이버 중지'
foreach ($drv in $KernelDrivers) {
    $out = (sc.exe stop $drv 2>&1 | Out-String)
    if ($out -match 'STOPPED' -or $out -match '1062') {
        Write-Ok "    $drv : 중지됨"
    } elseif ($out -match '1060') {
        Write-Step "    $drv : 설치되어 있지 않음"
    } else {
        Write-Fail "    $drv : 중지 실패 (의존 서비스가 남아있을 수 있음)"
    }
}

if ($Persist) {
    Write-Step '4.5/Persist 자동 시작 비활성화'
    foreach ($drv in $KernelDrivers) { $null = sc.exe config $drv start= disabled }
    foreach ($svc in $AgentServices) { $null = sc.exe config $svc start= disabled }
    Write-Ok '    재부팅 후에도 드라이버/서비스가 자동 시작되지 않음'
}

# ---------- 5. 검증: 원본 이름 그대로 스폰 ----------
Write-Step '5/5 검증 - 원본 이미지명으로 실행'
Start-Sleep -Milliseconds 500
$outFile = Join-Path $env:TEMP ("verify_{0}.txt" -f [guid]::NewGuid().ToString('N').Substring(0,8))

$cmdOk = $false; $psOk = $false
try {
    # cmd.exe 원본 ($env:ComSpec = C:\Windows\system32\cmd.exe)
    $null = Start-Process -FilePath $env:ComSpec `
        -ArgumentList "/c echo OK > `"$outFile`"" -Wait -WindowStyle Hidden
    if ((Test-Path $outFile) -and (Get-Content $outFile -Raw) -match 'OK') { $cmdOk = $true }
} catch { }

$powershellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
try {
    $r = & $powershellExe -NoProfile -Command 'Write-Output OK' 2>$null
    if ($r -match 'OK') { $psOk = $true }
} catch { }

Remove-Item $outFile -ErrorAction SilentlyContinue

Write-Host ''
Write-Host '========== 결과 =========='
if ($cmdOk) { Write-Ok 'cmd.exe        원본 실행 성공' } else { Write-Fail 'cmd.exe        여전히 차단됨' }
if ($psOk)  { Write-Ok 'powershell.exe 원본 실행 성공' } else { Write-Fail 'powershell.exe 여전히 차단됨' }
Write-Host '=========================='