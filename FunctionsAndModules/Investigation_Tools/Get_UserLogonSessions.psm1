function Get-UserLogonSessions {
    <#
    .SYNOPSIS
    Retrieves information about user logon sessions.

    .DESCRIPTION
    This function retrieves details about user logon sessions from the Windows Security event log. 
    It filters the logon events (Event ID 4624) based on the specified username(s) and date range. 
    The output includes the username, logon time, and logon type for each session.

    This function is useful for investigating user activity, auditing, and troubleshooting logon-related issues.

    .PARAMETER UserName
    Specifies the username(s) to filter the logon sessions. Wildcards are supported (e.g., "*", "jdoe*", etc.).
    By default, all usernames are included.

    .PARAMETER StartDate
    Specifies the start date for the logon session search. Only events occurring on or after this date are included.
    The default is one day prior to the current date.

    .PARAMETER EndDate
    Specifies the end date for the logon session search. Only events occurring on or before this date are included.
    The default is the current date.

    .EXAMPLE
    Get-UserLogonSessions -UserName "jdoe" -StartDate "2023-01-01" -EndDate "2023-01-31"
    Retrieves logon sessions for user "jdoe" within the specified date range.

    .EXAMPLE
    Get-UserLogonSessions -UserName "*" -StartDate (Get-Date).AddDays(-7) -EndDate (Get-Date)
    Retrieves logon sessions for all users within the last 7 days.

    .EXAMPLE
    Get-UserLogonSessions -UserName "admin*" -Verbose
    Retrieves logon sessions for all users whose usernames start with "admin" and displays verbose output.

    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$UserName = "*",

        [ValidateScript({ $_ -is [datetime] -or ([datetime]::TryParse($_, [ref]$null)) })]
        [datetime]$StartDate = (Get-Date).AddDays(-1).Date,

        [ValidateScript({ $_ -is [datetime] -or ([datetime]::TryParse($_, [ref]$null)) })]
        [datetime]$EndDate = (Get-Date).Date.AddDays(1).AddSeconds(-1)
    )
    begin {
        Write-Verbose "Initializing logon session retrieval process."
        $LogonSessions = @()
    }
    process {
        Write-Verbose "Retrieving logon sessions from Security event log within the specified date range."

        try {
            $Filter = @{
                LogName = "Security"
                Id = 4624
                StartTime = $StartDate
                EndTime = $EndDate
            }

            $LogonSessions = Get-WinEvent -FilterHashtable $Filter -ErrorAction Stop |
                Where-Object {
                    ($_.Properties[5].Value -like $UserName)
                } |
                Select-Object @{Name = 'UserName'; Expression = { $_.Properties[5].Value }},
                              @{Name = 'LogonTime'; Expression = { $_.TimeCreated }},
                              @{Name = 'LogonType'; Expression = { $_.Properties[8].Value }}

            if ($LogonSessions.Count -eq 0) {
                Write-Warning "No logon sessions found for the specified criteria."
            } else {
                Write-Verbose "Logon sessions retrieved: $($LogonSessions.Count)"
            }
        } catch {
            Write-Error "An error occurred while retrieving logon sessions: $_.Exception.Message"
            Write-Debug "Error details: $_"
        }
    }
    end {
        Write-Verbose "Logon session retrieval process completed."
        Write-Debug "Total logon sessions retrieved: $($LogonSessions.Count)"
        return $LogonSessions
    }
}