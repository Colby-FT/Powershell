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

function Get-RandomString {
    [CmdletBinding()]
    param (
        [int]$length = 14
    )
    Begin {
        $chars = @()
        $chars += [char[]](65..90)   # Uppercase A-Z
        $chars += [char[]](97..122)  # Lowercase a-z
        $chars += [char[]](48..57)   # Numbers 0-9
        $allowedSpecialChars = "!#$%&'()*+,-./:;<=>?@[\]^_`{|}~"
        $chars += [char[]]($allowedSpecialChars.ToCharArray())
        $chars = $chars | Sort-Object -Unique
    }
    Process {
        $RandString = -join (1..$length | ForEach-Object { $chars | Get-Random })
    }
    End {
        Return $RandString
    }
}

function Set-BiosPasswords {
    Begin {
        $ComputerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
        $Manufacturer = $ComputerSystem.Manufacturer
        Write-Output "Manufacturer: $Manufacturer"
        
        $Password = Get-RandomString -length 16
        Write-Output "Generated Password: $Password"
    }
    Process {
        switch -regex ($Manufacturer) {
            "Lenovo" {
                try {
                    $iniContent = @"
[Settings]
PowerOnPassword=$Password
"@
                    $tempFolderPath = [System.IO.Path]::GetTempPath()
                    $iniFilePath = "$tempFolderPath\settings.ini"
                    Set-Content -Path $iniFilePath -Value $iniContent
                    cd $tempFolderPath
                    Start-Process ThinkBiosConfig.hta -ArgumentList "config=PowerOnPasswordControl,Enable"
                    Start-Process ThinkBiosConfig.hta -ArgumentList "config=BIOSPasswordAtReboot,Enable"
                    Start-Process ThinkBiosConfig.hta -ArgumentList $iniFilePath

                    if ($LASTEXITCODE -ne 0) {
                        Write-Host "Failed to set BIOS password using ThinkBiosConfig. ExitCode: $LASTEXITCODE"
                        throw "ThinkBiosConfig method failed"
                    } else {
                        Write-Host "BIOS password set successfully using ThinkBiosConfig."
                    }
                } catch {
                    Write-Host "An error occurred while setting the BIOS password using ThinkBiosConfig: $_"
                }
            }
            "Dell" {
                try {
                    Set-ExecutionPolicy -ExecutionPolicy bypass -Scope Process
                    Import-Module DellBiosProvider -ErrorAction SilentlyContinue
                    $DellBIOS = Get-DellBiosProvider
                    $result1 = $DellBIOS.SetBiosPassword("System", $Password)
                    $result2 = $DellBIOS.SetBiosPassword("Admin", $Password)

                    if ($result1 -ne 0) {
                        Write-Host "Failed to set system password using DellBiosProvider. ReturnValue: $result1"
                        throw "DellBiosProvider method failed"
                    } else {
                        Write-Host "System password set successfully using DellBiosProvider."
                    }

                    if ($result2 -ne 0) {
                        Write-Host "Failed to set admin password using DellBiosProvider. ReturnValue: $result2"
                        throw "DellBiosProvider method failed"
                    } else {
                        Write-Host "Admin password set successfully using DellBiosProvider."
                    }
                } catch {
                    Write-Host "An error occurred while setting the BIOS password using DellBiosProvider: $_"
                }
            }
            "HP|Hewlett" {
                try {
                    $BCUPath = "C:\Program Files (x86)\HP\BIOS Configuration Utility\BiosConfigUtility64.exe"
                    if (Test-Path $BCUPath) {
                        & $BCUPath /npwd:$Password /cpwd:$Password /nspwd:$Password /cspwd:$Password

                        if ($LASTEXITCODE -ne 0) {
                            Write-Host "Failed to set BIOS passwords using HP BCU. ExitCode: $LASTEXITCODE"
                            throw "HP BCU method failed"
                        } else {
                            Write-Host "BIOS passwords set successfully using HP BCU."
                        }
                    } else {
                        Write-Host "HP BIOS Configuration Utility not found. Attempting to set BIOS password using CIM..."

                        try {
                            $Interface = Get-CimInstance -Namespace root\hp\instrumentedBIOS -ClassName HP_BIOSSettingInterface
                            $result1 = $Interface | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{Setting="PowerOn Password"; Value="<utf-16/>$Password"} -ErrorAction Stop
                            $result2 = $Interface | Invoke-CimMethod -MethodName SetBIOSSetting -Arguments @{Setting="Setup Password"; Value="<utf-16/>$Password"} -ErrorAction Stop

                            if ($result1.ReturnValue -ne 0) {
                                Write-Host "Failed to set power-on password using CIM. ReturnValue: $($result1.ReturnValue)"
                                throw "CIM method failed"
                            } else {
                                Write-Host "Power-on password set successfully using CIM."
                            }

                            if ($result2.ReturnValue -ne 0) {
                                Write-Host "Failed to set supervisor password using CIM. ReturnValue: $($result2.ReturnValue)"
                                throw "CIM method failed"
                            } else {
                                Write-Host "Supervisor password set successfully using CIM."
                            }
                        } catch {
                            Write-Host "CIM method failed. Attempting to set BIOS password using WMI..."

                            try {
                                $Interface = Get-WmiObject -Namespace root\hp\instrumentedBIOS -Class HP_BIOSSettingInterface
                                $result1 = $Interface.SetBIOSSetting("PowerOn Password", "<utf-16/>$Password")
                                $result2 = $Interface.SetBIOSSetting("Setup Password", "<utf-16/>$Password")

                                if ($result1.ReturnValue -ne 0) {
                                    Write-Host "Failed to set power-on password using WMI. ReturnValue: $($result1.ReturnValue)"
                                } else {
                                    Write-Host "Power-on password set successfully using WMI."
                                }

                                if ($result2.ReturnValue -ne 0) {
                                    Write-Host "Failed to set supervisor password using WMI. ReturnValue: $($result2.ReturnValue)"
                                } else {
                                    Write-Host "Supervisor password set successfully using WMI."
                                }
                            } catch {
                                Write-Host "An error occurred while setting the BIOS password using WMI: $_"
                            }
                        }
                    }
                } catch {
                    Write-Host "An error occurred while setting the BIOS password: $_"
                }
            }
            Default {
                Write-Output "Not a supported manufacturer."
                Return
            }
        }
    }
    End {
        Return $Password
    }
}

Install-BiosTool

$passwordToUDF = Set-BiosPasswords
if($passwordToUDF){
    New-ItemProperty -Path HKLM:\SOFTWARE\Centrastage -Name "custom$env:udf_27" -PropertyType String -Value "$passwordToUDF" -Force | out-null;
}

Write-Output "The Power on and UEFI admin passwords were set to: "
if($passwordToUDF){
    Get-ItemProperty -Path HKLM:\SOFTWARE\Centrastage -Name "custom$env:udf_27" | Select-Object custom
}

Start-Sleep -Seconds 15
Restart-Computer -Force
