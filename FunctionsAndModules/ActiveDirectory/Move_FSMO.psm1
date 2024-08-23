function Move-FSMO {
    <#
    .SYNOPSIS
    Moves FSMO roles to selected computer

    .DESCRIPTION
    Moves FSMO roles to selected computer

    .PARAMETER DestDir
    .PARAMETER Force

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
    [string]$DestServer,
    [switch]$Force
    )
    Begin {
        if ([string]::isnullorempty($DestServer)) {
            $DestServer = hostname
        }
    }
    Process {
        If(!($Force)){
            Move-ADDirectoryServerOperationMasterRole -Identity $DestServer -OperationMasterRole DomainNamingMaster,InfrastructureMaster,PDCEmulator,RIDMaster,SchemaMaster
        }
        Else{
            Move-ADDirectoryServerOperationMasterRole -Identity $DestServer -OperationMasterRole DomainNamingMaster,InfrastructureMaster,PDCEmulator,RIDMaster,SchemaMaster -Force
        }
    }
    End {
        $FSMO = New-Object PSObject -Property @{
            SchemaMaster = (Get-ADForest).SchemaMaster
            DomainNamingMaster = (Get-ADForest).DomainNamingMaster
            PDCEmulator = (Get-ADDomain).PDCEmulator
            RIDMaster = (Get-ADDomain).RIDMaster
            InfrastructureMaster = (Get-ADDomain).InfrastructureMaster
        }
        $FSMO
        Return $FSMO
    }
}