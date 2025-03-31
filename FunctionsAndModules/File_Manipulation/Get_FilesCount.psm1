Function Get-FilesCount {
    <#
    .SYNOPSIS
    Count the number of files matching specific criteria.

    .DESCRIPTION
    This function counts the number of files matching specific criteria on a specific drive or all drives.

    .PARAMETER FilesToFind
    Specifies the pattern or name of files to count.

    .PARAMETER SearchAllDrives
    Indicates whether to search all drives on the system.

    .PARAMETER CheckThisDisk
    Specifies the drive to search if not searching all drives.

    .EXAMPLE
    Get-FilesCount -FilesToFind "*.log" -SearchAllDrives
    Counts all .log files on all drives.

    .EXAMPLE
    Get-FilesCount -FilesToFind "*.txt" -CheckThisDisk "D:\"
    Counts all .txt files on the D: drive.

    .EXAMPLE
    Get-FilesCount -FilesToFind "*.csv"
    Counts all .csv files on the system drive.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline=$True, Mandatory=$true)]
        [String]$FilesToFind,
        [switch]$SearchAllDrives,
        [String]$CheckThisDisk = "$env:SystemDrive"
    )
    BEGIN {
        Write-Host -f Green "Initializing file count operation."
        $Files = @()
    }
    PROCESS {
        try {
            if ($SearchAllDrives) {
                Write-Host -f Green "Counting files on all drives."
                $Files += Get-PSDrive -PSProvider "FileSystem" | ForEach-Object {
                    Write-Host -f Green "Counting files on:" $_.Root
                    Get-ChildItem $_.Root -Filter $FilesToFind -Recurse -Force -ErrorAction SilentlyContinue
                }
            } else {
                Write-Host -f Green "Counting files on" $CheckThisDisk
                $Files += Get-ChildItem -Path $CheckThisDisk -Filter $FilesToFind -Force -ErrorAction SilentlyContinue -Recurse
            }
        } catch {
            Write-Host -f Red "An error occurred during file counting: $_"
        }
    }
    END {
        Write-Host -f Green "Total files found:" $Files.Count
        return $Files.Count
    }
}