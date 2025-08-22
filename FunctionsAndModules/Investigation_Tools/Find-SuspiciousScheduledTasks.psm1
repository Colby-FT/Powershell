function Find-SuspiciousScheduledTasks {
    <#
    .SYNOPSIS
    Scans scheduled tasks for suspicious indicators such as tampered signatures, privileged execution, obfuscated arguments, and malicious VirusTotal detections.

    .DESCRIPTION
    This function analyzes scheduled tasks on a Windows system to identify potentially malicious or misconfigured tasks. It checks for:
    - Tampered or unsigned executables
    - Suspicious command-line flags
    - Privileged execution contexts
    - Triggers commonly used by malware
    - VirusTotal reputation of executables

    Results are scored and optionally exported to CSV for further analysis.

    .PARAMETER KnownGoodSigners
    List of certificate subjects considered trusted for signed executables.

    .PARAMETER ExcludeVerifiedSigned
    If set, excludes tasks with verified trusted signatures from results.

    .PARAMETER IncludeDisabled
    If set, includes disabled tasks in the scan.

    .PARAMETER ExportCsvPath
    Path to export results to a CSV file.

    .PARAMETER VirusTotalApiKey
    API key for querying VirusTotal for file reputation.

    .EXAMPLE
    Find-SuspiciousScheduledTasks -ExportCsvPath "C:\SuspiciousTasks.csv" -VirusTotalApiKey "your-api-key"
    Scans scheduled tasks and exports suspicious ones to a CSV file, including VirusTotal reputation data.
    #>
    [CmdletBinding()]
    param (
        [string[]]$KnownGoodSigners = @("CN=Microsoft Corporation", "CN=Microsoft Windows", "CN=Microsoft Code Signing PCA"),
        [switch]$ExcludeVerifiedSigned,
        [switch]$IncludeDisabled,
        [switch]$cleanConsoleOutput,
        [string]$ExportCsvPath,
        [string]$VirusTotalApiKey
    )

    Begin {
        function Get-SignerInfo {
            param ($Path)
            if (-not $Path -or -not (Test-Path $Path)) {
                return @{ Signer = "Path not found"; Tampered = $false }
            }
            $sig = Get-AuthenticodeSignature $Path
            switch ($sig.Status) {
                'Valid' { return @{ Signer = $sig.SignerCertificate.Subject; Tampered = $false } }
                'HashMismatch' { return @{ Signer = "Tampered: Signature mismatch"; Tampered = $true } }
                'NotSigned' { return @{ Signer = "Not signed"; Tampered = $false } }
                default { return @{ Signer = "Signature status: $($sig.Status)"; Tampered = $true } }
            }
        }

        function Get-SuspiciousFlags {
            param ($Arguments)
            $flags = @('-EncodedCommand', '-nop', '-w hidden', '-noni', '-noexit')
            return $flags | Where-Object { $Arguments -match $_ }
        }

        function Score-Task {
            param ($Privileged, $Tampered, $Flags, $Triggers, $MaliciousCount)
            $score = 0
            if ($Privileged) { $score += 2 }
            if ($Tampered) { $score += 3 }
            if ($Flags.Count -gt 0) { $score += 2 }
            if ($Triggers | Where-Object { $_ -in @('Logon', 'Logoff', 'Startup', 'Boot', 'Shutdown') }) { $score += 2 }
            if ($MaliciousCount -gt 0) { $score += 5 }
            return $score
        }

        function Query-VirusTotal {
            param (
                [string]$FilePath,
                [string]$ApiKey
            )
            if (-not $FilePath -or -not (Test-Path $FilePath)) {
                return 0
            }
            $hash = (Get-FileHash $FilePath -Algorithm SHA256).Hash
            $url = "https://www.virustotal.com/api/v3/files/$hash"
            $headers = @{ "x-apikey" = $ApiKey }

            try {
                $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
                return $response.data.attributes.last_analysis_stats.malicious
            } catch {
                Write-Warning "VirusTotal query failed for $FilePath"
                return 0
            }
        }

        function IsValidPath {
            param ($Path)
            return ($Path -and $Path -notmatch '[<>:"|?*]' -and (Test-Path $Path))
        }

        $results = @()
    }

    Process {
        $tasks = Get-ScheduledTask

        foreach ($task in $tasks) {
            if (-not $IncludeDisabled -and $task.State -ne 'Ready') { continue }

            $user = $task.Principal.UserId
            $privileged = $user -match 'SYSTEM|Administrator'

            $suspiciousActions = @()
            $suspiciousTriggers = @()
            $score = 0

            foreach ($action in $task.Actions) {
                $flags = Get-SuspiciousFlags $action.Arguments
                $execPath = $action.Execute
                $resolvedPath = $null

                if ($execPath) {
                    try {
                        $resolvedPath = (Get-Command $execPath -ErrorAction SilentlyContinue).Source
                    } catch {}
                }

                $fullPath = if (IsValidPath $execPath) { $execPath }
                            elseif (IsValidPath $resolvedPath) { $resolvedPath }
                            else { $null }

                $sigInfo = Get-SignerInfo $fullPath
                if ($ExcludeVerifiedSigned -and $KnownGoodSigners -contains $sigInfo.Signer -and -not $sigInfo.Tampered) {
                    continue
                }

                $maliciousCount = 0
                if ($VirusTotalApiKey) {
                    $maliciousCount = Query-VirusTotal -FilePath $fullPath -ApiKey $VirusTotalApiKey
                }

                $taskScore = Score-Task $privileged $sigInfo.Tampered $flags $task.Triggers.TriggerType $maliciousCount
                $score += $taskScore

                $suspiciousActions += [PSCustomObject]@{
                    Execute = $action.Execute
                    Arguments = $action.Arguments
                    Flags = $flags -join ', '
                    Signer = $sigInfo.Signer
                    Tampered = $sigInfo.Tampered
                    VirusTotalMalicious = $maliciousCount
                    Score = $taskScore
                }
            }

            foreach ($trigger in $task.Triggers) {
                if ($trigger.TriggerType -in @('Logon', 'Logoff', 'Startup', 'Boot', 'Shutdown')) {
                    $suspiciousTriggers += $trigger.TriggerType
                }
            }

            if ($suspiciousActions.Count -gt 0 -or $suspiciousTriggers.Count -gt 0) {
                $results += [PSCustomObject]@{
                    TaskName = $task.TaskName
                    TaskPath = $task.TaskPath
                    RunAsUser = $user
                    Privileged = $privileged
                    Actions = $suspiciousActions
                    Triggers = $suspiciousTriggers
                    Score = $score
                }
            }
        }
    }

    End {
        if ($ExportCsvPath) {
            $flatResults = @()
            foreach ($task in $results) {
                foreach ($action in $task.Actions) {
                    $flatResults += [PSCustomObject]@{
                        TaskName = $task.TaskName
                        TaskPath = $task.TaskPath
                        RunAsUser = $task.RunAsUser
                        Privileged = $task.Privileged
                        Execute = $action.Execute
                        Arguments = $action.Arguments
                        Flags = $action.Flags
                        Signer = $action.Signer
                        Tampered = $action.Tampered
                        VirusTotalMalicious = if ($VirusTotalApiKey) { $action.VirusTotalMalicious } else { $null }
                        Triggers = ($task.Triggers -join ', ')
                        Score = $action.Score
                    }
                }
            }
            $flatResults | Export-Csv -Path $ExportCsvPath -NoTypeInformation
            Write-Host "Results exported to $ExportCsvPath"
        }
        if ($cleanConsoleOutput){
                foreach ($task in $results) {
                Write-Host "Suspicious Task Detected:"
                Write-Host "  Task Name: $($task.TaskName)"
                Write-Host "  Run As User: $($task.RunAsUser)"
                Write-Host "  Privileged: $($task.Privileged)"
                Write-Host "  Score: $($task.Score)"
                foreach ($action in $task.Actions) {
                    Write-Host "    Executes: $($action.Execute)"
                    Write-Host "    Arguments: $($action.Arguments)"
                    Write-Host "    Flags: $($action.Flags)"
                    Write-Host "    Signer: $($action.Signer)"
                    if ($VirusTotalApiKey) {
                        Write-Host "    VirusTotal Malicious: $($action.VirusTotalMalicious)"
                    }
                    if ($action.Tampered -and $action.Signer -notmatch "Not signed|Path not found") {
                        Write-Host "    ⚠️ Tampered File Detected"
                    }
                }
                if ($task.Triggers.Count -gt 0) {
                    Write-Host "  Suspicious Triggers:"
                    $task.Triggers | ForEach-Object { Write-Host "    $_" }
                }
                Write-Host "----------------------------------------"
            }
        }
        else {
            return $results
        }
    }
}
