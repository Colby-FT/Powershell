function Invoke-RemoteCommand {
    <#
    .SYNOPSIS
    Invoke a command on a remote computer

    .DESCRIPTION
    Allows you loop through multiple computers and send a remote command utilizing Invoke-Command.

    .PARAMETER DeviceNames
    .PARAMETER RemoteCommandBlock

    .EXAMPLE
    $DevNames = (Import-Csv -Path "C:\FT\PcList.csv").PCNames
    $CommandBlock = 'Set-DNS -Primary 192.168.1.2 -Secondary 192.168.1.3'
    Invoke-RemoteCommand -DeviceNames $DevNames -RemoteCommandBlock $CommandBlock
    
    Pulls the list of computer names from the column titled PCNames in PcList.csv and assigns to $DevNames. Then, loops through each device and sends the command to set-dns.

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,
        Position=1,
        ValueFromPipeline=$true,
        HelpMessage="Use an array, or enter a comma seperated list of computer names.")]
        [ValidateNotNullOrEmpty()]
        [String[]]$DeviceNames,
        [Parameter(Mandatory=$true)]
        [String]$RemoteCommandBlock
    )
    Begin {
        ##Create Credential Object
        [string]$userName = Read-Host "Enter the administrator username for the remote computer(s): "
        [string]$userPassword = Read-Host "Enter the password: "
        [securestring]$secStringPassword = ConvertTo-SecureString $userPassword -AsPlainText -Force
        [pscredential]$credObject = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)
    }
    Process {
        ##Push app out to each device
        foreach ($Device in $DeviceNames) {
            Invoke-Command -ComputerName "$Device" -ScriptBlock { $RemoteCommandBlock } -credential $credObject
        }
    }
}