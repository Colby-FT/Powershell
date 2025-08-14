function Get-FileFromWeb {
		<#
        .SYNOPSIS
        Downloads a file from the web and saves it to a specified location.

        .DESCRIPTION
        This function downloads a file from the specified URL and saves it to the provided destination path. 
        It ensures the parent directory exists and provides an option to override.

        .PARAMETER SourceURL
        The URL of the file to download.

        .PARAMETER DestinationPath
        The local path where the file will be saved.

        .PARAMETER DontOverwrite
        If specified, the function will not overwrite the file if it already exists.

        .EXAMPLE
        Get-FileFromWeb -SourceURL "http://example.com/file.zip" -DestinationPath "C:\Temp\file.zip"

        .EXAMPLE
        Get-FileFromWeb -SourceURL "http://example.com/file.txt" -DestinationPath "C:\Temp\file.txt" -Verbose
        #>

		[CmdletBinding()]
		param (
            [parameter(ValueFromPipeline=$True, Mandatory=$True)]
            [ValidateNotNullOrEmpty()]
            [string]$SourceURL,

            [parameter(Mandatory=$True)]
            [ValidateNotNullOrEmpty()]
            [string]$DestinationPath,

            [switch]$Overwrite
        )
		Begin {
			#Check if parent directory exists, and create if it doesn't.
			if (!(Test-Path -PathType Container (Split-Path -Parent $DestinationPath))){
				mkdir (Split-Path -Parent $DestinationPath) -Force | Out-Null
			}
            $Success = $true
		}
		Process {
            if (!$Overwrite) {
                #Check if file exists, and prompt for overwrite
                if (Test-Path $DestinationPath) {
                    Write-Warning "File already exists at $DestinationPath. If you want to replace it, please enable overwrite."
                    $Success = $false
                    return
                }
            }
            try {
                Write-Output "Downloading $SourceURL to $DestinationPath"
                Invoke-WebRequest -Uri $SourceURL -OutFile $DestinationPath -ErrorAction Stop
            } catch {
                Write-Error "Failed to download file. Error: $_"
                $Success = $false
                return
            }
        }
		End {
			if ($Success) {
                #Check for success
                if (Test-Path $DestinationPath) {
                    Write-Output "Download successful. The File is located at $DestinationPath"
                    return $DestinationPath
                } else {
                    Write-Output "Download failed"
                }
            }
        }
	}
	