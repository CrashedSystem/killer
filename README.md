```powershell
cd C:\Users\CKIRUser\Downloads
pwsh.exe -ExecutionPolicy Bypass -File .\Unblock-Shells.ps1
pwsh.exe -ep bypass
Import-Module .\Autokiller.ps1
Pause-JnessProcesses
