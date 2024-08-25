function Get-DeviceStatus {
    param (
        [string]$deviceName,
        [switch]$OutTable
    )
    $pingResult = Test-Connection -ComputerName $deviceName -Count 1 -Quiet
    $result = if ($pingResult) {
        $ipAddress = [System.Net.Dns]::GetHostAddresses($deviceName) | Where-Object { $_.AddressFamily -eq 'InterNetwork' }
        [PSCustomObject]@{
            DeviceName = $deviceName
            Status     = "Online"
            IPAddress  = $ipAddress.IPAddressToString
        }
    } else {
        [PSCustomObject]@{
            DeviceName = $deviceName
            Status     = "Offline"
            IPAddress  = "N/A"
        }
    }

    if ($OutTable) {
        $result | Format-Table -AutoSize
    } else {
        return $result
    }
}