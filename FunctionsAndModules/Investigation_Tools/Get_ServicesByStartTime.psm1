function Get-ServicesByStartTime {
	<#
	.SYNOPSIS
	Retrieves services that started within a specified time range or all currently running services.

	.DESCRIPTION
	This function retrieves Windows services that started within a specified time range.
	By default, it checks all services and uses a time range of yesterday to today.
	You can optionally filter by a specific service name or a list of service names.
	Alternatively, you can use the `-IncludeAllRunning` parameter to retrieve all currently running services, regardless of their start time.

	.PARAMETER ServiceName
	The name(s) of the service(s) to filter by. Wildcards are supported. Accepts a single service name, a list of service names, or input from the pipeline. Defaults to "*", which includes all services.

	.PARAMETER StartDate
	The start of the time range to filter services by. Defaults to the beginning of yesterday.
	Accepts a `datetime` object or a string in a valid date format, such as "YYYY-MM-DD HH:mm:ss" or "MM/DD/YYYY".

	.PARAMETER EndDate
	The end of the time range to filter services by. Defaults to the end of today.
	Accepts a `datetime` object or a string in a valid date format, such as "YYYY-MM-DD HH:mm:ss" or "MM/DD/YYYY".

	.PARAMETER IncludeAllRunning
	If specified, retrieves all currently running services, regardless of their start time. Overrides the `StartDate` and `EndDate` parameters.

	.EXAMPLE
	Get-ServicesByStartTime -ServiceName "wuauserv" -StartDate (Get-Date).AddDays(-2) -EndDate (Get-Date).AddDays(-1)
	Retrieves information about the "wuauserv" service that started between two days ago and yesterday.

	.EXAMPLE
	Get-ServicesByStartTime
	Retrieves all services that started between yesterday and today.

	.EXAMPLE
	Get-ServicesByStartTime -StartDate "2025-04-01 08:00:00" -EndDate "2025-04-01 18:00:00"
	Retrieves all services that started between 8:00 AM and 6:00 PM on April 1, 2025.

	.EXAMPLE
	Get-ServicesByStartTime -ServiceName "Win*" -StartDate (Get-Date).AddDays(-7) -EndDate (Get-Date)
	Retrieves all services with names starting with "Win" that started within the last 7 days.

	.EXAMPLE
	Get-ServicesByStartTime -IncludeAllRunning
	Retrieves all currently running services, regardless of their start time.
	#>
	[CmdletBinding()]
	param (
		 [Parameter(ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[string[]]$ServiceName = "*",

		[ValidateScript({ $_ -is [datetime] -or ([datetime]::TryParse($_, [ref]$null)) })]
		[datetime]$StartDate = (Get-Date).AddDays(-1).Date,

		[ValidateScript({ $_ -is [datetime] -or ([datetime]::TryParse($_, [ref]$null)) })]
		[datetime]$EndDate = (Get-Date).Date.AddDays(1).AddSeconds(-1),

		[switch]$IncludeAllRunning
	)

	begin {
		$results = @()
		$serviceNames = @()
	}

	process {
		if ($PSBoundParameters.ContainsKey('ServiceName')) {
			$serviceNames += $ServiceName
		}

		$serviceNames = if ($serviceNames.Count -eq 0) { "*" } else { $serviceNames }
		Write-Verbose "Retrieving services matching the names '$serviceNames'..."
		Get-CimInstance -ClassName Win32_Service | Where-Object { $serviceNames -contains $_.Name -or $_.Name -like $serviceNames } | ForEach-Object {
			$process = Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue
			if ($process -and ($IncludeAllRunning -or ($process.StartTime -ge $StartDate -and $process.StartTime -le $EndDate))) {
				$results += [PSCustomObject]@{
					Name        = $_.Name
					DisplayName = $_.DisplayName
					StartTime   = $process.StartTime
					ProcessId   = $process.Id
					ProcessName = $process.ProcessName
				}
			}
		}
	}	
	end {
		if (-not $results) {
			Write-Verbose "No services found matching the criteria."
			return @() # Return an empty array if no results
		}

		$results = $results | Sort-Object StartTime
		return $results
	}
}