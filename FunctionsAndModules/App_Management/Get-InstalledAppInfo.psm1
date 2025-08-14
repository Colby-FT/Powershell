function Get-InstalledAppInfo {
    <#
    .SYNOPSIS
    Retrieves information about installed applications from the Windows registry.

    .DESCRIPTION
    This function queries both 32-bit and 64-bit registry paths to collect details about installed applications.
    If an application name is provided, it filters results to match the name. Otherwise, it returns all installed applications.

    .PARAMETER AppName
    Optional. The name (or partial name) of the application to search for.

    .EXAMPLE
    Get-InstalledAppInfo -AppName "Chrome"
    Retrieves information about installed applications with names containing "Chrome".
    Note: This wildcards all searches. So, "Chrome" and "*Chrome*" will return the same results.

    .EXAMPLE
    Get-InstalledAppInfo
    Retrieves information about all installed applications.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$AppName
    )

    Begin {
        $registryPaths = @(
            "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )
        $results = @()
    }

    Process {
        foreach ($path in $registryPaths) {
            try {
                $items = Get-ItemProperty $path -ErrorAction Stop
                foreach ($item in $items) {
                    if (-not $AppName -or ($item.DisplayName -like "*$AppName*")) {
                        $results += [PSCustomObject]@{
                            DisplayName    = $item.DisplayName
                            DisplayVersion = $item.DisplayVersion
                            Publisher      = $item.Publisher
                            InstallDate    = $item.InstallDate
                            InstallLocation = $item.InstallLocation
                            UninstallString = $item.UninstallString
                            QuietUninstallString = $item.QuietUninstallString
                        }
                    }
                }
            } catch {
                Write-Warning "Failed to read registry path: $path. Error: $_"
            }
        }
    }

    End {
        return $results
    }
}