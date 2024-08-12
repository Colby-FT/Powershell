function Set-PwExpiresNextLogon {
    <#
    .SYNOPSIS
    Set AD Password Expires at Next Logon flag

    .DESCRIPTION
    Set AD Password Expires at Next Logon flag. Either set the flag for accounts (default), or remove the flag for accounts. If no CSV path is provided to -CsvName this will run on all accounts.

    .PARAMETER CsvName
    Enter the path to a csv with the list of Sam Account Names.
    The default is to title the username column SamAccountName. This can be overidden with the UserNameColumnTitle parameter.
    .PARAMETER ProjectFolder
    The default is $env:SystemDrive\FT
    .PARAMETER UserNameColumnTitle
    .PARAMETER LogFileName
    .PARAMETER SetDisable
    Defualt is to enable (set the flag). Include this switch to disable instead.

    .EXAMPLE
    Set-PwExpiresNextLogon
    Sets the password to expire at next logon for all AD accounts.

    .EXAMPLE
    Set-PwExpiresNextLogon -CsvName "C:\MyFolder\Users.csv"
    Sets the password to expire at next logon for all accounts listed in a CSV.
    #>
    [CmdletBinding()]
    param (
        [Parameter(HelpMessage='Enter the path to the CSV with the list of users. Such as "C:\FT\Users.csv"')]
        [String]$CsvName,
        [String]$ProjectFolder = "$env:SystemDrive\FT",
        [String]$UserNameColumnTitle = "SamAccountName",
        [String]$LogFileName = "PWExpiresNextLogon.log",
        [Switch]$SetDisable
    )
    Begin {
        $UserNamesList = Import-Csv -Path $CsvName
        Import-Module ActiveDirectory
        $WorkingDir = Set-ProjectFolder -baseDir $ProjectFolder
        Start-Transcript -Path "$WorkingDir\$LogFileName" -Append
    }
    Process {
        if([string]::isnullorempty($CsvName)){
            if(!($SetDisable)){
                Get-ADUser -Filter 'Name -like "*"' -Properties DisplayName | % {Set-ADUser $_ -ChangePasswordAtLogon:$True}
            }
            else{
                Get-ADUser -Filter 'Name -like "*"' -Properties DisplayName | % {Set-ADUser $_ -ChangePasswordAtLogon:$False}
            }
        }
        else{
            if(!($SetDisable)){
                foreach ($User in $UserNamesList) {
                    $ADUser = $User.$UserNameColumnTitle
                    Write-Host "Setting Password Expires at Next Logon flag for: " $ADUser
                    Set-ADUser $ADUser -ChangePasswordAtLogon:$True
                }
            }
            else{
                foreach ($User in $UserNamesList) {
                    $ADUser = $User.$UserNameColumnTitle
                    Write-Host "Removing Password Expires at Next Logon flag for: " $ADUser
                    Set-ADUser $ADUser -ChangePasswordAtLogon:$False
                }
            }
        }
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
