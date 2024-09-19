function Get-WindowsKey {
    <#
    .SYNOPSIS
    Get Windows Product Key

    .DESCRIPTION
    Attempt to get the OEM Windows key.  If that does not exist attempt to find a non-OEM key.

    .EXAMPLE
    Get-WindowsKey
    Gets Windows key

    #>
    Process {
        # Initialize variables
        $oemKey = $null
        $nonOemKey = $null
        $regKey = $null

        # Check for OEM key
        $oemKey = (Get-WmiObject -query 'select * from SoftwareLicensingService').OA3xOriginalProductKey

        # Check for non-OEM key
        $nonOemKey = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform').BackupProductKeyDefault

        # Check for registry key
        $regKey = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DigitalProductId
    }

    End {
        $results = @()

        if (![string]::IsNullOrWhiteSpace($oemKey)) {
            $results += "OEM Key: $oemKey"
        }
        if (![string]::IsNullOrWhiteSpace($nonOemKey)) {
            $results += "MS Windows Key: $nonOemKey"
        }
        if ($regKey) {
            $decodedKey = ConvertTo-ProductKey $regKey
            $results += "MS Windows NT Key: $decodedKey"
        }

        if ($results.Count -gt 0) {
            return $results
        } else {
            return "No Windows Product Key found"
        }
    }
}

function ConvertTo-ProductKey($digitalProductId) {
    $key = ""
    $chars = "BCDFGHJKMPQRTVWXY2346789"
    $isWin8 = ($digitalProductId[66] / 6) -band 1
    $last = 0
    $keyOffset = 52
    $len = 15
    $stringLen = 29
    $keyOutput = New-Object System.Text.StringBuilder

    for ($i = 24; $i -ge 0; $i--) {
        $current = 0
        for ($j = 14; $j -ge 0; $j--) {
            $current = $current * 256 -bxor $digitalProductId[$j + $keyOffset]
            $digitalProductId[$j + $keyOffset] = [math]::Floor($current / 24)
            $current = $current % 24
        }
        $keyOutput.Insert(0, $chars[$current])
    }

    $keyOutput.Insert(0, $chars[$last])
    $keyOutput.Insert(5, "-")
    $keyOutput.Insert(11, "-")
    $keyOutput.Insert(17, "-")
    $keyOutput.Insert(23, "-")

    return $keyOutput.ToString()
}
