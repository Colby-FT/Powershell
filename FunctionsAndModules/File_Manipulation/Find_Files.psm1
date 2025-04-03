Function Find-Files {
    <#
    .SYNOPSIS
    Search for files on the computer.

    .DESCRIPTION
    This function searches for files on the computer based on the specified pattern. 
    It can search either all drives or a specific drive.

    .PARAMETER FilesToFind
    The file name or pattern to search for (e.g., "*.txt", "*HelloWorld*").

    .PARAMETER SearchAllDrives
    If specified, searches all drives on the computer.

    .PARAMETER CheckThisDisk
    Specifies the disk to search. Defaults to the system drive.

    .EXAMPLE
    Find-Files -FilesToFind "*.txt" -SearchAllDrives
    Searches all drives for files with a .txt extension.

    .EXAMPLE
    Find-Files -FilesToFind "*HelloWorld*" -CheckThisDisk "D:\"
    Searches the D: drive for files with "HelloWorld" in the name.

    .EXAMPLE
    Find-Files -FilesToFind "*.log"
    Searches the system drive for files with a .log extension.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline=$True, Mandatory=$true)]
        [String]$FilesToFind,
        [switch]$SearchAllDrives,
        [ValidatePattern("^[A-Za-z]:\\$")]
        [String]$CheckThisDisk = "$env:SystemDrive\"
    )
    BEGIN {
        Write-Host -f Green "Initializing file count operation."
        $Files = @() # Initialize $Files as an empty array
    }
    PROCESS {
        try {
            if ($SearchAllDrives) {
                Write-Host -f Green "Finding files on all drives."
                $Files += Get-PSDrive -PSProvider "FileSystem" | ForEach-Object {
                    Write-Host -f Green "Searching:" $_.Root " for " $FilesToFind
                    Get-ChildItem $_.Root -Filter $FilesToFind -Recurse -Force -ErrorAction SilentlyContinue
                }
            } else {
                Write-Host -f Green "Finding files on" $CheckThisDisk
                $Files += Get-ChildItem -Path $CheckThisDisk -Filter $FilesToFind -Force -ErrorAction SilentlyContinue -Recurse
            }
        } catch {
            Write-Host -f Red "An error occurred during the file search: $_"
        }
    }
    END {
        Write-Host -f Green "Total files found:" $Files.Count
        return $Files
    }
}