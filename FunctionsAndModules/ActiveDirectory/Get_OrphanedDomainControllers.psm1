function Get-OrphanedDomainControllers {
    param(
        [Parameter(Mandatory)]
        [string]$DomainName
    )

    # Convert domain name to distinguished name format
    $dnParts = $DomainName -split '\.'
    $searchBase = "CN=Configuration," + ($dnParts | ForEach-Object { "DC=$_"} -join ",")

    # Get all live Domain Controllers
    $liveDCs = Get-ADDomainController -Filter * | Select-Object -ExpandProperty Name

    # Get all NTDS Settings objects (DCs in metadata)
    $ntdsObjects = Get-ADObject -SearchBase $searchBase `
      -LDAPFilter "(objectClass=nTDSDSA)" -Properties distinguishedName

    # Extract server names from NTDS objects
    $metadataDCs = $ntdsObjects | ForEach-Object {
        ($_."distinguishedName" -split ",")[1] -replace "^CN=", ""
    }

    # Compare lists
    $tombstonedDCs = $metadataDCs | Where-Object { $_ -notin $liveDCs }

    # Output results
    Write-Host "`nLive Domain Controllers:`n" -ForegroundColor Green
    $liveDCs

    Write-Host "`nTombstoned/Orphaned Domain Controllers in Metadata:`n" -ForegroundColor Red
    $tombstonedDCs
}
