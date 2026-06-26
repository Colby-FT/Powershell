function Uninstall-WithUninstallString {
    <#
    .SYNOPSIS
        Uninstall an application using the uninstall string from the registry
    
    .DESCRIPTION
        Searches the registry for an uninstall string for the specified app. Cleans up 
        the uninstall string and adds silent flags. Then uninstalls the app with robust 
        error handling and validation.
        If multiple matches are found for the specified app name, the function will 
        attempt to uninstall each matching application one at a time.
    
    .PARAMETER AppName
        The name of the application to uninstall. Can be partial name match.
    
    .PARAMETER UninstallTimeout
        Timeout in seconds for the uninstall process. Default is 300 seconds (5 minutes).
    
    .PARAMETER VerifyUninstall
        If specified, verifies the application was actually removed after uninstall.
    
    .EXAMPLE
        Uninstall-WithUninstallString -AppName "TeamViewer"
        Uninstalls TeamViewer silently
    
    .EXAMPLE
        Uninstall-WithUninstallString -AppName "Adobe" -VerifyUninstall
        Uninstalls all Adobe apps and verifies removal
    
    .NOTES
        Be careful providing partial application names. If multiple applications match 
        the provided AppName, the function will process each uninstall string individually.
        Requires administrator privileges for most uninstallations.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [string]$AppName,
        
        [Parameter()]
        [int]$UninstallTimeout = 300,
        
        [switch]$VerifyUninstall
    )
    
    Begin {
        Write-Verbose "Starting: $($MyInvocation.MyCommand.Name)"
        
        # Registry paths to search (both 64-bit and 32-bit)
        $RegPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
        )
        
        # Track uninstall results
        $UninstallResults = @()
    }
    
    Process {
        foreach ($RegPath in $RegPaths) {
            if (Test-Path $RegPath) {
                Write-Verbose "Searching: $RegPath"
                
                Get-ChildItem -LiteralPath $RegPath -ErrorAction SilentlyContinue | ForEach-Object {
                    try {
                        $RegItem = Get-ItemProperty -LiteralPath $_.PsPath -ErrorAction Stop
                    }
                    catch {
                        Write-Verbose "Could not read registry item: $($_.Exception.Message)"
                        return
                    }
                    
                    # Match by display name
                    if ($RegItem.DisplayName -and $RegItem.DisplayName -match [regex]::Escape($AppName)) {
                        Write-Host "Found match: $($RegItem.DisplayName)" -ForegroundColor Cyan
                        
                        $UninstallString = $RegItem.UninstallString
                        $QuietUninstallString = $RegItem.QuietUninstallString
                        $InstallLocation = $RegItem.InstallLocation
                        $DisplayVersion = $RegItem.DisplayVersion
                        
                        # Store info for validation
                        $AppInfo = @{
                            DisplayName = $RegItem.DisplayName
                            UninstallString = $UninstallString
                            QuietUninstallString = $QuietUninstallString
                            InstallLocation = $InstallLocation
                            Version = $DisplayVersion
                            RegistryPath = $_.PsPath
                            Success = $false
                            Error = $null
                        }
                        
                        if ($UninstallString -or $QuietUninstallString) {
                            # Use quiet uninstall string if available
                            $CommandToRun = if ($QuietUninstallString) { $QuietUninstallString } else { $UninstallString }
                            
                            Write-Host "Uninstall string: $CommandToRun" -ForegroundColor Gray
                            
                            # ===== IMPROVEMENT 1: Validate and fix the uninstall command =====
                            $CommandToRun = Invoke-CommandValidation -UninstallString $CommandToRun
                            
                            if (-not $CommandToRun) {
                                $AppInfo.Error = "Unable to construct valid uninstall command"
                                $UninstallResults += $AppInfo
                                return
                            }
                            
                            # ===== IMPROVEMENT 2: Execute with proper error handling =====
                            $Result = Invoke-UninstallExecution -UninstallString $CommandToRun -Timeout $UninstallTimeout
                            
                            $AppInfo.Success = $Result.Success
                            $AppInfo.Error = $Result.Error
                            
                            if ($Result.Success) {
                                Write-Host "Uninstall command executed successfully for $($RegItem.DisplayName)" -ForegroundColor Green
                            }
                            else {
                                Write-Host "Uninstall failed for $($RegItem.DisplayName): $($Result.Error)" -ForegroundColor Red
                            }
                            
                            # ===== IMPROVEMENT 3: Verify uninstall if requested =====
                            if ($VerifyUninstall -and $Result.Success) {
                                $Verification = Test-ApplicationUninstalled -AppName $RegItem.DisplayName -InstallLocation $InstallLocation
                                
                                if ($Verification) {
                                    Write-Host "Verification PASSED: $($RegItem.DisplayName) has been removed" -ForegroundColor Green
                                }
                                else {
                                    Write-Host "Verification FAILED: $($RegItem.DisplayName) may still be installed" -ForegroundColor Yellow
                                    # Note: This doesn't change Success to false since the uninstaller ran
                                }
                            }
                        }
                        else {
                            $AppInfo.Error = "No uninstall string found in registry"
                            Write-Host "No uninstall string found for: $($RegItem.DisplayName)" -ForegroundColor Yellow
                        }
                        
                        $UninstallResults += $AppInfo
                        Write-Host ("-" * 60) -ForegroundColor Gray
                    }
                }
            }
        }
    }
    
    End {
        # Summary output
        $TotalFound = $UninstallResults.Count
        $TotalSuccessful = ($UninstallResults | Where-Object { $_.Success }).Count
        $TotalFailed = ($UninstallResults | Where-Object { -not $_.Success -and $_.Error }).Count
        
        Write-Host "`n========== Uninstall Summary ==========" -ForegroundColor Cyan
        Write-Host "Applications found: $TotalFound"
        Write-Host "Successfully executed: $TotalSuccessful" -ForegroundColor Green
        if ($TotalFailed -gt 0) {
            Write-Host "Failed: $TotalFailed" -ForegroundColor Red
        }
        Write-Host "========================================`n" -ForegroundColor Cyan
        
        # Return results for pipeline use
        return $UninstallResults
    }
}

# ===== Helper Function: Validate and fix uninstall command =====
function Invoke-CommandValidation {
    <#
    .SYNOPSIS
        Validates and fixes an uninstall string to ensure it can be executed properly
    
    .DESCRIPTION
        Checks if the uninstall command is complete, detects if it's a PowerShell command,
        validates the executable path exists, and applies necessary fixes
    
    .PARAMETER UninstallString
        The raw uninstall string from the registry
    
    .OUTPUTS
        Validated and fixed uninstall string
    #>
    param (
        [Parameter(Mandatory)]
        [string]$UninstallString
    )
    
    Write-Verbose "Validating uninstall string: $UninstallString"
    
    # Trim whitespace
    $UninstallString = $UninstallString.Trim()
    
    if ([string]::IsNullOrWhiteSpace($UninstallString)) {
        Write-Warning "Uninstall string is empty"
        return $null
    }
    
    # Check if it's wrapped in quotes that need removal
    # Pattern: "path/to/exe" args -> need to extract exe path
    if ($UninstallString -match '^"([^"]+)"\s*(.*)$') {
        $ExePath = $Matches[1]
        $Args = $Matches[2]
        
        Write-Verbose "Detected quoted executable path: $ExePath"
        Write-Verbose "Arguments: $Args"
        
        # ===== Check 1: Verify file exists =====
        if (-not (Test-Path -LiteralPath $ExePath -ErrorAction SilentlyContinue)) {
            # Try without quotes in case the path got double-quoted
            $UnquotedPath = $ExePath -replace '^"|"=$', ''
            if (-not (Test-Path -LiteralPath $UnquotedPath -ErrorAction SilentlyContinue)) {
                Write-Warning "Executable not found: $ExePath"
                Write-Warning "This is likely why the uninstall failed previously"
                
                # Try to find the executable in common locations
                $FileName = [System.IO.Path]::GetFileName($ExePath)
                $FoundPath = Get-ChildItem -Path "C:\Program Files", "C:\Program Files (x86)" -Filter $FileName -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                
                if ($FoundPath) {
                    Write-Host "Found executable at alternative location: $($FoundPath.FullName)" -ForegroundColor Yellow
                    if ($Args) {
                        return "`"$($FoundPath.FullName)`" $Args"
                    }
                    else {
                        return "`"$($FoundPath.FullName)`""
                    }
                }
                
                return $null
            }
        }
        
        # If we get here, original path is valid
        return $UninstallString
    }
    
    # Check if it's a PowerShell command (starts with powershell.exe, msiexec, or has special patterns)
    if ($UninstallString -match '^powershell\.exe' -or $UninstallString -match '^msiexec' -or 
        $UninstallString -match 'powershell\s+-Command' -or $UninstallString -match 'msiexec\.exe') {
        Write-Verbose "Detected MSI or PowerShell installer"
        
        # Validate msiexec paths
        if ($UninstallString -match 'msiexec') {
            # Extract MSI path if present
            if ($UninstallString -match '/i\s*\{[A-F0-9\-]+\}' -or $UninstallString -match '/x\s*\{[A-F0-9\-]+\}') {
                Write-Verbose "Valid MSI product code detected"
            }
        }
        
        return $UninstallString
    }
    
    # Check if it's a cmd.exe style command
    if ($UninstallString -match '^cmd\.exe\s+/c' -or $UninstallString -match '^\/c\s+') {
        return $UninstallString
    }
    
    # Check if it's missing the executable path entirely (just has arguments)
    # This is rare but happens with some installers
    if ($UninstallString -match '^/[-/]') {
        Write-Warning "Uninstall string appears to be missing the executable path"
        Write-Warning "Raw string: $UninstallString"
        
        # Can't reliably fix this - return as-is and let it fail with clear error
        return $UninstallString
    }
    
    # If it looks like a relative path or starts with a drive letter
    if ($UninstallString -match '^[A-Za-z]:\\' -or $UninstallString -match '^[^\\]') {
        # Extract the executable part (everything before first space or before / -)
        $Parts = $UninstallString -split '\s+', 2
        $ExePath = $Parts[0]
        
        # Check if executable exists
        if (-not (Test-Path -LiteralPath $ExePath -ErrorAction SilentlyContinue)) {
            Write-Warning "Executable not found: $ExePath"
            
            # Try to resolve via PATH environment
            $FileName = [System.IO.Path]::GetFileName($ExePath)
            $FullPath = Get-Command $FileName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
            
            if ($FullPath) {
                Write-Verbose "Found in PATH: $FullPath"
                if ($Parts[1]) {
                    return "$FullPath $($Parts[1])"
                }
                return $FullPath
            }
        }
    }
    
    Write-Verbose "Command validation complete: $UninstallString"
    return $UninstallString
}

# ===== Helper Function: Execute uninstall with proper error handling =====
function Invoke-UninstallExecution {
    <#
    .SYNOPSIS
        Executes an uninstall command with proper error capture and handling
    
    .DESCRIPTION
        Attempts to run the uninstall command using multiple methods to maximize 
        success chance. Captures both stdout and stderr for debugging.
    
    .PARAMETER UninstallString
        The validated uninstall string to execute
    
    .PARAMETER Timeout
        Maximum time to wait for uninstall to complete
    
    .OUTPUTS
        Hashtable with Success and Error properties
    #>
    param (
        [Parameter(Mandatory)]
        [string]$UninstallString,
        
        [int]$Timeout = 300
    )
    
    $Result = @{
        Success = $false
        Error = $null
    }
    
    Write-Verbose "Attempting to execute: $UninstallString"
    
    # Check if it's an MSI package
    if ($UninstallString -match 'msiexec\.?exe?') {
        Write-Verbose "Detected MSI package - using msiexec handling"
        
        # Build MSI arguments
        $MsiArgs = $UninstallString -replace '.*msiexec\.?exe?\s*', ''
        
        # Ensure silent flags
        if ($MsiArgs -notmatch '/qn' -and $MsiArgs -notmatch '/quiet' -and $MsiArgs -notmatch '/q') {
            $MsiArgs += ' /qn /norestart'
        }
        
        Write-Host "Running: msiexec.exe $MsiArgs" -ForegroundColor Gray
        
        try {
            # Use Start-Process with redirection for error capture
            $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
            $ProcessInfo.FileName = "msiexec.exe"
            $ProcessInfo.Arguments = $MsiArgs
            $ProcessInfo.UseShellExecute = $false
            $ProcessInfo.RedirectStandardOutput = $true
            $ProcessInfo.RedirectStandardError = $true
            $ProcessInfo.CreateNoWindow = $true
            
            $Process = New-Object System.Diagnostics.Process
            $Process.StartInfo = $ProcessInfo
            
            $Process.Start() | Out-Null
            
            # Wait with timeout
            $Completed = $Process.WaitForExit($Timeout * 1000)
            
            $StdOut = $Process.StandardOutput.ReadToEnd()
            $StdErr = $Process.StandardError.ReadToEnd()
            
            if (-not $Completed) {
                $Process.Kill()
                $Result.Error = "MSI uninstall timed out after $Timeout seconds"
                Write-Warning $Result.Error
                return $Result
            }
            
            $ExitCode = $Process.ExitCode
            
            if ($ExitCode -eq 0) {
                $Result.Success = $true
                Write-Verbose "MSI uninstall completed successfully (Exit code: 0)"
            }
            elseif ($ExitCode -eq 3010) {
                $Result.Success = $true
                $Result.Error = "Success but reboot required (Exit code: 3010)"
                Write-Warning "Reboot required to complete uninstallation"
            }
            else {
                $Result.Error = "MSI failed with exit code: $ExitCode"
                if ($StdErr) {
                    $Result.Error += " | Stderr: $StdErr"
                }
                if ($StdOut) {
                    $Result.Error += " | Stdout: $StdOut"
                }
                Write-Warning $Result.Error
            }
            
            return $Result
        }
        catch {
            $Result.Error = "Exception during MSI uninstall: $_"
            Write-Warning $Result.Error
            return $Result
        }
    }
    
    # For non-MSI executables, try multiple execution methods
    $ExecutionMethods = @()
    
    # Method 1: Direct execution with Start-Process (current method but with better error handling)
    if ($UninstallString -match '^"([^"]+)"\s*(.*)$') {
        $ExecutionMethods += @{
            Name = "Direct quoted executable"
            ScriptBlock = {
                param($Exe, $Args, $TimeoutSec)
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = $Exe
                $psi.Arguments = $Args
                $psi.UseShellExecute = $false
                $psi.RedirectStandardOutput = $true
                $psi.RedirectStandardError = $true
                $psi.CreateNoWindow = $true
                
                $proc = [System.Diagnostics.Process]::Start($psi)
                $completed = $proc.WaitForExit($TimeoutSec * 1000)
                
                if (-not $completed) {
                    $proc.Kill()
                    throw "Process timed out"
                }
                
                $stdout = $proc.StandardOutput.ReadToEnd()
                $stderr = $proc.StandardError.ReadToEnd()
                
                if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) {
                    throw "Exit code: $($proc.ExitCode), Stderr: $stderr"
                }
                
                return @{ ExitCode = $proc.ExitCode; StdOut = $stdout; StdErr = $stderr }
            }
        }
    }
    
    # Method 2: Wrap with cmd /c
    $ExecutionMethods += @{
        Name = "CMD /c wrapper"
        ScriptBlock = {
            param($Cmd, $TimeoutSec)
            
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "cmd.exe"
            $psi.Arguments = "/c $Cmd"
            $psi.UseShellExecute = $false
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.CreateNoWindow = $true
            
            $proc = [System.Diagnostics.Process]::Start($psi)
            $completed = $proc.WaitForExit($TimeoutSec * 1000)
            
            if (-not $completed) {
                $proc.Kill()
                throw "Process timed out"
            }
            
            $stdout = $proc.StandardOutput.ReadToEnd()
            $stderr = $proc.StandardError.ReadToEnd()
            
            if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) {
                throw "Exit code: $($proc.ExitCode), Stderr: $stderr"
            }
            
            return @{ ExitCode = $proc.ExitCode; StdOut = $stdout; StdErr = $stderr }
        }
    }
    
    # Method 3: Try with Start-Process with different argument handling
    $ExecutionMethods += @{
        Name = "Start-Process no window"
        ScriptBlock = {
            param($Cmd, $TimeoutSec)
            
            # Try Start-Process with -Wait
            try {
                $output = @{
                    ExitCode = -1
                    StdOut = ""
                    StdErr = ""
                }
                
                # Try with common silent flags
                $silentFlags = @("", "/S", "/s", "/silent", "/quiet")
                
                foreach ($flag in $silentFlags) {
                    $fullArgs = if ($flag) { "$Cmd $flag" } else { $Cmd }
                    
                    $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $fullArgs" -Wait -PassThru -NoNewWindow -ErrorAction Stop
                    
                    if ($proc.ExitCode -in @(0, 3010)) {
                        $output.ExitCode = $proc.ExitCode
                        return $output
                    }
                }
                
                throw "All silent flags failed"
            }
            catch {
                throw $_
            }
        }
    }
    
    # Try each method
    foreach ($Method in $ExecutionMethods) {
        Write-Verbose "Trying: $($Method.Name)"
        
        try {
            $Output = & $Method.ScriptBlock -Exe $ExePath -Args $Args -Cmd $UninstallString -TimeoutSec $Timeout
            
            $Result.Success = $true
            Write-Verbose "Success with method: $($Method.Name)"
            return $Result
        }
        catch {
            Write-Verbose "Method failed: $($Method.Name) - $_"
            continue
        }
    }
    
    # If we get here, all methods failed
    $Result.Error = "All execution methods failed. Last error: $_"
    Write-Warning $Result.Error
    
    return $Result
}

# ===== Helper Function: Verify application was actually uninstalled =====
function Test-ApplicationUninstalled {
    <#
    .SYNOPSIS
        Verifies that an application has been successfully uninstalled
    
    .DESCRIPTION
        Checks registry locations and optionally the install location to verify
        the application is no longer present
    
    .PARAMETER AppName
        Name of the application to check
    
    .PARAMETER InstallLocation
        The install location from the registry (optional but speeds up verification)
    
    .OUTPUTS
        Boolean indicating if the app was successfully removed
    #>
    param (
        [Parameter(Mandatory)]
        [string]$AppName,
        
        [string]$InstallLocation
    )
    
    Write-Verbose "Verifying uninstall for: $AppName"
    
    # Check registry for the application
    $RegSearchPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    
    foreach ($Path in $RegSearchPaths) {
        if (Test-Path $Path) {
            $Matches = Get-ChildItem -LiteralPath $Path -ErrorAction SilentlyContinue | 
                       Get-ItemProperty -ErrorAction SilentlyContinue | 
                       Where-Object { $_.DisplayName -match [regex]::Escape($AppName) }
            
            if ($Matches) {
                Write-Verbose "Found registry entry - uninstall may not have completed"
                return $false
            }
        }
    }
    
    # Check if install location still exists and has content
    if ($InstallLocation -and (Test-Path $InstallLocation)) {
        $Contents = Get-ChildItem -LiteralPath $InstallLocation -ErrorAction SilentlyContinue
        if ($Contents) {
            Write-Verbose "Install location still contains files - uninstall may be incomplete"
            # Note: Some applications leave some files behind - this is a soft check
        }
    }
    
    # Check if the executable is still accessible
    $CommonExeNames = @("$AppName.exe", "$AppName*")
    
    # Check in Program Files
    $ProgramPaths = @(
        "C:\Program Files",
        "C:\Program Files (x86)"
    )
    
    foreach ($BasePath in $ProgramPaths) {
        if (Test-Path $BasePath) {
            $Found = Get-ChildItem -LiteralPath $BasePath -Filter "*$AppName*" -ErrorAction SilentlyContinue -Recurse
            if ($Found) {
                Write-Verbose "Found matching files in $BasePath - uninstall may not be complete"
                return $false
            }
        }
    }
    
    # Check running processes
    $RunningProcess = Get-Process -Name "*$AppName*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($RunningProcess) {
        Write-Verbose "Application process is still running: $($RunningProcess.Name)"
        return $false
    }
    
    Write-Verbose "Verification complete: Application appears to be removed"
    return $true
}