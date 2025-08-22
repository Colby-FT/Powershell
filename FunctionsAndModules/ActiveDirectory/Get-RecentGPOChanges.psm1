function Get-RecentGPOChanges {
    <#
    .SYNOPSIS
    Lists GPOs modified since a specified date, including metadata and linked OUs.

    .DESCRIPTION
    This function queries Group Policy Objects (GPOs) in the domain and identifies those modified since a given date (defaulting to 7 days ago). It provides:
    - GPO name and GUID
    - Description (synopsis)
    - Last modified time
    - Linked Organizational Units (OUs)
    - Creator and last modifier (if available)
    - Optional CSV export

    .PARAMETER Since
    The date to check for GPO modifications. Defaults to 7 days ago.

    .PARAMETER ExportCsvPath
    Path to export the results to a CSV file.

    .EXAMPLE
    Get-RecentGPOChanges -Since (Get-Date).AddDays(-14) -ExportCsvPath "C:\GPOChanges.csv"
    Lists GPOs modified in the last 14 days and exports the results to a CSV file.
    #>
    [CmdletBinding()]
    param (
        [datetime]$SinceDate = (Get-Date).AddDays(-7),
        [string]$ExportCsvPath,
        [switch]$cleanConsoleOutput
    )

    Begin {
        Import-Module GroupPolicy -ErrorAction Stop

        function Get-GPOLinks {
            $links = @{}
            $ous = Get-ADOrganizationalUnit -Filter * -Properties gPLink
            foreach ($ou in $ous) {
                if ($ou.gPLink) {
                    $foundMatch = ($ou.gPLink -split '\[LDAP://') | Where-Object { $_ -match 'CN={.*?}' }
                    foreach ($matchedItem in $foundMatch) {
                        $guid = ($matchedItem -split 'CN=|\}')[1]
                        if ($guid) {
                            if (-not $links.ContainsKey($guid)) {
                                $links[$guid] = @()
                            }
                            $links[$guid] += $ou.Name
                        }
                    }
                }
            }
            return $links
        }

        $linkedOUs = Get-GPOLinks
        $results = @()
    }

    Process {
        $gpos = Get-GPO -All
        foreach ($gpo in $gpos) {
            if ($gpo.ModificationTime -ge $SinceDate) {
                $creator = $gpo.Owner
                $modifier = $gpo.User
                $linked = $linkedOUs[$gpo.Id.Guid] -join ', '

                $results += [PSCustomObject]@{
                    Name = $gpo.DisplayName
                    GUID = $gpo.Id
                    Description = $gpo.Description
                    Modified = $gpo.ModificationTime
                    CreatedBy = $creator
                    ModifiedBy = $modifier
                    LinkedOUs = $linked
                }
            }
        }
    }

    End {
        if ($cleanConsoleOutput){
            Write-Host "`n=== GPOs Modified Since $SinceDate ==="
            $results | ForEach-Object {
                Write-Host "`n[$($_.Name)]"
                Write-Host "  GUID: $($_.GUID)"
                Write-Host "  Description: $($_.Description)"
                Write-Host "  Modified: $($_.Modified)"
                Write-Host "  Created By: $($_.CreatedBy)"
                Write-Host "  Modified By: $($_.ModifiedBy)"
                Write-Host "  Linked OUs: $($_.LinkedOUs)"
            }
        }
        if ($ExportCsvPath) {
            $results | Export-Csv -Path $ExportCsvPath -NoTypeInformation
            Write-Host "`nResults exported to $ExportCsvPath"
        }
        else{
            return $results
        }
    }
}
