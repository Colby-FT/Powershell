<#
This administrator-only PowerShell script creates a timestamped incident-response collection under C:\FT. It gathers Windows event logs, Edge profile data, remote-access tool folders, selected user and system files, registry hives and startup-related keys, scheduled-task definitions, and live system details such as running processes and established network connections. It also copies Defender support logs and writes a brief report of selected security and service events from the past seven days.

The script is intended to collect evidence for investigation; it does not remove files or change system settings. It will copy sensitive data, and some collection steps can fail if paths are missing or files are locked.
#>

#Requires -RunAsAdministrator
$Dest = "C:\FT"
$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$Base = "$Dest\IR_Collection_$Stamp"
New-Item -ItemType Directory -Path $Base,"$Base\EVTX","$Base\Registry" -Force | Out-Null

# ---- 1. Event logs (export raw .evtx) ----
$Logs = @(
    "Security","System","Application",
    "Microsoft-Windows-PowerShell/Operational",
    "Microsoft-Windows-Windows Defender/Operational",
    "Microsoft-Windows-TaskScheduler/Operational",
    "Microsoft-Windows-Bits-Client/Operational",
    "Microsoft-Windows-Windows Firewall With Advanced Security/Firewall",
    "Microsoft-Windows-Shell-Core/Operational",
    "Microsoft-Windows-DNS-Client/Operational"
)
foreach ($log in $Logs) {
    $safe = $log -replace "[/\\]","_"
    wevtutil e "$log" /ow:true /f:evtx >> "$Base\EVTX\$safe.evtx" 2>$null
}
# Sysmon if present
if (Get-WinEvent -ListLog "Microsoft-Windows-Sysmon/Operational" -ErrorAction SilentlyContinue) {
    wevtutil e "Microsoft-Windows-Sysmon/Operational" /ow:true /f:evtx >> "$Base\EVTX\Sysmon.evtx"
}

# ---- 2. Edge browser artifacts (all profiles) ----
$EdgeRoot = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
if (Test-Path $EdgeRoot) {
    Copy-Item $EdgeRoot "$Base\Edge_UserData" -Recurse -Force
}

# ---- 3. Remote access tool logs/folders ----
$RATPaths = @(
    "$env:ProgramData\AnyDesk",
    "${env:ProgramFiles(x86)}\TeamViewer",
    "$env:ProgramFiles\TeamViewer",
    "$env:ProgramData\ScreenConnect",
    "$env:ProgramData\ConnectWise",
    "$env:ProgramData\LogMeIn",
    "${env:ProgramFiles(x86)}\LogMeIn",
    "$env:ProgramData\GoToAssist",
    "$env:APPDATA\AnyDesk",
    "$env:APPDATA\TeamViewer"
)
foreach ($p in $RATPaths) {
    if (Test-Path $p) { Copy-Item $p "$Base\RAT_$(Split-Path $p -Leaf)" -Recurse -Force }
}

# ---- 4. Prefetch, Temp, Downloads, Startup, Recent ----
Copy-Item "C:\Windows\Prefetch" "$Base\Prefetch" -Recurse -Force
Copy-Item $env:TEMP "$Base\UserTemp" -Recurse -Force
Copy-Item "$env:USERPROFILE\Downloads" "$Base\Downloads" -Recurse -Force
Copy-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup" "$Base\StartupFolder" -Recurse -Force
Copy-Item "$env:APPDATA\Microsoft\Windows\Recent" "$Base\Recent_LNK" -Recurse -Force

# ---- 5. Registry hives + persistence-relevant keys ----
reg save HKLM\SYSTEM "$Base\Registry\SYSTEM.hiv" /y
reg save HKLM\SOFTWARE "$Base\Registry\SOFTWARE.hiv" /y
reg save HKLM\SECURITY "$Base\Registry\SECURITY.hiv" /y
reg save HKCU "$Base\Registry\NTUSER_HKCU.hiv" /y
if (Test-Path "C:\Windows\AppCompat\Programs\Amcache.hve") {
    Copy-Item "C:\Windows\AppCompat\Programs\Amcache.hve" "$Base\Registry\Amcache.hve" -Force
}
foreach ($rk in @(
    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
    "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RunMRU",
    "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths"
)) {
    $safe = ($rk -replace "[:\\]","_")
    reg export $rk "$Base\Registry\RunKeys_$safe.reg" /y
}

# ---- 6. Scheduled tasks (XML definitions + report) ----
Copy-Item "C:\Windows\System32\Tasks" "$Base\ScheduledTasks" -Recurse -Force
Get-ScheduledTask | ForEach-Object {
    [pscustomobject]@{ Name=$_.TaskName; Path=$_.TaskPath; State=$_.State; Actions=(($_.Actions | ForEach-Object {$_.Execute + " " + $_.Arguments}) -join "; ") }
} | Export-Csv "$Base\ScheduledTasks_Report.csv" -NoTypeInformation

# ---- 7. Live system snapshot (run BEFORE disconnecting from network) ----
Get-Process | Select Name,Id,Path,Company,StartTime |
    Export-Csv "$Base\Live_Processes.csv" -NoTypeInformation
Get-NetTCPConnection -State Established |
    Select LocalAddress,LocalPort,RemoteAddress,RemotePort,OwningProcess,@{n='Process';e={(Get-Process -Id $_.OwningProcess -EA SilentlyContinue).Name}} |
    Export-Csv "$Base\Live_NetConnections.csv" -NoTypeInformation
Get-DnsClientCache | Export-Csv "$Base\Live_DNSCache.csv" -NoTypeInformation
Get-Service | Where {$_.Status -eq "Running"} | Export-Csv "$Base\Live_Services.csv" -NoTypeInformation
Get-CimInstance Win32_StartupCommand | Export-Csv "$Base\Live_StartupCommands.csv" -NoTypeInformation

# ---- 8. Defender MPLogs (URLs/paths scanned even without detections) ----
Copy-Item "C:\ProgramData\Microsoft\Windows Defender\Support" "$Base\DefenderSupport" -Recurse -Force

# ---- 9. Quick triage report of key events (last 7 days) ----
$since = (Get-Date).AddDays(-7)
Get-WinEvent -FilterHashtable @{LogName="Security";Id=4624,4625,4672,4720,4688;StartTime=$since} -EA SilentlyContinue |
    Select TimeCreated,Id,Message | Out-File "$Base\Triage_Security_7days.txt"
Get-WinEvent -FilterHashtable @{LogName="System";Id=7045,7040;StartTime=$since} -EA SilentlyContinue |
    Select TimeCreated,Id,Message | Out-File "$Base\Triage_ServiceInstalls_7days.txt"

Write-Host "Collection complete: $Base" -ForegroundColor Green