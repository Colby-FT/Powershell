# Function to get the domain name
function Get-DomainName {
    <#
    .SYNOPSIS
	Get the domain name of the current computer
	
	.EXAMPLE
    $DomainName = Get-DomainName
    Get the domain name, and assign it to a variable
	
    #>
    Process {
        try {
            $domainName = (Get-WmiObject Win32_ComputerSystem).Domain
        }
        catch {
            $domainName = (Get-CimInstance Win32_ComputerSystem).Domain
        }
        finally {
            if ([string]::isnullorempty($domainName)) {
                throw "Domain name not found."
                Write-Error "Failed to retrieve the domain name."
            }
        }
    }
    End{
        if (!([string]::isnullorempty($domainName))) {
            return $domainName
        }
    }
}