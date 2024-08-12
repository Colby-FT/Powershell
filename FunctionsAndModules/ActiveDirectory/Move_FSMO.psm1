function Move-FSMO {
    <#
    .SYNOPSIS
    Moves FSMO roles to selected computer

    .DESCRIPTION
    Moves FSMO roles to selected computer

    .PARAMETER DestDir

    .EXAMPLE
    Move-FSMO
    Moves all the FSMO roles to the computer the command is being executed on

    .EXAMPLE
    Move-FSMO -DestServer DC02
    Moves all FSMO roles to DC02
    
    .EXAMPLE
    Move-FSMO -DestServer DC02 -Force
    Seizes all FSMO roles to DC02
    #>

    [CmdletBinding()]
    Param (
    [string]$DestServer
    )
    Begin {
        if ([string]::isnullorempty($DestServer)) {
            $DestServer = hostname
        }
    }
    Process {
        Move-ADDirectoryServerOperationMasterRole -Identity $DestServer -OperationMasterRole DomainNamingMaster,InfrastructureMaster,PDCEmulator,RIDMaster,SchemaMaster
    }
}