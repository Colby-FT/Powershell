Function Set-FilesExtension {
    <#
    .SYNOPSIS
    Change the extension of files matching specific criteria.

    .DESCRIPTION
    This function changes the extension of files matching specific criteria on a specific drive or all drives.

    .PARAMETER FilesToFind
    The file name or pattern to search for (e.g., "*.txt", "*HelloWorld*").

    .PARAMETER SearchAllDrives
    Indicates whether to search all drives on the system.

    .PARAMETER CheckThisDisk
    Specifies the drive to search if not searching all drives.

    .PARAMETER NewExtension
    Specifies the new file extension to apply.

    .EXAMPLE
    Set-FilesExtension -FilesToFind "*.txt" -NewExtension ".log" -SearchAllDrives
    Finds all .txt files on all drives and changes their extension to .log.

    .EXAMPLE
    Set-FilesExtension -FilesToFind "*.csv" -NewExtension ".xlsx" -CheckThisDisk "C:\"
    Finds all .csv files on the C: drive and changes their extension to .xlsx.

    .EXAMPLE
    Set-FilesExtension -FilesToFind "*.tmp" -NewExtension ".bak"
    Finds all .tmp files on the system drive and changes their extension to .bak.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $True, Mandatory = $true)]
        [String]$FilesToFind,
        [switch]$SearchAllDrives,
        [String]$CheckThisDisk = "$env:SystemDrive",
        [String]$NewExtension
    )
    BEGIN {
        Write-Host -f Green "Initializing file extension change operation."
        $Files = @()
    }
    PROCESS {
        try {
            if ($SearchAllDrives) {
                Write-Host -f Green "Changing file extensions on all drives."
                $Files += Get-PSDrive -PSProvider "FileSystem" | ForEach-Object {
                    Write-Host -f Green "Changing extensions on:" $_.Root " for " $FilesToFind
                    Get-ChildItem $_.Root -Filter $FilesToFind -Recurse -Force -ErrorAction SilentlyContinue
                }
            } else {
                Write-Host -f Green "Changing file extensions on" $CheckThisDisk
                $Files += Get-ChildItem -Path $CheckThisDisk -Filter $FilesToFind -Force -ErrorAction SilentlyContinue -Recurse
            }

            $Files | ForEach-Object {
                try {
                    $NewName = [System.IO.Path]::ChangeExtension($_.FullName, $NewExtension)
                    Rename-Item -Path $_.FullName -NewName $NewName -ErrorAction SilentlyContinue
                } catch {
                    Write-Host -f Red "Failed to rename file: $($_.FullName). Error: $_"
                }
            }

            Write-Host -f Green "File extensions changed successfully."
        } catch {
            Write-Host -f Red "An error occurred during the file extension change operation: $_"
        }
    }
    END {
        Write-Host -f Green "File extension change operation completed on " $Files.Count " files."
    }
}