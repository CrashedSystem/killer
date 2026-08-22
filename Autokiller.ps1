Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;

    public static class Kernel32Sig
    {
        [DllImport("kernel32.dll")]
        public static extern bool CheckRemoteDebuggerPresent(IntPtr hProcess, out bool pbDebuggerPresent);

        [DllImport("kernel32.dll")]
        public static extern int DebugActiveProcess(int PID);

        [DllImport("kernel32.dll")]
        public static extern int DebugActiveProcessStop(int PID);
    }
"@

function Pause-JnessProcesses {
    param (
        [string]$TargetPublisher = "JNESS",
        [switch]$KillInsteadOfPause
    )

    $privy = whoami /priv
    if (!($privy -match "SeDebugPrivilege")) {
        Write-Error "SeDebugPrivilege 권한(관리자 권한)이 필요합니다."
        return
    }

    Write-Host "[$TargetPublisher] 디지털 서명 프로세스 탐색 중..." -ForegroundColor Cyan
    $processes = Get-Process | Where-Object { $_.Path -and $_.Id -ne $PID }
    $foundCount = 0

    # 'in' 양쪽에 공백을 주어 수정 완료
    foreach ($proc in $processes) {
        try {
            $cert = Get-AuthenticodeSignature -FilePath $proc.Path
            $publisher = $cert.SignerCertificate.Subject

            if ($publisher -like "*$TargetPublisher*") {
                $foundCount++
                if ($KillInsteadOfPause) {
                    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
                    Write-Host "[강제 종료] $($proc.Name) (PID: $($proc.Id))" -ForegroundColor Red
                } else {
                    $handle = $proc.Handle
                    $isDebuggerPresent = $false
                    [Kernel32Sig]::CheckRemoteDebuggerPresent($handle, [ref]$isDebuggerPresent) | Out-Null

                    if (!$isDebuggerPresent) {
                        [Kernel32Sig]::DebugActiveProcess($proc.Id) | Out-Null
                        Write-Host "[일시정지] $($proc.Name) (PID: $($proc.Id))" -ForegroundColor Green
                    }
                }
            }
        } catch { continue }
    }
    Write-Host "총 $foundCount 개 처리 완료." -ForegroundColor Cyan
}

Export-ModuleMember -Function Pause-JnessProcesses
