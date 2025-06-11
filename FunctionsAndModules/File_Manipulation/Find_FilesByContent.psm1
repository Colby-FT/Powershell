Function Find-FilesByContent {
    <#
    .SYNOPSIS
    Search the computer for files containing specified content.

    .DESCRIPTION
    This function searches the computer for files containing specified content. 
    It can filter files by type and size.

    .PARAMETER StringToFind
    Specifies the string to search for within the files.

    .PARAMETER SearchAllDrives
    Indicates whether to search all drives on the system.

    .PARAMETER FileTypeToSearch
    Specifies the file type to search, such as `.txt` or `.log`.

    .PARAMETER CheckThisDisk
    Specifies the drive to search if not searching all drives.

    .PARAMETER MaxFileSizeToSearchInKB
    Specifies the maximum file size (in KB) to include in the search.

    .EXAMPLE
    Find-FilesByContent -StringToFind "Error" -SearchAllDrives
    Searches all drives for .txt files smaller than 100KB containing the text "Error".

    .EXAMPLE
    Find-FilesByContent -StringToFind "Important" -FileTypeToSearch ".log" -CheckThisDisk "E:\" -MaxFileSizeToSearchInKB 500
    Searches the E: drive for .log files smaller than 500KB containing the text "Important".

    .EXAMPLE
    Find-FilesByContent -StringToFind "TODO"
    Searches the system drive for .txt files smaller than 100KB containing the text "TODO".
    #>
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline=$True, Mandatory=$true)]
        [String]$StringToFind,
        [switch]$SearchAllDrives,
        [String]$FileTypeToSearch = ".txt",
        [ValidatePattern("^[A-Za-z]:\\.*")]
        [String]$CheckThisDisk = "$env:SystemDrive\",
        [int]$MaxFileSizeToSearchInKB = 100
    )
    BEGIN {
        Write-Host -f Green "Initializing file search operation."
        $FoundFiles = @()
        $FilesToCheck = @()
    }
    PROCESS {
        try {
            if ($SearchAllDrives) {
                Write-Host -f Green "Gathering all $FileTypeToSearch files on all drives."
                $FilesToCheck = Get-PSDrive -PSProvider "FileSystem" | ForEach-Object {
                    Write-Host -f Green "Gathering from:" $_.Root
                    Get-ChildItem $_.Root -Force -ErrorAction SilentlyContinue -Recurse -Filter "*$FileTypeToSearch"
                }
            } else {
                Write-Host -f Green "Gathering all $FileTypeToSearch files on $CheckThisDisk."
                $FilesToCheck = Get-ChildItem -Path $CheckThisDisk -Force -ErrorAction SilentlyContinue -Recurse -Filter "*$FileTypeToSearch"
            }

            Write-Host -f Green "Searching gathered files for: $StringToFind"
            $FoundFiles += $FilesToCheck | Where-Object { ($_.Length / 1KB) -lt $MaxFileSizeToSearchInKB } | Select-String "$StringToFind" -ErrorAction SilentlyContinue
        } catch {
            Write-Host -f Red "An error occurred during the file content search: $_"
        }
    }
    END {
        Write-Host -f Green "File search operation completed."
        return $FoundFiles
    }
}