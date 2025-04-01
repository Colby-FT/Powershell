function Get-NetworkConnectionProcess {
    <#
    .SYNOPSIS
    Get-NetworkConnections retrieves network connections for specified IP addresses.

    .DESCRIPTION
    This function retrieves network connections for specified IP addresses. It uses the Get-NetTCPConnection cmdlet to get TCP connections and filters them based on the provided IP addresses. For each connection, it retrieves the owning process information using Get-Process.
    The output includes local and remote addresses, ports, connection state, process name, and process ID.

    .PARAMETER IPAddresses
    Enter an IP address or a list of IP addresses to check for network connections.

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
    $results = Get-NetworkConnectionProcess -IPAddresses "192.34.22.62"
    Write-Output $results | Export-Csv -Path "connections.csv" -NoTypeInformation
    Export the results to a CSV file.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$IPAddresses
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