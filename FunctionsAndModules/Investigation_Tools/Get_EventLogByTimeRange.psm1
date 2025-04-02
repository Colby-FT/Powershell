function Get-EventLogByTimeRange {
    <#
    .SYNOPSIS
    Retrieves Windows Event Logs within a specified time range.

    .DESCRIPTION
    This function retrieves event logs filtered by time range, event ID, source, or level.

    .PARAMETER LogName
    The name of the event log (e.g., "Application", "System").

	.PARAMETER StartDate
	The start of the time range to filter services by. Defaults to the beginning of yesterday.
	Accepts a `datetime` object or a string in a valid date format, such as "YYYY-MM-DD HH:mm:ss" or "MM/DD/YYYY".

	.PARAMETER EndDate
	The end of the time range to filter services by. Defaults to the end of today.
	Accepts a `datetime` object or a string in a valid date format, such as "YYYY-MM-DD HH:mm:ss" or "MM/DD/YYYY".

    .PARAMETER EventID
    The event ID(s) to filter by.

    .PARAMETER Source
    The source(s) to filter by.

    .PARAMETER Level
    The event level(s) to filter by (e.g., "Information", "Warning", "Error").

    .EXAMPLE
    Get-EventLogByTimeRange -LogName "System" -StartDate (Get-Date).AddHours(-1) -EndDate (Get-Date)
    Retrieves system logs from the last hour.

    .EXAMPLE
    Get-EventLogByTimeRange -LogName "Application" -StartDate (Get-Date).AddDays(-7) -EndDate (Get-Date) -EventID 1000
    Retrieves application logs from the last 7 days with Event ID 1000.

    .EXAMPLE
    Get-EventLogByTimeRange -LogName "Security" -StartDate (Get-Date).AddDays(-1) -EndDate (Get-Date) -Level "Error"
    Retrieves security logs from the last day with an event level of "Error".

    .EXAMPLE
    Get-EventLogByTimeRange -LogName "System" -StartDate (Get-Date).AddHours(-2) -EndDate (Get-Date) -Source "Service Control Manager"
    Retrieves system logs from the last 2 hours with the source "Service Control Manager".

    .EXAMPLE
    Get-EventLogByTimeRange -LogName "*" -StartDate (Get-Date).AddDays(-30) -EndDate (Get-Date) -Level "Critical", "Error"
    Retrieves logs from all event logs in the last 30 days with levels "Critical" or "Error".

    .EXAMPLE
    Get-EventLogByTimeRange -LogName "System" -StartDate "2023-10-01 08:00:00" -EndDate "2023-10-01 18:00:00"
    Retrieves system logs between 8:00 AM and 6:00 PM on October 1, 2023.

    .OUTPUTS
    Returns event log entries that match the specified criteria.
    #>
    [CmdletBinding()]
    param (
        [string]$LogName = "*",

		[ValidateScript({ $_ -is [datetime] -or ([datetime]::TryParse($_, [ref]$null)) })]
		[datetime]$StartDate = (Get-Date).AddDays(-1).Date,

		[ValidateScript({ $_ -is [datetime] -or ([datetime]::TryParse($_, [ref]$null)) })]
		[datetime]$EndDate = (Get-Date).Date.AddDays(1).AddSeconds(-1),

        [int[]]$EventID,

        [string[]]$Source,

        [ValidateSet("Information", "Warning", "Error", "Critical", "Verbose", "LogAlways")]
        [string[]]$Level
    )

    process {
        try {
            # Validate LogName
            if ($LogName -ne "*" -and -not (Get-WinEvent -ListLog $LogName -ErrorAction SilentlyContinue)) {
                throw "The specified log name '$LogName' does not exist on this system."
            }

            Write-Verbose "Retrieving logs from '$LogName' between $StartDate and $EndDate."

            $filter = @{
                LogName = $LogName
                StartTime = $StartDate
                EndTime = $EndDate
            }
            if ($EventID) { $filter.Id = $EventID }
            if ($Source) { $filter.ProviderName = $Source }

            $results = Get-WinEvent -FilterHashtable $filter | Where-Object {
                ($null -eq $Level -or $Level -contains $_.LevelDisplayName)
            }

            Write-Verbose "Retrieved $($results.Count) log entries."
            return $results
        } catch {
            Write-Error "An error occurred while retrieving event logs: $_"
            Write-Verbose "Error details: $_"
            return $null
        }
    }
}