function Set-ServiceConfig{
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
        [string[]] [Parameter(ValueFromPipeline=$True)] $ServiceName,
        [string]$Recover = "restart",
        [string]$Status = "start",
        [string]$Startup = "automatic"
    )
    BEGIN
    {
        IF($Recover = "restart")
        {
            $resetCounter = 4000
            $action = "restart"+"/"+30000+"/"+"restart"+"/"+30000+"/"+"restart"+"/"+30000
        }
        ElseIf($Recover = "noaction")
        {
            $resetCounter = 4000
            $action = '//////'
        }
        ElseIf($Recover = "reboot")
        {
            $resetCounter = 4000
            $action = "reboot"+"/"+30000
        }
        else 
        {
            Write-Information 'Please set -Recover to "restart", "noaction", or "reboot"'
            Break
        }
    }
    PROCESS
    {
        foreach ($service in $ServiceName)
        {
            Set-Service -Name $($service) -StartupType $($Startup)
            sc.exe failure $($service) actions= $action reset= $resetCounter
            If($Status = "start")
            {
                Start-Service -Name $($service)
            }
            ElseIf($Status = "stop")
            {
                Stop-Service -Name $($service)
            }
        }
    }
}
