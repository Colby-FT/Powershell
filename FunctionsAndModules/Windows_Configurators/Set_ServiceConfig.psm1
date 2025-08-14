function Set-ServiceConfig {
    <#
	.SYNOPSIS
	Change service settings
	
	.DESCRIPTION
    Change the startup type, recovery actions, and current running status of services.
    The default is to set the services to Automatic, restart three times, and Running.
	
	.PARAMETER ServiceName
	Looks for a string from the input. Name of the desired service to set.
	.PARAMETER Recover
	Default is "restart". Accepts "restart" "noaction" or "reboot"
	.PARAMETER Status
	Default is "start". Accepts "start" or "stop"
	.PARAMETER Startup
	Default is "automatic". Accepts "automatic" "manual" or "disabled"
	
	.EXAMPLE
	Set-ServiceConfig -ServiceName TrustedInstaller
    Configures default settings for Windows Modules Installer
    .EXAMPLE
    Set-ServiceConfig -ServiceName TrustedInstaller -Recover noaction -Status stop -Startup manual
    Configures Windows Modules Installer to take no recovery action, stop running, and require manual start-up.
    .EXAMPLE
    Get-Service -Name "xb*" | foreach $_.name {Set-ServiceConfig $_.name -Recover noaction -Status stop -Startup manual}
    Set all xBox services to take no recovery action, stop running, and require manual start-up.
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)] 
        [string[]] $ServiceName,
        [ValidateSet("restart", "noaction", "reboot", IgnoreCase=$True)]
        [string]$Recover = "restart",
        [ValidateSet("start", "stop", IgnoreCase=$True)]
        [string]$Status = "start",
        [ValidateSet("automatic", "manual", "disabled", IgnoreCase=$True)]
        [string]$Startup = "automatic"
    )
    BEGIN {
        $PauseTimeMilliSeconds = 30000
        if ($Recover -eq "restart") {
            $resetCounter = 4000
            $action = "restart"+"/"+$PauseTimeMilliSeconds+"/"+"restart"+"/"+$PauseTimeMilliSeconds+"/"+"restart"+"/"+$PauseTimeMilliSeconds
        }
        elseif ($Recover -eq "noaction") {
            $resetCounter = 4000
            $action = '//////'
        }
        elseif ($Recover -eq "reboot") {
            $resetCounter = 4000
            $action = "reboot"+"/"+$PauseTimeMilliSeconds
        }
        else {
            Write-Information 'Please set -Recover to "restart", "noaction", or "reboot"'
            return
        }
    }
    PROCESS {
        foreach ($service in $ServiceName) {
            Set-Service -Name $($service) -StartupType $($Startup)
            sc.exe failure $($service) actions= $action reset= $resetCounter
            if ($Status -eq "start") {
                Start-Service -Name $($service)
            }
            elseif ($Status -eq "stop") {
                Stop-Service -Name $($service)
            }
            Write-Verbose "The service $($service) has been set to $($Startup) with recovery action $($Recover) and status $($Status)."
        }
    }
}
