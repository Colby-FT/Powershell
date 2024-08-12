Function Find-FilesByContent
{
    <#
    .SYNOPSIS
    Search the computer for files containing specified content
    
    .DESCRIPTION
    Search the computer for files containing specified content
    
    .PARAMETER StringToFind,
    .PARAMETER SearchAllDrives
    .PARAMETER FileTypeToSearch
    .PARAMETER MaxSizeForRansomNoteInKB

    .EXAMPLE
    Find-FilesByContent -StringToFind "Find This Note" -SearchAllDrives
    Search the entire computer for .txt files that are 100KB or smaller containing the text "Find This Note"

    .EXAMPLE
    Find-FilesByContent -StringToFind "Find This Note" -FileTypeToSearch ".pdf" -CheckThisDisk "F:\" -MaxFileSizeToSearchInKB 500
    Search the F: drive for .pdf files that are 500KB or smaller containing the text "Find This Note"

    .EXAMPLE
    Find-FilesByContent -StringToFind "Find This Note"
    Search the C:\ drive for .txt files that are 100KB or smaller containing the text "Find This Note"

    #>
    [CmdletBinding()]
    Param
    (
        [parameter(ValueFromPipeline=$True)]
        [String]$StringToFind,
        [switch]$SearchAllDrives,
        [String]$FileTypeToSearch=".txt",
        [String]$CheckThisDisk="C:\",
        [int]$MaxFileSizeToSearchInKB=100
    )
    BEGIN
    {
        if ($SearchAllDrives) {
            Write-Host -f Green "Gathering all" $FileTypeToSearch "Files on all drives."
            <#Get-PSDrive -PSProvider "FileSystem" |  ForEach-Object {Write-Host -f Green "Gathering from:" $_.Root}#>
            $FilesToCheck=Get-PSDrive -PSProvider "FileSystem" |  ForEach-Object {Write-Host -f Green "Gathering from:" $_.Root; Get-ChildItem $_.Root -Force -ErrorAction SilentlyContinue -r -filter *"$FileTypeToSearch"}
        }
        else {
            $diskToCheck = $CheckThisDisk;
            Write-Host -f Green "Gathering all" $FileTypeToSearch "Files on" $diskToCheck
            $FilesToCheck=Get-PSDrive -PSProvider "FileSystem" |  ForEach-Object {Get-ChildItem "$diskToCheck" -Force -ErrorAction SilentlyContinue -r -filter *"$FileTypeToSearch"}
        }
    }
    PROCESS
    {
        Write-Host -f Green "Searching gathered files for: " $StringToFind
        $FilesToCheck | Where-Object {($_.Length / 1kb) -lt $MaxFileSizeToSearchInKB} | Select-String "$StringToFind" -ErrorAction SilentlyContinue
    }
}