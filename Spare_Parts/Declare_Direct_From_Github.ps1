function Set-SupportedTlsProtocols {
    <#
    .SYNOPSIS
    Sets the SecurityProtocol property to all supported TLS/SSL protocols, similar to .NET 4.7+ auto-negotiation.

    .DESCRIPTION
    Iterates through a list of common SecurityProtocolType values and sets [Net.ServicePointManager]::SecurityProtocol to a bitwise combination of only those protocols supported by the current .NET runtime.

    .EXAMPLE
    Set-SupportedTlsProtocols
    #>
    [CmdletBinding()]
    param ()

    $values = @(3072, 12288, 768, 192, 48)
    $supportedProtocols = 0
    foreach ($value in $values) {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], $value)
            $supportedProtocols = $supportedProtocols -bor $value
        } catch {
            Write-Verbose "Protocol $value is not supported."
        }
    }
    [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], $supportedProtocols)
}

# Define the base URL for downloading functions and modules
$FuncsandMods = "https://raw.githubusercontent.com/Colby-FT/Powershell/main/FunctionsAndModules/"

## File Manipulation Functions
# These functions are used for various file operations such as finding, counting, removing, and modifying files.
(new-object Net.WebClient).DownloadString("$($FuncsandMods)File_Manipulation/Find_Files.psm1") | Invoke-Expression # Find-Files function
(new-object Net.WebClient).DownloadString("$($FuncsandMods)File_Manipulation/Find_FilesByContent.psm1") | Invoke-Expression # Find-FilesByContent function
(new-object Net.WebClient).DownloadString("$($FuncsandMods)File_Manipulation/Get_FilesCount.psm1") | Invoke-Expression # Get-FilesCount function
(new-object Net.WebClient).DownloadString("$($FuncsandMods)File_Manipulation/Remove_Files.psm1") | Invoke-Expression # Remove-Files function
(new-object Net.WebClient).DownloadString("$($FuncsandMods)File_Manipulation/Set_FilesExtension.psm1") | Invoke-Expression # Set-FilesExtension function

## Investigation Tools
# These functions assist in investigating system changes, logs, and network activities.
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Investigation_Tools/Get-FileChangesByPath.psm1") | Invoke-Expression # Get-FileChangesByPath function
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Investigation_Tools/Get_EventLogByTimeRange.psm1") | Invoke-Expression # Get-EventLogByTimeRange function
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Investigation_Tools/Get_NetworkConnectionProcess.psm1") | Invoke-Expression # Get-NetworkConnectionProcess function
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Investigation_Tools/Get_ServicesByStartTime.psm1") | Invoke-Expression # Get-ServicesByStartTime function
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Investigation_Tools/Get_UserLogonSessions.psm1") | Invoke-Expression # Get-UserLogonSessions function
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Investigation_Tools/Watch_FileChangesByPath.psm1") | Invoke-Expression # Watch-FileChangesByPath function

## Networking Functions
# These functions are used for managing and monitoring network configurations and connections.
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Networking/Get_DeviceStatus.psm1") | Invoke-Expression # Get-DeviceStatus function
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Networking/Invoke_RemoteCommand.psm1") | Invoke-Expression # Invoke-RemoteCommand function
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Networking/Scan-NetworkRange.psm1") | Invoke-Expression # Scan-NetworkRange function
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Networking/Set_DNS.psm1") | Invoke-Expression # Set-DNS function

## Random Utilities
# These functions provide miscellaneous utilities for tasks such as downloading files, generating random strings, and managing system configurations.
(new-object Net.WebClient).DownloadString("$($FuncsandMods)RandomUtilities/Get_FileFromWeb.psm1") | Invoke-Expression # Get-FileFromWeb function
(new-object Net.WebClient).DownloadString("$($FuncsandMods)RandomUtilities/Get_RandomString.psm1") | Invoke-Expression # Get-RandomString function
(new-object Net.WebClient).DownloadString("$($FuncsandMods)RandomUtilities/Get_UninstallString.psm1") | Invoke-Expression # Get-UninstallString function
(new-object Net.WebClient).DownloadString("$($FuncsandMods)RandomUtilities/Get_WindowsKey.psm1") | Invoke-Expression # Get-WindowsKey function
(new-object Net.WebClient).DownloadString("$($FuncsandMods)RandomUtilities/Get_WindowsPatchStatus.psm1") | Invoke-Expression # Get-WindowsPatchStatus function
(new-object Net.WebClient).DownloadString("$($FuncsandMods)RandomUtilities/Install_AppFromWeb.psm1") | Invoke-Expression # Install-AppFromWeb function
(new-object Net.WebClient).DownloadString("$($FuncsandMods)RandomUtilities/Set_ProjectFolder.psm1") | Invoke-Expression # Set-ProjectFolder function
(new-object Net.WebClient).DownloadString("$($FuncsandMods)RandomUtilities/Set_ServiceConfig.psm1") | Invoke-Expression # Set-ServiceConfig function
(new-object Net.WebClient).DownloadString("$($FuncsandMods)RandomUtilities/Set_Window.psm1") | Invoke-Expression # Set-Window function
(new-object Net.WebClient).DownloadString("$($FuncsandMods)RandomUtilities/Uninstall_WithUninstallString.psm1") | Invoke-Expression # Uninstall-WithUninstallString function

## Scripts and Applets
# These scripts provide additional functionality, such as enabling BitLocker or managing Active Directory.
<##ScriptsAndApplets
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/refs/heads/main/ScriptsAndApplets/EnableBitlocker.ps1") | Invoke-Expression # Calls and runs Enable-Bitlocker script
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/refs/heads/main/ScriptsAndApplets/ADToolKit.ps1") | Invoke-Expression # Calls and runs ADToolKit script
##>

## Error Handling for Offline Function Declaration
# This block attempts to declare a function from GitHub. If it fails, it falls back to an offline version.
<## Block to get the latest version of the function from GitHub, and if it fails, declare the offline version of the function.
$SourceURL = "$($FuncsandMods)RandomUtilities/Install_AppFromWeb.psm1" # Set the desired function or script URL here
try {
    (new-object Net.WebClient).DownloadString($SourceURL) | Invoke-Expression
    write-host "Function has been declared successfully."
}
catch {
    Write-Host "URL is not reachable. Declaring offline version of function. This may not be the newest version. For best results, please make sure the device has internet access."
    # the offline version of the function here
}
##>

## Declaration of this Script
# This block declares the current script to ensure all functions are up-to-date.
<##Runs this script to declare all of the above functions from GitHub.
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/refs/heads/main/Spare_Parts/Declare_Direct_From_Github.ps1") | Invoke-Expression # Calls and run this script
##>