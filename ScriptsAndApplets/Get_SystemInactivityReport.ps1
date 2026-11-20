########################################
#region Get-IntuneDeviceLockPolicy
########################################
function Get-IntuneDeviceLockPolicy {
    <#
    .SYNOPSIS
        Retrieves Intune/MDM-pushed DeviceLock and screen lock policies with reliable enrollment detection.

    .DESCRIPTION
        Reads the PolicyManager registry hive (filtered to security-relevant namespaces),
        the ADMX-backed policy defaults, and the DeviceLock CSP location to report which
        screen lock and inactivity policies were pushed by Intune.

        Enrollment is confirmed via the MDM enrollment registry requiring a known Intune
        ProviderID (MS DM Server, MEM, Intune, MDM, or GUID-style), with dsregcmd /status
        MDM URL block as the authoritative override. Azure AD join and generic deployment
        authorities (Deploy Authority, Cloud Authority, Local Authority) are tracked
        separately and do NOT imply MDM enrollment.

    .PARAMETER IncludeUserPolicies
        Also reads the per-user PolicyManager hive (HKU) for user-targeted Intune policies,
        including the Personalization / ADMX-backed screen saver settings.

    .EXAMPLE
        Get-IntuneDeviceLockPolicy

    .EXAMPLE
        Get-IntuneDeviceLockPolicy -IncludeUserPolicies -Verbose

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    param (
        [switch]$IncludeUserPolicies
    )

    Begin {
        Write-Verbose "[$($MyInvocation.InvocationName)] Entering Begin block."

        $mdmProviderPatterns = @(
            'MS DM Server', 'MEM', 'Intune', 'MDM',
            '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$'
        )

        $scriptBlock_GetMdmStatus = {
            $enrollmentsPath = "HKLM:\SOFTWARE\Microsoft\Enrollments"
            $status = [ordered]@{
                MdmEnrolled           = $false
                AzureAdJoined         = $false
                DeployAuthority       = $false
                EnrollmentSource      = $null
                MdmDeviceAuthority     = $null
                MdmUrl                = $null
                MdmDiscoveryServiceUrl = $null
                MdmComplianceUrl      = $null
                Upn                   = $null
                ProviderID            = $null
                DsregcmdConfirmed     = $false
            }

            if (Test-Path $enrollmentsPath) {
                $enrollmentKeys = Get-ChildItem -Path $enrollmentsPath -ErrorAction SilentlyContinue
                foreach ($key in $enrollmentKeys) {
                    $props = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue
                    if (-not $props) { continue }

                    if ($props.EnrollmentState -eq 1) {
                        if ($props.DeviceAuthority -in @('Cloud Authority','Local Authority')) {
                            $status.AzureAdJoined = $true
                            if (-not $status.Upn -and $props.UserPrincipalName) { $status.Upn = $props.UserPrincipalName }
                            continue
                        }
                        if ($props.DeviceAuthority -eq 'Deploy Authority' -or $props.ProviderID -eq 'Deploy Authority') {
                            $status.DeployAuthority = $true
                            continue
                        }
                    }

                    if ($props.EnrollmentState -eq 1 -and $props.ProviderID) {
                        $providerMatch = $false
                        foreach ($pattern in $mdmProviderPatterns) {
                            if ($props.ProviderID -match $pattern) { $providerMatch = $true; break }
                        }
                        if ($providerMatch) {
                            $status.MdmEnrolled = $true
                            $status.EnrollmentSource = "Registry (HKLM\Enrollments\$($key.PSChildName))"
                            $status.ProviderID = $props.ProviderID
                            $status.MdmDeviceAuthority = $props.DeviceAuthority
                            if ($props.UserPrincipalName) { $status.Upn = $props.UserPrincipalName }
                            break
                        }
                    }
                }
            }

            try {
                $dsregcmd = & dsregcmd /status 2>$null
                $inMdm = $false
                foreach ($line in $dsregcmd) {
                    if ($line -match "MDM Enrollment:") { $inMdm = $true; continue }
                    if ($inMdm) {
                        if ($line -match "MDM Url:\s*(.+)")                { $status.MdmUrl = $matches[1].Trim(); $status.DsregcmdConfirmed = $true }
                        elseif ($line -match "MDM Compliance Url:\s*(.+)")   { $status.MdmComplianceUrl = $matches[1].Trim() }
                        elseif ($line -match "MDM Discovery Service Url:\s*(.+)") { $status.MdmDiscoveryServiceUrl = $matches[1].Trim() }
                        elseif ($line -match "^\s*$" -and $status.MdmUrl)   { $inMdm = $false }
                    }
                }
                if ($status.MdmUrl) {
                    $status.MdmEnrolled = $true
                    if (-not $status.EnrollmentSource) { $status.EnrollmentSource = "dsregcmd (MDM URL present)" }
                }
            }
            catch {
                Write-Verbose "[$($MyInvocation.InvocationName)] dsregcmd unavailable or failed: $_"
            }

            return [pscustomobject]$status
        }

        $scriptBlock_GetPolicyManagerSettings = {
            $results = [ordered]@{}
            $pmRoot = "HKLM:\SOFTWARE\Microsoft\PolicyManager"
            $allowedAreas = @('DeviceLock','Security','AboveLock','DevicePassword','Authentication','Licensing')

            $devicePath = "$pmRoot\current\device"
            if (Test-Path $devicePath) {
                $areas = Get-ChildItem -Path $devicePath -ErrorAction SilentlyContinue
                foreach ($area in $areas) {
                    if ($area.PSChildName -notin $allowedAreas) { continue }
                    $props = Get-ItemProperty -Path $area.PSPath -ErrorAction SilentlyContinue
                    if ($props) {
                        foreach ($p in $props.PSObject.Properties) {
                            if ($p.Name -in @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider')) { continue }
                            $results["$($area.PSChildName)/$($p.Name)"] = $p.Value
                        }
                    }
                }
            }
            return $results
        }

        $scriptBlock_GetDeviceLockCSP = {
            $deviceLock = [ordered]@{}
            $dlPath = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\DeviceLock"

            if (Test-Path $dlPath) {
                $props = Get-ItemProperty -Path $dlPath -ErrorAction SilentlyContinue
                if ($props) {
                    foreach ($p in $props.PSObject.Properties) {
                        if ($p.Name -in @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider')) { continue }
                        $deviceLock[$p.Name] = $p.Value
                    }
                }
            }

            $effPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
            if (Test-Path $effPath) {
                $effProps = Get-ItemProperty -Path $effPath -ErrorAction SilentlyContinue
                if ($null -ne $effProps.InactivityTimeoutSecs) {
                    $deviceLock['InactivityTimeoutSecs_Effective'] = $effProps.InactivityTimeoutSecs
                }
            }
            return $deviceLock
        }

        $scriptBlock_GetAdmxDefaultSettings = {
            $results = [ordered]@{}
            $admxPath = "HKLM:\SOFTWARE\Microsoft\PolicyManager\AdmxDefault"
            $relevantKeys = @(
                'InactivityTimeoutSecs',
                'ScreenSaveActive','ScreenSaveTimeOut','ScreenSaverIsSecure','SCRNSAVE.EXE',
                'MaxPasswordAge','MinPasswordLength','PasswordComplexity'
            )

            if (Test-Path $admxPath) {
                $admxNodes = Get-ChildItem -Path $admxPath -Recurse -ErrorAction SilentlyContinue
                foreach ($node in $admxNodes) {
                    $props = Get-ItemProperty -Path $node.PSPath -ErrorAction SilentlyContinue
                    if ($props) {
                        foreach ($p in $props.PSObject.Properties) {
                            if ($p.Name -in @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider')) { continue }
                            if ($p.Name -in $relevantKeys) {
                                $results["AdmxDefault/$($node.PSChildName)/$($p.Name)"] = $p.Value
                            }
                        }
                    }
                }
            }
            return $results
        }

        $scriptBlock_GetPolicyEnforcedScreenSaver = {
            $policyScreenSaver = [ordered]@{}
            $policySystemPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
            if (Test-Path $policySystemPath) {
                $psProps = Get-ItemProperty -Path $policySystemPath -ErrorAction SilentlyContinue
                foreach ($name in 'ScreenSaveActive','ScreenSaveTimeOut','ScreenSaverIsSecure','SCRNSAVE.EXE','InactivityTimeoutSecs') {
                    if ($null -ne $psProps.$name) {
                        $policyScreenSaver[$name] = $psProps.$name
                    }
                }
            }
            return $policyScreenSaver
        }

        $scriptBlock_GetUserPolicyManagerSettings = {
            $results = [ordered]@{}
            $regExe = Get-Command reg.exe -ErrorAction SilentlyContinue
            if (-not $regExe) {
                Write-Warning "[$($MyInvocation.InvocationName)] reg.exe not found; skipping user PolicyManager hive."
                return $results
            }
            $usersOutput = & reg query "HKU" 2>$null
            $userSids = $usersOutput | Where-Object { $_ -match "S-1-5-21" }
            $allowedAreas = @(
                'DeviceLock','Security','AboveLock','DevicePassword','Authentication',
                'Personalization','ADMXPolicy','PolicyConfig'
            )
            foreach ($sid in $userSids) {
                $sid = $sid.Trim()
                $userPmPath = "HKU\$sid\SOFTWARE\Microsoft\PolicyManager\current\user"
                $regOutput = & reg query $userPmPath /s 2>$null
                if ($regOutput) {
                    $currentArea = $null
                    foreach ($line in $regOutput) {
                        if ($line -match "HKEY_USERS\\$sid\\.*\\([^\\]+)$") { $currentArea = $matches[1] }
                        elseif ($line -match "^\s+(\S+)\s+REG_(\S+)\s+(.*)$") {
                            if ($currentArea -in $allowedAreas) {
                                $results["User/$currentArea/$($matches[1])"] = $matches[3]
                            }
                        }
                    }
                }
            }
            return $results
        }

        $scriptBlock_GetUserAdmxDefaultSettings = {
            $results = [ordered]@{}
            $regExe = Get-Command reg.exe -ErrorAction SilentlyContinue
            if (-not $regExe) { return $results }

            $relevantKeys = @(
                'InactivityTimeoutSecs',
                'ScreenSaveActive','ScreenSaveTimeOut','ScreenSaverIsSecure','SCRNSAVE.EXE'
            )

            $usersOutput = & reg query "HKU" 2>$null
            $userSids = $usersOutput | Where-Object { $_ -match "S-1-5-21" }
            foreach ($sid in $userSids) {
                $sid = $sid.Trim()
                $userAdmxPath = "HKU\$sid\SOFTWARE\Microsoft\PolicyManager\AdmxDefault"
                $regOutput = & reg query $userAdmxPath /s 2>$null
                if ($regOutput) {
                    $currentKey = $null
                    foreach ($line in $regOutput) {
                        if ($line -match "HKEY_USERS\\$sid\\.*\\([^\\]+)$") { $currentKey = $matches[1] }
                        elseif ($line -match "^\s+(\S+)\s+REG_(\S+)\s+(.*)$") {
                            $valName = $matches[1]; $valData = $matches[3]
                            if ($valName -in $relevantKeys) {
                                $results["User/$currentKey/$valName"] = $valData
                            }
                        }
                    }
                }
            }
            return $results
        }
    }

    Process {
        try {
            Write-Verbose "[$($MyInvocation.InvocationName)] Collecting Intune/MDM policy sources."

            $mdmStatus = & $scriptBlock_GetMdmStatus
            $devicePolicies = & $scriptBlock_GetPolicyManagerSettings
            $deviceLockCSP = & $scriptBlock_GetDeviceLockCSP
            $admxDefaults = & $scriptBlock_GetAdmxDefaultSettings
            $policyScreenSaver = & $scriptBlock_GetPolicyEnforcedScreenSaver

            $userPolicies = [ordered]@{}
            $userAdmxDefaults = [ordered]@{}
            if ($IncludeUserPolicies) {
                $userPolicies = & $scriptBlock_GetUserPolicyManagerSettings
                $userAdmxDefaults = & $scriptBlock_GetUserAdmxDefaultSettings
            }

            $output = [ordered]@{
                MdmEnrolled                = $mdmStatus.MdmEnrolled
                AzureAdJoined              = $mdmStatus.AzureAdJoined
                DeployAuthority             = $mdmStatus.DeployAuthority
                EnrollmentSource           = $mdmStatus.EnrollmentSource
                MdmUrl                     = $mdmStatus.MdmUrl
                MdmDiscoveryServiceUrl     = $mdmStatus.MdmDiscoveryServiceUrl
                MdmComplianceUrl           = $mdmStatus.MdmComplianceUrl
                MdmDeviceAuthority          = $mdmStatus.MdmDeviceAuthority
                Upn                        = $mdmStatus.Upn
                ProviderID                 = $mdmStatus.ProviderID
                DsregcmdConfirmed          = $mdmStatus.DsregcmdConfirmed
                DeviceLockCSP              = [pscustomobject]$deviceLockCSP
                PolicyEnforcedScreenSaver  = [pscustomobject]$policyScreenSaver
                IntuneRelevantPolicies     = [pscustomobject]$devicePolicies
                AdmxDefaultPolicies        = [pscustomobject]$admxDefaults
                IntuneUserPolicies          = if ($IncludeUserPolicies) { [pscustomobject]$userPolicies } else { $null }
                IntuneUserAdmxPolicies     = if ($IncludeUserPolicies) { [pscustomobject]$userAdmxDefaults } else { $null }
                Timestamp                  = Get-Date
            }

            Write-Output ([pscustomobject]$output)
        }
        catch {
            $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                $_, "IntunePolicyCollectionError",
                [System.Management.Automation.ErrorCategory]::InvalidOperation, $null
            )
            $PSCmdlet.WriteError($ErrorRecord)
        }
    }

    End {
        Write-Verbose "[$($MyInvocation.InvocationName)] Entering End block."
    }
}
#endregion Get-IntuneDeviceLockPolicy

########################################
#region Get-SystemInactivityReport
########################################
function Get-SystemInactivityReport {
    <#
    .SYNOPSIS
        Comprehensive report of machine inactivity, screen saver, power settings,
        and Intune/MDM-pushed screen lock policies with enrollment validation.

    .DESCRIPTION
        Collects machine inactivity lock settings, screen saver configuration, power plan
        settings (display off, sleep, hibernate, unattended sleep, console lock, dim),
        GPO screen saver policies (HKLM and HKCU), dynamic lock, and Intune DeviceLock
        policies. Distinguishes Intune-pushed values from local/user values by attributing
        each setting to its policy source.

        Enrollment is confirmed via the MDM enrollment registry (requiring a known Intune
        ProviderID) and dsregcmd /status (requiring MDM URL block), distinguishing Azure AD
        join and Deploy Authority from true MDM enrollment. Includes a Policy Application
        Status section that distinguishes "not configured in Intune" from "configured but
        not applied" from "applied."

    .PARAMETER IncludeUserPolicies
        Also reads the per-user PolicyManager hive (HKU) for user-targeted Intune policies,
        including the Personalization / ADMX-backed screen saver settings.

    .PARAMETER Diagnostic
        Runs the raw evidence commands inline and displays their output before the
        formatted report.

    .EXAMPLE
        Get-SystemInactivityReport

    .EXAMPLE
        Get-SystemInactivityReport -IncludeUserPolicies -Verbose

    .EXAMPLE
        Get-SystemInactivityReport -Diagnostic
    #>

    [CmdletBinding()]
    param (
        [switch]$IncludeUserPolicies,

        [switch]$Diagnostic
    )

    #Clean up screen and set location to system drive for consistent output
    Set-Location $env:SystemDrive; Clear-Host;

    #region Helpers
    $convertSeconds = {
        param([uint32]$seconds)
        if ($null -eq $seconds -or $seconds -eq 0) { return "Never (0)" }
        $hours = [math]::Floor($seconds / 3600)
        $minutes = [math]::Floor(($seconds % 3600) / 60)
        $secs = $seconds % 60
        $parts = @()
        if ($hours -gt 0) { $parts += "$hours hr" }
        if ($minutes -gt 0) { $parts += "$minutes min" }
        if ($secs -gt 0 -and $hours -eq 0) { $parts += "$secs sec" }
        return $parts -join " "
    }

    # Reusable powercfg parser — extracts AC and DC values for any alias
    # Coerces null output to empty string to avoid [regex]::Match ArgumentNullException
    $queryPowercfg = {
        param([string]$Alias)
        $output = powercfg /query SCHEME_CURRENT $Alias 2>$null
        $output = "$output"  # Coerce null to empty string

        $acValue = 0; $dcValue = 0

        if (-not [string]::IsNullOrWhiteSpace($output)) {
            $acMatch = [regex]::Match($output, "Current AC Power Setting Index:\s*0x([0-9a-fA-F]+)")
            if ($acMatch.Success) { $acValue = [Convert]::ToUInt32($acMatch.Groups[1].Value, 16) }

            $dcMatch = [regex]::Match($output, "Current DC Power Setting Index:\s*0x([0-9a-fA-F]+)")
            if ($dcMatch.Success) { $dcValue = [Convert]::ToUInt32($dcMatch.Groups[1].Value, 16) }
        }

        return [pscustomobject]@{ AC = $acValue; DC = $dcValue }
    }
    #endregion Helpers

    #region Diagnostic Mode
    if ($Diagnostic) {
        Write-Host ""
        Write-Host "============================================" -ForegroundColor DarkCyan
        Write-Host "       DIAGNOSTIC MODE - RAW EVIDENCE        " -ForegroundColor Cyan
        Write-Host "============================================" -ForegroundColor DarkCyan
        Write-Host ""

        Write-Host "[1] dsregcmd /status | Select-String 'MDM'" -ForegroundColor Yellow
        Write-Host "    Expected: MDM URL block if Intune-managed" -ForegroundColor DarkGray
        $mdmRaw = & dsregcmd /status 2>$null | Select-String "MDM"
        if ($mdmRaw) {
            foreach ($line in $mdmRaw) { Write-Host "    $($line.ToString().Trim())" -ForegroundColor Green }
        } else {
            Write-Host "    (empty - no MDM enrollment block found)" -ForegroundColor Red
        }
        Write-Host ""

        Write-Host "[2] PolicyManager\current\device\DeviceLock" -ForegroundColor Yellow
        Write-Host "    Expected: MaxInactivityTimeDeviceLock value if Intune DeviceLock applied" -ForegroundColor DarkGray
        $dlRaw = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\DeviceLock" -ErrorAction SilentlyContinue
        if ($dlRaw) {
            $dlRaw.PSObject.Properties | Where-Object { $_.Name -notmatch "^PS" } | ForEach-Object {
                Write-Host "    $($_.Name) = $($_.Value)" -ForegroundColor Green
            }
        } else {
            Write-Host "    (empty - DeviceLock namespace does not exist)" -ForegroundColor Red
        }
        Write-Host ""

        Write-Host "[3] PolicyManager\AdmxDefault (recursive - inactivity/screen saver keys)" -ForegroundColor Yellow
        Write-Host "    Expected: InactivityTimeoutSecs or ScreenSaveTimeOut if ADMX-backed policy applied" -ForegroundColor DarkGray
        $admxRaw = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\PolicyManager\AdmxDefault" -Recurse -ErrorAction SilentlyContinue |
            ForEach-Object { Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue } |
            Select-Object InactivityTimeoutSecs, ScreenSaveTimeOut, ScreenSaveActive, ScreenSaverIsSecure, PSChildName |
            Where-Object { $_.InactivityTimeoutSecs -ne $null -or $_.ScreenSaveTimeOut -ne $null -or $_.ScreenSaveActive -ne $null -or $_.ScreenSaverIsSecure -ne $null }
        if ($admxRaw) {
            $admxRaw | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Green
        } else {
            Write-Host "    (empty - no ADMX-backed inactivity or screen saver policies found)" -ForegroundColor Red
        }
        Write-Host ""

        Write-Host "[4] Enrollment registry - ProviderID check" -ForegroundColor Yellow
        Write-Host "    Expected: ProviderID = 'MS DM Server' or Intune GUID if MDM-enrolled" -ForegroundColor DarkGray
        Write-Host "             'Deploy Authority' / 'Cloud Authority' = NOT Intune MDM" -ForegroundColor DarkGray
        $enrollRaw = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Enrollments" -ErrorAction SilentlyContinue |
            ForEach-Object { Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue } |
            Select-Object EnrollmentState, DeviceAuthority, ProviderID, UserPrincipalName |
            Where-Object { $_.EnrollmentState -eq 1 -or $_.ProviderID -ne $null }
        if ($enrollRaw) {
            $enrollRaw | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Green
        } else {
            Write-Host "    (no enrollment keys found)" -ForegroundColor Red
        }
        Write-Host ""

        if ($IncludeUserPolicies) {
            Write-Host "[5] User PolicyManager (HKU - Personalization / screen saver)" -ForegroundColor Yellow
            Write-Host "    Expected: ScreenSaveActive / ScreenSaveTimeOut if user-targeted policy applied" -ForegroundColor DarkGray
            $regExe = Get-Command reg.exe -ErrorAction SilentlyContinue
            if ($regExe) {
                $usersOutput = & reg query "HKU" 2>$null
                $userSids = $usersOutput | Where-Object { $_ -match "S-1-5-21" }
                $foundUserPolicy = $false
                foreach ($sid in $userSids) {
                    $sid = $sid.Trim()
                    $userPmPath = "HKU\$sid\SOFTWARE\Microsoft\PolicyManager\current\user"
                    $regOutput = & reg query $userPmPath /s 2>$null
                    if ($regOutput) {
                        $currentArea = $null
                        foreach ($line in $regOutput) {
                            if ($line -match "HKEY_USERS\\$sid\\.*\\([^\\]+)$") { $currentArea = $matches[1] }
                            elseif ($line -match "^\s+(\S+)\s+REG_(\S+)\s+(.*)$") {
                                if ($currentArea -in @('Personalization','DeviceLock','Security','AboveLock','DevicePassword','Authentication','ADMXPolicy','PolicyConfig')) {
                                    Write-Host "    [$sid] $currentArea/$($matches[1]) = $($matches[3])" -ForegroundColor Green
                                    $foundUserPolicy = $true
                                }
                            }
                        }
                    }
                }
                if (-not $foundUserPolicy) {
                    Write-Host "    (empty - no user-targeted Intune policies found)" -ForegroundColor Red
                }
            }
            Write-Host ""
        }
    }
    #endregion Diagnostic Mode

    Write-Host ""
    Write-Host "=================================================" -ForegroundColor DarkCyan
    Write-Host " SYSTEM INACTIVITY SETTINGS REPORT $env:COMPUTERNAME  " -ForegroundColor Cyan
    Write-Host "=================================================" -ForegroundColor DarkCyan
    Write-Host ""

    #region Intune / MDM Enrollment
    Write-Host "--- Intune / MDM Enrollment ---" -ForegroundColor Magenta

    $intunePolicy = Get-IntuneDeviceLockPolicy -IncludeUserPolicies:$IncludeUserPolicies -ErrorAction SilentlyContinue

    if ($intunePolicy) {
        if ($intunePolicy.AzureAdJoined) {
            Write-Host "  Azure AD Joined: " -NoNewline; Write-Host "Yes" -ForegroundColor Green
        } else {
            Write-Host "  Azure AD Joined: " -NoNewline; Write-Host "No" -ForegroundColor Gray
        }

        if ($intunePolicy.DeployAuthority) {
            Write-Host "  Deploy Authority: " -NoNewline; Write-Host "Yes (SCCM/ConfigMgr - not Intune MDM)" -ForegroundColor DarkYellow
        }

        if ($intunePolicy.MdmEnrolled) {
            Write-Host "  MDM Enrolled:    " -NoNewline; Write-Host "Yes" -ForegroundColor Green
            Write-Host "  Source:          $($intunePolicy.EnrollmentSource)"
            if ($intunePolicy.ProviderID) {
                Write-Host "  Provider ID:     $($intunePolicy.ProviderID)"
            }
            if ($intunePolicy.MdmUrl) {
                Write-Host "  MDM URL:         $($intunePolicy.MdmUrl)"
            }
            if ($intunePolicy.MdmDiscoveryServiceUrl) {
                Write-Host "  Discovery URL:  $($intunePolicy.MdmDiscoveryServiceUrl)" -ForegroundColor DarkGray
            }
            if ($intunePolicy.Upn) {
                Write-Host "  UPN:            $($intunePolicy.Upn)" -ForegroundColor DarkGray
            }
        } else {
            Write-Host "  MDM Enrolled:    " -NoNewline; Write-Host "No" -ForegroundColor Red
            Write-Host "  Source:          No Intune MDM provider found in registry or dsregcmd" -ForegroundColor DarkGray
            if ($intunePolicy.AzureAdJoined) {
                Write-Host "  Note:           Device is Azure AD Joined but NOT Intune MDM-enrolled." -ForegroundColor Yellow
            }
            if ($intunePolicy.DeployAuthority) {
                Write-Host "  Note:           Deploy Authority present (SCCM/ConfigMgr), not Intune MDM." -ForegroundColor Yellow
            }
            if (-not $intunePolicy.AzureAdJoined -and -not $intunePolicy.DeployAuthority) {
                Write-Host "  Note:           Device is not Azure AD Joined, not Deploy Authority, not MDM." -ForegroundColor Yellow
            }
            Write-Host "                  Intune policies cannot apply without MDM enrollment." -ForegroundColor Yellow
        }
    } else {
        Write-Host "  Enrolled:        " -NoNewline; Write-Host "Unable to determine" -ForegroundColor Red
    }
    Write-Host ""
    #endregion

    #region Intune DeviceLock CSP Policies
    Write-Host "--- Intune DeviceLock CSP (Pushed Policies) ---" -ForegroundColor Magenta

    if ($intunePolicy -and $intunePolicy.DeviceLockCSP) {
        $dl = $intunePolicy.DeviceLockCSP
        $dlProps = $dl.PSObject.Properties | Where-Object { $_.Value -ne $null }
        if ($dlProps) {
            foreach ($p in $dlProps) {
                $val = $p.Value
                $readable = ""
                if ($p.Name -match "TimeInSeconds|InactivityTime|InactivityTimeout|MaxInactivityTimeDeviceLock" -and [uint32]::TryParse([string]$val, [ref]$null)) {
                    $readable = " (" + (& $convertSeconds ([uint32]$val)) + ")"
                }
                Write-Host "  $($p.Name): $val$readable" -ForegroundColor Green
            }
        } else {
            Write-Host "  No DeviceLock CSP values found." -ForegroundColor Gray
            Write-Host "  Path checked: HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\DeviceLock" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "  No DeviceLock CSP data available." -ForegroundColor Gray
    }
    Write-Host ""
    #endregion

    #region ADMX-Backed Intune Policies (Device)
    Write-Host "--- ADMX-Backed Intune Policies - Device (Inactivity / Screen Saver) ---" -ForegroundColor Magenta

    if ($intunePolicy -and $intunePolicy.AdmxDefaultPolicies) {
        $admx = $intunePolicy.AdmxDefaultPolicies
        $admxProps = $admx.PSObject.Properties | Where-Object { $_.Value -ne $null }
        if ($admxProps) {
            foreach ($p in $admxProps) {
                $val = $p.Value
                $readable = ""
                if ($p.Name -match "InactivityTimeout|ScreenSaveTimeOut" -and [uint32]::TryParse([string]$val, [ref]$null)) {
                    $readable = " (" + (& $convertSeconds ([uint32]$val)) + ")"
                }
                Write-Host "  $($p.Name) = $val$readable" -ForegroundColor Green
            }
        } else {
            Write-Host "  No ADMX-backed inactivity or screen saver policies found." -ForegroundColor Gray
            Write-Host "  Path checked: HKLM\SOFTWARE\Microsoft\PolicyManager\AdmxDefault (recursive)" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "  No ADMX-backed policy data available." -ForegroundColor Gray
    }
    Write-Host ""
    #endregion

    #region User-Targeted Intune Policies
    Write-Host "--- User-Targeted Intune Policies (Screen Saver / Personalization) ---" -ForegroundColor Magenta

    $userPolicyFound = $false
    if ($intunePolicy -and $intunePolicy.IntuneUserPolicies) {
        $up = $intunePolicy.IntuneUserPolicies
        $upProps = $up.PSObject.Properties | Where-Object { $_.Value -ne $null }
        if ($upProps) {
            foreach ($p in $upProps) {
                Write-Host "  $($p.Name) = $($p.Value)" -ForegroundColor Green
                $userPolicyFound = $true
            }
        }
    }

    if ($intunePolicy -and $intunePolicy.IntuneUserAdmxPolicies) {
        $uadmx = $intunePolicy.IntuneUserAdmxPolicies
        $uadmxProps = $uadmx.PSObject.Properties | Where-Object { $_.Value -ne $null }
        if ($uadmxProps) {
            foreach ($p in $uadmxProps) {
                $val = $p.Value
                $readable = ""
                if ($p.Name -match "ScreenSaveTimeOut|InactivityTimeout" -and [uint32]::TryParse([string]$val, [ref]$null)) {
                    $readable = " (" + (& $convertSeconds ([uint32]$val)) + ")"
                }
                Write-Host "  $($p.Name) = $val$readable" -ForegroundColor Green
                $userPolicyFound = $true
            }
        }
    }

    if (-not $userPolicyFound) {
        if ($IncludeUserPolicies) {
            Write-Host "  No user-targeted Intune policies found." -ForegroundColor Gray
            Write-Host "  Checked: HKU\<SID>\SOFTWARE\Microsoft\PolicyManager\current\user" -ForegroundColor DarkGray
            Write-Host "  Namespaces: DeviceLock, Security, AboveLock, DevicePassword, Authentication, Personalization, ADMXPolicy, PolicyConfig" -ForegroundColor DarkGray
        } else {
            Write-Host "  User policy check skipped (use -IncludeUserPolicies to enable)." -ForegroundColor Gray
        }
    }
    Write-Host ""
    #endregion

    #region Policy-Enforced Screen Saver (HKLM policy path)
    Write-Host "--- Policy-Enforced Screen Saver (HKLM Policies\System) ---" -ForegroundColor Magenta

    if ($intunePolicy -and $intunePolicy.PolicyEnforcedScreenSaver) {
        $pss = $intunePolicy.PolicyEnforcedScreenSaver
        $pssProps = $pss.PSObject.Properties | Where-Object { $_.Value -ne $null }
        if ($pssProps) {
            foreach ($p in $pssProps) {
                $val = $p.Value
                $readable = ""
                if ($p.Name -eq "ScreenSaveTimeOut" -and [int]::TryParse([string]$val, [ref]$null)) {
                    $readable = " (" + (& $convertSeconds ([uint32]$val)) + ")"
                }
                Write-Host "  $($p.Name): $val$readable" -ForegroundColor Green
            }
        } else {
            Write-Host "  No policy-enforced screen saver values under HKLM Policies\System." -ForegroundColor Gray
        }
    } else {
        Write-Host "  No policy-enforced screen saver data available." -ForegroundColor Gray
    }
    Write-Host ""
    #endregion

    #region GPO Screen Saver Policies (HKCU and HKLM Personalization)
    Write-Host "--- GPO Screen Saver Policies (User & Machine Policy Paths) ---" -ForegroundColor Magenta

    $hkcuGpoPath = "HKCU:\Software\Policies\Microsoft\Windows\Control Panel\Desktop"
    $hkcuGpo = Get-ItemProperty -Path $hkcuGpoPath -ErrorAction SilentlyContinue
    $hkcuGpoFound = $false
    if ($hkcuGpo) {
        foreach ($name in 'ScreenSaveActive','ScreenSaveTimeOut','ScreenSaverIsSecure','SCRNSAVE.EXE') {
            if ($null -ne $hkcuGpo.$name) {
                $val = $hkcuGpo.$name
                $readable = ""
                if ($name -eq "ScreenSaveTimeOut" -and [int]::TryParse([string]$val, [ref]$null)) {
                    $readable = " (" + (& $convertSeconds ([uint32]$val)) + ")"
                }
                Write-Host "  [HKCU GPO] $name = $val$readable" -ForegroundColor Green
                $hkcuGpoFound = $true
            }
        }
    }

    $hklmGpoPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Control Panel\Personalization"
    $hklmGpo = Get-ItemProperty -Path $hklmGpoPath -ErrorAction SilentlyContinue
    $hklmGpoFound = $false
    if ($hklmGpo) {
        foreach ($name in 'ScreenSaveActive','ScreenSaveTimeOut','ScreenSaverIsSecure','SCRNSAVE.EXE','NoLockScreen') {
            if ($null -ne $hklmGpo.$name) {
                $val = $hklmGpo.$name
                $readable = ""
                if ($name -eq "ScreenSaveTimeOut" -and [int]::TryParse([string]$val, [ref]$null)) {
                    $readable = " (" + (& $convertSeconds ([uint32]$val)) + ")"
                }
                Write-Host "  [HKLM GPO] $name = $val$readable" -ForegroundColor Green
                $hklmGpoFound = $true
            }
        }
    }

    if (-not $hkcuGpoFound -and -not $hklmGpoFound) {
        Write-Host "  No GPO-enforced screen saver policies found." -ForegroundColor Gray
        Write-Host "  Checked: HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" -ForegroundColor DarkGray
        Write-Host "          HKLM\SOFTWARE\Policies\Microsoft\Windows\Control Panel\Personalization" -ForegroundColor DarkGray
    }
    Write-Host ""
    #endregion

    #region Intune Relevant Policies (filtered summary)
    Write-Host "--- Intune Relevant Policies (Filtered Summary) ---" -ForegroundColor Magenta

    if ($intunePolicy -and $intunePolicy.IntuneRelevantPolicies) {
        $rp = $intunePolicy.IntuneRelevantPolicies
        $rpProps = $rp.PSObject.Properties | Where-Object { $_.Value -ne $null }
        if ($rpProps) {
            foreach ($p in $rpProps) {
                Write-Host "  $($p.Name) = $($p.Value)" -ForegroundColor Green
            }
        } else {
            Write-Host "  No security-relevant Intune policies found." -ForegroundColor Gray
            Write-Host "  (Checked: DeviceLock, Security, AboveLock, DevicePassword, Authentication, Licensing)" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "  No Intune relevant policy data available." -ForegroundColor Gray
    }
    Write-Host ""
    #endregion

    #region Machine Inactivity Lock (Effective)
    Write-Host "--- Machine Inactivity Lock (Effective Value) ---" -ForegroundColor Yellow

    $gpoInactivity = Get-ItemProperty `
        -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
        -Name "InactivityTimeoutSecs" -ErrorAction SilentlyContinue

    $inactivityAttribution = "Local / Not set"
    if ($null -ne $gpoInactivity.InactivityTimeoutSecs -and $gpoInactivity.InactivityTimeoutSecs -gt 0) {
        $timeout = $gpoInactivity.InactivityTimeoutSecs
        $readable = & $convertSeconds $timeout
        Write-Host "  Status:        " -NoNewline; Write-Host "Configured" -ForegroundColor Green
        Write-Host "  Timeout:       $timeout seconds ($readable)"
        if ($intunePolicy -and $intunePolicy.DeviceLockCSP.InactivityTimeInSeconds) {
            $inactivityAttribution = "Intune (DeviceLock CSP)"
            Write-Host "  Source:        " -NoNewline; Write-Host "Intune (DeviceLock CSP)" -ForegroundColor Magenta
        } elseif ($intunePolicy -and $intunePolicy.AdmxDefaultPolicies -and ($intunePolicy.AdmxDefaultPolicies.PSObject.Properties | Where-Object { $_.Name -match "InactivityTimeout" })) {
            $inactivityAttribution = "Intune (ADMX-backed)"
            Write-Host "  Source:        " -NoNewline; Write-Host "Intune (ADMX-backed)" -ForegroundColor Magenta
        } else {
            $inactivityAttribution = "GPO or local policy"
            Write-Host "  Source:        " -NoNewline; Write-Host "GPO or local policy" -ForegroundColor DarkYellow
        }
    } else {
        Write-Host "  Status:        " -NoNewline; Write-Host "Not Configured" -ForegroundColor Gray
        Write-Host "  Timeout:       0 seconds (setting disabled or absent)"
    }
    Write-Host ""
    #endregion

    #region Screen Saver Settings (User Effective)
    Write-Host "--- Screen Saver Settings (User Effective Value) ---" -ForegroundColor Yellow

    $desktop = Get-ItemProperty -Path "HKCU:\Control Panel\Desktop" -ErrorAction SilentlyContinue

    $screenSaverActive = if ($desktop.ScreenSaveActive -eq "1") { $true } else { $false }
    $timeoutSec = if ($desktop.ScreenSaveTimeOut) { [int]$desktop.ScreenSaveTimeOut } else { 0 }
    $isSecure = $desktop.ScreenSaverIsSecure -eq "1"
    $scrnExe = $desktop."SCRNSAVE.EXE"

    $screenSaverAttribution = "User-configured"
    if ($intunePolicy -and $intunePolicy.PolicyEnforcedScreenSaver) {
        $pss = $intunePolicy.PolicyEnforcedScreenSaver
        if ($null -ne $pss.ScreenSaveActive -or $null -ne $pss.ScreenSaveTimeOut -or $null -ne $pss.ScreenSaverIsSecure) {
            $screenSaverAttribution = "Intune/GPO policy-enforced (HKLM)"
        }
    }
    if ($hkcuGpoFound -or $hklmGpoFound) {
        $screenSaverAttribution = "GPO policy-enforced"
    }
    if ($userPolicyFound) {
        $screenSaverAttribution = "Intune user-targeted policy"
    }

    Write-Host "  Enabled:       " -NoNewline
    if ($screenSaverActive) { Write-Host "Yes" -ForegroundColor Green }
    else { Write-Host "No" -ForegroundColor Gray }

    if ($timeoutSec -gt 0) {
        $readable = & $convertSeconds $timeoutSec
        Write-Host "  Timeout:       $timeoutSec seconds ($readable)"
    } else {
        Write-Host "  Timeout:       Not set (immediate or disabled)"
    }

    Write-Host "  Lock on Resume:" -NoNewline
    if ($isSecure) { Write-Host " Yes (password required)" -ForegroundColor Green }
    else { Write-Host " No (no password required)" -ForegroundColor Gray }

    if ([string]::IsNullOrWhiteSpace($scrnExe)) {
        Write-Host "  Executable:    None specified"
    } else {
        $scrnName = Split-Path $scrnExe -Leaf
        Write-Host "  Executable:    $scrnName"
        Write-Host "  Full Path:     $scrnExe" -ForegroundColor DarkGray
    }
    Write-Host "  Source:        " -NoNewline; Write-Host $screenSaverAttribution -ForegroundColor Magenta
    Write-Host ""
    #endregion

    #region Dynamic Lock
    Write-Host "--- Dynamic Lock (Bluetooth Proximity) ---" -ForegroundColor Yellow

    $winlogonPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"
    $winlogon = Get-ItemProperty -Path $winlogonPath -ErrorAction SilentlyContinue

    $dynamicLockDisabled = $false
    if ($null -ne $winlogon.DisableDynamicLock -and $winlogon.DisableDynamicLock -eq 1) {
        $dynamicLockDisabled = $true
    }

    Write-Host "  Dynamic Lock:  " -NoNewline
    if ($dynamicLockDisabled) {
        Write-Host "Disabled (DisableDynamicLock = 1)" -ForegroundColor Gray
    } else {
        Write-Host "Not disabled (may be enabled if a Bluetooth device is paired)" -ForegroundColor Green
    }
    Write-Host ""
    #endregion

    #region Power Plan
    Write-Host "--- Active Power Plan ---" -ForegroundColor Yellow

    $powerScheme = powercfg /getactivescheme 2>$null
    $schemeName = $null; $schemeGuid = $null
    if ($powerScheme -match "Power Scheme GUID:\s*([0-9a-fA-F-]+)\s+\((.+)\)") {
        $schemeGuid = $matches[1]
        $schemeName = $matches[2]
        Write-Host "  Name:          $schemeName"
        Write-Host "  GUID:          $schemeGuid"
    } else {
        Write-Host "  Unable to retrieve active power plan" -ForegroundColor Red
    }
    Write-Host ""
    #endregion

    #region Display Off Timeout
    Write-Host "--- Display Off Timeout (VIDEOIDLE) ---" -ForegroundColor Yellow

    $displayTimeout = & $queryPowercfg "SUB_VIDEO VIDEOIDLE"

    if ($displayTimeout.AC -gt 0) {
        $readable = & $convertSeconds $displayTimeout.AC
        Write-Host "  AC Power:      $($displayTimeout.AC) seconds ($readable)"
    } else {
        Write-Host "  AC Power:      Never (display stays on)"
    }

    if ($displayTimeout.DC -gt 0) {
        $readable = & $convertSeconds $displayTimeout.DC
        Write-Host "  DC Power:      $($displayTimeout.DC) seconds ($readable)" -ForegroundColor DarkGray
    } else {
        Write-Host "  DC Power:      Never" -ForegroundColor DarkGray
    }
    Write-Host ""
    #endregion

    #region Dim Display Timeout
    Write-Host "--- Dim Display Timeout (VIDEODIM) ---" -ForegroundColor Yellow

    $dimTimeout = & $queryPowercfg "SUB_VIDEO VIDEODIM"

    if ($dimTimeout.AC -gt 0) {
        $readable = & $convertSeconds $dimTimeout.AC
        Write-Host "  AC Power:      $($dimTimeout.AC) seconds ($readable)"
    } else {
        Write-Host "  AC Power:      Never (no dim)"
    }

    if ($dimTimeout.DC -gt 0) {
        $readable = & $convertSeconds $dimTimeout.DC
        Write-Host "  DC Power:      $($dimTimeout.DC) seconds ($readable)" -ForegroundColor DarkGray
    } else {
        Write-Host "  DC Power:      Never" -ForegroundColor DarkGray
    }
    Write-Host ""
    #endregion

    #region Console Lock Timeout
    Write-Host "--- Console Lock Display Off Timeout (CONSOLELOCK) ---" -ForegroundColor Yellow

    $consoleLockTimeout = & $queryPowercfg "SUB_VIDEO CONSOLELOCK"

    if ($consoleLockTimeout.AC -gt 0) {
        $readable = & $convertSeconds $consoleLockTimeout.AC
        Write-Host "  AC Power:      $($consoleLockTimeout.AC) seconds ($readable)"
    } else {
        Write-Host "  AC Power:      Never (display off immediately on lock, or not configured)"
    }

    if ($consoleLockTimeout.DC -gt 0) {
        $readable = & $convertSeconds $consoleLockTimeout.DC
        Write-Host "  DC Power:      $($consoleLockTimeout.DC) seconds ($readable)" -ForegroundColor DarkGray
    } else {
        Write-Host "  DC Power:      Never" -ForegroundColor DarkGray
    }
    Write-Host ""
    #endregion

    #region Sleep Timeout
    Write-Host "--- Sleep Timeout (STANDBYIDLE) ---" -ForegroundColor Yellow

    $sleepTimeout = & $queryPowercfg "SUB_SLEEP STANDBYIDLE"

    if ($sleepTimeout.AC -gt 0) {
        $readable = & $convertSeconds $sleepTimeout.AC
        Write-Host "  AC Power:      $($sleepTimeout.AC) seconds ($readable)"
    } else {
        Write-Host "  AC Power:      Never (sleep disabled)"
    }

    if ($sleepTimeout.DC -gt 0) {
        $readable = & $convertSeconds $sleepTimeout.DC
        Write-Host "  DC Power:      $($sleepTimeout.DC) seconds ($readable)" -ForegroundColor DarkGray
    } else {
        Write-Host "  DC Power:      Never" -ForegroundColor DarkGray
    }
    Write-Host ""
    #endregion

    #region Hibernate Timeout
    Write-Host "--- Hibernate Timeout (HIBERNATEIDLE) ---" -ForegroundColor Yellow

    $hibernateTimeout = & $queryPowercfg "SUB_SLEEP HIBERNATEIDLE"

    if ($hibernateTimeout.AC -gt 0) {
        $readable = & $convertSeconds $hibernateTimeout.AC
        Write-Host "  AC Power:      $($hibernateTimeout.AC) seconds ($readable)"
    } else {
        Write-Host "  AC Power:      Never (hibernate disabled)"
    }

    if ($hibernateTimeout.DC -gt 0) {
        $readable = & $convertSeconds $hibernateTimeout.DC
        Write-Host "  DC Power:      $($hibernateTimeout.DC) seconds ($readable)" -ForegroundColor DarkGray
    } else {
        Write-Host "  DC Power:      Never" -ForegroundColor DarkGray
    }
    Write-Host ""
    #endregion

    #region Unattended Sleep Timeout
    Write-Host "--- Unattended Sleep Timeout (UNATTENDSLEEP) ---" -ForegroundColor Yellow

    $unattendTimeout = & $queryPowercfg "SUB_SLEEP UNATTENDSLEEP"

    if ($unattendTimeout.AC -gt 0) {
        $readable = & $convertSeconds $unattendTimeout.AC
        Write-Host "  AC Power:      $($unattendTimeout.AC) seconds ($readable)"
    } else {
        Write-Host "  AC Power:      Never (no unattended sleep)"
    }

    if ($unattendTimeout.DC -gt 0) {
        $readable = & $convertSeconds $unattendTimeout.DC
        Write-Host "  DC Power:      $($unattendTimeout.DC) seconds ($readable)" -ForegroundColor DarkGray
    } else {
        Write-Host "  DC Power:      Never" -ForegroundColor DarkGray
    }
    Write-Host ""
    #endregion

    #region Policy Application Status
    Write-Host "--- Policy Application Status ---" -ForegroundColor Magenta

    $policyApplied = $false
    $policySource = "None"

    if ($intunePolicy) {
        if ($intunePolicy.DeviceLockCSP -and ($intunePolicy.DeviceLockCSP.PSObject.Properties | Where-Object { $_.Value -ne $null -and $_.Name -notmatch "Effective" })) {
            $policyApplied = $true
            $policySource = "Intune DeviceLock CSP (device-scoped)"
        } elseif ($intunePolicy.AdmxDefaultPolicies -and ($intunePolicy.AdmxDefaultPolicies.PSObject.Properties | Where-Object { $_.Value -ne $null })) {
            $policyApplied = $true
            $policySource = "Intune ADMX-backed (device-scoped)"
        } elseif ($intunePolicy.PolicyEnforcedScreenSaver -and ($intunePolicy.PolicyEnforcedScreenSaver.PSObject.Properties | Where-Object { $_.Value -ne $null })) {
            $policyApplied = $true
            $policySource = "Intune/GPO policy-enforced (HKLM)"
        } elseif ($userPolicyFound) {
            $policyApplied = $true
            $policySource = "Intune user-targeted policy"
        }
    }

    if (-not $intunePolicy.MdmEnrolled) {
        Write-Host "  Status:        " -NoNewline
        Write-Host "Cannot apply - device not Intune MDM-enrolled" -ForegroundColor Red
        Write-Host "  Explanation:  Intune policies require MDM enrollment. This device has no" -ForegroundColor DarkGray
        Write-Host "                 Intune MDM provider (no 'MS DM Server' ProviderID, no" -ForegroundColor DarkGray
        Write-Host "                 dsregcmd MDM URL block). Policies in the Intune portal cannot" -ForegroundColor DarkGray
        Write-Host "                 reach this device until MDM enrollment completes." -ForegroundColor DarkGray
    } elseif ($policyApplied) {
        Write-Host "  Status:        " -NoNewline
        Write-Host "Applied" -ForegroundColor Green
        Write-Host "  Source:        $policySource"
    } else {
        Write-Host "  Status:        " -NoNewline
        Write-Host "No Intune screen lock policy found on this device" -ForegroundColor Yellow
        Write-Host "  Explanation:  Device is MDM-enrolled but no DeviceLock, ADMX-backed, or" -ForegroundColor DarkGray
        Write-Host "                 user-targeted screen saver values were found in the registry." -ForegroundColor DarkGray
        Write-Host "                 The Intune policy may be created but not assigned to this" -ForegroundColor DarkGray
        Write-Host "                 device/user, or not yet synced." -ForegroundColor DarkGray
    }
    Write-Host ""
    #endregion

    #region Summary Table
    Write-Host "============================================" -ForegroundColor DarkCyan
    Write-Host "               SUMMARY TABLE                " -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor DarkCyan
    Write-Host ""

    $summaryData = [PSCustomObject]@{
        "Azure AD Joined"           = if ($intunePolicy.AzureAdJoined) { "Yes" } else { "No" }
        "Deploy Authority"          = if ($intunePolicy.DeployAuthority) { "Yes (SCCM/ConfigMgr)" } else { "No" }
        "MDM Enrolled"              = if ($intunePolicy.MdmEnrolled) { "Yes" } else { "No" }
        "Intune Policy Applied"     = if ($policyApplied) { "Yes ($policySource)" } elseif (-not $intunePolicy.MdmEnrolled) { "Cannot apply (not MDM-enrolled)" } else { "No" }
        "Machine Inactivity Lock"   = if ($gpoInactivity.InactivityTimeoutSecs -gt 0) { "$($gpoInactivity.InactivityTimeoutSecs) sec" } else { "Disabled" }
        "Inactivity Lock Source"    = $inactivityAttribution
        "Screen Saver"              = if ($screenSaverActive) { "Enabled" } else { "Disabled" }
        "Screen Saver Timeout"      = if ($timeoutSec -gt 0) { "$timeoutSec sec" } else { "Not set" }
        "Screen Saver Lock"         = if ($isSecure) { "Yes" } else { "No" }
        "Screen Saver Source"        = $screenSaverAttribution
        "GPO Screen Saver (HKCU)"   = if ($hkcuGpoFound) { "Present" } else { "None" }
        "GPO Screen Saver (HKLM)"   = if ($hklmGpoFound) { "Present" } else { "None" }
        "Dynamic Lock"              = if ($dynamicLockDisabled) { "Disabled" } else { "Not disabled" }
        "Display Off (AC)"          = if ($displayTimeout.AC -gt 0) { "$($displayTimeout.AC) sec" } else { "Never" }
        "Dim Display (AC)"          = if ($dimTimeout.AC -gt 0) { "$($dimTimeout.AC) sec" } else { "Never" }
        "Console Lock (AC)"        = if ($consoleLockTimeout.AC -gt 0) { "$($consoleLockTimeout.AC) sec" } else { "Never" }
        "Sleep (AC)"                = if ($sleepTimeout.AC -gt 0) { "$($sleepTimeout.AC) sec" } else { "Never" }
        "Hibernate (AC)"            = if ($hibernateTimeout.AC -gt 0) { "$($hibernateTimeout.AC) sec" } else { "Never" }
        "Unattended Sleep (AC)"    = if ($unattendTimeout.AC -gt 0) { "$($unattendTimeout.AC) sec" } else { "Never" }
        "Power Plan"                = if ($schemeName) { $schemeName } else { "Unknown" }
    }

    $summaryData | Format-List
    Write-Host ""
    #endregion

    #region Return Object
    return [PSCustomObject]@{
        MdmEnrolled                     = if ($intunePolicy) { $intunePolicy.MdmEnrolled } else { $null }
        AzureAdJoined                   = if ($intunePolicy) { $intunePolicy.AzureAdJoined } else { $null }
        DeployAuthority                  = if ($intunePolicy) { $intunePolicy.DeployAuthority } else { $null }
        EnrollmentSource                = if ($intunePolicy) { $intunePolicy.EnrollmentSource } else { $null }
        MdmUrl                          = if ($intunePolicy) { $intunePolicy.MdmUrl } else { $null }
        ProviderID                      = if ($intunePolicy) { $intunePolicy.ProviderID } else { $null }
        Upn                             = if ($intunePolicy) { $intunePolicy.Upn } else { $null }
        IntuneDeviceLockCSP             = if ($intunePolicy) { $intunePolicy.DeviceLockCSP } else { $null }
        IntuneAdmxDefaultPolicies       = if ($intunePolicy) { $intunePolicy.AdmxDefaultPolicies } else { $null }
        IntunePolicyEnforcedScreenSaver = if ($intunePolicy) { $intunePolicy.PolicyEnforcedScreenSaver } else { $null }
        IntuneRelevantPolicies          = if ($intunePolicy) { $intunePolicy.IntuneRelevantPolicies } else { $null }
        IntuneUserPolicies              = if ($intunePolicy) { $intunePolicy.IntuneUserPolicies } else { $null }
        IntuneUserAdmxPolicies         = if ($intunePolicy) { $intunePolicy.IntuneUserAdmxPolicies } else { $null }
        PolicyApplied                   = $policyApplied
        PolicySource                    = $policySource
        GPOInactivityTimeoutSec         = $gpoInactivity.InactivityTimeoutSecs
        InactivityLockSource            = $inactivityAttribution
        ScreenSaverEnabled              = $screenSaverActive
        ScreenSaverTimeoutSec           = $timeoutSec
        ScreenSaverSecure               = $isSecure
        ScreenSaverExe                  = $scrnExe
        ScreenSaverSource               = $screenSaverAttribution
        GpoScreenSaverHKCU              = $hkcuGpoFound
        GpoScreenSaverHKLM              = $hklmGpoFound
        DynamicLockDisabled             = $dynamicLockDisabled
        DisplayOffTimeoutAcSec          = $displayTimeout.AC
        DisplayOffTimeoutDcSec          = $displayTimeout.DC
        DimDisplayTimeoutAcSec          = $dimTimeout.AC
        DimDisplayTimeoutDcSec          = $dimTimeout.DC
        ConsoleLockTimeoutAcSec        = $consoleLockTimeout.AC
        ConsoleLockTimeoutDcSec        = $consoleLockTimeout.DC
        SleepTimeoutAcSec               = $sleepTimeout.AC
        SleepTimeoutDcSec               = $sleepTimeout.DC
        HibernateTimeoutAcSec          = $hibernateTimeout.AC
        HibernateTimeoutDcSec          = $hibernateTimeout.DC
        UnattendedSleepTimeoutAcSec    = $unattendTimeout.AC
        UnattendedSleepTimeoutDcSec    = $unattendTimeout.DC
        PowerPlanName                   = $schemeName
        PowerPlanGuid                   = $schemeGuid
    }
    #endregion
}
#endregion Get-SystemInactivityReport
Get-SystemInactivityReport -IncludeUserPolicies -Verbose