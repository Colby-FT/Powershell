function Uninstall-WithUninstallString {
    <#
    .SYNOPSIS
    Uninstall an application using the uninstall string from the registry
    
    .DESCRIPTION
    Searches the registry for an uninstall string for the specified app. Cleans up the uninstall string and adds silent flags. Then uninstalls the app
    
    .PARAMETER AppName

    .EXAMPLE
    Uninstall-WithUninstallString -AppName "TeamViewer"
    Uninstalls TeamViewer

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
        foreach ($RegPath in $RegPaths) {
            if (Test-Path $RegPath) {
                Get-ChildItem -LiteralPath $RegPath | ForEach-Object { 
                    Get-ItemProperty -LiteralPath $_.PsPath | ForEach-Object { 
                        if ($_.DisplayName -match $AppName) { 
                            $UninstallString = $_.UninstallString
                            if ($UninstallString) {
                                try {
                                    if ($UninstallString -match 'msiexec') {
                                        $UninstallString = $UninstallString -replace 'msiexec.exe .*{', '/Uninstall {'
                                        $UninstallString += ' /qn /norestart'
                                        Write-Output "Running: msiexec.exe $UninstallString"
                                        Start-Process -FilePath msiexec.exe -ArgumentList $UninstallString -Wait
                                    } else {
                                        Write-Output "Running: $UninstallString /S"
                                        Start-Process -FilePath $UninstallString -ArgumentList "/S" -Wait
                                    }
                                    Write-Output "Silent uninstallation process completed for $AppName."
                                } catch {
                                    Write-Output "Error during uninstallation: $_"
                                }
                            } else {
                                Write-Output "Uninstall string not found for $AppName."
                            }
                        } 
                    }
                }
            }
        }
    }
}