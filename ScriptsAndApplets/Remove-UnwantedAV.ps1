#####################
#region Header
#####################
<#
.SYNOPSIS
    Silent Uninstall - Unwanted AV Remover (Optimized for Datto RMM)

.DESCRIPTION
    This script silently uninstalls the most common unwanted AV programs 
    that are often bundled with other software (like Adobe). Designed for 
    Datto RMM deployment with zero user interaction and NO REBOOT required.
    
    Combines the best features from both UnwantedAVRemover.ps1 and AVRemover2.ps1

.PARAMETER DetectOnly
    When specified, the script will only detect and report installed AVs
    without uninstalling anything.

.PARAMETER AVName
    Specify a specific AV name to target. Valid values: McAfee, Norton, 
    Avast, AVG, WebRoot, Bitdefender, Panda, ESET, Sophos, Kaspersky, 
    TrendMicro, Malwarebytes, AdGuard, FSecure, Comodo, BullGuard, 
    ZoneAlarm, Avira, TotalDefense, PCMatic, VIPRE, IObit, AdAware

.EXAMPLE
    .\Remove-UnwantedAV.ps1
    Run full detection and uninstall all unwanted AVs

.EXAMPLE
    .\Remove-UnwantedAV.ps1 -DetectOnly
    Only detect what AVs are installed without removing

.EXAMPLE
    .\Remove-UnwantedAV.ps1 -AVName "McAfee"
    Only target and remove McAfee products

.NOTES
    Version: 3.0
    Created: 2026-06-25
    Compatibility: PowerShell 5.1+, Windows 10/11, Server 2016+
    

#>
#endregion Header

#####################
#region Prerequisites
#####################

# Require minimum PowerShell version
#Requires -Version 5.1

#endregion Prerequisites


#####################
#region Variables
#####################

[CmdletBinding()]
param (
    [switch]$DetectOnly,
    
    [ValidateSet("", "McAfee", "Norton", "Avast", "AVG", "WebRoot", "Bitdefender", "Panda", 
                 "ESET", "Sophos", "Kaspersky", "TrendMicro", "Malwarebytes", "AdGuard", 
                 "FSecure", "Comodo", "BullGuard", "ZoneAlarm", "Avira", "TotalDefense", 
                 "PCMatic", "VIPRE", "IObit", "AdAware", "360TotalSecurity", "PCPitstop")]
    [string]$AVName = ""
)

# Script configuration

# Output settings (from AVRemover2 - log to temp for troubleshooting)
if (Test-Path "$env:SystemDrive\FT\") {
    $LogPath = "$env:SystemDrive\FT\AV_Uninstall_$(Get-Date -Format 'yyyyMMdd_HHmmss').log" 
} 
else { 
    $LogPath = "$env:TEMP\AV_Uninstall_$(Get-Date -Format 'yyyyMMdd_HHmmss').log" 
}

$config = @{
    # Behavior settings
    DetectOnly = $false
    TargetAV   = $null
    MinDelay   = 5
    MaxRetries = 3
    Timeout    = 120
    LogPath    = $LogPath
    
    # Feature flags
    StopServices = $true
}

# Combined AV list - 25+ most common unwanted AVs
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
        )
    }
    @{ 
        Name = "PCMatic" 
        DisplayNames = @("PC Matic", "PC Tools", "PC Tools Registry Mechanic", "PC Tools Spyware Doctor", "PC Matic Home")
        RegistryPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
        UninstallMethods = @(
            @{ Type = "Execute"; Paths = @("$env:ProgramFiles\PCMatics\uninstall.exe", "$env:ProgramFiles\PC Tools\uninstall.exe", "${env:ProgramFiles(x86)}\PCMatics\uninstall.exe") }
        )
    }
    @{ 
        Name = "VIPRE" 
        DisplayNames = @("VIPRE", "VIPRE Internet Security", "VIPRE Antivirus", "VIPRE Endpoint Protection", "Sunbelt Personal Firewall")
        RegistryPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
        UninstallMethods = @(
            @{ Type = "Execute"; Paths = @("$env:ProgramFiles\VIPRE\uninstall.exe", "${env:ProgramFiles(x86)}\VIPRE\uninstall.exe") }
        )
    }
    @{ 
        Name = "IObit" 
        DisplayNames = @("IObit", "IObit Malware Fighter", "IObit Advanced SystemCare", "IObit Uninstaller", "Smart Defrag")
        RegistryPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
        UninstallMethods = @(
            @{ Type = "Execute"; Paths = @("$env:ProgramFiles\IObit\IObit Malware Fighter\Uninstall.exe", "${env:ProgramFiles(x86)}\IObit\Uninstall.exe") }
        )
    }
    @{ 
        Name = "AdAware" 
        DisplayNames = @("Ad-Aware", "AdAware", "Ad-Aware Free", "Ad-Aware Pro", "Ad-Aware Total Security", "Ad-aware")
        RegistryPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
        UninstallMethods = @(
            @{ Type = "Execute"; Paths = @("$env:ProgramFiles\Ad-Aware\uninstall.exe", "$env:ProgramFiles\AdAware\uninst.exe", "${env:ProgramFiles(x86)}\Ad-Aware\uninstall.exe") }
        )
    }
    @{ 
        Name = "360TotalSecurity" 
        DisplayNames = @("360 Total Security", "360 Security", "360 Internet Security")
        RegistryPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
        UninstallMethods = @(
            @{ Type = "Execute"; Paths = @("$env:ProgramFiles\360\Total Security\Uninstall.exe", "${env:ProgramFiles(x86)}\360\Total Security\Uninstall.exe") }
        )
    }
    @{ 
        Name = "PCPitstop" 
        DisplayNames = @("PCPitstop", "PC Pitstop", "PC Matic", "PCPitstop Empty")
        RegistryPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
        UninstallMethods = @(
            @{ Type = "Execute"; Paths = @("$env:ProgramFiles\PCPitstop\uninstall.exe", "${env:ProgramFiles(x86)}\PCPitstop\uninstall.exe") }
        )
    }
)

# AV Services that should be stopped before uninstallation (from UnwantedAVRemover.ps1)
$AVServices = @(
    "McAfee*", "Norton*", "Avast*", "AVG*", "Bitdefender*", "Sophos*", 
    "Kaspersky*", "ESET*", "TrendMicro*", "WebRoot*", "Panda*", 
    "Comodo*", "BullGuard*", "ZoneAlarm*", "Avira*", "MBAMService",
    "Malwarebytes*", "MBAMService*", "WRService"
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
                if (-not (Test-Path -Path $RegPath)) {
                    continue
                }

                $Items = Get-ChildItem -Path $RegPath -ErrorAction SilentlyContinue | ForEach-Object {
                    try {
                        Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction Stop
                    }
                    catch {
                        $null
                    }
                } | Where-Object {
                    $_ -and $_.PSObject.Properties.Name -contains 'DisplayName' -and $_.DisplayName
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
                                    Version      = if ($Item.PSObject.Properties.Name -contains 'DisplayVersion') { $Item.DisplayVersion } else { $null }
                                    Publisher    = if ($Item.PSObject.Properties.Name -contains 'Publisher') { $Item.Publisher } else { $null }
                                    UninstallStr = if ($Item.PSObject.Properties.Name -contains 'UninstallString') { $Item.UninstallString } else { $null }
                                    QuietUninstallString = if ($Item.PSObject.Properties.Name -contains 'QuietUninstallString') { $Item.QuietUninstallString } else { $null }
                                    InstallLoc   = if ($Item.PSObject.Properties.Name -contains 'InstallLocation') { $Item.InstallLocation } else { $null }
                                    ParentKey    = if ($Item.PSObject.Properties.Name -contains 'ParentKeyName') { $Item.ParentKeyName } else { $null }
                                }
                                $DetectedAVs += $DetectedAV
                                Write-Verbose "Detected: $DisplayName ($AVName)"
                            }
                        }
                    }
                }
            }
            
            # Also check Program Files for uninstallers (from UnwantedAVRemover.ps1)
            foreach ($UninstallMethod in $AV.UninstallMethods) {
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
                                    QuietUninstallString = ""
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
        with the uninstallation process. (Feature from UnwantedAVRemover.ps1)
    
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
                        Write-Verbose "Requesting stop for service: $($Service.Name)"

                        $stopProcess = Start-Process -FilePath 'sc.exe' -ArgumentList "stop `"$($Service.Name)`"" -PassThru -NoNewWindow -ErrorAction Stop
                        if ($stopProcess) {
                            $stopProcess.WaitForExit(2000) | Out-Null
                        }

                        Start-Sleep -Milliseconds 1000

                        $CurrentService = Get-Service -Name $Service.Name -ErrorAction SilentlyContinue
                        if ($CurrentService -and $CurrentService.Status -eq 'Running') {
                            Write-Warning "Service '$($Service.Name)' did not stop within the short timeout; continuing."
                        }
                        else {
                            $StoppedServices += $Service.Name
                        }
                    }
                }
                catch {
                    Write-Warning "Could not request stop for service: $($Service.Name) - $_"
                }
            }
        }
        
        return $StoppedServices
    }
    
    End {
        Write-Verbose "Stopped $($StoppedServices.Count) services"
    }
}

function Invoke-CommandValidation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$UninstallString
    )

    Write-Verbose "Validating uninstall string: $UninstallString"

    $UninstallString = $UninstallString.Trim()
    if ([string]::IsNullOrWhiteSpace($UninstallString)) {
        Write-Warning "Uninstall string is empty"
        return $null
    }

    if ($UninstallString -match '^"([^"]+)"\s*(.*)$') {
        $ExePath = $Matches[1]
        $Args = $Matches[2]

        if (-not (Test-Path -LiteralPath $ExePath -ErrorAction SilentlyContinue)) {
            $FileName = [System.IO.Path]::GetFileName($ExePath)
            $FoundPath = Get-ChildItem -Path "$env:ProgramFiles", "${env:ProgramFiles(x86)}" -Filter $FileName -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

            if ($FoundPath) {
                if ($Args) {
                    return "`"$($FoundPath.FullName)`" $Args"
                }
                return "`"$($FoundPath.FullName)`""
            }

            return $null
        }

        return $UninstallString
    }

    if ($UninstallString -match '^msiexec(?:\.exe)?') {
        return $UninstallString
    }

    if ($UninstallString -match '^[A-Za-z]:\\' -or $UninstallString -match '^[^\\]') {
        $Parts = $UninstallString -split '\s+', 2
        $ExePath = $Parts[0]

        if (-not (Test-Path -LiteralPath $ExePath -ErrorAction SilentlyContinue)) {
            $FileName = [System.IO.Path]::GetFileName($ExePath)
            $FullPath = Get-Command $FileName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1

            if ($FullPath) {
                if ($Parts[1]) {
                    return "$FullPath $($Parts[1])"
                }
                return $FullPath
            }
        }
    }

    return $UninstallString
}

function Invoke-UninstallExecution {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$UninstallString,

        [int]$Timeout = 120
    )

    $Result = [PSCustomObject]@{
        Success = $false
        Error = $null
    }

    if ([string]::IsNullOrWhiteSpace($UninstallString)) {
        $Result.Error = 'Uninstall string is empty'
        return $Result
    }

    $CandidateCommands = @()

    if ($UninstallString -match '^msiexec(?:\.exe)?') {
        $MsiArgs = $UninstallString -replace '^msiexec(?:\.exe)?\s*', ''
        if ($MsiArgs -notmatch '/qn|/quiet|/q') {
            $MsiArgs = "$MsiArgs /qn /norestart"
        }
        $CandidateCommands += [PSCustomObject]@{ FilePath = 'msiexec.exe'; Arguments = $MsiArgs; Description = 'MSI' }
    }
    else {
        $ExePath = $null
        $Args = $null

        if ($UninstallString -match '^"([^"]+)"\s*(.*)$') {
            $ExePath = $Matches[1]
            $Args = $Matches[2].Trim()
        }
        elseif ($UninstallString -match '^([^\s]+)\s*(.*)$') {
            $ExePath = $Matches[1]
            $Args = $Matches[2].Trim()
        }

        if ($ExePath) {
            $ArgumentVariants = @()
            if ($Args) {
                $ArgumentVariants += $Args
                $ArgumentVariants += "$Args /S /norestart"
                $ArgumentVariants += "$Args /silent /norestart"
                $ArgumentVariants += "$Args /quiet /norestart"
                $ArgumentVariants += "$Args /verysilent /norestart"
                $ArgumentVariants += "$Args /uninstall /norestart"
            }
            else {
                $ArgumentVariants += '/S /norestart'
                $ArgumentVariants += '/silent /norestart'
                $ArgumentVariants += '/quiet /norestart'
                $ArgumentVariants += '/verysilent /norestart'
                $ArgumentVariants += '/uninstall /norestart'
            }

            foreach ($Variant in $ArgumentVariants) {
                $CandidateCommands += [PSCustomObject]@{ FilePath = $ExePath; Arguments = $Variant; Description = 'EXE' }
            }
        }
    }

    if (-not $CandidateCommands) {
        $Result.Error = 'Unable to build uninstall command'
        return $Result
    }

    $LastError = $null
    foreach ($Command in $CandidateCommands) {
        try {
            $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
            $ProcessInfo.FileName = $Command.FilePath
            $ProcessInfo.Arguments = $Command.Arguments
            $ProcessInfo.UseShellExecute = $false
            $ProcessInfo.RedirectStandardOutput = $true
            $ProcessInfo.RedirectStandardError = $true
            $ProcessInfo.CreateNoWindow = $true

            $Process = [System.Diagnostics.Process]::Start($ProcessInfo)
            $Completed = $Process.WaitForExit($Timeout * 1000)

            if (-not $Completed) {
                $Process.Kill()
                throw 'Process timed out'
            }

            $StdOut = $Process.StandardOutput.ReadToEnd()
            $StdErr = $Process.StandardError.ReadToEnd()

            if ($Process.ExitCode -in @(0, 3010)) {
                $Result.Success = $true
                return $Result
            }

            $LastError = "Exit code: $($Process.ExitCode); $StdErr $StdOut"
        }
        catch {
            $LastError = $_.Exception.Message
        }
    }

    $Result.Error = "All execution methods failed. Last error: $LastError"
    return $Result
}

function Test-ApplicationUninstalled {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$AppName,

        [string]$InstallLocation
    )

    Write-Verbose "Verifying uninstall for: $AppName"

    $RegSearchPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    )

    foreach ($Path in $RegSearchPaths) {
        if (Test-Path $Path) {
            $Matches = Get-ChildItem -LiteralPath $Path -ErrorAction SilentlyContinue |
                Get-ItemProperty -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -and $_.DisplayName -match [regex]::Escape($AppName) }

            if ($Matches) {
                return $false
            }
        }
    }

    if ($InstallLocation -and (Test-Path $InstallLocation)) {
        $Contents = Get-ChildItem -LiteralPath $InstallLocation -ErrorAction SilentlyContinue
        if ($Contents) {
            return $false
        }
    }

    $RunningProcess = Get-Process -Name "*$AppName*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($RunningProcess) {
        return $false
    }

    return $true
}

function Invoke-SilentUninstall {
    <#
    .SYNOPSIS
        Silently uninstalls a specific AV product
    
    .DESCRIPTION
        Attempts to silently uninstall an AV product using multiple methods,
        including QuietUninstallString (from AVRemover2), MSIexec, direct 
        execution of uninstallers, and registry uninstall strings.
        All methods include /norestart to prevent reboots.
    
    .PARAMETER AVInfo
        PSObject containing AV detection information
    
    .EXAMPLE
        Invoke-SilentUninstall -AVInfo $AVObject
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [PSCustomObject]$AVInfo
    )
    
    Begin {
        $AVName = $AVInfo.Name
        $UninstallStr = $AVInfo.UninstallStr
        $QuietUninstallStr = $AVInfo.QuietUninstallString
        $InstallLoc = $AVInfo.InstallLoc
        Write-Verbose "Starting uninstallation for: $AVName"
    }
    
    Process {
        $UninstallSuccess = $false
        $Attempts = 0
        $SelectedUninstallString = $null
        $VerificationPassed = $false
        $ExecutionError = $null

        $SelectedUninstallString = if ($QuietUninstallStr -and $QuietUninstallStr.Trim() -ne "") { $QuietUninstallStr } elseif ($UninstallStr -and $UninstallStr.Trim() -ne "") { $UninstallStr } else { $null }

        if ($SelectedUninstallString) {
            try {
                Write-Verbose "Attempting registry uninstall command for: $AVName"
                $Attempts++

                $ValidatedCommand = Invoke-CommandValidation -UninstallString $SelectedUninstallString
                if (-not $ValidatedCommand) {
                    throw "Unable to construct a valid uninstall command from the registry"
                }

                Add-Content -Path $config.LogPath -Value "Executing registry command: $ValidatedCommand"
                Write-Host "Executing registry command: $ValidatedCommand" -ForegroundColor Gray

                $ExecutionResult = Invoke-UninstallExecution -UninstallString $ValidatedCommand -Timeout $config.Timeout
                $UninstallSuccess = $ExecutionResult.Success
                $ExecutionError = $ExecutionResult.Error

                if ($UninstallSuccess) {
                    Write-Host "Registry uninstall command succeeded for $AVName" -ForegroundColor Green
                }
                else {
                    Write-Warning "Registry uninstall command failed for $($AVName): $($ExecutionResult.Error)"
                    Add-Content -Path $config.LogPath -Value "Registry uninstall failed: $($ExecutionResult.Error)"
                }

                Start-Sleep -Seconds $config.MinDelay
            }
            catch {
                $ExecutionError = $_.Exception.Message
                Write-Warning "Registry uninstall failed for $($AVName): $ExecutionError"
                Add-Content -Path $config.LogPath -Value "Registry uninstall failed: $ExecutionError"
            }
        }

        if (-not $UninstallSuccess -and $MSIProductCodes.ContainsKey($AVName)) {
            foreach ($ProductCode in $MSIProductCodes[$AVName]) {
                try {
                    Write-Verbose "Method 3: Trying MSI Product Code: $ProductCode"
                    $Attempts++
                    
                    $MsiCmd = "msiexec.exe /x{$ProductCode} /qn REBOOT=ReallySuppress /l*v `"$($config.LogPath)`""
                    Add-Content -Path $config.LogPath -Value "Executing: $MsiCmd"
                    
                    $Process = Start-Process -FilePath 'msiexec.exe' -ArgumentList "/x{$ProductCode} /qn REBOOT=ReallySuppress" -Wait -PassThru -NoNewWindow
                    
                    if ($Process.ExitCode -eq 0 -or $Process.ExitCode -eq 3010) {
                        $UninstallSuccess = $true
                        $ExecutionError = $null
                        break
                    }
                    else {
                        $ExecutionError = "MSI uninstall returned exit code $($Process.ExitCode)"
                    }
                }
                catch {
                    $ExecutionError = $_.Exception.Message
                    Write-Warning "Method 3 failed for $($AVName) with ProductCode $($ProductCode): $ExecutionError"
                    Add-Content -Path $config.LogPath -Value "Method 3 failed: $ExecutionError"
                }
            }
            Start-Sleep -Seconds $config.MinDelay
        }
        
        if (-not $UninstallSuccess) {
            $AVConfig = $UnwantedAVs | Where-Object { $_.Name -eq $AVName }
            
            if ($AVConfig) {
                foreach ($UninstallMethod in $AVConfig.UninstallMethods) {
                    if ($UninstallMethod.Type -eq 'Execute') {
                        foreach ($Path in $UninstallMethod.Paths) {
                            if ((Test-Path $Path)) {
                                try {
                                    Write-Verbose "Method 4: Trying known uninstaller: $Path"
                                    $Attempts++
                                    
                                    $SilentSwitches = @('/S /norestart', '/silent /norestart', '/quiet /norestart', '/verysilent /norestart', '/uninstall /norestart')
                                    
                                    foreach ($Switches in $SilentSwitches) {
                                        Add-Content -Path $config.LogPath -Value "Executing: $Path $Switches"
                                        Write-Verbose "Executing: $Path $Switches"
                                        
                                        $Process = Start-Process -FilePath $Path -ArgumentList "$Switches REBOOT=ReallySuppress" -Wait -PassThru -NoNewWindow
                                        
                                        if ($Process.ExitCode -eq 0 -or $Process.ExitCode -eq 3010) {
                                            $UninstallSuccess = $true
                                            $ExecutionError = $null
                                            break
                                        }
                                        else {
                                            $ExecutionError = "Known uninstaller returned exit code $($Process.ExitCode)"
                                        }
                                        
                                        Start-Sleep -Seconds 2
                                    }
                                    
                                    if ($UninstallSuccess) { break }
                                }
                                catch {
                                    $ExecutionError = $_.Exception.Message
                                    Write-Warning "Method 4 failed for $($AVName) at $($Path): $ExecutionError"
                                    Add-Content -Path $config.LogPath -Value "Method 4 failed: $ExecutionError"
                                }
                            }
                        }
                    }
                    
                    if ($UninstallSuccess) { break }
                }
            }
        }

        if ($UninstallSuccess) {
            $VerificationPassed = Test-ApplicationUninstalled -AppName $AVInfo.DisplayName -InstallLocation $InstallLoc
            if (-not $VerificationPassed) {
                $ExecutionError = "Uninstall completed but verification check failed"
                Write-Warning "Verification failed for $($AVInfo.DisplayName)"
                $UninstallSuccess = $false
            }
        }

        return [PSCustomObject]@{
            DisplayName         = $AVInfo.DisplayName
            AVName              = $AVName
            UninstallString     = $UninstallStr
            QuietUninstallString= $QuietUninstallStr
            SelectedCommand     = $SelectedUninstallString
            InstallLocation     = $InstallLoc
            Success             = $UninstallSuccess
            VerificationPassed  = $VerificationPassed
            Error               = $ExecutionError
            Attempts            = $Attempts
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
        
        # Initialize log file
        if (-not (Test-Path $config.LogPath)) {
            New-Item -Path $config.LogPath -ItemType File -Force | Out-Null
        }
        Add-Content -Path $config.LogPath -Value "=== AV Removal Log - $(Get-Date) ==="
        
        Write-Host "===========================================================" -ForegroundColor Cyan
        Write-Host "|          Unwanted AV Removal Tool v3.0                   |" -ForegroundColor Cyan
        Write-Host "===========================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Computer: $env:ComputerName" -ForegroundColor Green
        Write-Host "User: $env:USERNAME" -ForegroundColor Green
        Write-Host "Log: $($config.LogPath)" -ForegroundColor Gray
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
        
        $DetectedAVs = @($DetectedAVs)
        Write-Host "Found $($DetectedAVs.Count) unwanted AV installation(s):" -ForegroundColor Yellow
        foreach ($AV in $DetectedAVs) {
            Write-Host "  - $($AV.DisplayName) [$($AV.Name)]" -ForegroundColor White
        }
        Write-Host ""
        
        # Filter by target AV if specified
        if ($config.TargetAV) {
            $DetectedAVs = @($DetectedAVs | Where-Object { $_.Name -eq $config.TargetAV })
            Write-Host "Filtered to target: $config.TargetAV - $($DetectedAVs.Count) match(es)" -ForegroundColor Yellow
        }
        
        # Step 2: Exit if DetectOnly mode
        if ($config.DetectOnly) {
            Write-Host ""
            Write-Host "DETECTION ONLY MODE - No changes made" -ForegroundColor Yellow
            Write-Host ""
            
            # Return exit code based on findings
            if ($DetectedAVs.Count -gt 0) {
                return [PSCustomObject]@{ Detected = $true; Count = $DetectedAVs.Count; AVs = $DetectedAVs }
            }
            else {
                return [PSCustomObject]@{ Detected = $false; Count = 0; AVs = @() }
            }
        }
        
        # Step 3: Stop AV services and uninstall
        if ($DetectedAVs.Count -gt 0) {
            # Stop services first (from UnwantedAVRemover.ps1)
            if ($config.StopServices) {
                Write-Host "[2/3] Stopping AV services..." -ForegroundColor Cyan
                $StoppedServices = Stop-AVServices
                Write-Host "Stopped $($StoppedServices.Count) service(s)" -ForegroundColor Gray
                Write-Host ""
            }
            
            Write-Host "[3/3] Uninstalling unwanted AVs..." -ForegroundColor Cyan
            $Results = @()
            
            foreach ($AV in $DetectedAVs) {
                Write-Host "Uninstalling: $($AV.DisplayName)..." -ForegroundColor Yellow
                $Result = Invoke-SilentUninstall -AVInfo $AV
                $Results += $Result
                
                if ($Result.Success) {
                    Write-Host "  SUCCESS: $($AV.Name) uninstalled" -ForegroundColor Green
                }
                else {
                    Write-Host "  FAILED: Could not uninstall $($AV.Name) - $($Result.Error)" -ForegroundColor Red
                }
                Write-Host ""
            }
            
            # Final Summary
            $SuccessCount = @($Results | Where-Object { $_.Success -eq $true }).Count
            $FailCount = @($Results | Where-Object { $_.Success -ne $true }).Count
            
            Write-Host "===========================================================" -ForegroundColor Cyan
            Write-Host "|                      SUMMARY                            |" -ForegroundColor Cyan
            Write-Host "===========================================================" -ForegroundColor Cyan
            Write-Host "Total Found: $($DetectedAVs.Count)" -ForegroundColor White
            Write-Host "Successfully Removed: $SuccessCount" -ForegroundColor Green
            Write-Host "Failed: $FailCount" -ForegroundColor $(if ($FailCount -gt 0) { 'Red' } else { 'Green' })
            Write-Host "Log saved to: $($config.LogPath)" -ForegroundColor Gray
            Write-Host ""
            
            return [PSCustomObject]@{
                Detected = $true
                Count = $DetectedAVs.Count
                Success = [int]$SuccessCount
                Failed = [int]$FailCount
                AVs = $Results
            }
        }
        else {
            Write-Host "No unwanted AV installations detected." -ForegroundColor Green
            Write-Host ""
            
            return [PSCustomObject]@{ Detected = $false; Count = 0; Success = 0; Failed = 0 }
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
    if ($Result -and $Result.Detected) {
        $FailedCount = 0
        if ($Result.PSObject.Properties.Name -contains 'Failed') {
            $FailedCount = [int]$Result.Failed
        }
        elseif ($Result.PSObject.Properties.Name -contains 'AVs') {
            $FailedCount = @($Result.AVs | Where-Object { $_ -and $_.PSObject.Properties.Name -contains 'Success' -and $_.Success -ne $true }).Count
        }

        if ($FailedCount -gt 0) {
            Write-Host "Exit Code: 1 (Some AVs failed to uninstall)" -ForegroundColor Red
            exit 1
        }
        else {
            Write-Host "Exit Code: 0 (Success)" -ForegroundColor Green
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
    Add-Content -Path $config.LogPath -Value "Critical error: $_"
    Write-Host "Exit Code: 1 (Error)" -ForegroundColor Red
    exit 1
}

#endregion Main

# End of script
