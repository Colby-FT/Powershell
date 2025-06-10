Function Purge-DNSEntries {
    <#
    .SYNOPSIS
	Purge DNS of stale entries
	
	.DESCRIPTION
	Finds all DNS Zones. Then searches for all entries that contain the string provided and purges them.  
    This searches Hostname and Data fields. 
    It also removes all name servers with the string in the name.
    If you enter an IP address, it will remove all A records with that IP address.
    This is useful for cleaning up DNS entries that are no longer needed, such as those from decommissioned servers or services.
	
	.PARAMETER PurgeThis
	
	
	.EXAMPLE
    Purge-DNSEntries -PurgeThis "DC-01"
    Finds and removes all entries containing DC-01
	
    #>
    [CmdletBinding()]
    Param (
        [parameter(ValueFromPipeline=$True)]
        [String[]]$PurgeThis
    )

    PROCESS {
        try {
            $DNSZones = Get-DnsServerZone
        } catch {
            Write-Error "Failed to retrieve DNS zones $_"
            return
        }

        ForEach ($Zone in $DNSZones) {
            foreach ($purgeValue in $PurgeThis) {
                try {
                    $records = Get-DnsServerResourceRecord -ZoneName $Zone.ZoneName | Where-Object {
                        $_.HostName -match "$purgeValue" -or
                        $_.RecordData.PtrDomainName -match "$purgeValue" -or
                        $_.RecordData.NameServer -match "$purgeValue" -or
                        $_.RecordData.HostNameAlias -match "$purgeValue" -or
                        $_.RecordData.DomainName -match "$purgeValue"
                    }
                } catch {
                    Write-Error "Failed to retrieve records for zone $($Zone.ZoneName) $_"
                    continue
                }

                foreach ($record in $records) {
                    try {
                        Remove-DnsServerResourceRecord -ZoneName $Zone.ZoneName -InputObject $record -Force
                        Write-Host "Removed record with Hostname $($record.HostName) and Data $($record.RecordData.NameServer) from zone $($Zone.ZoneName)"
                    } catch {
                        Write-Error "Failed to remove record $($record.HostName) in zone $($Zone.ZoneName) $_"
                    }
                }

                if ($purgeValue -match '^\d{1,3}(\.\d{1,3}){3}$') {
                    try {
                        $Arecords = Get-DnsServerResourceRecord -ZoneName $Zone.ZoneName | Where-Object { $_.RecordType -eq "A" }
                    } catch {
                        Write-Error "Failed to retrieve A records for zone $($Zone.ZoneName) $_"
                        continue
                    }
                    foreach ($arecord in $Arecords) {
                        $ip = $arecord.RecordData.IPv4Address.IPAddressToString
                        if ($purgeValue -eq $ip) {
                            try {
                                Write-Host "Removing A record for $($arecord.HostName) with IP $ip from zone $($Zone.ZoneName)"
                                Remove-DnsServerResourceRecord -ZoneName $Zone.ZoneName -RRType "A" -Name $arecord.HostName -RecordData $ip -Force
                            } catch {
                                Write-Error "Failed to remove A record $($arecord.HostName) with IP $ip in zone $($Zone.ZoneName) $_"
                            }
                        }
                    }
                }
                Write-Host "Completed removal of all instances of $purgeValue."
            }
        }
    }
}