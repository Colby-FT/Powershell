function Uninstall-WithUninstallString {
    <#
    .SYNOPSIS
    Uninstall an application using the uninstall string from the registry
    
    .DESCRIPTION
    Searches the registry for an uninstall string for the specified app. Cleans up the uninstall string and adds silent flags. Then uninstalls the app
    
    .PARAMETER AppName

    .EXAMPLE
    Uninstall-WithUninstallString -AppName "TeamViewer"
    Uninstalls TeamViewer

    #>
    [CmdletBinding()]
    param (
        [string]$AppName
    )
    Begin {
        $RegPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        )
    }
    Process {
        foreach ($RegPath in $RegPaths) {
            if (Test-Path $RegPath) {
                Get-ChildItem -LiteralPath $RegPath | ForEach-Object { 
                    Get-ItemProperty -LiteralPath $_.PsPath | ForEach-Object { 
                        if ($_.DisplayName -match $AppName) { 
                            $UninstallString = $_.UninstallString
                            if ($UninstallString) {
                                try {
                                    if ($UninstallString -match 'msiexec') {
                                        $UninstallString = $UninstallString -replace 'msiexec.exe .*{', '/Uninstall {'
                                        $UninstallString += ' /qn /norestart'
                                        Write-Output "Running: msiexec.exe $UninstallString"
                                        Start-Process -FilePath msiexec.exe -ArgumentList $UninstallString -Wait
                                    } else {
                                        $SilentFlags = @("/S", "/quiet", "/qn", "/silent")
                                        $SilentSuccess = $false
                                        foreach ($Flag in $SilentFlags) {
                                            Write-Output "Trying: $UninstallString $Flag"
                                            try {
                                                $Process = Start-Process -FilePath $UninstallString -ArgumentList $Flag -ErrorAction Stop -PassThru
                                                $Timeout = 300 # Timeout in seconds (5 minutes)
                                                $Elapsed = 0
                                                while (-not $Process.HasExited -and $Elapsed -lt $Timeout) {
                                                    Start-Sleep -Seconds 1
                                                    $Elapsed++
                                                }
                                                if (-not $Process.HasExited) {
                                                    Write-Output "Process exceeded timeout. Terminating process."
                                                    $Process.Kill()
                                                    Write-Output "Silent flag $Flag caused the process to hang and was terminated. Trying next flag."
                                                    continue
                                                }
                                                Write-Output "Silent uninstallation process completed for $AppName using flag: $Flag."
                                                $SilentSuccess = $true
                                                break
                                            } catch {
                                                Write-Output "Silent flag $Flag failed: $_"
                                            }
                                        }
                                        if (-not $SilentSuccess) {
                                            Write-Output "Common silent uninstall flags did not work. Please try uninstalling interactively."
                                        }
                                    }
                                    Write-Output "Silent uninstallation process completed for $AppName."
                                } catch {
                                    Write-Output "Error during uninstallation: $_"
                                }
                            } else {
                                Write-Output "Uninstall string not found for $AppName."
                            }
                        } 
                    }
                }
            }
        }
    }
}