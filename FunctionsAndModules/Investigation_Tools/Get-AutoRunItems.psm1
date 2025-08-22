function Get-AutoRunItems {
    <#
    .SYNOPSIS
    Detects auto-run mechanisms configured on a Windows system.

    .DESCRIPTION
    This function scans common locations and configurations that allow programs to automatically run during system startup, user logon, shutdown, or other triggers. It includes:
    - Startup folder items
    - Registry run keys
    - Scheduled tasks
    - WMI event consumers

    Results can be optionally exported to a CSV file.

    .PARAMETER ExportCsvPath
    Path to export the auto-run results to a CSV file.

    .EXAMPLE
    Get-AutoRunItems -ExportCsvPath "C:\AutoRunReport.csv"
    Scans for auto-run entries and exports the results to a CSV file.
    #>
    [CmdletBinding()]
    param (
        [string]$ExportCsvPath
    )

    Begin {
        function Get-StartupFolderItems {
            $paths = @(
                "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
                "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
            )
            $items = @()
            foreach ($path in $paths) {
                if (Test-Path $path) {
                    $items += Get-ChildItem -Path $path -File | Select-Object @{Name="Source";Expression={"Startup Folder"}}, Name, @{Name="Details";Expression={$_.FullName}}
                }
            }
            return $items
        }

        function Get-RegistryRunKeys {
            $locations = @(
                "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
            )
            $entries = @()
            foreach ($loc in $locations) {
                if (Test-Path $loc) {
                    $entries += Get-ItemProperty -Path $loc | ForEach-Object {
                        $_.PSObject.Properties | Where-Object { $_.Name -ne "PSPath" } | ForEach-Object {
                            [PSCustomObject]@{
                                Source = "Registry ($loc)"
                                Name = $_.Name
                                Details = $_.Value
                            }
                        }
                    }
                }
            }
            return $entries
        }

        function Get-ScheduledAutoRunTasks {
            $tasks = Get-ScheduledTask
            return $tasks | Where-Object {
                $_.Triggers.TriggerType -match 'Logon|Startup|Boot|Shutdown'
            } | ForEach-Object {
                [PSCustomObject]@{
                    Source = "Scheduled Task"
                    Name = $_.TaskName
                    Details = "Trigger: $($_.Triggers.TriggerType -join ', ') | State: $($_.State)"
                }
            }
        }

        function Get-WMIEventConsumers {
            try {
                $filters = Get-WmiObject -Namespace "root\subscription" -Class __EventFilter
                $consumers = Get-WmiObject -Namespace "root\subscription" -Class CommandLineEventConsumer
                $bindings = Get-WmiObject -Namespace "root\subscription" -Class __FilterToConsumerBinding

                $results = foreach ($bind in $bindings) {
                    $filter = $filters | Where-Object { $_.__Path -eq $bind.Filter }
                    $consumer = $consumers | Where-Object { $_.__Path -eq $bind.Consumer }
                    if ($filter -and $consumer) {
                        [PSCustomObject]@{
                            Source = "WMI Event Consumer"
                            Name = $consumer.Name
                            Details = "Query: $($filter.Query) | Command: $($consumer.CommandLineTemplate)"
                        }
                    }
                }
                return $results
            } catch {
                Write-Warning "Failed to query WMI event consumers: $_"
                return @()
            }
        }

        $autoRunItems = @()
    }

    Process {
        $autoRunItems += Get-StartupFolderItems
        $autoRunItems += Get-RegistryRunKeys
        $autoRunItems += Get-ScheduledAutoRunTasks
        $autoRunItems += Get-WMIEventConsumers
    }

    End {
        Write-Host "`n=== Auto-Run Items Detected ==="
        $autoRunItems | ForEach-Object {
            Write-Host "[$($_.Source)] $($_.Name): $($_.Details)"
        }

        if ($ExportCsvPath) {
            $autoRunItems | Export-Csv -Path $ExportCsvPath -NoTypeInformation
            Write-Host "`nResults exported to $ExportCsvPath"
        }
    }
}
