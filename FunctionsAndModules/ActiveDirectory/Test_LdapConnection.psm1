Function Test-LDAPConnection {
    [CmdletBinding()]
    Param (
        [Parameter(Position=0, Mandatory=$False, HelpMessage="Provide domain controllers names, example DC01", ValueFromPipeline=$true)]
        $DCs,
        [Parameter(Position=1, Mandatory=$False, HelpMessage="Provide port number for LDAP", ValueFromPipeline=$true)]
        $Port = "636"
    )
    $Results = @()
    Try {
        Import-Module ActiveDirectory -ErrorAction Stop
    } Catch {
        $_.Exception.Message
        Break
    }
    if ([string]::IsNullOrEmpty($DCs)) {
        $DCs = Get-ADDomainController -Filter * | Select-Object -ExpandProperty HostName
        Write-Verbose "No DCs provided, using all domain controllers in the domain."
    }
    ForEach ($DC in $DCs) {
        $DC = $DC.trim()
        Write-Verbose "Processing $DC"
        Try {
            $DCName = (Get-ADDomainController -Identity $DC).hostname
        } Catch {
            $_.Exception.Message
            Continue
        }
        If ($Null -ne $DCName) {
            Try {
                $Connection = [adsi]"LDAP://$($DCName):$Port"
            } Catch {
                $ExcMessage = $_.Exception.Message
                throw "Error: Failed to make LDAP connection. Exception: $ExcMessage"
            }
            If ($Connection.Path) {
                $Object = New-Object PSObject -Property ([ordered]@{
                    DC   = $DC
                    Port = $Port
                    Path = $Connection.Path
                })
                $Results += $Object
                Write-Output $Object
            }
        }
    }
    if (-not $Results) {
        Write-Host "No successful LDAP connections found." -ForegroundColor Yellow
    }
}