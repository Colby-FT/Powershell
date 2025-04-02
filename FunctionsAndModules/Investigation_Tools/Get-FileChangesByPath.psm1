function Get-FileChangesByPath {
    <#
    .SYNOPSIS
    Retrieves a history of file changes in a specified directory within a given date range.

    .DESCRIPTION
    This function scans a given directory and lists files that have been modified within a specified date range. 
    By default, it retrieves files modified in the last 48 hours.

    .PARAMETER Path
    The directory path to scan for file changes.

    .PARAMETER StartDate
    The start date of the range to filter file changes. Defaults to 48 hours ago.

    .PARAMETER EndDate
    The end date of the range to filter file changes. Defaults to the current date and time.

    .EXAMPLE
    Get-FileChangesByPath -Path "C:\MyDirectory"
    Retrieves a list of files modified in the last 48 hours in the specified directory.

    .EXAMPLE
    Get-FileChangesByPath -Path "C:\MyDirectory" -StartDate "2023-01-01" -EndDate "2023-01-02"
    Retrieves a list of files modified between January 1, 2023, and January 2, 2023, in the specified directory.

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [ValidateScript({ $_ -is [datetime] -or ([datetime]::TryParse($_, [ref]$null)) })]
        [datetime]$StartDate = (Get-Date).AddHours(-48),

        [ValidateScript({ $_ -is [datetime] -or ([datetime]::TryParse($_, [ref]$null)) })]
        [datetime]$EndDate = (Get-Date)
    )
    Begin {
        Write-Verbose "Validating the directory path: $Path"
        if (-not (Test-Path -Path $Path -PathType Container)) {
            throw "The specified path '$Path' is not a valid directory."
        }
    }
    Process {
        try {
            Write-Verbose "Retrieving files modified between $StartDate and $EndDate from: $Path"
            $fileChanges = Get-ChildItem -Path $Path -Recurse | Where-Object {
                $_.LastWriteTime -ge $StartDate -and $_.LastWriteTime -le $EndDate
            } | Select-Object FullName, LastWriteTime
        } catch {
            Write-Error "An error occurred while retrieving file changes: $_"
            $fileChanges = @() # Return an empty array in case of error
        }
    }
    End {
        Write-Verbose "Returning the list of file changes."
        return $fileChanges
    }
}
