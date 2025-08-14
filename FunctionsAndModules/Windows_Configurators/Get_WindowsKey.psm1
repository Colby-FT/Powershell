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
        $BakupKey = $null
        $DigProdKey = $null

        $oemkey = Get-CimInstance -ClassName SoftwareLicensingService | Select-Object -ExpandProperty OA3xOriginalProductKey
        if ([string]::IsNullOrWhiteSpace($oemKey)) {
            $oemKey = (Get-WmiObject -query 'select * from SoftwareLicensingService').OA3xOriginalProductKey
        }

        $BakupKey = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform').BackupProductKeyDefault

        $DigProdKey = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DigitalProductId
        $DigProdKey4 = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DigitalProductId4
    }

    End {
        $results = @()

        if (![string]::IsNullOrWhiteSpace($oemKey)) {
            $results += "OEM Key: $oemKey"
        }
        if (![string]::IsNullOrWhiteSpace($BakupKey)) {
            $results += "Backup Key: $BakupKey
            This is the key windows uses if no key is provided during installation."
        }
        if (![string]::IsNullOrWhiteSpace($DigProdKey)) {
            $decodedKey = ConvertTo-ProductKey $DigProdKey
            $decodedKey = $decodedKey[-1]
            $results += "Digital Product Key: $decodedKey
            Check against key showing in Activation Settings. Depending on key type this is often a 'dummy key' generated as a placeholder for the real key."
        }
        if (![string]::IsNullOrWhiteSpace($DigProdKey4)) {
            $decodedKey4 = ConvertTo-ProductKey $DigProdKey4
            $decodedKey4 = $decodedKey4[-1]
            $results += "Digital Product Key 4: $decodedKey4
            Check against key showing in Activation Settings. Depending on key type this is often a 'dummy key' generated as a placeholder for the real key."
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