Function Find-Files
{
    <#
    .SYNOPSIS
	Search the entire computer for files
	
	.DESCRIPTION
	Search the entire computer for files
	
	.PARAMETER FilesToFind
	
	
	.EXAMPLE
    Find-Files -FilesToFind *.txt
    Finds all files on the computer with a .txt extension

    .EXAMPLE
    Find-Files -FilesToFind *HelloWorld*
    Finds all files on the computer with HelloWorld anywhere in the name
	
    #>
    [CmdletBinding()]
    Param
	(
		[parameter(ValueFromPipeline=$True)]
		[String]$FilesToFind
	)

    PROCESS
    {
        Get-PSDrive -PSProvider "FileSystem" |  ForEach-Object {Write-Host -f Green "Searching:" $_.Root " for " $FilesToFind; Get-ChildItem $_.Root -Filter $FilesToFind -Recurse -Force -ErrorAction SilentlyContinue}
    }
}