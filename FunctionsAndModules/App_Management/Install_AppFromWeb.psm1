function Install-AppFromWeb {
    <#
    .SYNOPSIS
    Download and install an app from the web

    .DESCRIPTION
    This function checks if an application is already installed by verifying the existence of a specified path (e.g., a registry key or file path). 
    If the application is not installed, it downloads the installer from the provided URL, runs it silently, and cleans up the installer file.

    .PARAMETER InstallCheckPath
    The path to check if the application is already installed (e.g., a registry key or file path).

    .PARAMETER InstallerUrl
    The URL to download the installer from.

    .PARAMETER AppName
    The name of the installer file (e.g., "FirefoxInstaller.exe").

    .Parameter InstallerArguments
    Optional arguments to pass to the installer when running it. Default is set to /S

    .EXAMPLE
    Install-AppFromWeb -InstallCheckPath "HKLM:\Software\Mozilla" -InstallerUrl "https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=en-US" -AppName "FirefoxInstaller.exe"
    Checks if Firefox is already installed. If not, it downloads and installs the latest version.

    .EXAMPLE
    Install-AppFromWeb -InstallerUrl "https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=en-US" -AppName "FirefoxInstaller.exe"
    Skips the check for a previous install, and downloads/installs the latest Firefox.

    #>
    [CmdletBinding()]
    param (
        [string]$InstallCheckPath = $null,

        [ValidateNotNullOrEmpty()]
        [string]$InstallerUrl,

        [ValidateNotNullOrEmpty()]
        [string]$AppName,

        [string]$InstallerArguments = "/S"
    )

    Begin {
        $InstallerPath = Join-Path -Path $env:TEMP -ChildPath $AppName
        $Success = $true
    }
    Process {
        # Check if the application is already installed
        if ($InstallCheckPath -and (Test-Path -Path $InstallCheckPath)) {
            Write-Output "Application is already installed. Skipping installation."
            $Success = $false
            return
        }

        try {
            # Download the installer
            Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath -ErrorAction Stop
        } catch {
            Write-Error "Failed to download the installer from $InstallerUrl. Error: $_"
            $Success = $false
            return
        }
        
        try {
            # Run the installer silently
            Start-Process -FilePath $InstallerPath -ArgumentList $InstallerArguments -Wait -ErrorAction Stop
        } catch {
            Write-Error "Failed to run the installer $InstallerPath. Error: $_"
            $Success = $false
            return
        }
    }
    End {
        # Only clean up if the process was successful
        if ($Success -and (Test-Path -Path $InstallerPath)) {
            Remove-Item -Path $InstallerPath -Force
        }
    }
}
