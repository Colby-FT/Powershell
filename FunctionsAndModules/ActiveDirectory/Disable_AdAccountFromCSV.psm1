function Disable-AdAccountFromCSV {
    <#
    .SYNOPSIS
    Disable AD accounts listed in a CSV

    .DESCRIPTION
    Disable accounts listed by Sam Account Names in a CSV.

    .PARAMETER CsvName
    Enter the path to a csv with the list of Sam Account Names.
    The default is to title the username column SamAccountName. This can be overidden with the UserNameColumnTitle parameter.
    .PARAMETER ProjectFolder
    The default is $env:SystemDrive\FT
    .PARAMETER UserNameColumnTitle
    .PARAMETER LogFileName
    Sets the length of the randomly generated password. The default is 14.

    .EXAMPLE
    Disable-AdAccountFromCSV -CsvName "C:\MyFolder\Users.csv"
    Disables all accounts listed in Users.csv under the column titled SamAccountName
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,
        HelpMessage='Enter the path to the CSV with the list of users. Such as "C:\FT\Users.csv"')]
        [String]$CsvName,
        [String]$ProjectFolder = "$env:SystemDrive\FT",
        [String]$UserNameColumnTitle = "SamAccountName",
        [String]$LogFileName = "DisabledUsers.log"
    )
    Begin {
        try {
            $UserNamesList = Import-Csv -Path $CsvName
        } catch {
            Add-Content -Path "$LogFileName" -Value "Error importing CSV: $($_.Exception.Message)"
            Write-Host -ForegroundColor Red "Error importing CSV: $($_.Exception.Message)"
            return
        }
        Import-Module ActiveDirectory -ErrorAction SilentlyContinue
        $WorkingDir = Set-ProjectFolder -baseDir $ProjectFolder
        Write-Host "For errors check log file at $WorkingDir\$LogFileName, or run with -Verbose for more details."
        Start-Transcript -Path "$WorkingDir\$LogFileName" -Append
    }
    Process {
        $total = $UserNamesList.Count
        $i = 0
        foreach ($User in $UserNamesList) {
            $i++
            $ADUser = $User.$UserNameColumnTitle
            Write-Verbose "Disabling account $ADUser"
            Write-Progress -Activity "Disabling AD accounts from CSV" -Status "$i of $total" -PercentComplete (($i / $total) * 100)
            try {
                Disable-ADAccount -Identity $ADUser -ErrorAction SilentlyContinue
                Write-Host "Disabled $ADUser"
            } catch {
                Add-Content -Path "$WorkingDir\$LogFileName" -Value "Error disabling $ADUser $($_.Exception.Message)"
                Write-Verbose "Error disabling $ADUser $($_.Exception.Message)"
            }
        }
        Write-Progress -Activity "Processing Complete" -Completed
    }
    End {
        Stop-Transcript
        Write-Host "The log file can be found at $WorkingDir\$LogFileName"
    }
}

###############################
##### Support Functions ######
#############################
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
