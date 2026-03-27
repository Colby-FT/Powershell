&{
# =======================================================================
# --- USER DEFINED VARIABLES ---
# Define the core variables for the investigation here:
# =======================================================================

# 1. Exact UTC event time from the alert (Format: YYYY-MM-DDTHH:MM:SSZ)
    # Examples:
        # $AlertTimeString = "2024-06-15T14:22:30Z"
$AlertTimeString = ""

# 2. The affected user's profile name (used to search AppData directories)
    # Examples:
        # $TargetUsername  = "awest"
$TargetUsername  = ""

# 3. The malicious domain or IP address from the alert
    # Examples:
        # $MaliciousAddress = "DefinitelyNotMalicious.com"
        # $MaliciousAddress = "134.52.123.45"
$MaliciousAddress = ""

# =======================================================================
# --- INPUT VALIDATION ---
# =======================================================================

# Validate AlertTimeString
while ([string]::IsNullOrWhiteSpace($AlertTimeString)) {
    Write-Host "ERROR: AlertTimeString cannot be empty" -ForegroundColor Red
    $AlertTimeString = Read-Host "Enter Alert Time (UTC format YYYY-MM-DDTHH:MM:SSZ)"
}

# Attempt to parse the UTC time string into a DateTime object
try {
    $AlertTimeUTC = [datetime]::Parse($AlertTimeString, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
} catch {
    Write-Host "ERROR: Invalid date/time format. Expected: YYYY-MM-DDTHH:MM:SSZ" -ForegroundColor Red
    $AlertTimeString = Read-Host "Enter Alert Time (UTC format YYYY-MM-DDTHH:MM:SSZ)"
    $AlertTimeUTC = [datetime]::Parse($AlertTimeString, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
}

# =======================================================================
# --- SCRIPT EXECUTION ---
# =======================================================================

# Create a generous search window (-5 minutes to +15 minutes)
$StartTimeUTC = $AlertTimeUTC.AddMinutes(-5)
$EndTimeUTC = $AlertTimeUTC.AddMinutes(15)

# Convert strictly to the PC's Local Time for Event Logs
$StartTimeLocal = $StartTimeUTC.ToLocalTime()
$EndTimeLocal = $EndTimeUTC.ToLocalTime()

Write-Host "Collecting forensic data from $($StartTimeLocal) to $($EndTimeLocal) Local Time..." -ForegroundColor Cyan

# Initialize collection hashtable for all results
$Results = @{
    ProcessEvents = $null
    PSEvents = $null
    DroppedFiles = @()
    DroppedFilesWarnings = @()
    DNSResults = $null
    DNSWarning = $null
    RegistryHives = @{}
    RegistryWarnings = @()
    NetworkConnections = $null
    MaliciousConnections = $null
    ScheduledTasks = $null
    ScheduledTasksWarning = $null
    WMIConsumers = $null
    WMIBindings = $null
    WMIFilters = $null
    WMIWarning = $null
}

# =======================================================================
# Collect Event Logs for relevant activity within the time window
# =======================================================================

# Collect Security Logs for Process Executions (Event 4688)
$Results.ProcessEvents = Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4688; StartTime=$StartTimeLocal; EndTime=$EndTimeLocal} -ErrorAction SilentlyContinue | 
Select-Object TimeCreated, 
              @{Name='NewProcess';Expression={$_.Properties[5].Value}}, 
              @{Name='CommandLine';Expression={$_.Properties[8].Value}},
              @{Name='ParentProcess';Expression={$_.Properties[13].Value}} | 
Where-Object { 
    ($_.CommandLine -notmatch 'rocketagent|Datto|centrastage') -and
    ($_.NewProcess -notmatch 'rocketagent|Datto|centrastage') -and
    ($_.ParentProcess -notmatch 'rocketagent|Datto|centrastage') -and
    # Exclude benign system processes and services
    ($_.NewProcess -notmatch '(backgroundTaskHost|taskhostw|RuntimeBroker|sppsvc|wbem\\wmiprvse|conhost|SearchIndexer|SearchFilterHost|SearchProtocolHost|svchost|services\.exe|lsass|csrss|userinit|explorer\.exe|dllhost|rundll32.*shell32|OpenConsole|windowsterminal)' -or
     ($_.CommandLine -match '(Invoke-WebRequest|Invoke-RestMethod|curl|powershell.*-enc|\bIEX\b|DownloadString|DownloadFile|\$\(|certutil|bitsadmin)'))
}

# Collect PowerShell Logs for Suspicious Activity (Event 4104)
# Use stricter indicators to reduce noise from module metadata / normal system cmdlet code.
$psSuspiciousRegex = '(?i)\b(?:Invoke-Expression|IEX|\-enc|\-nop|\-w(?:\s+hidden)?|FromBase64String|DownloadString|Invoke-WebRequest|Invoke-RestMethod|Invoke-Command|New-Object\s+System\.Net\.WebClient|WebClient|Start-Process\s+powershell|certutil|bitsadmin|curl\s+http|powershell\s+-EncodedCommand|Invoke-WebRequest|DownloadFile|Invoke-RestMethod)\b'
$Results.PSEvents = Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-PowerShell/Operational'; ID=4104; StartTime=$StartTimeLocal; EndTime=$EndTimeLocal} -ErrorAction SilentlyContinue |
Where-Object {
    $_.Message -notmatch 'Workaround for DRMM' -and
    $_.Message -notmatch 'HelpUri=' -and
    $_.Message -match $psSuspiciousRegex
} |
ForEach-Object {
    $allLines = ($_.Message -split "[\r\n]+" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    $matchedLines = $allLines | Where-Object { $_ -match $psSuspiciousRegex }

    [PSCustomObject]@{
        TimeCreated    = $_.TimeCreated
        EventID        = $_.Id
        ProviderName   = $_.ProviderName
        MatchingTerms  = ([regex]::Matches($allLines -join " `n", $psSuspiciousRegex) | ForEach-Object {$_.Value}) -join ', '
        MessageSnippet = ($matchedLines | Select-Object -First 8) -join "`n"
    }
}

# =======================================================================
# Collect Dropped Files in common Staging Directories
# =======================================================================
if (-not [string]::IsNullOrWhiteSpace($TargetUsername)) {
    $TargetPaths = @(
        # User-specific locations
        "C:\Users\$TargetUsername\AppData\Local\Temp",
        "C:\Users\$TargetUsername\AppData\Roaming",
        "C:\Users\$TargetUsername\Downloads",
        
        # System-wide / World-writable locations
        "C:\ProgramData",
        "C:\Users\Public",
        "C:\Windows\Temp",
        "C:\PerfLogs",
        "C:\Windows\Tasks"
    )
    
    # Iterate through paths, filtering for items created within the time window
    foreach ($Path in $TargetPaths) {
        if (Test-Path $Path) {
            $DroppedFiles = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.CreationTimeUtc -ge $StartTimeUTC -and $_.CreationTimeUtc -le $EndTimeUTC } |
            Select-Object FullName, CreationTimeUtc, Length, Extension |
            Sort-Object CreationTimeUtc -Descending
            
            if ($DroppedFiles) {
                $Results.DroppedFiles += @{Path = $Path; Files = $DroppedFiles}
            }
        } else {
            $Results.DroppedFilesWarnings += "Path not accessible: $Path"
        }
    }
} else {
    $Results.DroppedFilesWarnings += "Skipping user-specific file search: TargetUsername is not provided"
}

# =======================================================================
# Collect DNS Cache for Malicious Domain or IP Resolution
# =======================================================================
[array]$resolvedMaliciousIPs = @()

if (-not [string]::IsNullOrWhiteSpace($MaliciousAddress)) {
    $Results.DNSResults = Get-DnsClientCache | 
        Where-Object { $_.Entry -like "*$MaliciousAddress*" -or $_.Data -like "*$MaliciousAddress*" } | 
        Select-Object Entry, RecordName, RecordType, Data

    if ($Results.DNSResults) {
        # Force the result into an array to prevent string concatenation bugs
        [array]$resolvedMaliciousIPs = @($Results.DNSResults | ForEach-Object { $_.Data } |
            Where-Object { [System.Net.IPAddress]::TryParse($_, [ref]$null) } |
            Select-Object -Unique)
    }

    $ipRef = $null
    if ([System.Net.IPAddress]::TryParse($MaliciousAddress, [ref]$ipRef)) {
        $resolvedMaliciousIPs += $MaliciousAddress
    }

    # Re-cast to array just to be safe after Select-Object
    [array]$resolvedMaliciousIPs = @($resolvedMaliciousIPs | Select-Object -Unique)

    if ($resolvedMaliciousIPs.Count -gt 0) {
        $Results.DNSWarning = "Resolved malicious address to IP(s): $($resolvedMaliciousIPs -join ', ')"
    } else {
        $Results.DNSWarning = "No DNS cache IP resolved for: $MaliciousAddress"
    }
} else {
    $Results.DNSWarning = "Skipping DNS cache check: MaliciousAddress is not provided"
}

# =======================================================================
# Collect Registry Run Keys for Persistence Mechanisms
# =======================================================================
$RegistryPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
)

foreach ($RegPath in $RegistryPaths) {
    try {
        if (Test-Path $RegPath) {
            $RunKeys = Get-ItemProperty -Path $RegPath -ErrorAction SilentlyContinue |
                Select-Object -Property * -ExcludeProperty PSPath, PSParentPath, PSChildName, PSDrive, PSProvider
            
            if ($RunKeys) {
                $Results.RegistryHives[$RegPath] = $RunKeys
            }
        }
    } catch {
        $Results.RegistryWarnings += "Could not access registry path: $RegPath - $_"
    }
}

# =======================================================================
# Collect Network Connections for Malicious Destinations
# =======================================================================
$Results.NetworkConnections = Get-NetTCPConnection -ErrorAction SilentlyContinue |
    Where-Object { $_.State -in @('Established', 'TimeWait', 'CloseWait', 'SynSent', 'SynReceived') } |
    Where-Object { $_.RemoteAddress -ne '127.0.0.1' } |
    Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State, @{
        Name='OwningProcess';
        Expression={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).Name}
    }

if (-not [string]::IsNullOrWhiteSpace($MaliciousAddress)) {
    if ($resolvedMaliciousIPs -and $resolvedMaliciousIPs.Count -gt 0) {
        $Results.MaliciousConnections = $Results.NetworkConnections | Where-Object { $resolvedMaliciousIPs -contains $_.RemoteAddress }
    } else {
        $Results.MaliciousConnections = $Results.NetworkConnections | Where-Object { $_.RemoteAddress -eq $MaliciousAddress }
    }
}

# =======================================================================
# Collect Scheduled Tasks for Suspicious Activity
# =======================================================================
try {
    $taskPathRoot = Join-Path $env:windir 'System32\Tasks'

    $Results.ScheduledTasks = Get-ScheduledTask -ErrorAction SilentlyContinue | ForEach-Object {
        $taskPathRelative = $_.TaskPath.TrimStart('\').TrimEnd('\')
        if ([string]::IsNullOrEmpty($taskPathRelative)) {
            $taskFilePath = Join-Path $taskPathRoot $_.TaskName
        } else {
            $taskFilePath = Join-Path $taskPathRoot (Join-Path $taskPathRelative $_.TaskName)
        }

        # Fix it if TaskPath has forward slashes or escaped backslashes
        $taskFilePath = $taskFilePath -replace '/', '\\'

        $createTime = $null
        $modifyTime = $null
        if (Test-Path $taskFilePath) {
            $info = Get-Item -LiteralPath $taskFilePath -ErrorAction SilentlyContinue
            if ($info) {
                $createTime = $info.CreationTime
                $modifyTime = $info.LastWriteTime
            }
        }

        [PSCustomObject]@{
            TaskName      = $_.TaskName
            TaskPath      = $_.TaskPath
            LastRunTime   = $_.LastRunTime
            LastTaskResult= $_.LastTaskResult
            NextRunTime   = ($_.Triggers | Select-Object -First 1).StartBoundary
            CreatedTime   = $createTime
            ModifiedTime  = $modifyTime
        }
    } | Where-Object {
        ($_.CreatedTime -and $_.CreatedTime -ge $StartTimeLocal -and $_.CreatedTime -le $EndTimeLocal) -or
        ($_.ModifiedTime -and $_.ModifiedTime -ge $StartTimeLocal -and $_.ModifiedTime -le $EndTimeLocal)
    }
} catch {
    $Results.ScheduledTasksWarning = "Could not retrieve scheduled tasks: $_"
}

# =======================================================================
# Collect WMI Event Consumers for Persistence (Filtered for Noise)
# =======================================================================
try {
    # Define the known-good default Windows WMI entries to ignore
    $wmiExclusions = '(?i)^(SCM Event Log Consumer|SCM Event Log Filter|BVTFilter|BVTConsumer)$'

    $Results.WMIConsumers = Get-WmiObject -Namespace "root\Subscription" -Class __EventConsumer -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch $wmiExclusions }

    $Results.WMIBindings = Get-WmiObject -Namespace "root\Subscription" -Class __FilterToConsumerBinding -ErrorAction SilentlyContinue |
        Where-Object { $_.Consumer -notmatch $wmiExclusions -and $_.Filter -notmatch $wmiExclusions }

    $Results.WMIFilters = Get-WmiObject -Namespace "root\Subscription" -Class __EventFilter -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch $wmiExclusions }

} catch {
    $Results.WMIWarning = "Could not retrieve WMI Event Consumers: $_"
}

# =======================================================================
# OUTPUT ALL RESULTS
# =======================================================================

Write-Host "`n$('='*75)" -ForegroundColor Cyan
Write-Host "INVESTIGATION RESULTS" -ForegroundColor Cyan
Write-Host "Alert Time: $AlertTimeUTC UTC" -ForegroundColor Cyan
Write-Host "Search Window: $($StartTimeLocal) to $($EndTimeLocal) Local Time" -ForegroundColor Cyan
Write-Host "$('='*75)`n" -ForegroundColor Cyan

# Display Process Executions
Write-Host "--- Suspicious Process Executions (Event 4688) ---" -ForegroundColor Yellow
if ($Results.ProcessEvents) {
    $Results.ProcessEvents | ForEach-Object {
        $risk = 'Unknown'
        if ($_.CommandLine -match '(Invoke-WebRequest|Invoke-RestMethod|curl.*http)') { $risk = 'HIGH' }
        elseif ($_.CommandLine -match '(powershell.*-enc|certutil|bitsadmin)') { $risk = 'HIGH' }
        elseif ($_.CommandLine -match '(\$\(|IEX|DownloadFile)') { $risk = 'CRITICAL' }
        
        $riskColor = 'White'
        if ($risk -eq 'HIGH') { $riskColor = 'Magenta' }
        if ($risk -eq 'CRITICAL') { $riskColor = 'Red' }
        
        Write-Host "[$risk]" -ForegroundColor $riskColor -NoNewline
        Write-Host " $(([System.IO.Path]::GetFileName($_.NewProcess))) | Parent: $(([System.IO.Path]::GetFileName($_.ParentProcess)))"
        Write-Host "  Cmd: $($_.CommandLine)" -ForegroundColor Gray
        Write-Host "  Time: $($_.TimeCreated)" -ForegroundColor Gray
        Write-Host ""
    }
    Write-Host "Found $($Results.ProcessEvents.Count) suspicious process execution(s)" -ForegroundColor Yellow
} else {
    Write-Host "No suspicious process executions found" -ForegroundColor Green
}

# Display PowerShell Logs
Write-Host "`n--- Suspicious PowerShell Executions (Event 4104) ---" -ForegroundColor Yellow
if ($Results.PSEvents) {
    $Results.PSEvents | Format-List TimeCreated, EventID, ProviderName, @{Name='Matches';Expression={$_.MatchingTerms -join ', '}}, @{Name='Snippet';Expression={$_.MessageSnippet}}
    Write-Host "Found $($Results.PSEvents.Count) suspicious PowerShell execution(s)" -ForegroundColor Yellow
} else {
    Write-Host "No suspicious PowerShell executions found. Either there were no matching events, or PowerShell logging is not enabled." -ForegroundColor Green
}

# Display Dropped Files
Write-Host "`n--- Suspicious Dropped Files ---" -ForegroundColor Yellow
if ($Results.DroppedFiles.Count -gt 0) {
    foreach ($DroppedFileSet in $Results.DroppedFiles) {
        Write-Host "Files in $($DroppedFileSet.Path):" -ForegroundColor Cyan
        $DroppedFileSet.Files | Format-Table -AutoSize
    }
} else {
    if ($Results.DroppedFilesWarnings.Count -gt 0) {
        foreach ($Warning in $Results.DroppedFilesWarnings) {
            Write-Host $Warning -ForegroundColor Gray
        }
    } else {
        Write-Host "No suspicious PowerShell executions found. Either there were no matching events, or PowerShell logging is not enabled." -ForegroundColor Green
    }
}

# Display DNS Results
Write-Host "`n--- DNS Cache Check ---" -ForegroundColor Yellow
if ($Results.DNSWarning) {
    Write-Host $Results.DNSWarning -ForegroundColor Gray
}
if ($Results.DNSResults) {
    $Results.DNSResults | Format-Table -AutoSize
    Write-Host "Found DNS resolution for malicious address: $MaliciousAddress" -ForegroundColor Yellow
} elseif (-not [string]::IsNullOrWhiteSpace($MaliciousAddress)) {
    Write-Host "No DNS cache entries found for: $MaliciousAddress" -ForegroundColor Green
}

# Display Registry Results
Write-Host "`n--- Registry Run Keys (Persistence Check) ---" -ForegroundColor Yellow
Write-Host "Note: Registry entries shown are current state (no time filtering available)" -ForegroundColor Gray
if ($Results.RegistryHives.Count -gt 0) {
    foreach ($HivePath in $Results.RegistryHives.Keys) {
        Write-Host "Registry entries in $($HivePath):" -ForegroundColor Cyan
        $Results.RegistryHives[$HivePath] | Format-List
    }
} else {
    Write-Host "No registry entries found" -ForegroundColor Green
}
if ($Results.RegistryWarnings.Count -gt 0) {
    foreach ($Warning in $Results.RegistryWarnings) {
        Write-Host $Warning -ForegroundColor Gray
    }
}

# Display Network Connections
Write-Host "`n--- Network Connections ---" -ForegroundColor Yellow

# Always show malicious connections if we were looking for them
if (-not [string]::IsNullOrWhiteSpace($MaliciousAddress)) {
    if ($Results.MaliciousConnections) {
        Write-Host "[CRITICAL] Connections to malicious address ($MaliciousAddress) / IPs:" -ForegroundColor Red
        $Results.MaliciousConnections | Format-Table -AutoSize
    } else {
        Write-Host "No active connections to known malicious address: $MaliciousAddress" -ForegroundColor Green
    }
}

# Still show the rest of the connections for general forensic visibility
if ($Results.NetworkConnections) {
    Write-Host "`nAll established/active network connections:" -ForegroundColor Cyan
    $Results.NetworkConnections | Format-Table -AutoSize
} else {
    Write-Host "No active network connections found" -ForegroundColor Green
}

# Display Scheduled Tasks
Write-Host "`n--- Scheduled Tasks (Recent Executions) ---" -ForegroundColor Yellow
if ($Results.ScheduledTasksWarning) {
    Write-Host $Results.ScheduledTasksWarning -ForegroundColor Yellow
} elseif ($Results.ScheduledTasks) {
    Write-Host "Scheduled tasks run during alert timeframe:" -ForegroundColor Yellow
    $Results.ScheduledTasks | Format-Table -AutoSize
} else {
    Write-Host "No scheduled tasks executed during alert timeframe" -ForegroundColor Green
}

# Display WMI Event Consumers
Write-Host "`n--- WMI Event Consumers (Persistence Mechanism) ---" -ForegroundColor Yellow
if ($Results.WMIWarning) {
    Write-Host $Results.WMIWarning -ForegroundColor Yellow
} else {
    if ($Results.WMIConsumers) {
        Write-Host "WMI Event Consumers found:" -ForegroundColor Yellow
        $Results.WMIConsumers | Select-Object Name, __CLASS | Format-Table -AutoSize
    } else {
        Write-Host "No WMI Event Consumers detected" -ForegroundColor Green
    }
    
    if ($Results.WMIBindings) {
        Write-Host "WMI Filter-to-Consumer Bindings found:" -ForegroundColor Yellow
        $Results.WMIBindings | Format-Table -AutoSize
    }
    
    if ($Results.WMIFilters) {
        Write-Host "WMI Event Filters:" -ForegroundColor Cyan
        $Results.WMIFilters | Select-Object Name, Query | Format-Table -AutoSize
    }
}

Write-Host "`n$('='*75)" -ForegroundColor Cyan
Write-Host "Investigation Complete" -ForegroundColor Cyan
Write-Host "$('='*75)`n" -ForegroundColor Cyan
}