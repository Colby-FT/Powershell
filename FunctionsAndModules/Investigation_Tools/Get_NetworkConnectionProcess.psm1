function Get-NetworkConnectionProcess {
    <#
    .SYNOPSIS
    Retrieves active and optionally attempted network connections for specified IP addresses, along with associated process details.

    .DESCRIPTION
    This function retrieves active network connections for specified IP addresses using the Get-NetTCPConnection cmdlet. 
    It also retrieves the owning process information for each connection. Optionally, it can include attempted connections 
    by analyzing the Windows Security Event Log for relevant events. The output includes details such as local and remote 
    addresses, ports, connection state, process name, and process ID.

    .PARAMETER IPAddresses
    Enter one or more IP addresses to check for network connections.

    .PARAMETER IncludeAttemptedConnections
    If specified, retrieves attempted network connections from the Windows Security Event Log in addition to active connections.

    .OUTPUTS
    PSCustomObject
    Returns objects containing network connection details and associated process information.

    .EXAMPLE
    Get-NetworkConnectionProcess -IPAddresses "192.34.22.62","52.111.229.0"
    Retrieves network connection details for a list of IP addresses.

    .EXAMPLE
    Get-NetworkConnectionProcess -IPAddresses "192.34.22.62"
    Retrieves network connection details for a single IP address.

    .EXAMPLE
    Get-NetworkConnectionProcess -IPAddresses "192.34.22.62" -IncludeAttemptedConnections
    Retrieves network connection details for a single IP address and includes attempted connections.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$IPAddresses,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeAttemptedConnections
    )
    Begin {
        [OutputType([PSCustomObject])]
        $results = @()
    }
    Process {
        foreach ($IPAddress in $IPAddresses) {
            $connections = Get-NetTCPConnection | Where-Object { $_.RemoteAddress -eq $IPAddress }

            if (-not $connections) {
                Write-Verbose "No connections found for IP address: $IPAddress"
                continue
            }

            foreach ($connection in $connections) {
                try {
                    $process = Get-Process -Id $connection.OwningProcess -ErrorAction Stop
                    $results += [PSCustomObject]@{
                        LocalAddress  = $connection.LocalAddress
                        LocalPort     = $connection.LocalPort
                        RemoteAddress = $connection.RemoteAddress
                        RemotePort    = $connection.RemotePort
                        State         = $connection.State
                        ProcessName   = $process.ProcessName
                        ProcessId     = $process.Id
                    }
                } catch {
                    Write-Warning "Failed to retrieve process for connection with RemoteAddress: $IPAddress"
                }
            }
        }

        if ($IncludeAttemptedConnections) {
            foreach ($IPAddress in $IPAddresses) {
                try {
                    $events = Get-WinEvent -LogName Security -FilterXPath "*[System[EventID=5156]]" -ErrorAction Stop |
                              Where-Object { $_.Message -match $IPAddress }

                    foreach ($event in $events) {
                        $localAddress = if ($event.Message -match 'Source Address:\s+(\S+)') { $matches[1] } else { $null }
                        $localPort = if ($event.Message -match 'Source Port:\s+(\d+)') { $matches[1] } else { $null }
                        $remoteAddress = if ($event.Message -match 'Destination Address:\s+(\S+)') { $matches[1] } else { $null }
                        $remotePort = if ($event.Message -match 'Destination Port:\s+(\d+)') { $matches[1] } else { $null }

                        $results += [PSCustomObject]@{
                            LocalAddress  = $localAddress
                            LocalPort     = $localPort
                            RemoteAddress = $remoteAddress
                            RemotePort    = $remotePort
                            State         = "Attempted"
                            ProcessName   = "N/A"
                            ProcessId     = "N/A"
                        }
                    }
                } catch {
                    Write-Warning "Failed to retrieve attempted connections for IP address: $IPAddress"
                }
            }
        }
    }
    End {
        if ($results.Count -eq 0) {
            Write-Verbose "No network connections found for the specified IP addresses."
        } else {
            Write-Verbose "Network connections retrieved successfully."
        }
        return $results
    }
}