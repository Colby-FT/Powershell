Function Remove-Files {
    <#
    .SYNOPSIS
    Remove files matching specific criteria.

    .DESCRIPTION
    This function removes files matching specific criteria on a specific drive or all drives.

    .PARAMETER FilesToDelete
    Specifies the pattern or name of files to delete.

    .PARAMETER SearchAllDrives
    Indicates whether to search all drives on the system.

    .PARAMETER CheckThisDisk
    Specifies the drive to search if not searching all drives.

    .EXAMPLE
    Remove-Files -FilesToDelete "*.tmp" -SearchAllDrives
    Finds and deletes all temporary files (*.tmp) on all drives.

    .EXAMPLE
    Remove-Files -FilesToDelete "OldFile.log" -CheckThisDisk "C:\"
    Finds and deletes the file named "OldFile.log" on the C: drive.

    .EXAMPLE
    Remove-Files -FilesToDelete "*Backup*"
    Finds and deletes all files with "Backup" in their name on the system drive.
    #>
    [CmdletBinding()]
    Param (
        [switch]$SearchAllDrives,
        [ValidatePattern("^[A-Za-z]:\\.*")]
        [String]$CheckThisDisk = "$env:SystemDrive\",
        [Parameter(ValueFromPipeline=$True, Mandatory=$true)]
        [String]$FilesToDelete
    )
    BEGIN {
        Write-Host -f Green "Initializing file removal operation."
        $Files = @()
    }
    PROCESS {
        try {
            if ($SearchAllDrives) {
                Write-Host -f Green "Removing files on all drives."
                $Files += Get-PSDrive -PSProvider "FileSystem" | ForEach-Object {
                    Write-Host -f Green "Searching:" $_.Root " for " $FilesToDelete
                    Get-ChildItem $_.Root -Filter $FilesToDelete -Recurse -Force -ErrorAction SilentlyContinue
                }
            } else {
                Write-Host -f Green "Searching files on" $CheckThisDisk
                $Files += Get-ChildItem $CheckThisDisk -Filter $FilesToDelete -Force -ErrorAction SilentlyContinue -Recurse
            }
            if ($Files) {
                $Files | Remove-Item -Force -ErrorAction SilentlyContinue
                Write-Host -f Green "Files removed successfully."
            } else {
                Write-Host -f Yellow "No files found to remove."
            }
        } catch {
            Write-Host -f Red "An error occurred during file removal: $_"
        }
    }
    END {
        if ($Files.Count -eq 0) {
            Write-Host -f Yellow "No files were removed."
        } else {
            Write-Host -f Green $Files.Count " files removed successfully."
            Write-Verbose "The following files were removed: $Files"
        }
    }
}