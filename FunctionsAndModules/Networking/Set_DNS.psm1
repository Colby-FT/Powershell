<#
ToDo: Add something to validate that IPv4 is active on the NIC before setting DNS.
#>
function Set-DNS {
    <#
    .SYNOPSIS
    Set the DNS

    .DESCRIPTION
    Finds all network adapters, and sets the DNS

    .PARAMETER Primary
    .PARAMETER Secondary

    .EXAMPLE
    Set-DNS
    Sets DNS on all nics to the loopback

    .EXAMPLE
    Set-DNS -Primary 8.8.8.8 -Secondary 8.8.4.4
    Sets DNS on all nics to google dns

    #>
    [CmdletBinding()]
    param (
        [ValidateScript({
            if ($_ -match '^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$') {
                $true
            } else {
                throw "Please enter a valid IP address"
            }
        })]
        $Primary = "127.0.0.1",
        [ValidateScript({
            if ($_ -match '^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$') {
                $true
            } else {
                throw "Please enter a valid IP address"
            }
        })]
        $Secondary = "127.0.0.1"
    )
    Begin {
        $NetAdapter = Get-NetAdapter | Select-Object InterfaceIndex; 
        $Adapter = $NetAdapter.InterfaceIndex; 
    }
    Process {
        ForEach($Index in $Adapter) {Set-DnsClientServerAddress -InterfaceIndex $Index -ServerAddresses ("$Primary","$Secondary")}
    }
    End {
        Write-Host "The IP Settings are:"
        ipconfig /all
        Read-Host -Prompt "Press any key to exit"
    }
}