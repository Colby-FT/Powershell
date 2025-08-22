function Send-WakeOnLan {
    param (
        [Parameter(Mandatory=$true)]
        [string]$MacAddress,

        [string]$BroadcastAddress = "255.255.255.255",
        [int]$Port = 9
    )

    # Convert MAC address to byte array
    $macBytes = $MacAddress -split '[:-]' | ForEach-Object { [Convert]::ToByte($_, 16) }

    # Create magic packet: 6 x 0xFF followed by 16 repetitions of MAC address
    $packet = New-Object byte[] (102)
    for ($i = 0; $i -lt 6; $i++) {
        $packet[$i] = 0xFF
    }
    for ($i = 0; $i -lt 16; $i++) {
        for ($j = 0; $j -lt 6; $j++) {
            $packet[6 + $i * 6 + $j] = $macBytes[$j]
        }
    }

    # Send packet via UDP
    $udpClient = New-Object System.Net.Sockets.UdpClient
    $udpClient.Connect($BroadcastAddress, $Port)
    $udpClient.Send($packet, $packet.Length) | Out-Null
    $udpClient.Close()
}

