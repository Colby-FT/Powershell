Function Search-DNSEntries {
    <#
    .SYNOPSIS
    Search DNS for entries matching a given string or IP address.

    .DESCRIPTION
    Finds all DNS Zones and searches for entries that contain the provided string or IP address.
    This searches Hostname and Data fields including PTR, NS, CNAME, and A records.
    Useful for auditing or identifying stale or misconfigured DNS entries.

    .PARAMETER SearchFor
    The string or IP address to search for in DNS records.

    .EXAMPLE
    Search-DNSEntries -SearchFor "DC-01"
    Finds and outputs all entries containing "DC-01"
    #>
    [CmdletBinding()]
    Param (
        [parameter(ValueFromPipeline=$True)]
        [String[]]$SearchFor
    )

    PROCESS {
        try {
            $DNSZones = Get-DnsServerZone
        } catch {
            Write-Error "Failed to retrieve DNS zones $_"
            return
        }

        ForEach ($Zone in $DNSZones) {
            foreach ($searchValue in $SearchFor) {
                try {
                    $records = Get-DnsServerResourceRecord -ZoneName $Zone.ZoneName | Where-Object {
                        $_.HostName -match "$searchValue" -or
                        $_.RecordData.PtrDomainName -match "$searchValue" -or
                        $_.RecordData.NameServer -match "$searchValue" -or
                        $_.RecordData.HostNameAlias -match "$searchValue" -or
                        $_.RecordData.DomainName -match "$searchValue"
                    }
                } catch {
                    Write-Error "Failed to retrieve records for zone $($Zone.ZoneName) $_"
                    continue
                }

                foreach ($record in $records) {
                    Write-Host "Found record in zone $($Zone.ZoneName): Hostname = $($record.HostName), Type = $($record.RecordType), Data = $($record.RecordData)"
                }

                if ($searchValue -match '^\d{1,3}(\.\d{1,3}){3}$') {
                    try {
                        $Arecords = Get-DnsServerResourceRecord -ZoneName $Zone.ZoneName | Where-Object { $_.RecordType -eq "A" }
                    } catch {
                        Write-Error "Failed to retrieve A records for zone $($Zone.ZoneName) $_"
                        continue
                    }
                    foreach ($arecord in $Arecords) {
                        $ip = $arecord.RecordData.IPv4Address.IPAddressToString
                        if ($searchValue -eq $ip) {
                            Write-Host "Found A record in zone $($Zone.ZoneName): Hostname = $($arecord.HostName), IP = $ip"
                        }
                    }
                }

                Write-Host "Completed search for all instances of $searchValue."
            }
        }
    }
}
