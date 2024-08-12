Function Install-RSATModule
{
	<#
	.SYNOPSIS
	Check if RSAT is installed and install if not
	#>
    [CmdletBinding()]
    Param(
        [switch]$Test = $false
    )

    $ADMod = Get-Module -ListAvailable -Name "ActiveDirectory"
	IF (-Not $ADMod)
	{
		

		If ((Get-CimInstance Win32_OperatingSystem).Caption -like "*Windows 10*")
		{
			Write-Verbose '---This system is running Windows 10'
		}
		Else 
		{
			Write-Warning '---This system is not running Windows 10'
			break
		}

		If (Get-HotFix -Id KB2693643 -ErrorAction SilentlyContinue)
		{

			Write-Verbose '---RSAT for Windows 10 is already installed'

		} 
		Else
		{

			Write-Verbose '---Downloading RSAT for Windows 10'

			If ((Get-CimInstance Win32_ComputerSystem).SystemType -like "x64*") 
			{
				$dl = 'WindowsTH-KB2693643-x64.msu'
			}
			Else
			{
				$dl = 'WindowsTH-KB2693643-x86.msu'
			}
			Write-Verbose '---Downloading RSAT for Windows 10'

			If ((Get-CimInstance Win32_ComputerSystem).SystemType -like "x64*") {
				$dl = 'WindowsTH-RSAT_WS_1803-x64.msu'
			} Else {
				$dl = 'WindowsTH-RSAT_WS_1803-x86.msu'
			}
			Write-Verbose "---Hotfix file is $dl"

			Write-Verbose "---$(Get-Date)"
			#Download file sample
			#https://gallery.technet.microsoft.com/scriptcenter/files-from-websites-4a181ff3
			$BaseURL = 'https://download.microsoft.com/download/1/D/8/1D8B5022-5477-4B9A-8104-6A71FF9D98AB/'
			$URL = $BaseURL + $dl
			$Destination = Join-Path -Path $HOME -ChildPath "Desktop\$dl"
			$WebClient = New-Object System.Net.WebClient
			$WebClient.DownloadFile($URL,$Destination)
			$WebClient.Dispose()

			Write-Verbose '---Installing RSAT for Windows 10'
			Write-Verbose "---$(Get-Date)"
			# http://stackoverflow.com/questions/21112244/apply-service-packs-msu-file-update-using-powershell-scripts-on-local-server
			wusa.exe $Destination /quiet /norestart /log:$home\Documents\RSAT.log

			# wusa.exe returns immediately. Loop until install complete.
			do {
				Write-Host "." -NoNewline
				Start-Sleep -Seconds 3
			} until (Get-HotFix -Id KB2693643 -ErrorAction SilentlyContinue)
			Write-Host "."
			Write-Verbose "---$(Get-Date)"
		}
		 
		Write-Verbose '---Downloading help for AD PowerShell'
		Update-Help -Module ActiveDirectory -Verbose -Force
		Import-Module ActiveDirectory

		Write-Verbose '---ActiveDirectory PowerShell module install complete.'
	}
	Else
	{
		Import-Module ActiveDirectory
	}
}