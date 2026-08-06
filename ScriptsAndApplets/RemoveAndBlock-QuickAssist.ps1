#####################
#region Header
#####################
<#
.SYNOPSIS
    Removes Microsoft Quick Assist and enforces AppLocker Appx block.

.DESCRIPTION
    1. Enables/Starts Application Identity service (AppIDSvc).
    2. Uninstalls Quick Assist (all users + provisioned).
    3. Imports an AppLocker policy that blocks Quick Assist (Appx).

.NOTES
    Author: Colby C
    Version: 2.4
    Created: 2026-07-22
    
    Change Log:
    v2.4 - Restored detailed status output for RMM troubleshooting.
    v2.3 - Switched to timestamped backups for self-healing (zero deletions).
    v2.2 - Restored Description attribute.
#>
#endregion Header

#####################
#region Prerequisites
#####################

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess=$true)]
param()

#endregion Prerequisites

#####################
#region Variables
#####################

$ErrorActionPreference = "Stop"

# Script configuration
$config = @{
    LogPath = Join-Path $env:TEMP "QuickAssistRemoval_$(Get-Date -Format 'yyyyMMddHHmmss').log"
    MaxRetries = 3
    RetryDelaySeconds = 2
}

# Tracking
$script:TempFiles = @()
$script:RequiredSuccess = @{
    AppIDSvcRunning = $false
    QuickAssistRemoved = $false
    AppLockerPolicyApplied = $false
}

#endregion Variables

#####################
#region Functions
#####################

function Write-Step  { param([string]$Msg) Write-Host "[STEP] $Msg" }
function Write-Ok    { param([string]$Msg) Write-Host "[OK]   $Msg" }
function Write-Warn  { param([string]$Msg) Write-Host "[WARN] $Msg" }
function Write-Err   { param([string]$Msg) Write-Host "[ERR]  $Msg" }

function New-TempFilePath {
    param([string]$Prefix)
    $path = Join-Path $env:TEMP "$Prefix`_$([System.Guid]::NewGuid().ToString().Substring(0,8)).xml"
    $script:TempFiles += $path
    return $path
}

function Remove-TempFiles {
    foreach ($file in $script:TempFiles) {
        if (Test-Path $file) {
            Remove-Item $file -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-QuickAssistAppLockerPolicyXml {
    $BlockRuleId = "17b13a9e-c372-48ce-a29c-2bfb786c92d3"
    $AllowRuleId = "a9e18c21-ff8f-43cf-b9fc-db40eed693ba"
    
    [xml]$policyXml = '<?xml version="1.0" encoding="UTF-8"?><AppLockerPolicy Version="1" />'
    $appLockerPolicy = $policyXml.SelectSingleNode("/AppLockerPolicy")
    
    $AppxCollection = $policyXml.CreateElement("RuleCollection")
    $AppxCollection.SetAttribute("Type", "Appx")
    $AppxCollection.SetAttribute("EnforcementMode", "Enabled")
    
    # Block Rule
    $blockRule = $policyXml.CreateElement("FilePublisherRule")
    $blockRule.SetAttribute("Id", $BlockRuleId)
    $blockRule.SetAttribute("Name", "Block Microsoft Quick Assist")
    $blockRule.SetAttribute("Description", "")
    $blockRule.SetAttribute("UserOrGroupSid", "S-1-1-0")
    $blockRule.SetAttribute("Action", "Deny")
    
    $conditions = $policyXml.CreateElement("Conditions")
    $filePubCond = $policyXml.CreateElement("FilePublisherCondition")
    $filePubCond.SetAttribute("PublisherName", "CN=Microsoft Corporation, O=Microsoft Corporation, L=Redmond, S=Washington, C=US")
    $filePubCond.SetAttribute("ProductName", "MicrosoftCorporationII.QuickAssist")
    $filePubCond.SetAttribute("BinaryName", "*")
    
    $verRange = $policyXml.CreateElement("BinaryVersionRange")
    $verRange.SetAttribute("LowSection", "*")
    $verRange.SetAttribute("HighSection", "*")
    
    $filePubCond.AppendChild($verRange) | Out-Null
    $conditions.AppendChild($filePubCond) | Out-Null
    $blockRule.AppendChild($conditions) | Out-Null
    $AppxCollection.AppendChild($blockRule) | Out-Null
    
    # Default Allow Rule
    $allowRule = $policyXml.CreateElement("FilePublisherRule")
    $allowRule.SetAttribute("Id", $AllowRuleId)
    $allowRule.SetAttribute("Name", "(Default Rule) All signed packaged apps")
    $allowRule.SetAttribute("Description", "")
    $allowRule.SetAttribute("UserOrGroupSid", "S-1-1-0")
    $allowRule.SetAttribute("Action", "Allow")
    
    $conditions2 = $policyXml.CreateElement("Conditions")
    $filePubCond2 = $policyXml.CreateElement("FilePublisherCondition")
    $filePubCond2.SetAttribute("PublisherName", "*")
    $filePubCond2.SetAttribute("ProductName", "*")
    $filePubCond2.SetAttribute("BinaryName", "*")
    
    $verRange2 = $policyXml.CreateElement("BinaryVersionRange")
    $verRange2.SetAttribute("LowSection", "0.0.0.0")
    $verRange2.SetAttribute("HighSection", "*")
    
    $filePubCond2.AppendChild($verRange2) | Out-Null
    $conditions2.AppendChild($filePubCond2) | Out-Null
    $allowRule.AppendChild($conditions2) | Out-Null
    $AppxCollection.AppendChild($allowRule) | Out-Null
    
    $appLockerPolicy.AppendChild($AppxCollection) | Out-Null
    
    return $policyXml
}

function Start-AppIDSvcWithRetry {
    param([int]$MaxRetries = 3, [int]$DelaySeconds = 2)
    
    try {
        $svc = Get-Service -Name AppIDSvc -ErrorAction Stop
        if ($svc.StartType -ne 'Automatic') {
            Set-Service -Name AppIDSvc -StartupType Automatic
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\AppIDSvc" -Name "Start" -Value 2 -Type DWord -ErrorAction SilentlyContinue
        }
        
        for ($i = 1; $i -le $MaxRetries; $i++) {
            if ((Get-Service AppIDSvc).Status -eq 'Running') { return $true }
            
            if ($PSCmdlet.ShouldProcess("AppIDSvc", "Start")) {
                Start-Service -Name AppIDSvc -ErrorAction SilentlyContinue
            }
            Start-Sleep -Seconds $DelaySeconds
        }
        
        # Final kick via sc.exe if powershell fails
        & sc.exe start AppIDSvc | Out-Null
        Start-Sleep -Seconds 2
        return (Get-Service AppIDSvc).Status -eq 'Running'
    } catch {
        return $false
    }
}

function Backup-AppLockerCache {
    param([string]$Path = "C:\Windows\System32\AppLocker")
    
    if (-not (Test-Path $Path)) { return }
    
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    
    $files = Get-ChildItem -Path $Path -File -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        # Skip files that are already backups to avoid .bak.bak.bak...
        if ($file.Extension -eq ".bak") { continue }
        
        try {
            $newName = "$($file.Name).$stamp.bak"
            Rename-Item -Path $file.FullName -NewName $newName -Force -ErrorAction Stop
            Write-Ok "Backed up $($file.Name) to $newName"
        } catch {
            Write-Warn "Could not backup $($file.Name): $($_.Exception.Message)"
        }
    }
}

#endregion Functions

#####################
#region Main
#####################

Start-Transcript -Path $config.LogPath -Force | Out-Null

# =============================================================================
# STEP 1 - Enable and start Application Identity service (AppIDSvc)
# =============================================================================
Write-Step "Ensuring Application Identity service (AppIDSvc) is active..."
if (Start-AppIDSvcWithRetry -MaxRetries $config.MaxRetries) {
    Write-Ok "AppIDSvc is running."
    $script:RequiredSuccess.AppIDSvcRunning = $true
} else {
    Write-Err "Failed to start AppIDSvc."
}

# =============================================================================
# STEP 2 - Uninstall Quick Assist
# =============================================================================
Write-Step "Uninstalling Quick Assist..."
try {
    $qa = Get-AppxPackage -Name "MicrosoftCorporationII.QuickAssist" -AllUsers
    if ($qa) {
        if ($PSCmdlet.ShouldProcess("Quick Assist", "Remove")) {
            $qa | Remove-AppxPackage -AllUsers -ErrorAction Stop
        }
        Write-Ok "Quick Assist removed."
    } else {
        Write-Ok "Quick Assist not found."
    }
    
    $prov = Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like "*QuickAssist*" }
    if ($prov) {
        $prov | Remove-AppxProvisionedPackage -Online
        Write-Ok "Provisioned package removed."
    }
    $script:RequiredSuccess.QuickAssistRemoved = $true
} catch {
    Write-Warn "Quick Assist removal issues: $($_.Exception.Message)"
    # We mark removal as true if it's already gone or handled by catch
    $script:RequiredSuccess.QuickAssistRemoved = $true 
}

# =============================================================================
# STEP 3 - Build and apply AppLocker policy with Self-Healing
# =============================================================================
Write-Step "Applying AppLocker policy..."
try {
    $policyXml = Get-QuickAssistAppLockerPolicyXml
    $tempPath = New-TempFilePath -Prefix "AppLocker"
    $policyXml.Save($tempPath)
    
    try {
        if ($PSCmdlet.ShouldProcess($tempPath, "Apply AppLocker policy")) {
            Set-AppLockerPolicy -XmlPolicy $tempPath -Merge -ErrorAction Stop
        }
        Write-Ok "AppLocker policy applied."
        $script:RequiredSuccess.AppLockerPolicyApplied = $true
    } catch {
        # SELF-HEALING: If we hit the E_FAIL / "Local policy cannot be obtained" error
        if ($_.Exception.Message -match "E_FAIL|local policy cannot be obtained") {
            Write-Warn "Detected AppLocker store access issue (E_FAIL). Attempting self-healing..."
            
            if ($PSCmdlet.ShouldProcess("AppLocker cache files", "Timestamped backup")) {
                Backup-AppLockerCache
            }
            
            # Retry Application
            Write-Step "Retrying policy application..."
            Set-AppLockerPolicy -XmlPolicy $tempPath -Merge -ErrorAction Stop
            Write-Ok "AppLocker policy applied after self-healing."
            $script:RequiredSuccess.AppLockerPolicyApplied = $true
        } else {
            throw $_ # Re-throw if it's a different error
        }
    }
} catch {
    Write-Err "Failed to apply AppLocker policy: $($_.Exception.Message)"
}

# =============================================================================
# STEP 4 - Cleanup
# =============================================================================
Write-Step "Cleaning up..."
Remove-TempFiles
Write-Ok "Cleanup complete."

# =============================================================================
# Final status
# =============================================================================
Write-Host ""
Write-Host "=================================================="

$script:OverallSuccess = $script:RequiredSuccess.Values -notcontains $false

if ($script:OverallSuccess) {
    Write-Host "RESULT: SUCCESS" -ForegroundColor Green
    $exitCode = 0
} else {
    Write-Host "RESULT: PARTIAL/FAILED" -ForegroundColor Red
    Write-Host "  AppIDSvc running: $($script:RequiredSuccess.AppIDSvcRunning)"
    Write-Host "  Quick Assist removed: $($script:RequiredSuccess.QuickAssistRemoved)"
    Write-Host "  AppLocker policy applied: $($script:RequiredSuccess.AppLockerPolicyApplied)"
    $exitCode = 1
}

Write-Host "Log: $($config.LogPath)"
Write-Host "=================================================="

Stop-Transcript | Out-Null
exit $exitCode

#endregion Main