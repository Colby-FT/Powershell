Function Manipulate-Files
{
    <#
    .SYNOPSIS
	Find and manipulate files in all drives
	
	.DESCRIPTION
	Search the entire computer for files, and output the paths, or get the count, or rename them, or delete them
	
	.PARAMETER FilesToFind
    
    .PARAMETER GetCount
    
    .PARAMETER SetFileExtension
    
    .PARAMETER RemoveFiles
	
	
	.EXAMPLE
    Manipulate-Files -FilesToFind *.txt
    Finds all files on the computer with a .txt extension

    .EXAMPLE
    Manipulate-Files -FilesToFind *HelloWorld*
    Finds all files on the computer with HelloWorld anywhere in the name

    .EXAMPLE
    Manipulate-Files -FilesToFind *.txt -GetCount
    Finds all files on the computer with a .txt extension and gets a count

    .EXAMPLE
    Manipulate-Files -FilesToFind *HelloWorld* -GetCount
    Finds all files on the computer with HelloWorld anywhere in the name and gets a count

    .EXAMPLE
    Manipulate-Files -FilesToFind *.txt -SetFileExtension .doc
    Finds all files on the computer with a .txt extension and changes the extension to .doc

    .EXAMPLE
    Manipulate-Files -RemoveFiles *.txt
    Finds all files on the computer with a .txt extension and deletes them

    .EXAMPLE
    Manipulate-Files -RemoveFiles *HelloWorld*
    Finds all files on the computer with a HelloWorld in the name and deletes them
    
    .EXAMPLE
    Manipulate-Files -RemoveFiles HelloWorld.ps1
    Finds all files on the computer named HelloWorld.ps1 and deletes them
	
    #>
    [CmdletBinding()]
    Param
	(
		[parameter(ValueFromPipeline=$True)]
        [String]$FilesToFind,
        [switch]$GetCount=$false,
        [String]$SetFileExtension,
        [String]$RemoveFiles
	)
    BEGIN
	{
		$FilesFound = Get-PSDrive -PSProvider "FileSystem" |  ForEach-Object {Write-Host -f Green "Searching:" $_.Root; Get-ChildItem $_.Root -Force -ErrorAction SilentlyContinue -include "$FilesToFind" -r }
	}
    PROCESS
	{
		If($GetCount)
		{
			($FilesFound | Measure-Object).count
		}
		ELSEIF($SetFileExtension)
		{
			$FilesFound | Rename-Item -NewName { $_.Name -replace "$FilesToFind","$NewFileName" }
		}
		ELSEIF($RemoveFiles)
		{
			$RemoveFiles | Remove-Item -Force
		}
        ELSE
        {
            $FilesFound = [PSObject]$FilesFound
            $FilesFound
        }
	}
}
