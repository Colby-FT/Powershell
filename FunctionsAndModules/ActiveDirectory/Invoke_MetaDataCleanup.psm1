Function Invoke-MetaDataCleanup{
    <#
    .SYNOPSIS
    Removes a Domain Controller from Active Directory

    .DESCRIPTION
    Performs a complete metadata cleanup of a domain controller.
    Make sure to seize any roles

    .PARAMETER DcToRemove

    .EXAMPLE
    Remove-DCFromAD -DcToRemove DC01
    Performs a metadata cleanup of DC01

    #>
    [CmdletBinding()]
    param(
        $DcToRemove
    )
    Begin {
        #Gather Domain info
        $FullyQualifiedDomainName = (Get-ADDomain).DNSRoot
        $DomainDistinguishedName = (Get-ADDomain).DistinguishedName

        #Get all AD Sites
        $AllADSites = Get-ADReplicationSite -Filter "*"


        #Formulate the FQDN of the former and new DC
        $DCToRemoveFQDN = "$($ADDCNameToRemove).$($FullyQualifiedDomainName)"
    }
    Process {
        :AllADSites Foreach ($AdSite in $AllADSites) {
            Write-Host "Working on site $($AdSite.Name)"

            Write-Host "Checking if site $($AdSite.Name) contains $($DcToRemove)"
            $DC_In_Site = $null
            $DC_In_Site = Get-ADObject -Identity "cn=$($DcToRemove),cn=servers,$($AdSite.DistinguishedName)" -Partition "CN=Configuration,$($DomainDistinguishedName)" -Properties * -ErrorAction SilentlyContinue

            If ($null -ne $DC_In_Site) {
                Write-Host "Site $($AdSite.Name) contains $($DcToRemove)" -ForegroundColor Cyan
                $StandardOut = New-TemporaryFile
                $ErrorOut = New-TemporaryFile
                
                Write-Host "Attempting to cleanup NTDS for $($DcToRemove)" -ForegroundColor Yellow
                $NTDS = $null
                $NTDS = Start-process -FilePath ntdsutil -argumentList """metadata cleanup"" ""remove selected server cn=$($DcToRemove),cn=servers,$($AdSite.DistinguishedName)"" q q" -wait -nonewwindow -RedirectStandardOutput $StandardOut.FullName -RedirectStandardError $ErrorOut -PassThru

                Get-Content -Path $StandardOut -Raw
                Remove-Item -Path $StandardOut -Confirm:$false -Force

                If ($NTDS.ExitCode -gt 0){
                    Get-Content -Path $ErrorOut -Raw
                    Remove-Item -Path $ErrorOut -Confirm:$false -Force
                    Throw "NTDS exit code was $($NTDS.ExitCode)"
                }

                Write-Host "Cleaned up NTDS for $($DcToRemove)" -ForegroundColor Green


                Write-Host "Attempting to cleanup site object for $($DcToRemove)" -ForegroundColor Yellow
                $DC_In_Site = Get-ADObject -Identity "cn=$($DcToRemove),cn=servers,$($AdSite.DistinguishedName)" -Partition "CN=Configuration,$($DomainDistinguishedName)" -Properties * -ErrorAction SilentlyContinue
                $DC_In_Site | Remove-ADObject -Recursive -Confirm:$false
                Write-Host "Cleaned up site object for $($DcToRemove)" -ForegroundColor Green

                Write-Host "Attempting to cleanup other AD objects with this DC name" -ForegroundColor Yellow
                $All_AD_Objects = Get-ADObject -Filter "*" 
                Foreach ($AD_Object in $All_AD_Objects) {
                    If ($AD_Object.DistinguishedName -like "*$($DcToRemove)*") {
                        Write-Host "Attempting to remove AD object $($AD_Object.DistinguishedName)" -ForegroundColor Yellow
                        $AD_Object | Remove-ADObject -Recursive -Confirm:$false 
                        Write-Host "Removed AD object $($AD_Object.DistinguishedName)" -ForegroundColor Green
                    }
                }
                break AllADSites
            }    
        }
    }
}



