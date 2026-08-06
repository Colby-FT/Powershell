<#
.SYNOPSIS
    Audits installed antivirus against site-level AV tags and writes compliance status to a UDF.
.DESCRIPTION
    Reads the Datto RMM site description from $env:CS_PROFILE_DESC, determines expected AV(s),
    compares against the installed AV, and writes a non-destructive compliance entry to the
    user-specified UDF using the Update-UDFData helper pattern.
    
    Supports both workstations and Windows Servers.
.NOTES
    ControlledString should match the prefix of the UDF entry this component owns.
#>

# --- CONFIGURATION ---
$ControlledString = "AV_Audit:"

# --- UDF UPDATE HELPER ---
function Update-UDFData {
    <#
        .Name
        Update-UDFData
        .Synopsis
        Updates the specified UDF contents given new data.
        .Description
        Updates the specified UDF to include new data while preserving data written by other components.
        CurrentUDFValue is the string value currently in the UDF. 
        ControlledString is a regular expression which indicates what portion of the string should be replaced/updated.
    #>
    param(
        [Parameter(Mandatory = $false, Position = 1)][string]$CurrentUDFValue = ";",        
        [Parameter(Mandatory = $True, Position = 2)][string]$ControlledString,
        [Parameter(Mandatory = $True, Position = 3)][string]$WriteValue                        
    )
    
    $ExistingUDFValue = $CurrentUDFValue
    if ([string]::IsNullOrEmpty($ExistingUDFValue)) { $ExistingUDFValue = ";" }
    $splitExisting = $ExistingUDFValue.Split(";")
    $CuratedArrayList = [System.Collections.ArrayList]@()
    foreach ($splitString in $splitExisting) {
        if ((![string]::IsNullOrEmpty($splitString)) -and ($splitString -notmatch $ControlledString)) {
            [void]$CuratedArrayList.Add($splitString)
        }
    }
    [void]$CuratedArrayList.Add($WriteValue)    
    $udfOutString = ""
    foreach ($String in $CuratedArrayList) {
        $udfOutString += "$($String);"
    }
    return $udfOutString
}

# --- VALIDATE UDF INPUT ---
$UDF = if ($ENV:usrUDF -match '^(?:[1-9]|[1-9]\d|1\d\d|2\d\d|300)$') {
    $ENV:usrUDF
}
else { 
    Write-Host "WARNING: Bad UDF given. Must be a number between 1-300 (Inclusive)!"; 
    Exit 1
}

# ==============================================================================
# AV DETECTION FUNCTIONS
# ==============================================================================

function Get-InstalledAV {
    <#
    .Synopsis
    Detects the installed antivirus product on Windows workstations and servers.
    #>
    
    $DetectedAV = $null
    $DetectionMethod = $null
    
    # --- METHOD 1: Windows Defender via Get-MpComputerStatus (Works on Server 2012R2+ and Win10/11) ---
    try {
        $MpStatus = Get-MpComputerStatus -ErrorAction Stop
        if ($MpStatus -and $MpStatus.AntivirusEnabled) {
            $DetectedAV = "Windows Defender Antivirus"
            $DetectionMethod = "MpComputerStatus"
        }
    }
    catch {
        # Defender not available or not enabled
    }
    
    # --- METHOD 2: Windows Defender via Registry (Fallback for older systems) ---
    if ([string]::IsNullOrEmpty($DetectedAV)) {
        try {
            $DefenderReg = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows Defender" -ErrorAction Stop
            if ($DefenderReg -and $DefenderReg.DisableAntiSpyware -eq 0) {
                $DetectedAV = "Windows Defender Antivirus"
                $DetectionMethod = "Registry_WinDefender"
            }
        }
        catch {
            # Defender not installed or disabled via policy
        }
    }
    
    # --- METHOD 3: WMI Security Center (Workstations only - Vista through Win10) ---
    if ([string]::IsNullOrEmpty($DetectedAV)) {
        try {
            $AvWmi = Get-CimInstance -Namespace "root\SecurityCenter2" -ClassName AntiVirusProduct -ErrorAction Stop |
                Select-Object -First 1
            if ($AvWmi) {
                $DetectedAV = $AvWmi.displayName
                $DetectionMethod = "WMI_SecurityCenter2"
            }
        }
        catch {
            # WMI provider not available (common on Windows Server)
        }
    }
    
    # --- METHOD 4: Service-Based Detection (Third-party AVs - Required for Servers) ---
    if ([string]::IsNullOrEmpty($DetectedAV)) {
        
        $AllServices = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Running' }
        
        # Check for common AV services
        $AVServices = @{
            # SentinelOne
            "SentinelOne"                           = @("SentinelOne", "SentinelOne Agent", "SentinelOne Service", "SentinelOneDesktop", "SentinelOneAgent")
            # CrowdStrike
            "CrowdStrike Falcon"                    = @("CSFalconService", "CSFalconContainerService", "CrowdStrike Falcon")
            # Sophos
            "Sophos Intercept X"                    = @("Sophos AutoUpdate", "Sophos Device Manager", "SAU", "SDD", "SophosEndpoint", "Sophos Intercept X")
            # Datto AV
            "Datto AV"                              = @("DattoAV", "Datto Backup Agent", "dattobackupagent", "DattoAgent")
            # Webroot
            "Webroot SecureAnywhere"                = @("WRSA", "Webroot", "WSSA", "WebrootSecureAnywhere")
            # Microsoft Defender (if installed as separate engine on server)
            "Microsoft Defender for Endpoint"       = @("MsMpEng", "WinDefend", "Microsoft Antimalware Service")
            # Trend Micro
            "Trend Micro"                           = @("OfficeScan", "Trend Micro Client Server", "TmListen", "NTRtSrv")
            # Kaspersky
            "Kaspersky"                             = @("AVP", "ksafe", "Kaspersky Endpoint Security")
            # McAfee
            "McAfee"                                = @("McShield", "McTaskManager", "McAfee Agent", "mcapexe")
            # Symantee
            "Symantec Endpoint Protection"          = @("SepMasterService", "smc", "Symantec Endpoint Protection")
            # Vipre
            "Vipre"                                 = @("Vipre", "SBAMSvc", "SBAT")
            # Bitdefender
            "Bitdefender"                           = @("BDESVC", "Bitdefender Endpoint Security", "epag")
            # Malwarebytes
            "Malwarebytes"                          = @("MBAMService", "Malwarebytes Service")
        }
        
        foreach ($AVName in $AVServices.Keys) {
            $ServiceNames = $AVServices[$AVName]
            foreach ($SvcName in $ServiceNames) {
                if ($AllServices | Where-Object { $_.Name -eq $SvcName -or $_.DisplayName -like "*$SvcName*" }) {
                    $DetectedAV = $AVName
                    $DetectionMethod = "Service: $SvcName"
                    break
                }
            }
            if ($DetectedAV) { break }
        }
    }
    
    # --- METHOD 5: Registry-Based Detection for Third-Party AVs (Servers) ---
    if ([string]::IsNullOrEmpty($DetectedAV)) {
        
        $AVRegistryPaths = @(
            "HKLM:\SOFTWARE\SentinalOne",
            "HKLM:\SOFTWARE\CrowdStrike",
            "HKLM:\SOFTWARE\Sophos",
            "HKLM:\SOFTWARE\Datto",
            "HKLM:\SOFTWARE\Webroot",
            "HKLM:\SOFTWARE\Trend Micro",
            "HKLM:\SOFTWARE\Kaspersky Lab",
            "HKLM:\SOFTWARE\McAfee",
            "HKLM:\SOFTWARE\Symantec",
            "HKLM:\SOFTWARE\Bitdefender"
        )
        
        foreach ($Path in $AVRegistryPaths) {
            if (Test-Path $Path) {
                $DetectedAV = ($Path -split ':\\')[-1]
                $DetectionMethod = "Registry: $Path"
                break
            }
        }
    }
    
    if ([string]::IsNullOrEmpty($DetectedAV)) {
        $DetectedAV = "None Detected"
        $DetectionMethod = "No AV Found"
    }
    
    return @{
        Name = $DetectedAV
        Method = $DetectionMethod
    }
}

# ==============================================================================
# MAIN LOGIC
# ==============================================================================

# Get Site Description
$SiteDesc = $env:CS_PROFILE_DESC
if ([string]::IsNullOrWhiteSpace($SiteDesc)) {
    $SiteDesc = ""
}

# Detect Installed AV
$AVInfo = Get-InstalledAV
$DetectedAV = $AVInfo.Name

Write-Host "Detected AV: $DetectedAV (via $($AVInfo.Method))"

# Determine Expected AV(s) from Site Tags
$ExpectedAVs = [System.Collections.ArrayList]@()

# Specific third-party AVs (mutually exclusive expected)
if ($SiteDesc -like "*AV:SentinelOne*") { [void]$ExpectedAVs.Add("SentinelOne") }
if ($SiteDesc -like "*AV:CrowdStrike*") { [void]$ExpectedAVs.Add("CrowdStrike") }
if ($SiteDesc -like "*AV:Sophos*") { [void]$ExpectedAVs.Add("Sophos") }

# Standard / legacy AVs (any combination allowed)
$StandardAVMap = @{
    "AV:Windows_Defender"   = "Windows Defender"
    "AV_Unsupported:DAV"    = "Datto AV"
    "AV_Antique:Webroot"    = "Webroot"
}

foreach ($Tag in $StandardAVMap.Keys) {
    if ($SiteDesc -like "*$Tag*") {
        [void]$ExpectedAVs.Add($StandardAVMap[$Tag])
    }
}

# Evaluate Compliance
$Status = "Compliant"
$Reason = ""

if ($SiteDesc -like "*AV_Other:Not_Responsible*") {
    $Status = "Excluded"
    $Reason = "Site marked AV_Other:Not_Responsible"
}
elseif ($ExpectedAVs.Count -eq 0) {
    $Status = "No_Policy"
    $Reason = "No recognized AV tag found in site description"
}
else {
    $Matched = $false
    foreach ($Expected in $ExpectedAVs) {
        if ($DetectedAV -like "*$Expected*") {
            $Matched = $true
            break
        }
    }

    if (-not $Matched) {
        $Status = "Non-Compliant"
        $Reason = "Expected one of: $($ExpectedAVs -join ', '). Found: $DetectedAV"
    }
}

# Write Result to UDF
$varname = "UDF_$UDF"
$CurrentUDFValue = [Environment]::GetEnvironmentVariable($varName)

$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
$WriteValue = "AV_Audit:$Status [$Timestamp] $Reason"

$UDFWriteVal = Update-UDFData -CurrentUDFValue $CurrentUDFValue -ControlledString $ControlledString -WriteValue $WriteValue

New-ItemProperty -Path HKLM:\SOFTWARE\Centrastage -Name "custom$UDF" -PropertyType String -Value $UDFWriteVal -Force | Out-Null

Write-Host "AV Audit Result: $Status"
Write-Host "Reason: $Reason"
Write-Host "UDF $UDF updated."