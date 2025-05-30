function Test-DCReplicationBetweenAllDCs {
    # Get all domain controllers in the domain
    $dcs = Get-ADDomainController -Filter * | Select-Object -ExpandProperty HostName

    Write-Host "Checking replication status for inbound errors between all DCs..." -ForegroundColor Cyan

    foreach ($source in $dcs) {
        foreach ($target in $dcs) {
            if ($source -ne $target) {
                Write-Host "`n--- Checking replication from $source to $target ---" -ForegroundColor Yellow
                $output = repadmin $target 2>&1

                if ($output -match $source -and $output -match "8606") {
                    Write-Host "⚠️  $target has error 8606 when replicating from $source!" -ForegroundColor Red
                    $output | Select-String $source -Context 0,5
                } elseif ($output -match $source) {
                    Write-Host "✅ $target is replicating from $source without error 8606." -ForegroundColor Green
                } else {
                    Write-Host "ℹ️  $target does not replicate from $source." -ForegroundColor Gray
                }
            }
        }
    }
}
