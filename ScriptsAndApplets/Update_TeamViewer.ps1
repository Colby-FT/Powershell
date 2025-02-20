###############Functions##############
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


# Function to check if the device is a server
function Is-Server {
    $os = Get-WmiObject Win32_OperatingSystem
    return $os.ProductType -eq 2 -or $os.ProductType -eq 3
}

##############Actions#################

<# Check if the device is a server
if (Is-Server) {
    # Set the security protocols for the current session
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor `
    [Net.SecurityProtocolType]::Tls11 -bor `
    [Net.SecurityProtocolType]::Tls -bor `
    [Net.SecurityProtocolType]::Ssl3

    Write-Output "Security protocols set for the current session."
} else {
    Write-Output "This device is not a server. No changes made."
}#>

# Set the security protocols for the current session
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor `
[Net.SecurityProtocolType]::Tls11 -bor `
[Net.SecurityProtocolType]::Tls -bor `
[Net.SecurityProtocolType]::Ssl3

Write-Output "Security protocols set for the current session."

# Define the installation paths
$installationPath1 = "C:\Program Files (x86)\TeamViewer"
$installationPath2 = "C:\Program Files\TeamViewer"

#Check for TeamViewer Full
if (Test-Path "$installationPath1\TeamViewer.exe") {
    Write-Output "TeamViewer Full Client is installed."
    $teamViewerType = "Full"
} 
elseif (Test-Path "$installationPath2\TeamViewer.exe") {
    Write-Output "TeamViewer Full Client is installed."
    $teamViewerType = "Full"
}
#Check for TeamViewer Host
else {
    $TVHostCim = Get-CimInstance -ClassName Win32_Product | Where-Object { $_.Name -like "TeamViewer Host*" }
    $TVHostWmi = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "TeamViewer Host*" }
    if ($TVHostCim) {
        $teamViewerType = "Host"
    }
    elseif ($TVHostWmi) {
        $teamViewerType = "Host"
    }
    else {
        Write-Output "TeamViewer is not installed or the version could not be determined."
        Exit
    }
}

## Check if the folder C:\FT exists, and create it if it doesn't
$folderPath = "C:\FT"
if (-Not (Test-Path $folderPath)) {
    New-Item -Path $folderPath -ItemType Directory
    Write-Output "Created folder C:\FT"
} 
else {
    Write-Output "Folder C:\FT already exists"
}

# Determine if the system is 32-bit or 64-bit
$is64Bit = [Environment]::Is64BitOperatingSystem

# Set the URLs based on the architecture
if ($is64Bit) {
    $fullClientUrl = "https://download.teamviewer.com/download/TeamViewer_Setup_x64.exe"
    $hostUrl = "https://download.teamviewer.com/download/TeamViewer_Host_Setup_x64.exe"
} 
else {
    $fullClientUrl = "https://download.teamviewer.com/download/TeamViewer_Setup.exe"
    $hostUrl = "https://download.teamviewer.com/download/TeamViewer_Host_Setup.exe"
}

# Set the installer path
$installerPath = "$folderPath\TeamViewer_Setup.exe"

# Download the appropriate TeamViewer installer
if ($teamViewerType -eq "Full") {
    Invoke-WebRequest -Uri $fullClientUrl -OutFile $installerPath
    Write-Output "Downloaded TeamViewer Full Client installer"
} 
elseif ($teamViewerType -eq "Host") {
    Invoke-WebRequest -Uri $hostUrl -OutFile $installerPath
    Write-Output "Downloaded TeamViewer Host installer"
}

# Check if the installer file exists after download
if (Test-Path -Path $installerPath) {

    ##Uninstall Old version before installing new
    Uninstall-WithUninstallString -AppName "TeamViewer"

    # Run the installer silently
    Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait
    Write-Output "Installed TeamViewer silently"
} else {
    Write-Output "Installer file not found at $installerPath"
    exit
}

# Stop and start the TeamViewer service
Stop-Service -Name "TeamViewer"
Start-Service -Name "TeamViewer"
Write-Output "Restarted TeamViewer service"


#Return installed version
$teamViewerPath32 = "HKLM:\SOFTWARE\TeamViewer"
$teamViewerPath64 = "HKLM:\SOFTWARE\WOW6432Node\TeamViewer"

if (Test-Path $teamViewerPath32) {
    Get-ItemProperty -Path $teamViewerPath32 -Name "Version"
} 
elseif (Test-Path $teamViewerPath64) {
    Get-ItemProperty -Path $teamViewerPath64 -Name "Version"
} 
else {
    Write-Output "TeamViewer is not installed."
}