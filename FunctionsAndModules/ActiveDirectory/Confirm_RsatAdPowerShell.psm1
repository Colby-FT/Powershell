function Confirm-RSATADPowerShell {
    <#
    .SYNOPSIS
    Enter quick description here

    .DESCRIPTION
    Enter Description Here

    .PARAMETER Param1

    .EXAMPLE
    Example here
    Description of example here

    #>
    Begin {
        $feature = Get-WindowsFeature -Name RSAT-AD-PowerShell
    }
    Process {
        if ($feature.Installed) {
            Write-Output "RSAT-AD-PowerShell is already installed."
        } else {
            Write-Output "RSAT-AD-PowerShell is not installed. Installing now..."
            Install-WindowsFeature -Name RSAT-AD-PowerShell -IncludeManagementTools
            if ($?) {
                Write-Output "RSAT-AD-PowerShell has been successfully installed."
            } else {
                Write-Output "Failed to install RSAT-AD-PowerShell."
            }
        }
    }
}
