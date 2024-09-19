function Install-BiosTool {
    <#
    .SYNOPSIS
    Installs BIOS Utility

    .DESCRIPTION
    Checks if the computer is Lenovo, Dell, or HP. Then installs the appropriate BIOS utility

    .EXAMPLE
    Install-BiosTool
    Checks if the computer is Lenovo, Dell, or HP. Then installs the appropriate BIOS utility
    #>
    Begin {
        $ComputerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
        $Manufacturer = $ComputerSystem.Manufacturer
        Write-Output "Manufacturer: $Manufacturer"
    }
    Process {
        switch -regex ($Manufacturer) {
            "Dell" {
                Write-Output "Checking for DellBiosProvider..."
                if (Get-Module -ListAvailable -Name DellBIOSProvider) {
                    Write-Output "DellBiosProvider is already installed."
                } else {
                    Write-Output "Installing DellBiosProvider..."
                    try {
                        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
                        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction Stop
                        Install-Module -Name DellBIOSProvider -Force -ErrorAction Stop
                        Write-Output "DellBiosProvider installed successfully."
                    } catch {
                        Write-Output "Failed to install DellBiosProvider: $_"
                    }
                }
            }
            "HP|Hewlett" {
                Write-Output "Checking for HP BIOS Configuration Utility (BCU)..."
                $BCUPath = "C:\Program Files (x86)\HP\BIOS Configuration Utility\BiosConfigUtility64.exe"
                if (Test-Path $BCUPath) {
                    Write-Output "HP BIOS Configuration Utility (BCU) is already installed."
                } else {
                    Write-Output "Installing HP BIOS Configuration Utility (BCU)..."
                    try {
                        $BCUInstallerUrl = "https://ftp.hp.com/pub/caps-softpaq/cmit/HP_BCU.exe"
                        $BCUInstallerPath = "C:\Temp\HP_BCU.exe"
                        Invoke-WebRequest -Uri $BCUInstallerUrl -OutFile $BCUInstallerPath -ErrorAction Stop
                        Start-Process -FilePath $BCUInstallerPath -ArgumentList "/S" -Wait -ErrorAction Stop
                        Write-Output "HP BIOS Configuration Utility (BCU) installed successfully."
                    } catch {
                        Write-Output "Failed to install HP BIOS Configuration Utility (BCU): $_"
                    }
                }
            }
            "Lenovo" {
                $url = "https://download.lenovo.com/cdrt/tools/tbct142.zip"
                $tempFolderPath = [System.IO.Path]::GetTempPath()
                $zipFilePath = Join-Path -Path $tempFolderPath -ChildPath "tbct142.zip"

                try {
                    Write-Output "Downloading ZIP file from $url..."
                    Invoke-WebRequest -Uri $url -OutFile $zipFilePath -ErrorAction Stop
                    Write-Output "Download completed successfully."
                    Write-Output "Unpacking ZIP file to $tempFolderPath..."
                    Expand-Archive -Path $zipFilePath -DestinationPath $tempFolderPath -Force -ErrorAction Stop
                    Write-Output "Unpacking completed successfully."
                    Remove-Item -Path $zipFilePath -ErrorAction Stop
                    Write-Output "ZIP file removed successfully."
                } catch {
                    Write-Error "An error occurred: $_"
                }
            }
            default {
                Write-Output "Manufacturer not supported or not recognized."
            }
        }
    }
}
