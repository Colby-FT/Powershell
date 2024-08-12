Function Set-FilesExtension
{
    <#
    .SYNOPSIS
	Search the entire computer for files and set the name
	
	.DESCRIPTION
	Search the entire computer for files and replace the searched for string
	
	.PARAMETER FilesToFind

    .PARAMETER NewFileName
	
	
	.EXAMPLE
    Set-FilesExtension -FilesToFind *.txt -NewFileName .doc
    Finds all files on the computer with a .txt extension and changes the extension to .doc

    .EXAMPLE
    Set-FilesExtension -FilesToFind *HelloWorld* -NewFileName GoodbyeWorld
    Finds all files on the computer with HelloWorld anywhere in the name and replaces HelloWorld with GoodbyeWorld
    
    .EXAMPLE
    Set-FilesExtension -FilesToFind HelloWorld.ps1 -NewFileName GoodbyeWorld.ps1
    Finds all files on the computer named HelloWorld.ps1 and renames them GoodbyeWorld.ps1
	
    #>
    [CmdletBinding()]
    Param
	(
		[parameter(ValueFromPipeline=$True)]
		[String]$FilesToFind,
        [String]$NewFileName
	)

    $FilesFound = Get-PSDrive -PSProvider "FileSystem" |  ForEach-Object {Write-Host -f Green "Searching:" $_.Root " for " $FilesToFind; Get-ChildItem $_.Root -Force -ErrorAction SilentlyContinue -filter "$FilesToFind" -r }
    $FilesFound | Rename-Item -NewName { $_.Name -replace "$FilesToFind","$NewFileName" }
}