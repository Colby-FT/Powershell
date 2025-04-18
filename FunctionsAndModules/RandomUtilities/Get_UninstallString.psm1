function Get-UninstallString {
    <#
    .SYNOPSIS
    Get the uninstall string from the registry
    
    .DESCRIPTION
    Searches the registry for an uninstall string for the specified app
    
    .PARAMETER AppName

    .EXAMPLE
    Get-UninstallString -AppName "TeamViewer"
    Gets the uninstall string for TeamViewer

    #>
    [CmdletBinding()]
    param (
        [string]$AppName
    )
    Begin {
        $RegPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        )
    }
    Process {
        $Found = $false
        foreach ($RegPath in $RegPaths) {
            if (Test-Path $RegPath) {
                try {
                    Get-ChildItem -LiteralPath $RegPath | ForEach-Object {
                        Get-ItemProperty -LiteralPath $_.PsPath | ForEach-Object {
                            if ($_.DisplayName -match $AppName) {
                                $UninstallString = $_.UninstallString
                                $DisplayName = $_.DisplayName
                                Write-Verbose "The provided uninstall string for $DisplayName is: "
                                $Found = $true
                                return $UninstallString
                            }
                        }
                    }
                }
                catch {
                    Write-Host "Error accessing registry path: $RegPath"
                }
            }
        }
        if (-not $Found) {
            Write-Host "Uninstall string not found for $AppName."
            return $null
        }
    }
}