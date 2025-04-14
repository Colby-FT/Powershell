function Get-WindowsPatchStatus {
    <#
    .SYNOPSIS
    Retrieves the Windows patch status, including OS version, build number, last update check, and last patch installed.

    .DESCRIPTION
    This function gathers information about the Windows operating system and its update status. It retrieves the OS version, build number, the last time Windows Update was checked, and details about the most recent patch installed.

    .PARAMETER None
    This function does not take any parameters.

    .EXAMPLE
    PS> Get-WindowsPatchStatus
    Hostname: MYCOMPUTER
    OS Version: 10.0.19044
    OS Build Number: 19044
    Last Windows Update check was run on: 3/15/2023 10:00:00 AM
    Last Windows Patch ID KB5021234 was installed on: 3/10/2023

    Retrieves and displays the patch status of the local Windows machine.
    #>
    [CmdletBinding()]
    param ()

    Begin {
        $ReturnValue = [PSCustomObject]@{
            Hostname               = $env:COMPUTERNAME
            OSVersion              = $null
            OSBuildNumber          = $null
            LastUpdateCheck        = $null
            LastPatchID            = $null
            LastPatchInstalledDate = $null
        }
    }
    Process {
        try {
            # Get the OS version and build number
            $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
            $ReturnValue.OSVersion = $osInfo.Version
            $ReturnValue.OSBuildNumber = $osInfo.BuildNumber
        }
        catch {
            Write-Error "Failed to retrieve OS information. Ensure you have the necessary permissions."
            return
        }

        try {
            # Get the last time Windows Update was run
            $updateSession = New-Object -ComObject Microsoft.Update.Session
            $updateSearcher = $updateSession.CreateUpdateSearcher()
            $lastUpdateRun = $updateSearcher.QueryHistory(0, 1) | Select-Object -First 1
            $ReturnValue.LastUpdateCheck = $lastUpdateRun.Date
        }
        catch {
            Write-Error "Failed to retrieve Windows Update history. Ensure you have the necessary permissions."
            return
        }

        try {
            # Get the most recent Windows Patch information
            $lastPatch = Get-CimInstance -Query "SELECT * FROM Win32_QuickFixEngineering" |
                         Sort-Object -Property InstalledOn -Descending |
                         Select-Object -First 1
            $ReturnValue.LastPatchID = $lastPatch.HotFixID
            $ReturnValue.LastPatchInstalledDate = $lastPatch.InstalledOn
        }
        catch {
            Write-Error "Failed to retrieve Windows Patch information. Ensure you have the necessary permissions."
            return
        }
    }
    End {
        return $ReturnValue
    }
}
