##File_Manipulation
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/main/FunctionsAndModules/File_Manipulation/Find_Files.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/main/FunctionsAndModules/File_Manipulation/Find_FilesByContent.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/main/FunctionsAndModules/File_Manipulation/Get_FilesCount.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/main/FunctionsAndModules/File_Manipulation/Remove_Files.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/main/FunctionsAndModules/File_Manipulation/Set_FilesExtension.psm1") | Invoke-Expression

##Investigation_Tools
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/main/FunctionsAndModules/Investigation_Tools/Get-FileChangesByPath.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/main/FunctionsAndModules/Investigation_Tools/Get_EventLogByTimeRange.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/main/FunctionsAndModules/Investigation_Tools/Get_NetworkConnectionProcess.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/main/FunctionsAndModules/Investigation_Tools/Get_ServicesByStartTime.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/main/FunctionsAndModules/Investigation_Tools/Get_UserLogonSessions.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/main/FunctionsAndModules/Investigation_Tools/Watch_FileChangesByPath.psm1") | Invoke-Expression

##Networking
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/main/FunctionsAndModules/Networking/Get_DeviceStatus.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/main/FunctionsAndModules/Networking/Invoke_RemoteCommand.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/main/FunctionsAndModules/Networking/Scan-NetworkRange.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/main/FunctionsAndModules/Networking/Set_DNS.psm1") | Invoke-Expression

##RandomUtilities
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/main/FunctionsAndModules/RandomUtilities/Get_FileFromWeb.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/main/FunctionsAndModules/RandomUtilities/Get_RandomString.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/main/FunctionsAndModules/RandomUtilities/Get_UninstallString.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/main/FunctionsAndModules/RandomUtilities/Get_WindowsKey.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/main/FunctionsAndModules/RandomUtilities/Get_WindowsPatchStatus.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/main/FunctionsAndModules/RandomUtilities/Install_AppFromWeb.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/main/FunctionsAndModules/RandomUtilities/Set_ProjectFolder.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/main/FunctionsAndModules/RandomUtilities/Set_ServiceConfig.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/main/FunctionsAndModules/RandomUtilities/Set_Window.psm1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/main/FunctionsAndModules/RandomUtilities/Uninstall_WithUninstallString.psm1") | Invoke-Expression

<##ScriptsAndApplets
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/refs/heads/main/ScriptsAndApplets/EnableBitlocker.ps1") | Invoke-Expression
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/refs/heads/main/ScriptsAndApplets/ADToolKit.ps1") | Invoke-Expression
##>


<## Block to get the latest version of the function from GitHub, and if it fails, declare the offline version of the function.
$SourceURL = "https://raw.githubusercontent.com/Colby-FT/Powershell/main/FunctionsAndModules/RandomUtilities/Install_AppFromWeb.psm1"
try {
    (new-object Net.WebClient).DownloadString($SourceURL) | Invoke-Expression
    write-host "Function has been declared successfully."
}
catch {
    Write-Host "URL is not reachable. Declaring offline version of function. This may not be the newest version. For best results, please make sure the device has internet access."
    # Declare the offline version of the function here
}
##>

<##Runs this script to declare all of the above functions from GitHub.
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/Colby-FT/Powershell/refs/heads/main/Spare_Parts/Declare_Direct_From_Github.ps1") | Invoke-Expression 
##>