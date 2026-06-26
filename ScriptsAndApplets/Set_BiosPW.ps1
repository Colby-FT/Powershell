function Get-RandomString {
    [CmdletBinding()]
    param (
        [int]$length = 16
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
        $script:RandString = -join (1..$length | ForEach-Object { $chars | Get-Random })
    }
    End {
        Return $script:RandString
    }
}

function Set-DellBiosPasswords {
    [CmdletBinding()]
    param(
        [string]$NewPassword
    )
    
    try {
        Write-Output "Attempting to set Dell BIOS passwords via WMI..."
        
        $SecurityInterface = Get-CimInstance -Namespace root\dcim\sysman\wmisecurity -ClassName SecurityInterface -ErrorAction Stop
        
        if (-not $SecurityInterface) {
            Write-Output "ERROR: Could not connect to Dell SecurityInterface WMI class. This system may not support WMI-based BIOS management (requires 2018+ models)."
            return $false
        }
        
        # Set Admin (Supervisor) password - no existing password
        $adminResult = Invoke-CimMethod -InputObject $SecurityInterface -MethodName SetNewPassword -Arguments @{
            SecType = 0
            SecHndCount = 0
            SecHandle = [byte[]]@()
            NameId = "Admin"
            OldPassword = ""
            NewPassword = $NewPassword
        } -ErrorAction Stop
        
        if ($adminResult.ReturnValue -eq 0 -or $adminResult.ReturnValue -eq 4) {
            Write-Output "Admin password set successfully (or already set)."
        } else {
            Write-Output "WARNING: Admin password result code: $($adminResult.ReturnValue)"
        }
        
        # Set System (Power-On) password - requires admin password to be set first
        $encoder = New-Object System.Text.UTF8Encoding
        $bytes = $encoder.GetBytes($NewPassword)
        
        $systemResult = Invoke-CimMethod -InputObject $SecurityInterface -MethodName SetNewPassword -Arguments @{
            SecType = 1
            SecHndCount = $bytes.Length
            SecHandle = $bytes
            NameId = "System"
            OldPassword = ""
            NewPassword = $NewPassword
        } -ErrorAction Stop
        
        if ($systemResult.ReturnValue -eq 0) {
            Write-Output "System (Power-On) password set successfully."
            return $true
        } elseif ($systemResult.ReturnValue -eq 3) {
            Write-Output "Access denied. System password requires Admin password to be set first. Setting both in sequence..."
            
            # Re-set admin password first with proper authentication
            $adminResult2 = Invoke-CimMethod -InputObject $SecurityInterface -MethodName SetNewPassword -Arguments @{
                SecType = 0
                SecHndCount = 0
                SecHandle = [byte[]]@()
                NameId = "Admin"
                OldPassword = ""
                NewPassword = $NewPassword
            }
            
            Start-Sleep -Seconds 2
            
            # Now try system password again
            $systemResult2 = Invoke-CimMethod -InputObject $SecurityInterface -MethodName SetNewPassword -Arguments @{
                SecType = 1
                SecHndCount = $bytes.Length
                SecHandle = $bytes
                NameId = "System"
                OldPassword = ""
                NewPassword = $NewPassword
            }
            
            if ($systemResult2.ReturnValue -eq 0) {
                Write-Output "System (Power-On) password set successfully after admin password."
                return $true
            } else {
                Write-Output "ERROR: Failed to set system password. Return code: $($systemResult2.ReturnValue)"
                return $false
            }
        } else {
            Write-Output "ERROR: Failed to set system password. Return code: $($systemResult.ReturnValue)"
            return $false
        }
        
    } catch {
        Write-Output "ERROR: Exception setting Dell BIOS passwords: $_"
        return $false
    }
}

function Set-HPBiosPasswords {
    [CmdletBinding()]
    param(
        [string]$NewPassword
    )
    
    try {
        Write-Output "Attempting to set HP BIOS passwords via WMI..."
        
        # Check if Sure Admin is enabled (certificate-based auth replaces passwords)
        $SureAdmin = Get-CimInstance -Namespace root\hp\InstrumentedBIOS -ClassName HP_BIOSSetting | Where-Object { $_.Name -eq "Enhanced BIOS Authentication Mode" }
        if ($SureAdmin -and $SureAdmin.CurrentValue -eq "Enabled") {
            Write-Output "ERROR: HP Sure Admin is enabled. This replaces BIOS passwords with certificate-based auth. This script does not support Sure Admin."
            Write-Output "To manage this device, use HP's Sure Admin tooling or disable Sure Admin in BIOS."
            return $false
        }
        
        $Interface = Get-CimInstance -Namespace root\hp\InstrumentedBIOS -ClassName HP_BIOSSettingInterface -ErrorAction Stop
        
        if (-not $Interface) {
            Write-Output "ERROR: Could not connect to HP BIOS Setting Interface WMI class."
            return $false
        }
        
        # Set Setup Password (Admin)
        $setupResult = Invoke-CimMethod -InputObject $Interface -MethodName SetBIOSSetting -Arguments @{
            Name = "Setup Password"
            Value = "<utf-16/>$NewPassword"
            Password = "<utf-16/>"
        } -ErrorAction Stop
        
        if ($setupResult.ReturnValue -ne 0) {
            Write-Output "WARNING: Setup password result code: $($setupResult.ReturnValue)"
        } else {
            Write-Output "Setup (Admin) password set successfully."
        }
        
        Start-Sleep -Milliseconds 500
        
        # Set Power-On Password
        $powerOnResult = Invoke-CimMethod -InputObject $Interface -MethodName SetBIOSSetting -Arguments @{
            Name = "Power-On Password"
            Value = "<utf-16/>$NewPassword"
            Password = "<utf-16/>$NewPassword"  # Need current setup password to authorize
        } -ErrorAction Stop
        
        if ($powerOnResult.ReturnValue -eq 0) {
            Write-Output "Power-On password set successfully."
            return $true
        } elseif ($powerOnResult.ReturnValue -eq 6) {
            Write-Output "Access denied. Trying without authorization (no setup password exists yet)..."
            
            # Try without password authorization - first time setup
            $powerOnResult2 = Invoke-CimMethod -InputObject $Interface -MethodName SetBIOSSetting -Arguments @{
                Name = "Power-On Password"
                Value = "<utf-16/>$NewPassword"
                Password = "<utf-16/>"
            }
            
            if ($powerOnResult2.ReturnValue -eq 0) {
                Write-Output "Power-On password set successfully."
                return $true
            } else {
                Write-Output "ERROR: Failed to set Power-On password. Return code: $($powerOnResult2.ReturnValue)"
                return $false
            }
        } else {
            Write-Output "ERROR: Failed to set Power-On password. Return code: $($powerOnResult.ReturnValue)"
            return $false
        }
        
    } catch {
        Write-Output "ERROR: Exception setting HP BIOS passwords: $_"
        return $false
    }
}

function Set-LenovoBiosPasswords {
    [CmdletBinding()]
    param(
        [string]$NewPassword
    )
    
    try {
        Write-Output "Attempting to set Lenovo BIOS passwords via WMI..."
        
        # Check password state
        $PasswordSettings = Get-CimInstance -Namespace root\wmi -ClassName Lenovo_BiosPasswordSettings -ErrorAction Stop
        
        if (-not $PasswordSettings) {
            Write-Output "ERROR: Could not connect to Lenovo BIOS Password Settings WMI class."
            return $false
        }
        
        # Check if certificate-based auth is in use (value 128)
        if ($PasswordSettings.PasswordState -eq 128) {
            Write-Output "ERROR: Certificate-based authentication is in use. This script does not support certificate-based BIOS management."
            return $false
        }
        
        $PasswordSet = Get-CimInstance -Namespace root\wmi -ClassName Lenovo_SetBiosPassword -ErrorAction Stop
        
        if (-not $PasswordSet) {
            Write-Output "ERROR: Could not connect to Lenovo Set Bios Password WMI class."
            return $false
        }
        
        # Determine current state
        $state = $PasswordSettings.PasswordState
        $hasSupervisor = ($state -band 2) -eq 2
        $hasPowerOn = ($state -band 1) -eq 1
        
        Write-Output "Current state: Supervisor=$hasSupervisor, PowerOn=$hasPowerOn"
        
        if (-not $hasSupervisor) {
            Write-Output ""
            Write-Output "=============================================="
            Write-Output "CRITICAL LIMITATION FOR LENOVO:"
            Write-Output "The FIRST supervisor password cannot be set programmatically."
            Write-Output "You must manually set a supervisor password in BIOS ONE TIME,"
            Write-Output "or boot into System Deployment Boot Mode (SDBM) at startup."
            Write-Output "=============================================="
            Write-Output ""
            Write-Output "Attempting to set Power-On password only (if supervisor already exists)..."
            
            # Try to set Power-On password - requires supervisor password authorization
            # Without supervisor set, we can't do anything programmatically
            if (-not $hasPowerOn) {
                Write-Output "ERROR: Cannot set Power-On password without a supervisor password already in place."
                Write-Output "Please manually set a supervisor password in BIOS, then re-run this script."
                return $false
            }
        }
        
        # Set/Change Supervisor Password (if one already exists)
        if ($hasSupervisor) {
            # We need the current supervisor password - use the new one as we're changing it
            Write-Output "Changing supervisor password..."
            $supervisorResult = Invoke-CimMethod -InputObject $PasswordSet -MethodName SetBiosPassword -Arguments @{
                parameter = "pap,$NewPassword,$NewPassword,ascii,us"
            }
            
            if ($supervisorResult.Return -eq 0) {
                Write-Output "Supervisor password set/changed successfully."
            } else {
                Write-Output "WARNING: Supervisor password result code: $($supervisorResult.Return)"
            }
        }
        
        Start-Sleep -Milliseconds 500
        
        # Set Power-On Password
        # If supervisor exists, use it to authorize; otherwise attempt without
        if ($hasSupervisor) {
            $powerOnResult = Invoke-CimMethod -InputObject $PasswordSet -MethodName SetBiosPassword -Arguments @{
                parameter = "pop,$NewPassword,$NewPassword,ascii,us"
            }
        } else {
            # Try without authorization - might work if no passwords set
            $powerOnResult = Invoke-CimMethod -InputObject $PasswordSet -MethodName SetBiosPassword -Arguments @{
                parameter = "pop,,$NewPassword,ascii,us"
            }
        }
        
        if ($powerOnResult.Return -eq 0) {
            Write-Output "Power-On password set successfully."
            return $true
        } else {
            Write-Output "WARNING: Power-On password result code: $($powerOnResult.Return)"
            # Note: For Lenovo, the power-on password change is validated at reboot, not immediately
            if ($powerOnResult.Return -eq 0 -or $powerOnResult.Return -eq 2) {
                Write-Output "Power-On password operation submitted (will be validated at next reboot)."
                return $true
            }
            return $false
        }
        
    } catch {
        Write-Output "ERROR: Exception setting Lenovo BIOS passwords: $_"
        return $false
    }
}

function Set-SurfaceBiosPasswords {
    [CmdletBinding()]
    param(
        [string]$NewPassword
    )
    
    Write-Output ""
    Write-Output "=============================================="
    Write-Output "MICROSOFT SURFACE LIMITATION:"
    Write-Output "Surface devices do not support setting UEFI passwords"
    Write-Output "programmatically via WMI like Dell/HP/Lenovo."
    Write-Output ""
    Write-Output "Options for Surface devices:"
    Write-Output "1. Use Surface IT Toolkit with UEFI Configurator"
    Write-Output "2. Enroll in DFCI (Device Firmware Configuration Interface)"
    Write-Output "   via Microsoft Intune - this ELIMINATES the need for"
    Write-Output "   passwords (uses certificate-based auth)"
    Write-Output "3. Set password manually in UEFI (boot with Volume-Up + Power)"
    Write-Output "=============================================="
    Write-Output ""
    
    # Check if Surface IT Toolkit assemblies are available
    try {
        $surfaceAssembly = [Reflection.Assembly]::LoadWithPartialName("Microsoft.Surface.FirmwareOption")
        if ($surfaceAssembly) {
            Write-Output "Surface FirmwareOption assembly found. Attempting alternative method..."
            
            # This may work on some Surface models
            # Note: This is a best-effort - not all models support this
            try {
                $firmwareOption = New-Object Microsoft.Surface.FirmwareOption.FirmwareOptionManager
                # Methods vary by model - this is framework-only demonstration
                Write-Output "Surface FirmwareOption available but specific password methods not pre-loaded."
            } catch {
                # Ignore - just informational
            }
        }
    } catch {
        # Assembly not available - this is expected
    }
    
    # Check if enrolled in DFCI (zero-touch management)
    try {
        $DFCI = Get-CimInstance -Namespace root\Microsoft\Surface -ClassName DFCI_Enrollment -ErrorAction SilentlyContinue
        if ($DFCI -and $DFCI.State -eq "Enabled") {
            Write-Output ""
            Write-Output "Device IS enrolled in DFCI - no password needed!"
            Write-Output "DFCI provides certificate-based UEFI management."
            return $true
        }
    } catch {
        # WMI class may not exist
    }
    
    return $false
}

# ============================================
# MAIN SCRIPT EXECUTION
# ============================================

Write-Output "================================================"
Write-Output "BIOS Password Set Script"
Write-Output "================================================"
Write-Output ""

# Detect manufacturer
$ComputerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
$Manufacturer = $ComputerSystem.Manufacturer

Write-Output "Detected Manufacturer: $Manufacturer"

# Generate random password
$Password = Get-RandomString -length 16
Write-Output "Generated Password: $Password"
Write-Output ""

$success = $false

# Route to appropriate vendor function
switch -Regex ($Manufacturer) {
    "Dell" {
        Write-Output ">>> Processing DELL system <<<"
        $success = Set-DellBiosPasswords -NewPassword $Password
    }
    "HP|Hewlett" {
        Write-Output ">>> Processing HP system <<<"
        $success = Set-HPBiosPasswords -NewPassword $Password
    }
    "Lenovo" {
        Write-Output ">>> Processing LENOVO system <<<"
        $success = Set-LenovoBiosPasswords -NewPassword $Password
    }
    "Microsoft|Surface" {
        Write-Output ">>> Processing MICROSOFT SURFACE system <<<"
        $success = Set-SurfaceBiosPasswords -NewPassword $Password
    }
    Default {
        Write-Output "ERROR: Unsupported manufacturer: $Manufacturer"
        Write-Output "Supported manufacturers: Dell, HP, Lenovo, Microsoft Surface"
    }
}

Write-Output ""

# Store password in registry for retrieval (Datto RMM can read this)
if ($success -or ($Manufacturer -match "Surface|Lenovo")) {
    # For informational purposes, store the generated password
    # This allows recovery if needed - in production you may want to encrypt this
    $regPath = "HKLM:\SOFTWARE\Centrastage"
    
    # Use the UDF variable from Datto RMM
    if ($env:udf_27) {
        $udfProperty = "custom$env:udf_27"
        try {
            New-ItemProperty -Path $regPath -Name $udfProperty -PropertyType String -Value $Password -Force | Out-Null
            Write-Output "Password stored in registry for Datto RMM retrieval: $udfProperty"
        } catch {
            Write-Output "WARNING: Could not store password in registry: $_"
        }
    }
}

Write-Output ""
Write-Output "================================================"
if ($success) {
    Write-Output "RESULT: Passwords configured successfully!"
    Write-Output "Password set: $Password"
} else {
    Write-Output "RESULT: Password configuration completed with warnings or errors."
    Write-Output "Please review the output above."
}
Write-Output "================================================"

# Optional: Trigger a restart to apply changes (especially for Dell)
# Uncomment the following lines if you want automatic restart
# Write-Output ""
# Write-Output "Restarting computer in 30 seconds to apply BIOS changes..."
# Start-Sleep -Seconds 30
# Restart-Computer -Force
