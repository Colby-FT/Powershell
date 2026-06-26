#Requires -Version 5.1
<#
.SYNOPSIS
    Silent AV Uninstall Script for Datto RMM
.DESCRIPTION
    Untop 20 most common unwanted AV products without user interaction or reboot
.NOTES
    REBOOT=ReallySuppress - Prevents reboot
    Run as SYSTEM context (Datto RMM default)
#>

$ErrorActionPreference = "SilentlyContinue"

# Registry paths for uninstall strings
$UninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

# AV Product Display Names (partial matches) - UPDATE THIS LIST BASED ON YOUR ENVIRONMENT
$UnwantedAVs = @(
    "McAfee",
    "Norton",
    "Avast",
    "AVG",
    "Avira",
    "Bitdefender",
    "Kaspersky",
    "Panda",
    "Trend Micro",
    "ESET",
    "Sophos",
    "Webroot",
    "Malwarebytes",
    "Comodo",
    "ZoneAlarm",
    "PC Matic",
    "PCPitstop",
    "VIPRE",
    "IObit",
    "360 Total Security",
    "Ad-aware",
    "Adaware",
    "Microsoft Security Essentials",
    "Windows Defender"  # Optional - remove if you want to keep Defender
)

function Get-UninstallString {
    param([string]$DisplayName)
    
    foreach ($Path in $UninstallPaths) {
        $Items = Get-ItemProperty $Path -ErrorAction SilentlyContinue | 
                 Where-Object { $_.DisplayName -like "*$DisplayName*" }
        
        foreach ($Item in $Items) {
            if ($Item.UninstallString) {
                return @{
                    DisplayName = $Item.DisplayName
                    UninstallString = $Item.UninstallString
                    QuietUninstallString = $Item.QuietUninstallString
                    NoModify = $Item.NoModify
                    NoRepair = $Item.NoRepair
                }
            }
        }
    }
    return $null
}

function Invoke-SilentUninstall {
    param(
        [string]$UninstallString,
        [hashtable]$AdditionalProps
    )
    
    if ([string]::IsNullOrWhiteSpace($UninstallString)) { return $false }
    
    $uninstallStr = $UninstallString
    $logPath = "$env:TEMP\AV_Uninstall_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    
    # Handle MSI-based uninstalls
    if ($uninstallStr -match 'msiexec') {
        # Extract MSI product code if present
        if ($uninstallStr -match '/[xi]\s*\{[A-F0-9\-]+\}') {
            $uninstallStr = $uninstallStr -replace '/i', '/x'
            $uninstallStr = $uninstallStr -replace '/x\s+', '/x {'
            $uninstallStr = $uninstallStr -replace '/x\{([^}]+)\}', '/x {$1}'
            $uninstallStr = "$uninstallStr /qn REBOOT=ReallySuppress /l*v `"$logPath`""
        }
    } else {
        # EXE-based uninstall - add common silent switches
        $silentSwitches = " /S /silent /quiet /qn /verysilent /uninstall"
        $uninstallStr = "$uninstallStr $silentSwitches REBOOT=ReallySuppress"
    }
    
    # Add reboot suppression if not present
    if ($uninstallStr -notlike "*REBOOT=ReallySuppress*") {
        $uninstallStr = "$uninstallStr REBOOT=ReallySuppress"
    }
    
    Write-Host "Executing: $uninstallStr"
    
    try {
        Start-Process cmd -ArgumentList "/c $uninstallStr" -Wait -NoNewWindow -ErrorAction Stop
        return $true
    } catch {
        Write-Host "Error: $_"
        return $false
    }
}

# Main execution
Write-Host "=== Starting AV Removal Process ==="
Write-Host "Will scan for and remove unwanted AV products..."

$removedCount = 0

foreach ($AVName in $UnwantedAVs) {
    Write-Host "`nChecking for: $AVName"
    
    $avInfo = Get-UninstallString -DisplayName $AVName
    if ($avInfo) {
        Write-Host "  Found: $($avInfo.DisplayName)"
        
        $uninstallStr = if ($avInfo.QuietUninstallString) { 
            $avInfo.QuietUninstallString 
        } else { 
            $avInfo.UninstallString 
        }
        
        if (Invoke-SilentUninstall -UninstallString $uninstallStr) {
            Write-Host "  -> Uninstall initiated successfully"
            $removedCount++
            Start-Sleep -Seconds 5
        }
    } else {
        Write-Host "  Not found"
    }
}

Write-Host "`n=== Process Complete ==="
Write-Host "Products processed: $removedCount"
Write-Host "No reboot was triggered (REBOOT=ReallySuppress applied)"