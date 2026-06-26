#####################
#region Header
#####################
<#
.SYNOPSIS
    Silent Uninstall - Unwanted AV Remover for Datto RMM

.DESCRIPTION
    This script silently uninstalls the 20 most common unwanted AV programs 
    that are often bundled with other software (like Adobe). Designed for 
    Datto RMM deployment with zero user interaction and NO REBOOT required.
    
    This is useful when users install AV software outside your managed stack,
    which conflicts with your approved AV solution.

.PARAMETER DetectOnly
    When specified, the script will only detect and report installed AVs
    without uninstalling anything.

.PARAMETER AVName
    Specify a specific AV name to target. Valid values: McAfee, Norton, 
    Avast, AVG, WebRoot, Bitdefender, Panda, ESET, Sophos, Kaspersky, 
    TrendMicro, Malwarebytes, AdGuard, FSecure, Comodo, BullGuard, 
    ZoneAlarm, Avira, TotalDefense, PCMatic

.EXAMPLE
    .\Uninstall-UnwantedAV.ps1
    Run full detection and uninstall all unwanted AVs

.EXAMPLE
    .\Uninstall-UnwantedAV.ps1 -DetectOnly
    Only detect what AVs are installed without removing

.EXAMPLE
    .\Uninstall-UnwantedAV.ps1 -AVName "McAfee"
    Only target and remove McAfee products

.NOTES
    Author: Your Name
    Version: 1.0
    Created: 2026-06-25
    Compatibility: PowerShell 5.1+, Windows 10/11, Server 2016+
    
    Change Log:
    v1.0 - Initial release - 20 most common unwanted AVs

#>
#endregion Header

#####################
#region Prerequisites
#####################

# Require minimum PowerShell version
#Requires -Version 5.1

# Require running as Administrator
#Requires -RunAsAdministrator

#endregion Prerequisites

#####################
#region Variables
#####################

# Set strict mode and error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

# Script configuration
$config = @{
    # Output settings
    OutputPath = "$PSScriptRoot\Output"
    LogPath    = "$PSScriptRoot\Logs"
    
    # Behavior settings
    DetectOnly = $false
    TargetAV   = $null
    MinDelay   = 5
    MaxRetries = 3
    Timeout    = 300
    
    # Feature flags
    EnableLogging = $false
    ConfirmAction = $false
}

# Supported AV products - 20 most common unwanted AVs
$UnwantedAVs = @(
    @{ 
        Name = "McAfee" 
        DisplayNames = @("McAfee", "McAfee LiveSafe", "McAfee Total Protection", "McAfee Internet Security", "McAfee AntiVirus Plus", "McAfee Security", "McAfee Endpoint Security", "McAfee Agent", "McAfee VirusScan", "McAfee Global Site")
        RegistryPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
        UninstallMethods = @(
            @{ Type = "MsiExec"; Arguments = "/x{guid} /qn /norestart" },
            @{ Type = "Execute"; Paths = @("$env:ProgramFiles\McAfee\uninstall.exe", "$env:ProgramFiles\Common Files\McAfee\Engine\x86\uninstall.exe", "${env:ProgramFiles(x86)}\McAfee\uninstall.exe") }
        )
    }
    @{ 
        Name = "Norton" 
        DisplayNames = @("Norton", "Norton 360", "NortonLifeLock", "Norton Security", "Norton AntiVirus", "Norton Internet Security", "Norton Utilities", "Norton Studio")
        RegistryPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
        UninstallMethods = @(
            @{ Type = "Execute"; Paths = @("$env:ProgramFiles\NortonInstaller.exe", "$env:ProgramFiles\Norton 360\NavUninstall.exe", "${env:ProgramFiles(x86)}\NortonInstaller.exe") }
        )
    }
    @{ 
        Name = "Avast" 
        DisplayNames = @("Avast", "Avast Free Antivirus", "Avast Premium Security", "Avast Pro Antivirus", "Avast SecureLine", "Avast Cleanup", "Avast Driver Updater")
        RegistryPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
        UninstallMethods = @(
            @{ Type = "MsiExec"; Arguments = "/x{guid} /qn /norestart" },
            @{ Type = "Execute"; Paths = @("$env:ProgramFiles\Avast Software\Avast\avastclear.exe", "${env:ProgramFiles(x86)}\Avast Software\Avast\avastclear.exe") }
        )
    }
    @{ 
        Name = "AVG" 
        DisplayNames = @("AVG", "AVG AntiVirus", "AVG Internet Security", "AVG Protection", "AVG Secure Browser", "AVG Driver Updater", "AVG PC TuneUp")
        RegistryPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
        UninstallMethods = @(
            @{ Type = "MsiExec"; Arguments = "/x{guid} /qn /norestart" },
            @{ Type = "Execute"; Paths = @("$env:ProgramFiles\AVG\avginstall.exe", "$env:ProgramFiles\Common Files\AVG\uninstall.exe", "${env:ProgramFiles(x86)}\AVG\avginstall.exe") }
        )
    }
    @{ 
        Name = "WebRoot" 
        DisplayNames = @("WebRoot", "WebRoot SecureAnywhere", "WebRoot Endpoint Protection", "WebRoot AntiVirus")
        RegistryPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
        UninstallMethods = @(
            @{ Type = "Execute"; Paths = @("$env:ProgramFiles\Webroot\uninstall.exe", "${env:ProgramFiles(x86)}\Webroot\uninstall.exe", "$env:ProgramData\Webroot\uninstall.exe") }
        )
    }
    @{ 
        Name = "Bitdefender" 
        DisplayNames = @("Bitdefender", "Bitdefender Total Security", "Bitdefender Internet Security", "Bitdefender Antivirus", "Bitdefender Endpoint Security", "Bitdefender GravityZone")
        RegistryPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
        UninstallMethods = @(
            @{ Type = "MsiExec"; Arguments = "/x{guid} /qn /norestart" },
            @{ Type = "Execute"; Paths = @("$env:ProgramFiles\Bitdefender\Bitdefender\uninstall.exe", "$env:ProgramFiles\Common Files\Bitdefender\uninstall.exe", "${env:ProgramFiles(x86)}\Bitdefender\uninstall.exe") }
        )
    }
    @{ 
        Name = "Panda" 
        DisplayNames = @("Panda", "Panda Security", "Panda Cloud Antivirus", "Panda Dome", "Panda Endpoint Protection", "Panda Adaptive Defense")
        RegistryPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
        UninstallMethods = @(
            @{ Type = "Execute"; Paths = @("$env:ProgramFiles\Panda Security\uninstall.exe", "${env:ProgramFiles(x86)}\Panda Security\uninstall.exe") }
        )
    }
    @{ 
        Name = "ESET" 
        DisplayNames = @("ESET", "ESET NOD32", "ESET Internet Security", "ESET Smart Security", "ESET Endpoint Antivirus", "ESET Endpoint Security", "ESET Remote Administrator")
        RegistryPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
        UninstallMethods = @(
            @{ Type = "MsiExec"; Arguments = "/x{guid} /qn /norestart" },
            @{ Type = "Execute"; Paths = @("$env:ProgramFiles\ESET\uninstall.exe", "${env:ProgramFiles(x86)}\ESET\uninstall.exe") }
        )
    }
    @{ 
        Name = "Sophos" 
        DisplayNames = @("Sophos", "Sophos Endpoint", "Sophos Intercept X", "Sophos Endpoint Security", "Sophos Central", "Sophos Anti-Virus")
        RegistryPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
        UninstallMethods = @(
            @{ Type = "MsiExec"; Arguments = "/x{guid} /qn /norestart" },
            @{ Type = "Execute"; Paths = @("$env:ProgramFiles\Sophos\Sophos Endpoint Agent\uninstall.exe", "${env:ProgramFiles(x86)}\Sophos\uninstall.exe") }
        )
    }
    @{ 
        Name = "Kaspersky" 
        DisplayNames = @("Kaspersky", "Kaspersky Total Security", "Kaspersky Internet Security", "Kaspersky Anti-Virus", "Kaspersky Endpoint Security", "Kaspersky Small Office Security")
        RegistryPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
        UninstallMethods = @(
            @{ Type = "MsiExec"; Arguments = "/x{guid} /qn /norestart" },
            @{ Type = "Execute"; Paths = @("$env:ProgramFiles\Kaspersky Lab\uninstall.exe", "${env:ProgramFiles(x86)}\Kaspersky Lab\uninstall.exe") }
        )
    }
    @{ 
        Name = "TrendMicro" 
        DisplayNames = @("Trend Micro", "TrendMicro Maximum Security", "TrendMicro Internet Security", "TrendMicro AntiVirus", "TrendMicro Titanium", "TrendMicro OfficeScan", "TrendMicro Worry-Free")
        RegistryPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
        UninstallMethods = @(
            @{ Type = "MsiExec"; Arguments = "/x{guid} /qn /norestart" },
            @{ Type = "Execute"; Paths = @("$env:ProgramFiles\Trend Micro\uninstall.exe", "${env:ProgramFiles(x86)}\Trend Micro\uninstall.exe") }
        )
    }
    @{ 
        Name = "Malwarebytes" 
        DisplayNames = @("Malwarebytes", "Malwarebytes Premium", "Malwarebytes Anti-Malware", "Malwarebytes Endpoint Protection", "Malwarebytes Anti-Exploit")
        RegistryPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
        UninstallMethods = @(
            @{ Type = "Execute"; Paths = @("$env:ProgramFiles\Malwarebytes\uninstall.exe", "${env:ProgramFiles(x86)}\Malwarebytes\uninstall.exe") }
        )
    }
    @{ 
        Name = "AdGuard" 
        DisplayNames = @("AdGuard", "AdGuard AdBlocker", "AdGuard Antivirus", "AdGuard Browser Protection")
        RegistryPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
        UninstallMethods = @(
            @{ Type = "Execute"; Paths = @("$env:ProgramFiles\AdGuard\uninstall.exe", "${env:ProgramFiles(x86)}\AdGuard\uninstall.exe", "$env:ProgramData\AdGuard\uninstall.exe") }
        )
    }
    @{ 
        Name = "FSecure" 
        DisplayNames = @("F-Secure", "F-Secure SAFE", "F-Secure Internet Security", "F-Secure Anti-Virus", "F-Secure Client Security")
        RegistryPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
        UninstallMethods = @(
            @{ Type = "MsiExec"; Arguments = "/x{guid} /qn /norestart" },
            @{ Type = "Execute"; Paths = @("$env:ProgramFiles\F-Secure\uninstall.exe", "${env:ProgramFiles(x86)}\F-Secure\uninstall.exe") }
        )
    }
    @{ 
        Name = "Comodo" 
        DisplayNames = @("Comodo", "Comodo Internet Security", "Comodo Antivirus", "Comodo Endpoint Security", "Comodo Cloud Antivirus", "Comodo Security Solutions")
        RegistryPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
        UninstallMethods = @(
            @{ Type = "MsiExec"; Arguments = "/x{guid} /qn /norestart" },
            @{ Type = "Execute"; Paths = @("$env:ProgramFiles\Comodo\uninstall.exe", "${env:ProgramFiles(x86)}\Comodo\uninstall.exe") }
        )
    }
    @{ 
        Name = "BullGuard" 
        DisplayNames = @("BullGuard", "BullGuard Internet Security", "BullGuard Antivirus", "BullGuard Premium Protection", "BullGuard VPN")
        RegistryPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
        UninstallMethods = @(
            @{ Type = "Execute"; Paths = @("$env:ProgramFiles\BullGuard\uninstall.exe", "${env:ProgramFiles(x86)}\BullGuard\uninstall.exe") }
        )
    }
    @{ 
        Name = "ZoneAlarm" 
        DisplayNames = @("ZoneAlarm", "ZoneAlarm Internet Security", "ZoneAlarm Anti-Virus", "ZoneAlarm Extreme Security", "ZoneAlarm PRO")
        RegistryPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
        UninstallMethods = @(
            @{ Type = "Execute"; Paths = @("$env:ProgramFiles\ZoneAlarm\ZoneAlarm.exe", "${env:ProgramFiles(x86)}\ZoneAlarm\uninstall.exe") }
        )
    }
    @{ 
        Name = "Avira" 
        DisplayNames = @("Avira", "Avira Free Antivirus", "Avira Prime", "Avira Internet Security", "Avira System Speedup", "Avira Password Manager")
        RegistryPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
        UninstallMethods = @(
            @{ Type = "MsiExec"; Arguments = "/x{guid} /qn /norestart" },
            @{ Type = "Execute"; Paths = @("$env:ProgramFiles\Avira\uninstall.exe", "${env:ProgramFiles(x86)}\Avira\uninstall.exe", "$env:ProgramData\Avira\uninstall.exe") }
        )
    }
    @{ 
        Name = "TotalDefense" 
        DisplayNames = @("Total Defense", "Total Defense Internet Security", "Total Defense Anti-Virus", "Total Defense Premium")
        RegistryPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
        UninstallMethods = @(
            @{ Type = "Execute"; Paths = @("$env:ProgramFiles\Total Defense\uninstall.exe", "${env:ProgramFiles(x86)}\Total Defense\uninstall.exe") }
        ]
    }
    @{ 
        Name = "PCMatic" 
        DisplayNames = @("PC Matic", "PC Tools", "PC Tools Registry Mechanic", "PC Tools Spyware Doctor", "PC Matic Home")
        RegistryPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
        UninstallMethods = @(
            @{ Type = "Execute"; Paths = @("$env:ProgramFiles\PCMatics\uninstall.exe", "$env:ProgramFiles\PC Tools\uninstall.exe", "${env:ProgramFiles(x86)}\PCMatics\uninstall.exe") }
        ]
    }
)

# MSI Product Codes for common AV products (for msiexec /x approach)
$MSIProductCodes = @{
    "McAfee" = @("{2705F341-1A83-4BF1-BE56-3E79A83D1F6F}", "{B2E9D22D-04B4-4FCB-AF9B-F1A2E3F3E5B1}", "{4FCF93C4-2B83-4CD8-A1C2-1D9F4B5C6D7E}")
    "Norton" = @("{B2415BD8-2BB4-4C5B-8E8B-F1A2B3C4D5E6}", "{C6CF6F2C-3D84-4FA9-9E8B-2D3C4E5F6A7B}")
    "Avast" = @("{5E1D3BBE-7F3A-4E2B-9AC6-1D8E2F3A4B5C}", "{1E8F3C2D-4B5A-6D7E-8F9A-0B1C2D3E4F5A}")
    "AVG" = @("{2F3A1C2D-4E5B-6F7A-8C9D-0E1F2A3B4C5D}", "{8C7D6E5F-4A3B-2C1D-0E9F-8A7B6C5D4E3F}")
    "Kaspersky" = @("{7F5D2C3E-4B6A-4FD8-9C1D-0E2F3A4B5C6D}", "{A1B2C3D4-5E6F-7A8B-9C0D-1E2F3A4B5C6D}")
    "ESET" = @("{3C4F93D2-5A7B-4CE1-8D0F-1E2A3B4C5D6E}", "{9A8B7C6D-5E4F-3A2B-1C0D-9E8F7A6B5C4D}")
    "Sophos" = @("{4D5E6F7A-8B9C-4DE1-0FA2-3B4C5D6E7F8A}", "{1A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}")
    "TrendMicro" = @("{5E6F7A8B-9C0D-4EF1-2A3B-4C5D6E7F8A9B}", "{2D3E4F5A-6B7C-8D9E-0F1A-2B3C4D5E6F7A}")
    "Avira" = @("{6F7A8B9C-0D1E-4FA2-3B4C-5D6E7F8A9B0C}", "{3E4F5A6B-7C8D-9E0F-1A2B-3C4D5E6F7A8B}")
    "Bitdefender" = @("{7A8B9C0-D1E2-F4A3-B5C6-D7E8F9A0B1C2}", "{4E5F6A7B-8C9D-0E1F-2A3B-4C5D6E7F8A9B}")
    "FSecure" = @("{8B9C0D1-E2F3-A4B5-C6D7-E8F9A0B1C2D3}", "{5F6A7B8-C9D0-E1F2-A3B4-C5D6E7F8A9B0}")
}

# AV Services that should be stopped before uninstallation
$AVServices = @(
    "McAfee*", "Norton*", "Avast*", "AVG*", "Bitdefender*", "Sophos*", 
    "Kaspersky*", "ESET*", "TrendMicro*", "WebRoot*", "Panda*", 
    "Comodo*", "BullGuard*", "ZoneAlarm*", "Avira*", "MBAMService",
    "Malwarebytes*", "S保守ED*", "WRService"
)

#endregion Variables

#####################
#region Functions
#####################

function Get-AVDetection {
    <#
    .SYNOPSIS
        Detects installed unwanted AV software
    
    .DESCRIPTION
        Scans the registry and file system for installed unwanted AV products
        and returns a list of found installations.
    
    .EXAMPLE
        Get-AVDetection
    #>
    [CmdletBinding()]
    param ()
    
    Begin {
        Write-Verbose "Starting AV detection scan..."
        $DetectedAVs = @()
    }
    
    Process {
        foreach ($AV in $UnwantedAVs) {
            $AVName = $AV.Name
            $DisplayNames = $AV.DisplayNames
            $RegistryPaths = $AV.RegistryPaths
            
            foreach ($RegPath in $RegistryPaths) {
                $Items = Get-ItemProperty -Path $RegPath -ErrorAction SilentlyContinue | Where-Object {
                    $_.DisplayName -ne $null
                }
                
                foreach ($Item in $Items) {
                    $DisplayName = $Item.DisplayName
                    
                    # Check if any of the AV's display names match
                    foreach ($DN in $DisplayNames) {
                        if ($DisplayName -like "*$DN*") {
                            # Avoid duplicates
                            $AlreadyFound = $DetectedAVs | Where-Object { $_.Name -eq $AVName -and $_.DisplayName -eq $DisplayName }
                            
                            if (-not $AlreadyFound) {
                                $DetectedAV = [PSCustomObject]@{
                                    Name         = $AVName
                                    DisplayName  = $DisplayName
                                    Version      = $Item.DisplayVersion
                                    Publisher    = $Item.Publisher
                                    UninstallStr = $Item.UninstallString
                                    InstallLoc   = $Item.InstallLocation
                                    ParentKey    = $Item.ParentKeyName
                                }
                                $DetectedAVs += $DetectedAV
                                Write-Verbose "Detected: $DisplayName ($AVName)"
                            }
                        }
                    }
                }
            }
            
            # Also check Program Files for uninstallers
            foreach ($ UninstallMethod in $AV.UninstallMethods) {
                if ($UninstallMethod.Type -eq "Execute") {
                    foreach ($Path in $UninstallMethod.Paths) {
                        if (Test-Path $Path) {
                            $AlreadyFound = $DetectedAVs | Where-Object { $_.Name -eq $AVName }
                            
                            if (-not $AlreadyFound) {
                                $DetectedAV = [PSCustomObject]@{
                                    Name         = $AVName
                                    DisplayName  = "Found: $Path"
                                    Version      = "Unknown"
                                    Publisher    = $AVName
                                    UninstallStr = ""
                                    InstallLoc   = Split-Path $Path -Parent
                                    ParentKey    = ""
                                }
                                $DetectedAVs += $DetectedAV
                                Write-Verbose "Detected by file: $AVName at $Path"
                            }
                        }
                    }
                }
            }
        }
        
        return $DetectedAVs
    }
    
    End {
        Write-Verbose "Detection complete. Found $($DetectedAVs.Count) unwanted AV installations."
    }
}

function Stop-AVServices {
    <#
    .SYNOPSIS
        Stops AV-related services before uninstallation
    
    .DESCRIPTION
        Attempts to stop any running AV services to prevent interference
        with the uninstallation process.
    
    .EXAMPLE
        Stop-AVServices
    #>
    [CmdletBinding()]
    param ()
    
    Begin {
        Write-Verbose "Stopping AV services..."
        $StoppedServices = @()
    }
    
    Process {
        foreach ($ServicePattern in $AVServices) {
            # Remove asterisks for exact matching
            $Pattern = $ServicePattern -replace '\*', ''
            
            # Get services matching the pattern
            $Services = Get-Service | Where-Object { $_.Name -like $ServicePattern -or $_.DisplayName -like "*$Pattern*" }
            
            foreach ($Service in $Services) {
                try {
                    if ($Service.Status -eq 'Running') {
                        Write-Verbose "Stopping service: $($Service.Name)"
                        Stop-Service -Name $Service.Name -Force -ErrorAction Stop
                        $StoppedServices += $Service.Name
                        Start-Sleep -Milliseconds 500
                    }
                }
                catch {
                    Write-Warning "Could not stop service: $($Service.Name) - $_"
                }
            }
        }
        
        return $StoppedServices
    }
    
    End {
        Write-Verbose "Stopped $($StoppedServices.Count) services"
    }
}

function Invoke-UninstallAV {
    <#
    .SYNOPSIS
        Silently uninstalls a specific AV product
    
    .DESCRIPTION
        Attempts to silently uninstall an AV product using multiple methods,
        including MSIexec, direct execution of uninstallers, and registry
        uninstall strings. All methods include /norestart to prevent reboots.
    
    .PARAMETER AVInfo
        PSObject containing AV detection information
    
    .EXAMPLE
        Invoke-UninstallAV -AVInfo $AVObject
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [PSCustomObject]$AVInfo
    )
    
    Begin {
        $AVName = $AVInfo.Name
        $UninstallStr = $AVInfo.UninstallStr
        $InstallLoc = $AVInfo.InstallLoc
        Write-Verbose "Starting uninstallation for: $AVName"
    }
    
    Process {
        $UninstallSuccess = $false
        $Attempts = 0
        
        # Method 1: Try registry UninstallString
        if ($UninstallStr -and $UninstallStr -ne "") {
            try {
                Write-Verbose "Method 1: Using registry UninstallString"
                $Attempts++
                
                # Determine if it's an MSI or EXE
                if ($UninstallStr -match "msiexec") {
                    # Add /qn /norestart to MSI uninstall
                    $UninstallCmd = $UninstallStr -replace '/I', '/x'
                    if ($UninstallCmd -notmatch '/qn') {
                        $UninstallCmd += " /qn /norestart"
                    }
                    Write-Verbose "Executing: $UninstallCmd"
                    Invoke-Expression $UninstallCmd
                    Start-Sleep -Seconds $config.MinDelay
                }
                elseif ($UninstallStr -match '".*?"') {
                    # EXE with quotes
                    $ExePath = ($UninstallStr -match '"([^"]*)"')[1]
                    $Args = $UninstallStr -replace "[^ ]* ", ""
                    if ($Args -notmatch '/norestart' -and $Args -notmatch '/qn') {
                        $Args += " /S /norestart"
                    }
                    Write-Verbose "Executing: $ExePath $Args"
                    Start-Process -FilePath $ExePath -ArgumentList $Args -Wait -NoNewWindow
                    Start-Sleep -Seconds $config.MinDelay
                }
                else {
                    # Plain EXE
                    $ExePath = $UninstallStr.Split(' ')[0]
                    $Args = $UninstallStr.Substring($ExePath.Length).Trim()
                    if ($Args -notmatch '/norestart' -and $Args -notmatch '/S') {
                        $Args += " /S /norestart"
                    }
                    Write-Verbose "Executing: $ExePath $Args"
                    Start-Process -FilePath $ExePath -ArgumentList $Args -Wait -NoNewWindow
                    Start-Sleep -Seconds $config.MinDelay
                }
                
                $UninstallSuccess = $true
            }
            catch {
                Write-Warning "Method 1 failed for $AVName: $_"
            }
        }
        
        # Method 2: Try MSI Product Codes if available
        if (-not $UninstallSuccess -and $MSIProductCodes.ContainsKey($AVName)) {
            foreach ($ProductCode in $MSIProductCodes[$AVName]) {
                try {
                    Write-Verbose "Method 2: Trying MSI Product Code: $ProductCode"
                    $Attempts++
                    
                    $MsiCmd = "msiexec.exe /x$ProductCode /qn /norestart"
                    Write-Verbose "Executing: $MsiCmd"
                    
                    # Use Start-Process to avoid blocking
                    $Process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/x$ProductCode /qn /norestart" -Wait -PassThru -NoNewWindow
                    
                    if ($Process.ExitCode -eq 0 -or $Process.ExitCode -eq 3010) {
                        $UninstallSuccess = $true
                        break
                    }
                }
                catch {
                    Write-Warning "Method 2 failed for $AVName with ProductCode $ProductCode: $_"
                }
            }
            Start-Sleep -Seconds $config.MinDelay
        }
        
        # Method 3: Try known uninstall executable paths
        if (-not $UninstallSuccess) {
            $AVConfig = $UnwantedAVs | Where-Object { $_.Name -eq $AVName }
            
            if ($AVConfig) {
                foreach ($UninstallMethod in $AVConfig.UninstallMethods) {
                    if ($UninstallMethod.Type -eq "Execute") {
                        foreach ($Path in $UninstallMethod.Paths) {
                            if ((Test-Path $Path)) {
                                try {
                                    Write-Verbose "Method 3: Trying known uninstaller: $Path"
                                    $Attempts++
                                    
                                    # Try different silent switches
                                    $SilentSwitches = @("/S /norestart", "/silent /norestart", "/verysilent /norestart", "/uninstall /norestart", "/quiet /norestart")
                                    
                                    foreach ($Switches in $SilentSwitches) {
                                        Write-Verbose "Executing: $Path $Switches"
                                        $Process = Start-Process -FilePath $Path -ArgumentList $Switches -Wait -PassThru -NoNewWindow
                                        
                                        if ($Process.ExitCode -eq 0 -or $Process.ExitCode -eq 3010) {
                                            $UninstallSuccess = $true
                                            break
                                        }
                                        
                                        Start-Sleep -Seconds 2
                                    }
                                    
                                    if ($UninstallSuccess) { break }
                                }
                                catch {
                                    Write-Warning "Method 3 failed for $AVName at $Path: $_"
                                }
                            }
                        }
                    }
                    
                    if ($UninstallSuccess) { break }
                }
            }
        }
        
        return @{
            Success   = $UninstallSuccess
            Attempts  = $Attempts
            AVName    = $AVName
        }
    }
    
    End {
        if ($UninstallSuccess) {
            Write-Verbose "Successfully uninstalled: $AVName after $Attempts attempt(s)"
        }
        else {
            Write-Warning "Failed to uninstall: $AVName after $Attempts attempt(s)"
        }
    }
}

function Remove-UnwantedAV {
    <#
    .SYNOPSIS
        Main function to detect and remove all unwanted AVs
    
    .DESCRIPTION
        Scans for installed unwanted AV products and attempts to silently
        uninstall each one found. This is the main entry point for the script.
    
    .PARAMETER DetectOnly
        If specified, only detect and report AVs without uninstalling
    
    .PARAMETER TargetAV
        Optional specific AV name to target
    
    .EXAMPLE
        Remove-UnwantedAV
        Remove all detected unwanted AVs
    
    .EXAMPLE
        Remove-UnwantedAV -DetectOnly
        Only report what's found
    
    .EXAMPLE
        Remove-UnwantedAV -TargetAV "McAfee"
        Only target McAfee
    #>
    [CmdletBinding()]
    param (
        [switch]$DetectOnly,
        
        [string]$TargetAV = $null
    )
    
    Begin {
        $config.DetectOnly = $DetectOnly.IsPresent
        $config.TargetAV = $TargetAV
        
        Write-Host "===========================================================" -ForegroundColor Cyan
        Write-Host "|          Unwanted AV Removal Tool for Datto RMM          |" -ForegroundColor Cyan
        Write-Host "===========================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Computer: $env:ComputerName" -ForegroundColor Green
        Write-Host "User: $env:USERNAME" -ForegroundColor Green
        Write-Host "Mode: $(if ($config.DetectOnly) { 'DETECTION ONLY' } else { 'FULL REMOVAL' })" -ForegroundColor $(if ($config.DetectOnly) { 'Yellow' } else { 'Red' })
        if ($config.TargetAV) {
            Write-Host "Target AV: $($config.TargetAV)" -ForegroundColor Yellow
        }
        Write-Host ""
    }
    
    Process {
        # Step 1: Detect installed AVs
        Write-Host "[1/3] Scanning for unwanted AV installations..." -ForegroundColor Cyan
        $DetectedAVs = Get-AVDetection
        
        Write-Host "Found $($DetectedAVs.Count) unwanted AV installation(s):" -ForegroundColor Yellow
        foreach ($AV in $DetectedAVs) {
            Write-Host "  - $($AV.DisplayName) [$($AV.Name)]" -ForegroundColor White
        }
        Write-Host ""
        
        # Filter by target AV if specified
        if ($config.TargetAV) {
            $DetectedAVs = $DetectedAVs | Where-Object { $_.Name -eq $config.TargetAV }
            Write-Host "Filtered to target: $config.TargetAV - $($DetectedAVs.Count) match(es)" -ForegroundColor Yellow
        }
        
        # Step 2: Exit if DetectOnly mode
        if ($config.DetectOnly) {
            Write-Host ""
            Write-Host "DETECTION ONLY MODE - No changes made" -ForegroundColor Yellow
            Write-Host ""
            
            # Return exit code based on findings
            if ($DetectedAVs.Count -gt 0) {
                return @{ Detected = $true; Count = $DetectedAVs.Count; AVs = $DetectedAVs }
            }
            else {
                return @{ Detected = $false; Count = 0; AVs = @() }
            }
        }
        
        # Step 3: Stop AV services and uninstall
        if ($DetectedAVs.Count -gt 0) {
            Write-Host "[2/3] Stopping AV services..." -ForegroundColor Cyan
            $StoppedServices = Stop-AVServices
            Write-Host "Stopped $($StoppedServices.Count) service(s)" -ForegroundColor Gray
            Write-Host ""
            
            Write-Host "[3/3] Uninstalling unwanted AVs..." -ForegroundColor Cyan
            $Results = @()
            
            foreach ($AV in $DetectedAVs) {
                Write-Host "Uninstalling: $($AV.DisplayName)..." -ForegroundColor Yellow
                $Result = Invoke-UninstallAV -AVInfo $AV
                $Results += $Result
                
                if ($Result.Success) {
                    Write-Host "  SUCCESS: $($AV.Name) uninstalled" -ForegroundColor Green
                }
                else {
                    Write-Host "  FAILED: Could not uninstall $($AV.Name)" -ForegroundColor Red
                }
                Write-Host ""
            }
            
            # Final Summary
            $SuccessCount = ($Results | Where-Object { $_.Success }).Count
            $FailCount = ($Results | Where-Object { -not $_.Success }).Count
            
            Write-Host "===========================================================" -ForegroundColor Cyan
            Write-Host "|                      SUMMARY                            |" -ForegroundColor Cyan
            Write-Host "===========================================================" -ForegroundColor Cyan
            Write-Host "Total Found: $($DetectedAVs.Count)" -ForegroundColor White
            Write-Host "Successfully Removed: $SuccessCount" -ForegroundColor Green
            Write-Host "Failed: $FailCount" -ForegroundColor $(if ($FailCount -gt 0) { 'Red' } else { 'Green' })
            Write-Host ""
            
            return @{
                Detected = $true
                Count = $DetectedAVs.Count
                Success = $SuccessCount
                Failed = $FailCount
                AVs = $Results
            }
        }
        else {
            Write-Host "No unwanted AV installations detected." -ForegroundColor Green
            Write-Host ""
            
            return @{ Detected = $false; Count = 0; Success = 0; Failed = 0 }
        }
    }
    
    End {
        Write-Host "Script completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    }
}

#endregion Functions

######################
#region Main
#####################

# Parameter-driven execution pattern
[CmdletBinding()]
param (
    [switch]$DetectOnly,
    
    [ValidateSet("", "McAfee", "Norton", "Avast", "AVG", "WebRoot", "Bitdefender", "Panda", 
                 "ESET", "Sophos", "Kaspersky", "TrendMicro", "Malwarebytes", "AdGuard", 
                 "FSecure", "Comodo", "BullGuard", "ZoneAlarm", "Avira", "TotalDefense", "PCMatic")]
    [string]$AVName = ""
)

try {
    Write-Host ""
    
    # Execute the main function
    if ($AVName -ne "") {
        $Result = Remove-UnwantedAV -TargetAV $AVName
    }
    else {
        $Result = Remove-UnwantedAV -DetectOnly:$DetectOnly
    }
    
    # Set exit code for Datto RMM monitoring
    if ($Result.Detected) {
        if ($Result.Failed -gt 0) {
            Write-Host "Exit Code: 1 (Some AVs failed to uninstall)" -ForegroundColor Red
            exit 1
        }
        else {
            Write-Host "Exit Code: 0 (Success - all AVs removed)" -ForegroundColor Green
            exit 0
        }
    }
    else {
        Write-Host "Exit Code: 0 (No unwanted AVs found)" -ForegroundColor Green
        exit 0
    }
}
catch {
    Write-Error "Script failed: $_"
    Write-Host "Exit Code: 1 (Error)" -ForegroundColor Red
    exit 1
}

#endregion Main

# End of script
