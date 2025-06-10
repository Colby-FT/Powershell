Function Purge-DNSEntries {
    <#
    .SYNOPSIS
	Purge DNS of stale entries
	
	.DESCRIPTION
	Finds all DNS Zones. Then searches for all entries that contain the string provided and purges them.  This searches this searches Hostname and Data fields. It also removes all name servers with the string in the name.
	
	.PARAMETER PurgeThis
	
	
	.EXAMPLE
    Purge-DNSEntries -PurgeThis "DC-01"
    Finds and removes all entries containing DC-01
	
    #>
    [CmdletBinding()]
    Param
	(
		[parameter(ValueFromPipeline=$True)]
		[String]$PurgeThis
	)

    PROCESS
    {
        $DNSZones = Get-dnsServerZone

        ForEach ($Zone in $DNSZones)
        {
            $records = Get-DnsServerResourceRecord -ZoneName $Zone.ZoneName | Where-Object {
            $_.HostName -match "$PurgeThis" -or
            $_.RecordData.PtrDomainName -match "$PurgeThis" -or
            $_.RecordData.NameServer -match "$PurgeThis" -or
            $_.recorddata.HostNameAlias -match "$PurgeThis" -or
            $_.recorddata.DomainName -match "$PurgeThis"
            }

            foreach ($record in $records) {
                    # Remove the resource record
                    Remove-DnsServerResourceRecord -ZoneName $zone.ZoneName -InputObject $record -Force
                    Write-Host "Removed record with Hostname: $($record.hostname) and Data: $($record.RecordData.NameServer) from zone: $($zone.ZoneName)"
                } 
        }

        Write-Host "Completed removal of all instances of $PurgeThis."
    }
}