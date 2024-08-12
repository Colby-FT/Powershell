#Check if chrome is installed 
$ChromePath64 = “$env:Systemdrive\Program Files (x86)\Google\Chrome\Application\chrome.exe”
$ChromePath32 = “$env:Systemdrive\Program Files\Google\Chrome\Application\chrome.exe”
If((Test-Path $ChromePath64) -or (Test-Path $ChromePath32)) { 
    
    Write-host "Installing"

    #Get the latest version installer 
    $Path = $env:TEMP 
    $Installer = “chrome_installer.exe” 
    Invoke-WebRequest "https://dl.google.com/chrome/install/latest/chrome_installer.exe" -OutFile $Path\$Installer

    #Run the installer silently
    Start-Process -FilePath $Path\$Installer -Args "/silent /install" -Verb RunAs -Wait

    #Cleanup
    Remove-Item $Path\$Installer
} 
Else { 
    Exit
}
