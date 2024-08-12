function Set-ADPasswordFromCSV {
    <#
    .SYNOPSIS
    Set AD Passwords for list of users from CSV

    .DESCRIPTION
    Create a list of Sam Account Names in a CSV. Either generate random passwords (default), or add passwords for each user to a second column in the csv.

    .PARAMETER CsvName
    Enter the path to a csv with the list of Sam Account Names, and passwords if applicable.
    The default is to title the username column SamAccountName and the passwords column Password. This can be overidden with the UserNameColumnTitle, and PwColumnTitle parameters.
    .PARAMETER ProjectFolder
    The default is $env:SystemDrive\FT
    .PARAMETER PwFromCSV
    A switch to determine if the passwords should be generated or provided in the CSV.
    If the switch is enabled a Password column must be included in the CSV.
    .PARAMETER UserNameColumnTitle
    .PARAMETER PwColumnTitle
    .PARAMETER LogFileName
    .PARAMETER PwLength
    Sets the length of the randomly generated password. The default is 14.

    .EXAMPLE
    Set-ADPasswordFromCSV -CsvName "C:\MyFolder\Users.csv"
    Sets random 14 character passwords for all users listed in Users.csv

    .EXAMPLE
    Set-ADPasswordFromCSV -CsvName "C:\MyFolder\Users.csv" -PwLength 22
    Sets a 22 character password

    .EXAMPLE
    Set-ADPasswordFromCSV -CsvName "C:\MyFolder\Users.csv" -PwFromCSV
    Sets the passwords provided in the CSV

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,
        HelpMessage='Enter the path to the CSV with the list of users. Such as "C:\FT\Users.csv"')]
        [String]$CsvName,
        [String]$ProjectFolder = "$env:SystemDrive\FT",
        [Switch]$PwFromCSV,
        [String]$UserNameColumnTitle = "SamAccountName",
        [String]$PwColumnTitle = "Password",
        [String]$LogFileName = "ResetUserPasswords.log",
        [Int]$PwLength = 14
    )
    Begin {
        $UserNamesList = Import-Csv -Path $CsvName
        Import-Module ActiveDirectory
        $WorkingDir = Set-ProjectFolder -baseDir $ProjectFolder
        Start-Transcript -Path "$WorkingDir\$LogFileName" -Append
    }
    Process {
        if(!($PwFromCSV)){
            foreach ($User in $UserNamesList) {
                $ADUser = $User.$UserNameColumnTitle
                $ADPW = Get-RandomString -length $PwLength
                $password = ConvertTo-SecureString -AsPlainText $ADPW -force
                Write-Host "Setting Password for " $ADUser " to " $ADPW
                Set-ADAccountPassword $ADUser -NewPassword $password -Reset
            }
        }
        else{
            foreach ($User in $UserNamesList) {
                $ADUser = $User.$UserNameColumnTitle
                $ADPW = $user.$PwColumnTitle
                $password = ConvertTo-SecureString -AsPlainText $ADPW -force
                Write-Host "Setting Password for " $ADUser " to " $ADPW
                Set-ADAccountPassword $ADUser -NewPassword $password -Reset
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
function Get-RandomString {
    <#
    .SYNOPSIS
    Generate a random string

    .DESCRIPTION
    Generates a random string with upper, lower, numbers, and special characters. The default length is 14 characters.

    .PARAMETER length

    .EXAMPLE
    Get-RandomString
    Generate a 14 character string

    .EXAMPLE
    Get-RandomString -length 20
    Generate a 20 character string
    #>
    [CmdletBinding()]
    param (
        [int]$length = 14
    )
    Begin {
        $chars = @()
        $chars += [char[]](65..90)   # Uppercase A-Z
        $chars += [char[]](97..122)  # Lowercase a-z
        $chars += [char[]](48..57)   # Numbers 0-9
        $chars += [char[]](33..47)   # Special characters ! " # $ % & ' ( ) * + , - . /   
    }
    Process {
        $RandString = -join (1..$length | ForEach-Object { $chars | Get-Random })
    }
    End {
        Return $RandString
    }
}

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
