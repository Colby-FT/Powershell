function Invoke-ADSchemaReplicationAllDCs {
    # Get all domain controllers in the domain
    $allDCs = Get-ADDomainController -Filter * | Select-Object -ExpandProperty HostName

    # Get the schema naming context
    $schemaDN = (Get-ADRootDSE).schemaNamingContext

    foreach ($sourceDC in $allDCs) {
        $targetDCs = $allDCs | Where-Object { $_ -ne $sourceDC }
        foreach ($target in $targetDCs) {
            Sync-ADObject -Object (Get-ADObject -Identity $schemaDN) -Source $sourceDC -Destination $target
        }
    }
}