function Set-PasswordNeverExpires {
    <#
    .SYNOPSIS
    Set AD Password Never Expires flag

    .DESCRIPTION
    Set AD Password Never Expires flag. Either remove the flag from accounts (default), or set the flag for accounts. If no CSV path is provided to -CsvName this will run on all accounts.

    .PARAMETER CsvName
    Enter the path to a csv with the list of Sam Account Names.
    The default is to title the username column SamAccountName. This can be overidden with the UserNameColumnTitle parameter.
    .PARAMETER ProjectFolder
    The default is $env:SystemDrive\FT
    .PARAMETER UserNameColumnTitle
    .PARAMETER LogFileName
    .PARAMETER SetEnable
    Defualt is to disable (remove the flag). Include this switch to enable pw ever expires instead.

    .EXAMPLE
    Set-PasswordNeverExpires
    Removes the password never expires flag from all AD accounts.

    .EXAMPLE
    Set-PasswordNeverExpires -CsvName "C:\MyFolder\Users.csv"
    Removes the password never expires flag from all accounts listed in a CSV.

    .EXAMPLE
    Set-ADPasswordFromCSV -CsvName "C:\MyFolder\Users.csv" -SetEnable
    Sets the Password Never Expires flag for all accounts listed in a CSV. Useful for service accounts.

    #>
    [CmdletBinding()]
    param (
        [Parameter(HelpMessage='Enter the path to the CSV with the list of users. Such as "C:\FT\Users.csv"')]
        [String]$CsvName,
        [String]$ProjectFolder = "$env:SystemDrive\FT",
        [String]$UserNameColumnTitle = "SamAccountName",
        [String]$LogFileName = "PwNeverExpires.log",
        [Switch]$SetEnable
    )
    Begin {
        try {
            if (![string]::IsNullOrEmpty($CsvName)) {
                $UserNamesList = Import-Csv -Path $CsvName
            }
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
        if([string]::isnullorempty($CsvName)){
            $users = Get-ADUser -Filter 'Name -like "*"' -Properties SamAccountName
            $total = $users.Count
            $i = 0
            if(!($SetEnable)){
                foreach ($user in $users) {
                    $i++
                    Write-Verbose "Removing Password Never Expires flag for $($user.SamAccountName)"
                    Write-Progress -Activity "Removing Password Never Expires flag for all users" -Status "$i of $total" -PercentComplete (($i / $total) * 100)
                    try { Set-ADUser $user -PasswordNeverExpires:$False -ErrorAction SilentlyContinue } catch {
                        Add-Content -Path "$WorkingDir\$LogFileName" -Value "Error removing PasswordNeverExpires for $($user.SamAccountName): $($_.Exception.Message)"
                        Write-Verbose "Error removing PasswordNeverExpires for $($user.SamAccountName): $($_.Exception.Message)"
                    }
                }
            }
            else{
                foreach ($user in $users) {
                    $i++
                    Write-Verbose "Setting Password Never Expires flag for $($user.SamAccountName)"
                    Write-Progress -Activity "Setting Password Never Expires flag for all users" -Status "$i of $total" -PercentComplete (($i / $total) * 100)
                    try { Set-ADUser $user -PasswordNeverExpires:$True -ErrorAction SilentlyContinue } catch {
                        Add-Content -Path "$WorkingDir\$LogFileName" -Value "Error setting PasswordNeverExpires for $($user.SamAccountName): $($_.Exception.Message)"
                        Write-Verbose "Error setting PasswordNeverExpires for $($user.SamAccountName): $($_.Exception.Message)"
                    }
                }
            }
            Write-Progress -Activity "Processing Complete" -Completed
        }
        else{
            $total = $UserNamesList.Count
            $i = 0
            if(!($SetEnable)){
                foreach ($User in $UserNamesList) {
                    $i++
                    $ADUser = $User.$UserNameColumnTitle
                    Write-Verbose "Removing Password Never Expires flag for $ADUser"
                    Write-Progress -Activity "Removing Password Never Expires flag from CSV" -Status "$i of $total" -PercentComplete (($i / $total) * 100)
                    try { Set-ADUser $ADUser -PasswordNeverExpires:$False -ErrorAction SilentlyContinue } catch {
                        Add-Content -Path "$WorkingDir\$LogFileName" -Value "Error removing PasswordNeverExpires for $ADUser $($_.Exception.Message)"
                        Write-Verbose "Error removing PasswordNeverExpires for $ADUser $($_.Exception.Message)"
                    }
                }
            }
            else{
                foreach ($User in $UserNamesList) {
                    $i++
                    $ADUser = $User.$UserNameColumnTitle
                    Write-Verbose "Setting Password Never Expires flag for $ADUser"
                    Write-Progress -Activity "Setting Password Never Expires flag from CSV" -Status "$i of $total" -PercentComplete (($i / $total) * 100)
                    try { Set-ADUser $ADUser -PasswordNeverExpires:$True -ErrorAction SilentlyContinue } catch {
                        Add-Content -Path "$WorkingDir\$LogFileName" -Value "Error setting PasswordNeverExpires for $ADUser $($_.Exception.Message)"
                        Write-Verbose "Error setting PasswordNeverExpires for $ADUser $($_.Exception.Message)"
                    }
                }
            }
            Write-Progress -Activity "Processing Complete" -Completed
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
