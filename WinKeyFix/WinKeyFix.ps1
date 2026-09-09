param(
    [switch]$SelfTest,
    [switch]$Install,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

$cs = @'
using System;
using System.Runtime.InteropServices;
using System.Threading;

public static class WinKeyFix
{
    public delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    private struct KBDLLHOOKSTRUCT
    {
        public uint vkCode;
        public uint scanCode;
        public uint flags;
        public uint time;
        public UIntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT
    {
        public int X;
        public int Y;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MSG
    {
        public IntPtr hwnd;
        public uint message;
        public UIntPtr wParam;
        public IntPtr lParam;
        public uint time;
        public POINT pt;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    private static extern int GetMessage(out MSG lpMsg, IntPtr hWnd, uint wMsgFilterMin, uint wMsgFilterMax);

    [DllImport("user32.dll")]
    private static extern bool PostThreadMessage(uint idThread, uint Msg, UIntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll")]
    private static extern uint GetCurrentThreadId();

    [DllImport("kernel32.dll")]
    private static extern int GetLastWin32Error();

    [DllImport("user32.dll")]
    private static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    [DllImport("user32.dll")]
    private static extern short GetAsyncKeyState(int vKey);

    private const int WH_KEYBOARD_LL = 13;
    private const uint WM_KEYDOWN = 0x0100;
    private const uint WM_KEYUP = 0x0101;
    private const uint WM_QUIT = 0x0012;
    private const uint KEYEVENTF_KEYUP = 0x0002;
    private const byte VK_NULL = 0xFF;
    private const byte VK_LWIN = 0x5B;

    private static LowLevelKeyboardProc _proc;
    private static IntPtr _hook = IntPtr.Zero;
    private static volatile bool _running = false;
    private static uint _threadId = 0;

    public static int LastError = 0;

    private static IntPtr LowLevelProc(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0)
        {
            KBDLLHOOKSTRUCT k = (KBDLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(KBDLLHOOKSTRUCT));
            if (k.vkCode == VK_NULL)
            {
                if (wParam.ToInt64() == WM_KEYDOWN)
                    keybd_event(VK_LWIN, 0, 0U, UIntPtr.Zero);
                else if (wParam.ToInt64() == WM_KEYUP)
                    keybd_event(VK_LWIN, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
                return (IntPtr)1;
            }
        }
        return CallNextHookEx(_hook, nCode, wParam, lParam);
    }

    private static void Run()
    {
        _threadId = GetCurrentThreadId();
        _proc = LowLevelProc;
        _hook = SetWindowsHookEx(WH_KEYBOARD_LL, _proc, IntPtr.Zero, 0);
        if (_hook == IntPtr.Zero)
            LastError = GetLastWin32Error();
        _running = true;
        MSG msg;
        while (_running)
        {
            int r = GetMessage(out msg, IntPtr.Zero, 0, 0);
            if (r == 0) break;
            if (r == -1) break;
        }
        if (_hook != IntPtr.Zero)
            UnhookWindowsHookEx(_hook);
        _hook = IntPtr.Zero;
        _running = false;
    }

    public static int Start()
    {
        Thread t = new Thread(Run);
        t.IsBackground = true;
        t.SetApartmentState(ApartmentState.STA);
        t.Start();
        for (int i = 0; i < 300 && _hook == IntPtr.Zero && _running == false; i++) { }
        for (int i = 0; i < 300 && _hook == IntPtr.Zero && LastError == 0; i++) { Thread.Sleep(10); }
        return _hook != IntPtr.Zero ? 0 : 1;
    }

    public static bool IsRunning
    {
        get { return _running && _hook != IntPtr.Zero; }
    }

    public static void Stop()
    {
        _running = false;
        if (_threadId != 0)
            PostThreadMessage(_threadId, WM_QUIT, UIntPtr.Zero, IntPtr.Zero);
        Thread.Sleep(200);
    }

    public static void InjectFF(bool down)
    {
        keybd_event(VK_NULL, 0, down ? 0U : KEYEVENTF_KEYUP, UIntPtr.Zero);
    }

    public static bool IsKeyDown(int vk)
    {
        return (GetAsyncKeyState(vk) & 0x8000) != 0;
    }
}
'@

Add-Type -TypeDefinition $cs -Language CSharp

function Show-Status {
    param([string]$s)
    Write-Output $s
    Write-Host $s
}

if ($Uninstall) {
    try {
        Unregister-ScheduledTask -TaskName "WinKeyFix" -Confirm:$false -ErrorAction Stop
        Show-Status "OK: WinKeyFix 예약 작업이 제거되었습니다."
    } catch {
        Show-Status "INFO: 제거할 예약 작업이 없거나 이미 없습니다. ($($_.Exception.Message))"
    }
    exit 0
}

if ($Install) {
    $scriptPath = $PSCommandPath
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    Register-ScheduledTask -TaskName "WinKeyFix" -Action $action -Trigger $trigger `
        -Description "LUCOMS K667 Windows key remap (VK 0xFF -> VK_LWIN)" -Force | Out-Null
    Show-Status "OK: 로그온 시 자동 실행 예약 작업이 등록되었습니다. (재부팅/재로그인 후 적용)"
    Show-Status "INFO: 지금 바로 적용하려면 이 파일을 계속 실행해 두세요."
    exit 0
}

if ($SelfTest) {
    $rc = [WinKeyFix]::Start()
    if ($rc -ne 0) {
        Show-Status "FAIL: 훅 설치 실패 (Win32Error=$([WinKeyFix]::LastError))"
        exit 1
    }
    Show-Status "INFO: 훅 설치됨 (IsRunning=$([WinKeyFix]::IsRunning)). 테스트 진행 중..."
    Start-Sleep -Milliseconds 200

    $before = [WinKeyFix]::IsKeyDown(0x5B)
    [WinKeyFix]::InjectFF($true)
    Start-Sleep -Milliseconds 200
    $during = [WinKeyFix]::IsKeyDown(0x5B)
    [WinKeyFix]::InjectFF($false)
    Start-Sleep -Milliseconds 200
    $after = [WinKeyFix]::IsKeyDown(0x5B)

    Show-Status "RESULT: VK_LWIN down 감지 : before=$before during=$during after=$after"
    if ($during -and -not $before -and -not $after) {
        Show-Status "PASS: 0xFF -> VK_LWIN 변환 정상 동작합니다."
    } else {
        Show-Status "WARN: 결과가 예상과 다릅니다. 메뉴가 떴어도 물리 키로 재확인하세요."
    }
    [WinKeyFix]::Stop()
    exit 0
}

$rc = [WinKeyFix]::Start()
if ($rc -ne 0) {
    Show-Status "FAIL: 훅 설치 실패 (Win32Error=$([WinKeyFix]::LastError))"
    exit 1
}

Show-Status "HOOK_OK: WinKeyFix 동작 중 - 윈도우키(VK 0xFF)가 VK_LWIN으로 매핑됨. 종료하려면 이 창을 닫거나 Ctrl+C."

while ($true) {
    Start-Sleep -Seconds 1
}