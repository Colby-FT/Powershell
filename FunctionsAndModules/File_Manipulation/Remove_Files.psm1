Function Remove-Files
{
    <#
    .SYNOPSIS
	Search the entire computer for files and delete them
	
	.DESCRIPTION
	Search the entire computer for files and delete them
	
	.PARAMETER FilesToDelete
	
	
	.EXAMPLE
    Remove-Files -FilesToDelete *.txt
    Finds all files on the computer with a .txt extension and deletes them

    .EXAMPLE
    Remove-Files -FilesToDelete *HelloWorld*
    Finds all files on the computer with a HelloWorld in the name and deletes them
    
    .EXAMPLE
    Remove-Files -FilesToDelete HelloWorld.ps1
    Finds all files on the computer named HelloWorld.ps1 and deletes them
	
    #>
    [CmdletBinding()]
    Param
	(
		[parameter(ValueFromPipeline=$True)]
		[String]$FilesToDelete
	)

    $DeleteThese = Get-PSDrive -PSProvider "FileSystem" | ForEach-Object {Write-Host -f Green "Searching:" $_.Root " for " $FilesToDelete; Get-ChildItem $_.Root -force -ErrorAction SilentlyContinue -filter "$FilesToDelete" -r};
    $DeleteThese | Remove-Item -Force
}