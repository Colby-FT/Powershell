function Copy-DrivesParallel {
    <#
    .SYNOPSIS
    Copies drives from one or more remote Windows computers to a local destination in parallel.

    .DESCRIPTION
    Uses robocopy to copy the contents of specified drives (or all available drives) from remote computers using their ADMIN$ shares.
    Supports parallel execution and error handling. Only accessible drives are copied; inaccessible or network drives are skipped.
    Creates destination subdirectories named for each source device and drive letter.

    .PARAMETER SourceDevices
    Array of remote computer names to copy drives from.

    .PARAMETER DestinationDirectory
    Root directory where backups will be stored.

    .PARAMETER MaxConcurrentJobs
    Maximum number of robocopy jobs to run in parallel.

    .PARAMETER AllDrives
    If set, attempts to copy all drive letters (A-Z) from each device. Otherwise, only the system drive is copied.

    .EXAMPLE
    Copy-DrivesParallel -SourceDevices @("COMPUTER1","COMPUTER2") -DestinationDirectory "X:\Backups" -MaxConcurrentJobs 2 -AllDrives
    Copies all available drives from COMPUTER1 and COMPUTER2 to X:\Backups in parallel.

    .EXAMPLE
    Copy-DrivesParallel -SourceDevices @("COMPUTER1") -DestinationDirectory "X:\Backups" -MaxConcurrentJobs 2
    Copies only the system drive from COMPUTER1 to X:\Backups.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$SourceDevices,
        [Parameter(Mandatory)]
        [string]$DestinationDirectory,
        [int]$MaxConcurrentJobs = 2,
        [switch]$AllDrives
    )
    Begin {
        $procQueue = @()
        $spinner = @('|','/','-','\')
        $spinIndex = 0
    }
    Process {
        foreach ($device in $SourceDevices) {
            # Choose drives to copy
            if ($AllDrives) {
                $drives = [char[]](65..90) | ForEach-Object { $_.ToString() } # A-Z
            } else {
                $drives = @($env:SystemDrive.TrimEnd(':'))
            }

            foreach ($driveLetter in $drives) {
                $sourcePath = "\\$device\$driveLetter`$"
                # Only copy if source path exists
                if (!(Test-Path $sourcePath)) {
                    Write-Warning "Skipping ${sourcePath} Path not found or inaccessible."
                    continue
                }
                $destPath = Join-Path -Path $DestinationDirectory -ChildPath "$device\Drive-$driveLetter"
                if (!(Test-Path -Path $destPath)) {
                    try {
                        New-Item -Path $destPath -ItemType Directory | Out-Null
                        attrib -H -S $destPath
                    } catch {
                        Write-Error "Failed to create destination directory ${destPath}"
                        continue
                    }
                }
                $logPath = Join-Path -Path $DestinationDirectory -ChildPath "RoboLogs\$device`_$driveLetter.log"
                if (!(Test-Path -Path (Split-Path $logPath))) {
                    try {
                        New-Item -Path (Split-Path $logPath) -ItemType Directory | Out-Null
                    } catch {
                        Write-Error "Failed to create log directory $(Split-Path $logPath)"
                        continue
                    }
                }

                # Limit concurrent jobs
                while ($procQueue.Count -ge $MaxConcurrentJobs) {
                    $procQueue = $procQueue | Where-Object { !$_.HasExited }
                    $runningCount = $procQueue.Count
                    $spinnerChar = $spinner[$spinIndex % $spinner.Count]
                    $spinIndex++
                    Write-Host ("`r{0} Jobs running: {1} " -f $spinnerChar, $runningCount) -NoNewline
                    Start-Sleep -Seconds 2
                }

                # Start robocopy process
                try {
                    $arguments = @(
                        $sourcePath
                        $destPath
                        "/w:1"
                        "/r:1"
                        "/e"
                        "/xj"
                        "/mt:64"
                        "/z"
                        "/log:$logPath"
                        "/fp"
                        "/v"
                    )
                    $proc = Start-Process -FilePath "robocopy.exe" -ArgumentList $arguments -NoNewWindow -PassThru
                    if ($null -eq $proc) {
                        throw "Start-Process did not return a process object."
                    }
                    Write-Host ("Started robocopy for {0}:{1}" -f $device, $driveLetter)
                    $procQueue += $proc
                } catch {
                    Write-Error "Failed to start robocopy process for ${sourcePath}: $_"
                }
            }
        }
    }
    End {
        # Wait for all remaining robocopy processes to finish
        while ($procQueue.Count -gt 0) {
            $procQueue = $procQueue | Where-Object { !$_.HasExited }
            Start-Sleep -Seconds 2
        }
        Write-Host "`rAll jobs completed.              "
    }
}