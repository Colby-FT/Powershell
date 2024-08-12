Function Get-FilesCount
{
    <#
    .SYNOPSIS
	Search the entire computer for files and get a count
	
	.DESCRIPTION
    Search the entire computer for files and get a count
	
	.PARAMETER FilesToFind
	
	
	.EXAMPLE
    Get-FilesCount -FilesToFind *.txt
    Finds all files on the computer with a .txt extension and gets a count

    .EXAMPLE
    Get-FilesCount -FilesToFind *HelloWorld*
    Finds all files on the computer with HelloWorld anywhere in the name and gets a count
	
    #>
    [CmdletBinding()]
    Param
	(
		[parameter(ValueFromPipeline=$True)]
		[String]$FilesToFind
	)

    $FilesToCount = Get-PSDrive -PSProvider "FileSystem" |  ForEach-Object {Write-Host -f Green "Searching:" $_.Root " for " $FilesToFind; Get-ChildItem $_.Root -filter $FilesToFind -Recurse -Force -ErrorAction SilentlyContinue}

    ($FilesToCount | Measure-Object).count
}