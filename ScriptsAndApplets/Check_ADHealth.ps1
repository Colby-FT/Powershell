<#
.SYNOPSIS
General AD Health Checks

.DESCRIPTION
Run some general health checks on AD and output them to a txt
#>

#######################
##### Functions ######
#####################

#Function to create the working directory
function Set-ProjectFolder {
    <#
    .SYNOPSIS
    Create a project folder

    .DESCRIPTION
    The default (with no parameters) is to create C:\FT

    .PARAMETER baseDir
    .PARAMETER taskDir
    .PARAMETER changeDir

    .EXAMPLE
    Set-ProjectFolder
    Creates C:\FT

    .EXAMPLE
    Set-ProjectFolder -taskDir "WorkWork" -changeDir
    Creates C:\FT\WorkWork and changes to that directory

    .EXAMPLE
    $ProjectFolder = Set-ProjectFolder -taskDir "Work\Work"
    Creates C:\FT\Work\Work and assigns the path to the variable $ProjectFolder

    .EXAMPLE
    Set-ProjectFolder -baseDir "D:\FT" -changeDir
    Overides the default base directory to creates D:\FT\ and changes to that directory

    #>
    [CmdletBinding()]
    param (
        [string]$baseDir = "$env:SystemDrive\FT",
        [string]$taskDir,
        [switch]$changeDir
    )
    process {
        #If the path doesn't exist - Make it. 
        if (!(test-path $basedir)){
            #New-Item -Path "$baseDir" -ItemType "directory"
            mkdir "$basedir"
        }
        #Check if task dir is needed
        if (!([string]::isnullorempty($taskDir))){
            if (!(test-path "$baseDir\$taskDir")){
                #New-Item -Path "$baseDir\$taskDir" -ItemType "directory"
                mkdir "$baseDir\$taskDir"
            }
        }
    }
    end {
        #Set working dir
        if($changeDir){
            if (!([string]::isnullorempty($taskDir))){
                Set-Location "$baseDir\$taskDir"
            }
            else{
                Set-Location "$baseDir"
            }
        }
        #Return path for working dir
        if (!([string]::isnullorempty($taskDir))){
            return "$baseDir\$taskDir"
        }
        else{
            return "$baseDir"
        }
    }
}

#Function to get the domain name
function Get-DomainName {
    <#
    .SYNOPSIS
	Get the domain name of the current computer
	
	.EXAMPLE
    $DomainName = Get-DomainName
    Get the domain name, and assign it to a variable
	
    #>
    Process {
        try {
            $domainName = (Get-WmiObject Win32_ComputerSystem).Domain
            if ([string]::isnullorempty($domainName)) {
                throw "Domain name not found."
            }
            return $domainName
        }
        catch {
            Write-Error "Failed to retrieve the domain name."
        }
    }
}

##########################
##### Do the thing ######
########################

# Set some variables
[string]$outputDir = Set-ProjectFolder
[string]$baseFilename = "HealthChecks"
[string]$HName = hostname
[string]$domainName = Get-DomainName
[string]$DateTime = (Get-Date).ToString("MMddyy_HHmm")
[string]$outputFile = "$outputDir\$HName`_$baseFilename`_$DateTime.txt"

#Generate the file
New-Item -Path $outputFile -ItemType "file" -Force

# Run the commands and write the output to the file
Write-Host "Getting FSMO roles"
Add-Content -Path $outputFile -Value "-----FSMO START-----"
netdom query fsmo | Add-Content -Path $outputFile
Add-Content -Path $outputFile -Value "-----FSMO END-----"

Write-Host "Running RepAdmin /showrepl"
Add-Content -Path $outputFile -Value "-----REPADMIN END-----"
repadmin /showrepl | Add-Content -Path $outputFile
Add-Content -Path $outputFile -Value "-----REPADMIN END-----"

Write-Host "Running dcdiag /v"
Add-Content -Path $outputFile -Value "-----DCDIAG START-----"
dcdiag /v | Add-Content -Path $outputFile
Add-Content -Path $outputFile -Value "-----DCDIAG END-----"

Write-Host "Running dcdiag /test:net"
Add-Content -Path $outputFile -Value "-----NETLOGON START-----"
dcdiag /test:netlogons | Add-Content -Path $outputFile
Add-Content -Path $outputFile -Value "-----NETLOGON END-----"

# Notify the user
Write-Host "Health check report saved to $outputFile"