Function Install-SysInternals
{
	<#
	.SYNOPSIS
	Check if SysInternals is installed and install if not
	#>
	[CmdletBinding()]
	$SysIntsPath = "C:\SysInternals"
	If (!(Test-Path $SysIntsPath))
	{
		$SysIntsZip = "$SysIntsPath\SysInternals.zip"
        New-Item $SysIntsPath -ItemType Directory
        $URL = "https://download.sysinternals.com/files/SysinternalsSuite.zip" 
        $WebClient = New-Object System.Net.WebClient
		$WebClient.DownloadFile($URL,$SysIntsZip)
		$WebClient.Dispose()
		Expand-Archive -LiteralPath $SysIntsZip -DestinationPath $SysIntsPath
	}
	Else
	{
		Write-Verbose "SysInternals is already installed. Adding to Path."
	}
	[Environment]::SetEnvironmentVariable("Path",$Env:Path + ";C:\sysinternals", "Machine")
}