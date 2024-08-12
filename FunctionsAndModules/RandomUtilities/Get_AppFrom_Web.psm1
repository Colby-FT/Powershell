function Get-AppFromWeb {
    <#
    .SYNOPSIS
    Download and install an app from the web

    .DESCRIPTION
    Download an app from a provided url, and install it

    .PARAMETER testPath
    .PARAMETER installerUrl
    .PARAMETER appName

    .EXAMPLE
    Get-AppFromWeb -testPath "HKLM:\Software\Mozilla" -installerUrl "https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=en-US" -appName "FireFox.exe"
    Checks if FireFox is already installed. If not, it downloads and installs the latest version.

    .EXAMPLE
    Get-AppFromWeb -installerUrl "https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=en-US" -appName "FireFox.exe"
    Skips the check for a previous install, and downloads/installs the latest FireFox.

    #>
    [CmdletBinding()]
    param (
        [string]$testPath,
        [string]$installerUrl,
        [switch]$appName
    )
    Process {
        #Check if app exists, and install if it doesn't
        if (!(Test-Path -Path "$testPath")) {
            # Define the path to save the installer
            $installerPath = "$env:TEMP\$appName"
            # Download the installer
            Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath
            # Run the installer silently
            Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait
            # Clean up the installer file
            Remove-Item -Path $installerPath
        }

        else {
            exit
        }
    }
}