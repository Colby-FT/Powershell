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
Set-SupportedTlsProtocols

# Define the base URL for downloading functions and modules
$FuncsandMods = "https://raw.githubusercontent.com/Colby-FT/Powershell/main/FunctionsAndModules/"

## Active Directory Functions
(new-object Net.WebClient).DownloadString("$($FuncsandMods)ActiveDirectory/Confirm_RsatAdPowerShell.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)ActiveDirectory/Disable_AdAccountFromCSV.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)ActiveDirectory/Get_DomainName.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)ActiveDirectory/Get-DHCPLogInfo.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)ActiveDirectory/Get-DHCPLogInfo2.psm1") | Invoke-Expression
# Add additional AD functions here as needed

## App Management Functions
(new-object Net.WebClient).DownloadString("$($FuncsandMods)App_Management/Get_UninstallString.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)App_Management/Get_installedAppinfo.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)App_Management/Install_AppfromWeb.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)App_Management/Test_Appinstalled.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)App_Management/Uninstall_WithUninstallString.psm1") | Invoke-Expression

## File Management Functions
(new-object Net.WebClient).DownloadString("$($FuncsandMods)File_Management/Find_Files.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)File_Management/Find_FilesByContent.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)File_Management/Get_FileCount.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)File_Management/Remove_Files.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)File_Management/Set_FileExtension.psm1") | Invoke-Expression

## Input Box Utilities
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Input_Boxes/Input_Boxes.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Input_Boxes/Invoke_InputBox.psm1") | Invoke-Expression

## Investigation Tools
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Investigation_Tools/Find-SuspiciousScheduledTasks.ps1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Investigation_Tools/Get_EventLogByTimeRange.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Investigation_Tools/Get_NetworkConnectionProcess.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Investigation_Tools/Get_ServicesByStartTime.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Investigation_Tools/Get_UserLogonSessions.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Investigation_Tools/Get-AutoRunItems.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Investigation_Tools/Get-FileChangesByPath.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Investigation_Tools/Watch_FileChangesByPath.psm1") | Invoke-Expression

## Mod Installers
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Mod_Installers/Install_BiosTool.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Mod_Installers/Install_RSAT.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Mod_Installers/Install_SysInternals.psm1") | Invoke-Expression

## Networking Functions
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Networking/Get_DeviceStatus.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Networking/Invoke_RemoteCommand.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Networking/Scan-NetworkRange.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Networking/Search-DNSEntries.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Networking/Send-WakeOnLan.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Networking/Set_DNS.psm1") | Invoke-Expression

## Random Utilities
(new-object Net.WebClient).DownloadString("$($FuncsandMods)RandomUtilities/Get_RandomString.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)RandomUtilities/New-PlainTextCredential.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)RandomUtilities/Set_ProjectFolder.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)RandomUtilities/Set_Window.psm1") | Invoke-Expression

## Windows Configurators
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Windows_Configurators/Get_WindowsKey.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Windows_Configurators/Get_WindowsPatchStatus.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Windows_Configurators/Set_ServiceConfig.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("$($FuncsandMods)Windows_Configurators/Set-SupportedTlsProtocols.psm1") | Invoke-Expression


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