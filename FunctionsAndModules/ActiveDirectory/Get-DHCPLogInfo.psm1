function Get-DHCPLogInfo {
    <#
    .SYNOPSIS
	DHCP log parser
	
	.DESCRIPTION
    Searches all dhcp logs for all activity related to specified IP address
	
	.PARAMETER IPAddress
		
	.EXAMPLE
    Get-DHCPLogInfo -IPAddress 10.10.32.64
    Finds all entries in the DHCP logs related to 10.10.32.64
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$IPAddress
    )
    Begin {
        # Define the path to the DHCP log files
        $dhcpLogPath = "$env:SystemDrive\Windows\System32\dhcp"

        # Get a list of all DHCP log files
        $dhcpLogFiles = Get-ChildItem -Path $dhcpLogPath -Filter "DhcpSrvLog-*.log"
    }
    Process {
        # Loop through each log file and search for the IP address
        foreach ($logFile in $dhcpLogFiles) {
            # Output the name of the current log file being searched
            Write-Host "Searching in file: $($logFile.Name)"
            
            # Get the content of the DHCP log file and filter for the IP address
            Get-Content $logFile.FullName | Where-Object { $_ -match $IPAddress }
        }
    }
}