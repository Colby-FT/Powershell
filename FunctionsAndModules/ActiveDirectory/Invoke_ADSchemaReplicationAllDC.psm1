function Invoke-ADSchemaReplicationAllDCs {
    try {
        # Get all domain controllers in the domain
        $allDCs = Get-ADDomainController -Filter * | Select-Object -ExpandProperty HostName

        # Get the schema naming context
        $schemaDN = (Get-ADRootDSE).schemaNamingContext

        foreach ($sourceDC in $allDCs) {
            $targetDCs = $allDCs | Where-Object { $_ -ne $sourceDC }
            foreach ($target in $targetDCs) {
                try {
                    Sync-ADObject -Object (Get-ADObject -Identity $schemaDN) -Source $sourceDC -Destination $target -ErrorAction Stop
                    Write-Host "Successfully synced schema from $sourceDC to $target" -ForegroundColor Green
                } catch {
                    Write-Warning "Failed to sync schema from $sourceDC to $target $($_.Exception.Message)"
                }
            }
        }
    } catch {
        Write-Error "Error during schema replication: $($_.Exception.Message)"
    }
}