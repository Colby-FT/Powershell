
function Scan-NetworkRange {

    <#
    .SYNOPSIS
	Scan a range of IP addresses for active IPs
	
	.DESCRIPTION
	Scan a range of IP addresses for active IPs
	
	.PARAMETER StartRange
    .PARAMETER EndRange
	.PARAMETER OnlyActive
    
	.EXAMPLE
    Scan-NetworkRange -StartRange "192.168.1.21" -EndRange "192.168.1.100"
    This will output active and inactive IPs within the range 192.168.1.21-100.

    .EXAMPLE
    Scan-NetworkRange -StartRange "10.1.1.1" -EndRange "10.20.255.255" -OnlyActive
    This will output only the active IPs within the absolutely massive range 10.1-20.1-255.1-255
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateScript({
            if ($_ -match '^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$') {
                $true
            } else {
                throw "Please enter a valid IP address"
            }
        })]
        [string]$StartRange,
        
        [Parameter(Mandatory=$true)]
        [ValidateScript({
            if ($_ -match '^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$') {
                $true
            } else {
                throw "Please enter a valid IP address"
            }
        })]
        [string]$EndRange,

        [switch]$OnlyActive=$false
    )

    # Convert the IP range to a sequence of numbers
    $startIP = $StartRange.Split('.').ForEach({ [int]$_ })
    $endIP = $EndRange.Split('.').ForEach({ [int]$_ })
    
    # Loop through each segment of the IP address
    for ($a = $startIP[0]; $a -le $endIP[0]; $a++) {
        for ($b = $startIP[1]; $b -le $endIP[1]; $b++) {
            for ($c = $startIP[2]; $c -le $endIP[2]; $c++) {
                for ($d = $startIP[3]; $d -le $endIP[3]; $d++) {
                    $currentIP = "$a.$b.$c.$d"
                    $ping = Test-Connection -ComputerName $currentIP -Count 1 -Quiet
                    if ($ping) {
                        try {
                            $hostEntry = [System.Net.Dns]::GetHostEntry($currentIP)
                            $hostname = $hostEntry.HostName
                        } catch {
                            $hostname = "Hostname not found"
                        }
                        if (-not $OnlyActive) {
                            Write-Host "IP: $currentIP is active. Hostname: $hostname"
                        } else {
                            Write-Host "IP: $currentIP is active. Hostname: $hostname"
                        }
                    } elseif (-not $OnlyActive) {
                        Write-Host "IP: $currentIP is inactive."
                    }
                }
                # Reset the last segment after each loop
                $startIP[3] = 0
            }
            # Reset the third segment after each loop
            $startIP[2] = 0
        }
        # Reset the second segment after each loop
        $startIP[1] = 0
    }
}
