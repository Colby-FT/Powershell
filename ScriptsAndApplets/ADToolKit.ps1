<#
.SYNOPSIS
A toolkit of some common AD tasks

.DESCRIPTION
0 - Run some general health checks
1 - Pull a list of all active users in AD or users with admin privileges
2 - Pull a list of all computers or all domain controllers
3 - Set the password on accounts
4 - Remove the password never expires flag on accounts
5 - Set the password expires at next logon flag on accounts
6 - Disable accounts in AD
7 - Set DNS on this device
8 - Purge DNS of a specified entry
9 - Search DHCP for activity related to an IP
10 - Scan a network range for active IPs
11 - Move FSMO roles to a different server
12 - Perform Metadata Cleanup (Remove demoted or tombstoned DC from AD)
13 - Reset Kerberos password
99 - Exit

ToDo: Purge DNS gets most, but not all entries.  Especially struggles in domains with lots of sites
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
    Set-ProjectFolder -baseDir "D:\WorkDir" -changeDir
    Overides the default base directory to creates D:\WorkDir\ and changes to that directory

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
            if ($null -eq $domainName -or $domainName -eq '') {
                throw "Domain name not found."
            }
            return $domainName
        }
        catch {
            Write-Error "Failed to retrieve the domain name."
            return "UnknownDomain"
        }
    }
}

#Function to get DHCP info
function Get-DHCPLogInfo {
    <#
    .SYNOPSIS
	DHCP log parser
	
	.DESCRIPTION
    Searches all dhcp logs for all activity related to specified IP address
	
	.PARAMETER IPAddress
		
	.EXAMPLE
    Get-DHCPLogInfo -IPAddress 10.10.32.64
    Finds all entries in the DHCP logs related to 10.10.32.64
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$IPAddress
    )
    Begin {
        # Define the path to the DHCP log files
        $dhcpLogPath = "$env:SystemDrive\Windows\System32\dhcp"

        # Get a list of all DHCP log files
        $dhcpLogFiles = Get-ChildItem -Path $dhcpLogPath -Filter "DhcpSrvLog-*.log"
    }
    Process {
        # Loop through each log file and search for the IP address
        foreach ($logFile in $dhcpLogFiles) {
            # Output the name of the current log file being searched
            Write-Host "Searching in file: $($logFile.Name)"
            
            # Get the content of the DHCP log file and filter for the IP address
            Get-Content $logFile.FullName | Where-Object { $_ -match $IPAddress }
        }
    }
}

#Function to purge entry from DNS
Function Purge-DNSEntries {
    <#
    .SYNOPSIS
	Purge DNS of stale entries
	
	.DESCRIPTION
	Finds all DNS Zones. Then searches for all entries that contain the string provided and purges them.  
    This searches Hostname and Data fields. 
    It also removes all name servers with the string in the name.
    If you enter an IP address, it will remove all A records with that IP address.
    This is useful for cleaning up DNS entries that are no longer needed, such as those from decommissioned servers or services.
	
	.PARAMETER PurgeThis
	
	
	.EXAMPLE
    Purge-DNSEntries -PurgeThis "DC-01"
    Finds and removes all entries containing DC-01
	
    #>
    [CmdletBinding()]
    Param (
        [parameter(ValueFromPipeline=$True)]
        [String[]]$PurgeThis
    )

    PROCESS {
        try {
            $DNSZones = Get-DnsServerZone
        } catch {
            Write-Error "Failed to retrieve DNS zones $_"
            return
        }

        ForEach ($Zone in $DNSZones) {
            foreach ($purgeValue in $PurgeThis) {
                try {
                    $records = Get-DnsServerResourceRecord -ZoneName $Zone.ZoneName | Where-Object {
                        $_.HostName -match "$purgeValue" -or
                        $_.RecordData.PtrDomainName -match "$purgeValue" -or
                        $_.RecordData.NameServer -match "$purgeValue" -or
                        $_.RecordData.HostNameAlias -match "$purgeValue" -or
                        $_.RecordData.DomainName -match "$purgeValue"
                    }
                } catch {
                    Write-Error "Failed to retrieve records for zone $($Zone.ZoneName) $_"
                    continue
                }

                foreach ($record in $records) {
                    try {
                        Remove-DnsServerResourceRecord -ZoneName $Zone.ZoneName -InputObject $record -Force
                        Write-Host "Removed record with Hostname $($record.HostName) and Data $($record.RecordData.NameServer) from zone $($Zone.ZoneName)"
                    } catch {
                        Write-Error "Failed to remove record $($record.HostName) in zone $($Zone.ZoneName) $_"
                    }
                }

                if ($purgeValue -match '^\d{1,3}(\.\d{1,3}){3}$') {
                    try {
                        $Arecords = Get-DnsServerResourceRecord -ZoneName $Zone.ZoneName | Where-Object { $_.RecordType -eq "A" }
                    } catch {
                        Write-Error "Failed to retrieve A records for zone $($Zone.ZoneName) $_"
                        continue
                    }
                    foreach ($arecord in $Arecords) {
                        $ip = $arecord.RecordData.IPv4Address.IPAddressToString
                        if ($purgeValue -eq $ip) {
                            try {
                                Write-Host "Removing A record for $($arecord.HostName) with IP $ip from zone $($Zone.ZoneName)"
                                Remove-DnsServerResourceRecord -ZoneName $Zone.ZoneName -RRType "A" -Name $arecord.HostName -RecordData $ip -Force
                            } catch {
                                Write-Error "Failed to remove A record $($arecord.HostName) with IP $ip in zone $($Zone.ZoneName) $_"
                            }
                        }
                    }
                }
                Write-Host "Completed removal of all instances of $purgeValue."
            }
        }
    }
}

#Function to Scan network range
function Scan-NetworkRange {

    <#
    .SYNOPSIS
	Scan a range of IP addresses for active IPs
	
	.DESCRIPTION
	Scan a range of IP addresses for active IPs
	
	.PARAMETER StartRange
    .PARAMETER EndRange
	.PARAMETER OnlyActive
    
	.EXAMPLE
    Scan-NetworkRange -StartRange "192.168.1.21" -EndRange "192.168.1.100"
    This will output active and inactive IPs within the range 192.168.1.21-100.

    .EXAMPLE
    Scan-NetworkRange -StartRange "10.1.1.1" -EndRange "10.20.255.255" -OnlyActive
    This will output only the active IPs within the absolutely massive range 10.1-20.1-255.1-255
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateScript({
            if ($_ -match '^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$') {
                $true
            } else {
                throw "Please enter a valid IP address"
            }
        })]
        [string]$StartRange,
        
        [Parameter(Mandatory=$true)]
        [ValidateScript({
            if ($_ -match '^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$') {
                $true
            } else {
                throw "Please enter a valid IP address"
            }
        })]
        [string]$EndRange,

        [switch]$OnlyActive=$false
    )

    # Convert the IP range to a sequence of numbers
    $startIP = $StartRange.Split('.').ForEach({ [int]$_ })
    $endIP = $EndRange.Split('.').ForEach({ [int]$_ })
    
    # Loop through each segment of the IP address
    for ($a = $startIP[0]; $a -le $endIP[0]; $a++) {
        for ($b = $startIP[1]; $b -le $endIP[1]; $b++) {
            for ($c = $startIP[2]; $c -le $endIP[2]; $c++) {
                for ($d = $startIP[3]; $d -le $endIP[3]; $d++) {
                    $currentIP = "$a.$b.$c.$d"
                    $ping = Test-Connection -ComputerName $currentIP -Count 1 -Quiet
                    if ($ping) {
                        try {
                            $hostEntry = [System.Net.Dns]::GetHostEntry($currentIP)
                            $hostname = $hostEntry.HostName
                        } catch {
                            $hostname = "Hostname not found"
                        }
                        if (-not $OnlyActive) {
                            Write-Host "IP: $currentIP is active. Hostname: $hostname"
                        } else {
                            Write-Host "IP: $currentIP is active. Hostname: $hostname"
                        }
                    } elseif (-not $OnlyActive) {
                        Write-Host "IP: $currentIP is inactive."
                    }
                }
                # Reset the last segment after each loop
                $startIP[3] = 0
            }
            # Reset the third segment after each loop
            $startIP[2] = 0
        }
        # Reset the second segment after each loop
        $startIP[1] = 0
    }
}

#Function to Set DNS
function Set-DNS {
    <#
    .SYNOPSIS
    Set the DNS

    .DESCRIPTION
    Finds all network adapters, and sets the DNS

    .PARAMETER Primary
    .PARAMETER Secondary

    .EXAMPLE
    Set-DNS
    Sets DNS on all nics to the loopback

    .EXAMPLE
    Set-DNS -Primary 8.8.8.8 -Secondary 8.8.4.4
    Sets DNS on all nics to google dns

    #>
    [CmdletBinding()]
    param (
        [ValidateScript({
            if ($_ -match '^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$') {
                $true
            } else {
                throw "Please enter a valid IP address"
            }
        })]
        $Primary = "127.0.0.1",
        [ValidateScript({
            if ($_ -match '^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$') {
                $true
            } else {
                throw "Please enter a valid IP address"
            }
        })]
        $Secondary = "127.0.0.1"
    )
    Begin {
        $NetAdapter = Get-NetAdapter | Where-Object { (Get-NetIPInterface -InterfaceAlias $_.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue).AddressFamily -eq 'IPv4' };
        $Adapter = $NetAdapter.InterfaceIndex
    }
    Process {
        ForEach($Index in $Adapter) {Set-DnsClientServerAddress -InterfaceIndex $Index -ServerAddresses ("$Primary","$Secondary")}
    }
    End {
        Write-Host "The IP Settings are:"
        ipconfig /all
    }
}

#Function to prompt the user
function Prompt-User {
    # Prompt the user to choose an option
    $choice = Read-Host 'Choose an option
    0 - Run some general health checks
    1 - Pull a list of all active users in AD or users with admin privileges
    2 - Pull a list of all computers or all domain controllers
    3 - Set the password on accounts
    4 - Set or Remove the password never expires flag on accounts
    5 - Set the password expires at next logon flag on accounts
    6 - Disable accounts in AD
    7 - Set DNS on this device
    8 - Purge DNS of a specified entry
    9 - Search DHCP for activity related to an IP
    10 - Scan a network range for active IPs
    11 - Move FSMO roles to a different server
    12 - Perform a metadata cleanup (Remove a demoted or tombstoned DC from AD)
    13 - Reset Kerberos Password
    14 - Check for orphaned domain controllers
    15 - Replicate AD Schema between all DCs
    99 - Exit
    '
    return $choice
}

#Function to move FSMO roles
function Move-FSMO {
    <#
    .SYNOPSIS
    Moves FSMO roles to selected computer

    .DESCRIPTION
    Moves FSMO roles to selected computer

    .PARAMETER DestDir
    .PARAMETER Force

    .EXAMPLE
    Move-FSMO
    Moves all the FSMO roles to the computer the command is being executed on

    .EXAMPLE
    Move-FSMO -DestServer DC02
    Moves all FSMO roles to DC02
    
    .EXAMPLE
    Move-FSMO -DestServer DC02 -Force
    Seizes all FSMO roles to DC02
    #>

    [CmdletBinding()]
    Param (
    [string]$DestServer,
    [switch]$Force
    )
    Begin {
        if ([string]::isnullorempty($DestServer)) {
            $DestServer = hostname
        }
    }
    Process {
        If(!($Force)){
            Move-ADDirectoryServerOperationMasterRole -Identity $DestServer -OperationMasterRole DomainNamingMaster,InfrastructureMaster,PDCEmulator,RIDMaster,SchemaMaster
        }
        Else{
            Move-ADDirectoryServerOperationMasterRole -Identity $DestServer -OperationMasterRole DomainNamingMaster,InfrastructureMaster,PDCEmulator,RIDMaster,SchemaMaster -Force
        }
    }
    End {
        $FSMO = New-Object PSObject -Property @{
            SchemaMaster = (Get-ADForest).SchemaMaster
            DomainNamingMaster = (Get-ADForest).DomainNamingMaster
            PDCEmulator = (Get-ADDomain).PDCEmulator
            RIDMaster = (Get-ADDomain).RIDMaster
            InfrastructureMaster = (Get-ADDomain).InfrastructureMaster
        }
        $FSMO
        Return $FSMO
    }
}

#Function to generate passwords
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

#Function to set Passwords from CSV
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
        try {
            $UserNamesList = Import-Csv -Path $CsvName
        } catch {
            Add-Content -Path "$LogFileName" -Value "Error importing CSV $($_.Exception.Message)"
            Write-Host -ForegroundColor Red "Error importing CSV $($_.Exception.Message)"
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
        if(!($PwFromCSV)){
            foreach ($User in $UserNamesList) {
                $i++
                $ADUser = $User.$UserNameColumnTitle
                $ADPW = Get-RandomString -length $PwLength
                $password = ConvertTo-SecureString -AsPlainText $ADPW -force
                Write-Verbose "Setting Password for $ADUser to $ADPW"
                Write-Progress -Activity "Setting random passwords from CSV" -Status "$i of $total" -PercentComplete (($i / $total) * 100)
                try {
                    Set-ADAccountPassword $ADUser -NewPassword $password -Reset -ErrorAction SilentlyContinue
                } catch {
                    Add-Content -Path "$WorkingDir\$LogFileName" -Value "Error setting password for $ADUser $($_.Exception.Message)"
                    Write-Verbose "Error setting password for $ADUser $($_.Exception.Message)"
                }
            }
        }
        else{
            foreach ($User in $UserNamesList) {
                $i++
                $ADUser = $User.$UserNameColumnTitle
                $ADPW = $User.$PwColumnTitle
                $password = ConvertTo-SecureString -AsPlainText $ADPW -force
                Write-Verbose "Setting Password for $ADUser to $ADPW"
                Write-Progress -Activity "Setting provided passwords from CSV" -Status "$i of $total" -PercentComplete (($i / $total) * 100)
                try {
                    Set-ADAccountPassword $ADUser -NewPassword $password -Reset -ErrorAction SilentlyContinue
                } catch {
                    Add-Content -Path "$WorkingDir\$LogFileName" -Value "Error setting password for $ADUser $($_.Exception.Message)"
                    Write-Verbose "Error setting password for $ADUser $($_.Exception.Message)"
                }
            }
        }
        Write-Progress -Activity "Processing Complete" -Completed
    }
    End {
        Stop-Transcript
        Write-Host "The log file can be found at $WorkingDir\$LogFileName"
    }
}

#Function to set pw never expire flag
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
            if(!($SetDisable)){
                foreach ($user in $users) {
                    $i++
                    Write-Verbose "Setting Password Expires at Next Logon for $($user.SamAccountName)"
                    Write-Progress -Activity "Setting Password Expires at Next Logon for all users" -Status "$i of $total" -PercentComplete (($i / $total) * 100)
                    try { Set-ADUser $user -ChangePasswordAtLogon:$True -ErrorAction SilentlyContinue 
                    } catch {
                        Add-Content -Path "$WorkingDir\$LogFileName" -Value "Error setting ChangePasswordAtLogon for $($user.SamAccountName): $($_.Exception.Message)"
                        Write-Verbose "Error setting ChangePasswordAtLogon for $($user.SamAccountName): $($_.Exception.Message)"
                    }
                }
            }
            else{
                foreach ($user in $users) {
                    $i++
                    Write-Verbose "Removing Password Expires at Next Logon for $($user.SamAccountName)"
                    Write-Progress -Activity "Removing Password Expires at Next Logon for all users" -Status "$i of $total" -PercentComplete (($i / $total) * 100)
                    try { Set-ADUser $user -ChangePasswordAtLogon:$False -ErrorAction SilentlyContinue } catch {
                        Add-Content -Path "$WorkingDir\$LogFileName" -Value "Error clearing ChangePasswordAtLogon for $($user.SamAccountName): $($_.Exception.Message)"
                        Write-Verbose "Error clearing ChangePasswordAtLogon for $($user.SamAccountName): $($_.Exception.Message)"
                    }
                }
            }
            Write-Progress -Activity "Processing Complete" -Completed
        }
        else{
            $total = $UserNamesList.Count
            $i = 0
            if(!($SetDisable)){
                foreach ($User in $UserNamesList) {
                    $i++
                    $ADUser = $User.$UserNameColumnTitle
                    Write-Verbose "Setting Password Expires at Next Logon for $ADUser"
                    Write-Progress -Activity "Setting Password Expires at Next Logon from CSV" -Status "$i of $total" -PercentComplete (($i / $total) * 100)
                    try { Set-ADUser $ADUser -ChangePasswordAtLogon:$True -ErrorAction SilentlyContinue } catch {
                        Add-Content -Path "$WorkingDir\$LogFileName" -Value "Error setting ChangePasswordAtLogon for $ADUser $($_.Exception.Message)"
                        Write-Verbose "Error setting ChangePasswordAtLogon for $ADUser $($_.Exception.Message)"
                    }
                }
            }
            else{
                foreach ($User in $UserNamesList) {
                    $i++
                    $ADUser = $User.$UserNameColumnTitle
                    Write-Verbose "Removing Password Expires at Next Logon for $ADUser"
                    Write-Progress -Activity "Removing Password Expires at Next Logon from CSV" -Status "$i of $total" -PercentComplete (($i / $total) * 100)
                    try { Set-ADUser $ADUser -ChangePasswordAtLogon:$False -ErrorAction SilentlyContinue } catch {
                        Add-Content -Path "$WorkingDir\$LogFileName" -Value "Error clearing ChangePasswordAtLogon for $ADUser $($_.Exception.Message)"
                        Write-Verbose "Error clearing ChangePasswordAtLogon for $ADUser $($_.Exception.Message)"
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


#Function to disable accounts from CSV
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

#Function to set PW expire logon flag
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
                Get-ADUser -Filter 'Name -like "*"' -Properties DisplayName | ForEach-Object {Set-ADUser $_ -ChangePasswordAtLogon:$True}
            }
            else{
                Get-ADUser -Filter 'Name -like "*"' -Properties DisplayName | ForEach-Object {Set-ADUser $_ -ChangePasswordAtLogon:$False}
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

#Function to set password never expires flag
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

#Funtion to do Metadata cleanup
Function Invoke-MetaDataCleanup{
    <#
    .SYNOPSIS
    Removes a Domain Controller from Active Directory

    .DESCRIPTION
    Performs a complete metadata cleanup of a domain controller.
    Make sure to seize any roles

    .PARAMETER DcToRemove

    .EXAMPLE
    Remove-DCFromAD -DcToRemove DC01
    Performs a metadata cleanup of DC01

    #>
    [CmdletBinding()]
    param(
        $DcToRemove
    )
    Begin {
        #Gather Domain info
        $FullyQualifiedDomainName = (Get-ADDomain).DNSRoot
        $DomainDistinguishedName = (Get-ADDomain).DistinguishedName

        #Get all AD Sites
        $AllADSites = Get-ADReplicationSite -Filter "*"

        #Formulate the FQDN of the DC
        #$DCToRemoveFQDN = "$($ADDCNameToRemove).$($FullyQualifiedDomainName)"
    }
    Process {
        :AllADSites Foreach ($AdSite in $AllADSites) {
            Write-Host "Working on site $($AdSite.Name)"

            Write-Host "Checking if site $($AdSite.Name) contains $($DcToRemove)"
            $DC_In_Site = $null
            $DC_In_Site = Get-ADObject -Identity "cn=$($DcToRemove),cn=servers,$($AdSite.DistinguishedName)" -Partition "CN=Configuration,$($DomainDistinguishedName)" -Properties * -ErrorAction SilentlyContinue

            If ($null -ne $DC_In_Site) {
                Write-Host "Site $($AdSite.Name) contains $($DcToRemove)" -ForegroundColor Cyan
                $StandardOut = New-TemporaryFile
                $ErrorOut = New-TemporaryFile
                
                Write-Host "Attempting to cleanup NTDS for $($DcToRemove)" -ForegroundColor Yellow
                $NTDS = $null
                $NTDS = Start-process -FilePath ntdsutil -argumentList """metadata cleanup"" ""remove selected server cn=$($DcToRemove),cn=servers,$($AdSite.DistinguishedName)"" q q" -wait -nonewwindow -RedirectStandardOutput $StandardOut.FullName -RedirectStandardError $ErrorOut -PassThru

                Get-Content -Path $StandardOut -Raw
                Remove-Item -Path $StandardOut -Confirm:$false -Force

                If ($NTDS.ExitCode -gt 0){
                    Get-Content -Path $ErrorOut -Raw
                    Remove-Item -Path $ErrorOut -Confirm:$false -Force
                    Throw "NTDS exit code was $($NTDS.ExitCode)"
                }

                Write-Host "Cleaned up NTDS for $($DcToRemove)" -ForegroundColor Green


                Write-Host "Attempting to cleanup site object for $($DcToRemove)" -ForegroundColor Yellow
                $DC_In_Site = Get-ADObject -Identity "cn=$($DcToRemove),cn=servers,$($AdSite.DistinguishedName)" -Partition "CN=Configuration,$($DomainDistinguishedName)" -Properties * -ErrorAction SilentlyContinue
                $DC_In_Site | Remove-ADObject -Recursive -Confirm:$false
                Write-Host "Cleaned up site object for $($DcToRemove)" -ForegroundColor Green

                Write-Host "Attempting to cleanup other AD objects with this DC name" -ForegroundColor Yellow
                $All_AD_Objects = Get-ADObject -Filter "*" 
                Foreach ($AD_Object in $All_AD_Objects) {
                    If ($AD_Object.DistinguishedName -like "*$($DcToRemove)*") {
                        Write-Host "Attempting to remove AD object $($AD_Object.DistinguishedName)" -ForegroundColor Yellow
                        $AD_Object | Remove-ADObject -Recursive -Confirm:$false 
                        Write-Host "Removed AD object $($AD_Object.DistinguishedName)" -ForegroundColor Green
                    }
                }
                break AllADSites
            }    
        }
    }
}

#Function to check for ophaned domain controllers
function Get-OrphanedDomainControllers {
    param(
        [Parameter(Mandatory)]
        [string]$DomainName
    )

    # Convert domain name to distinguished name format
    $dnParts = $DomainName -split '\.'
    $searchBase = "CN=Configuration," + ($dnParts | ForEach-Object { "DC=$_"} -join ",")

    # Get all live Domain Controllers
    $liveDCs = Get-ADDomainController -Filter * | Select-Object -ExpandProperty Name

    # Get all NTDS Settings objects (DCs in metadata)
    $ntdsObjects = Get-ADObject -SearchBase $searchBase `
      -LDAPFilter "(objectClass=nTDSDSA)" -Properties distinguishedName

    # Extract server names from NTDS objects
    $metadataDCs = $ntdsObjects | ForEach-Object {
        ($_."distinguishedName" -split ",")[1] -replace "^CN=", ""
    }

    # Compare lists
    $tombstonedDCs = $metadataDCs | Where-Object { $_ -notin $liveDCs }

    # Output results
    Write-Host "`nLive Domain Controllers:`n" -ForegroundColor Green
    $liveDCs

    Write-Host "`nTombstoned/Orphaned Domain Controllers in Metadata:`n" -ForegroundColor Red
    $tombstonedDCs
}

# Function to invoke schema replication across all domain controllers
function Invoke-ADSchemaReplicationAllDCs {
    try {
        # Get all domain controllers in the domain
        $allDCs = Get-ADDomainController -Filter * | Select-Object -ExpandProperty HostName

        # Get the schema naming context
        $schemaDN = (Get-ADRootDSE).schemaNamingContext

        foreach ($sourceDC in $allDCs) {
            $targetDCs = $allDCs | Where-Object { $_ -ne $sourceDC }
            foreach ($target in $targetDCs) {
                try {
                    Sync-ADObject -Object (Get-ADObject -Identity $schemaDN) -Source $sourceDC -Destination $target -ErrorAction Stop
                    Write-Host "Successfully synced schema from $sourceDC to $target" -ForegroundColor Green
                } catch {
                    Write-Warning "Failed to sync schema from $sourceDC to $target $($_.Exception.Message)"
                }
            }
        }
    } catch {
        Write-Error "Error during schema replication: $($_.Exception.Message)"
    }
}

#######################
##### Formatting #####
#####################

####Set a window title and foreground color
$uiConfig = (Get-Host).UI.RawUI
$uiConfig.WindowTitle = "Active Directory Toolkit"
$uiConfig.ForegroundColor = "Cyan"

Write-Host ""
Write-Host "===========================================================" -ForeGroundColor Green
Write-Host "|                                                         |" -ForeGroundColor Green
Write-Host "|              Active Directory Toolkit                   |" -ForeGroundColor Green
Write-Host "|                                                         |" -ForeGroundColor Green
Write-Host "|                Written By: Colby C                      |" -ForeGroundColor Green
Write-Host "|                                                         |" -ForeGroundColor Green
Write-Host "===========================================================" -ForeGroundColor Green
Write-Host ""

Write-Host ""
Write-Host "You are working on $env:ComputerName" -ForeGroundColor Green
Write-Host ""
$IPInfo = (Get-NetIPAddress -AddressFamily IPv4).IPAddress
Write-Host "The IP is $IPInfo" -ForeGroundColor Green
Write-Host ""
Write-Host "The domain is" (Get-ADDomain).DNSRoot  -ForeGroundColor Green
Write-Host ""
Write-Host "The domain controllers are:"  -ForeGroundColor Green
Write-Host "Name`t`tIPv4Address`tSite`t`tOperatingSystem" -ForegroundColor Green
Get-ADDomainController -Filter * | ForEach-Object {
    $name = $_.Name
    $ip = $_.IPv4Address
    $site = $_.Site
    $os = $_.OperatingSystem
    Write-Host "$name`t$ip`t$site`t$os" -ForegroundColor Green
}
Write-Host ""
Write-Host "The FSMO roles holders are:"  -ForeGroundColor Green
Write-Host "Schema Master : $((Get-ADForest).SchemaMaster)" -ForeGroundColor Green
Write-Host "Domain Naming Master : $((Get-ADForest).DomainNamingMaster)" -ForeGroundColor Green
Write-Host "PDC Emulator : $((Get-ADDomain).PDCEmulator)" -ForeGroundColor Green
Write-Host "RID Master : $((Get-ADDomain).RIDMaster)" -ForeGroundColor Green
Write-Host "Infrastructure Master : $((Get-ADDomain).InfrastructureMaster)"  -ForeGroundColor Green
Write-Host ""


#########################
##### Do The Thing #####
#######################
do {
    # Prompt the user to choose an option
    $userChoice = Prompt-User

    # Call the corresponding function based on the user's choice
    switch ($userChoice) {
        #Health checks (Complete)
        0 {
            #Ask the user to use default workdir or not
            $UserSetDir = Read-Host -Prompt "Enter the path you want to use for the working directory. Leave blank to use the default C:\FT\"
            if ([string]::isnullorempty($UserSetDir)){
                [string]$outputDir = Set-ProjectFolder
            }
            else {
                [string]$outputDir = Set-ProjectFolder -baseDir "$UserSetDir"
            }
            # Set some variables
            [string]$baseFilename = "HealthChecks"
            [string]$HName = $env:Computername
            [string]$DateTime = (Get-Date).ToString("MMddyy_HHmm")
            [string]$outputFile = "$outputDir\$Hname`_$baseFilename`_$DateTime.txt"

            #Generate the file
            New-Item -Path $outputFile -ItemType "file" -Force

            # Run the commands and write the output to the file
            Write-Host "Getting FSMO roles"
            Add-Content -Path $outputFile -Value "-----FSMO START-----"
            Write-OutPut "Schema Master : $((Get-ADForest).SchemaMaster)" | Add-Content -Path $outputFile
            Write-OutPut "Domain Naming Master : $((Get-ADForest).DomainNamingMaster)" | Add-Content -Path $outputFile
            Write-OutPut "PDC Emulator : $((Get-ADDomain).PDCEmulator)" | Add-Content -Path $outputFile
            Write-OutPut "RID Master : $((Get-ADDomain).RIDMaster)" | Add-Content -Path $outputFile
            Write-OutPut "Infrastructure Master : $((Get-ADDomain).InfrastructureMaster)" | Add-Content -Path $outputFile
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
        }
        #Pull users (Complete)
        1 {
            #Ask the user to use default workdir or not
            Write-Host "Enter the path you want to use for the working directory. Leave blank to use the default C:\FT\"
            $UserSetDir = Read-Host
            if ([string]::isnullorempty($UserSetDir)){
                [string]$outputDir = Set-ProjectFolder
            }
            else {
                [string]$outputDir = Set-ProjectFolder -baseDir "$UserSetDir"
            }
            $userType = Read-Host "Would you like to:
            1 - Pull all active users
            2 - Pull all users with administrative privileges"
            switch($userType){
                1{
                    # Set some variables
                    [string]$baseFilename = "Users"
                    [string]$domainName = Get-DomainName
                    [string]$DateTime = (Get-Date).ToString("MMddyy_HHmm")
                    [string]$outputFile = "$outputDir\$domainName`_$baseFilename`_$DateTime.csv"
                    
                    #Do the thing
                    Get-ADUser -Filter 'enabled -eq $true' -properties name,SamAccountName,CanonicalName,created,lastlogondate,mail,passwordlastset,passwordneverexpires,enabled | Select-Object name,SamAccountName,CanonicalName,created,lastlogondate,mail,passwordlastset,passwordneverexpires,enabled | Export-Csv $outputFile
                }
                2 {
                    # Set some variables
                    [string]$baseFilename = "AdminUsers"
                    [string]$domainName = Get-DomainName
                    [string]$DateTime = (Get-Date).ToString("MMddyy_HHmm")
                    [string]$outputFile = "$outputDir\$domainName`_$baseFilename`_$DateTime.csv"
                
                    #Do the thing
                    get-adgroupmember -Identity Administrators -Recursive | Select-Object name |foreach-object {Get-ADUser -filter "name -eq '$($_.name)'" -properties *} | select-object name,SamAccountName,CanonicalName,created,lastlogondate,mail,passwordlastset,passwordneverexpires,enabled | Export-CSV $outputFile
                }
                default{Write-Host "Invalid entry. Please enter 1 or 2." }
            }
        }
        #Pull computers (Complete)
        2 {
            #Ask the user to use default workdir or not
            Write-Host "Enter the path you want to use for the working directory. Leave blank to use the default C:\FT\"
            $UserSetDir = Read-Host
            if ([string]::isnullorempty($UserSetDir)){
                [string]$outputDir = Set-ProjectFolder
            }
            else {
                [string]$outputDir = Set-ProjectFolder -baseDir "$UserSetDir"
            }
            $pcType = Read-Host "Would you like to:
            1 - Pull all computers
            2 - Pull domain controllers"
            switch($pcType){
                1{
                    # Set some variables
                    [string]$baseFilename = "Computers"
                    [string]$domainName = Get-DomainName
                    [string]$DateTime = (Get-Date).ToString("MMddyy_HHmm")
                    [string]$outputFile = "$outputDir\$domainName`_$baseFilename`_$DateTime.csv"
                    
                    #Do the thing
                    get-adcomputer -filter * -properties name,LastLogonDate,OperatingSystem,description | select-object name,LastLogonDate,OperatingSystem,description | Export-Csv $outputFile
                }
                2{
                    # Set some variables
                    [string]$baseFilename = "DCs"
                    [string]$domainName = Get-DomainName
                    [string]$DateTime = (Get-Date).ToString("MMddyy_HHmm")
                    [string]$outputFile = "$outputDir\$domainName`_$baseFilename`_$DateTime.csv"

                    # Get the distinguished name of the Domain Controllers OU
                    $DcOu = (Get-ADOrganizationalUnit -Filter 'Name -eq "Domain Controllers"').DistinguishedName

                    # Use the distinguished name in the Get-ADComputer command
                    Get-ADComputer -Filter * -SearchBase $DcOu -Properties Name,LastLogonDate,OperatingSystem,Description | Select-Object Name,LastLogonDate,OperatingSystem,Description
                }
            }
        }
        #Set pw (Complete)
        3 {
            $PwCsvPath = Read-Host "Enter the path to the CSV with the list of SAM Account Names: "
            $CsvOrRand = Read-Host "Would you like to:
            1 - Generate random passwords
            2 - Use passwords listed in the CSV"

            switch ($CsvOrRand){
                1{
                    [int]$PwCharCnt = Read-Host "How many characters should the password be: "
                    Set-ADPasswordFromCSV -CsvName $PwCsvPath -PwLength $PwCharCnt
                }
                2{
                    Set-ADPasswordFromCSV -CsvName "C:\MyFolder\Users.csv" -PwFromCSV
                }
                default{
                    Write-Host "Please enter 1 for random passwords, or 2 for passwords from CSV."
                }
            }
        }
        #Remove pw no expire (Complete)
        4 {
            $AllOrCsv = Read-Host "Would you like to:
            1 - Remove the password never expires flag from all users
            2 - Remove the password never expires flag from users in a csv
            3 - Set the password never expires flag for users in a csv
            "
            switch ($AllOrCsv){
                1 {
                    $UserSetDir = Read-Host 'Enter the path for the working directory. i.e. C:\FT\ '
                    Set-PasswordNeverExpires -ProjectFolder $UserSetDir
                }
                2 {
                    $UserSetCSV = Read-Host 'Enter the path to the CSV with the list of SAM Account Names. i.e. C:\FT\Users.csv: '
                    $UserSetDir = Read-Host 'Enter the path for the working directory. i.e. C:\FT\ '
                    Set-PasswordNeverExpires -CsvName $UserSetCsv -ProjectFolder $UserSetDir
                }
                3 {
                    $UserSetCSV = Read-Host 'Enter the path to the CSV with the list of SAM Account Names. i.e. C:\FT\Users.csv: '
                    $UserSetDir = Read-Host 'Enter the path for the working directory. i.e. C:\FT\ '
                    Set-PasswordNeverExpires -CsvName $UserSetCsv -ProjectFolder $UserSetDir -SetEnable
                }
                default {
                    Write-Host "Please enter 1 for all users or 2 for users from CSV."
                }
            }
        }
        #Set pw expire (Complete)
        5 {
            $AllOrCsv = Read-Host "Would you like to:
            1 - Set the password to expire at next logon for all users
            2 - Set the password to expire at next logon for users from a csv
            "
            switch ($AllOrCsv){
                1 {
                    $UserSetDir = Read-Host 'Enter the path for the working directory. i.e. C:\FT\ '
                    Set-PwExpiresNextLogon -ProjectFolder $UserSetDir
                }
                2 {
                    $UserSetCSV = Read-Host 'Enter the path to the CSV with the list of SAM Account Names. i.e. C:\FT\Users.csv '
                    $UserSetDir = Read-Host 'Enter the path for the working directory. i.e. C:\FT\ '
                    Set-PwExpiresNextLogon -CsvName $UserSetCSV -ProjectFolder $UserSetDir
                }
                default {
                    Write-Host "Please enter 1 or 2"
                }
            }
        }
        #Disable accounts (Complete)
        6 {
            $UserSetCSV = Read-Host 'Enter the path to the CSV with the list of SAM Account Names. i.e. C:\FT\Users.csv '
            $UserSetDir = Read-Host 'Enter the path for the working directory. i.e. C:\FT\ '
            Disable-AdAccountFromCSV -CsvName $UserSetCSV -ProjectFolder $UserSetDir
        }
        #Set DNS (Complete)
        7 {
            #Ask the user for IPs
            Write-Host "Enter the Primary IP"
            $UserPrimaryIP = Read-Host
            Write-Host "Enter the Secondary IP"
            $UserSecondaryIP = Read-Host

            #Do the thing
            Set-DNS -Primary $UserPrimaryIP -Secondary $UserSecondaryIP
        }        
        #Purge DNS (WIP - Functional)
            <#Needs some troubleshooting...
            Gets a lot of the DNS entries, but not quite all of them#>
        8 {
            #Ask the user for the item to purge
            Write-Host "Enter what you want to remove. Such as DC01.Contoso.com, or 192.168.42.42"
            $UserItemToPurge = Read-Host

            #Do the thing
            Purge-DNSEntries -PurgeThis "$UserItemToPurge"

            #Inform user
            Write-Host "Make sure to doublecheck DNS.  This seems to leave a few stragglers some times." -ForeGroundColor Red
        }
        #Search DHCP (Complete)
        9 {
            #Ask the user for the item to purge
            Write-Host "Enter IP address that you want to search for."
            $UserIpToFind = Read-Host

            #Do the thing
            Get-DHCPLogInfo -IPAddress $UserIpToFind

            Read-Host -Prompt "Press any key to continue..."
        }
        #Scan a network range (Complete)
        10 {
            #Ask the user for IPs
            Write-Host "Enter the start IP"
            $UserStartIP = Read-Host
            Write-Host "Enter the end IP"
            $UserEndIP = Read-Host

            #Do the thing
            Scan-NetworkRange -StartRange $UserStartIP -EndRange $UserEndIP -OnlyActive

            Read-Host -Prompt "Press any key to continue..."
        }
        #Move FSMO roles (Complete)
        11 {
            #Ask the user to use this computer or not
            $UserSetPC = Read-Host "Enter the name of the computer to move roles to. Leave blank for this computer."
            if ([string]::isnullorempty($UserSetPC)){
                Move-FSMO
            }
            else {
                Move-FSMO -DestServer $UserSetPC
            }
        }
        12 {
            $DcToRmv = Read-Host "Enter the name of the Domain Controller you would like to perform a metadata cleanup for.  NOTE: This can NOT be undone. : "
            Invoke-MetaDataCleanup -DcToRemove $DcToRmv
        }
        13{
            $ADUser = "krbtgt"
            $ADPW = Get-RandomString
            $password = ConvertTo-SecureString -AsPlainText $ADPW -force
            Write-Host "Setting Password for " $ADUser " to " $ADPW
            Set-ADAccountPassword $ADUser -NewPassword $password -Reset
        }
        14 {
            $DomainName = Get-DomainName
            Get-OrphanedDomainControllers -DomainName $DomainName
        }
        15 {
            Invoke-ADSchemaReplicationAllDCs
        }
        99 {
            Write-Host "Thank you for using the AD Toolkit."
            Exit
        }
        
        default { Write-Output "Invalid choice. Please choose an option from 0 to 15, or 99." }
    }
} while ($userChoice -ne 99)