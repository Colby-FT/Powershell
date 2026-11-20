#Requires -Version 5.1

#####################
#region Header ######
<#
.SYNOPSIS
A toolkit of some common AD tasks

.DESCRIPTION
Menu-driven toolkit. Options:
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
11 - Move or seize FSMO roles to a different server
12 - Perform a metadata cleanup (Remove a demoted or tombstoned DC from AD)
13 - Reset the krbtgt (Kerberos) password
14 - Check for orphaned domain controllers
15 - Replicate AD Schema between all DCs
99 - Exit

Path prompts accept input with or without quotes, and with or without a trailing backslash.
All CSV exports are written as UTF-8, without the #TYPE information line.
#>

#endregion Header ######

#######################
#region Functions ######
#####################
#Function to clean up typed input (whitespace and wrapping quotes)
function ConvertTo-CleanInput {
    <#
    .SYNOPSIS
        Trims whitespace and wrapping quotes from typed input.

    .DESCRIPTION
        Removes leading/trailing whitespace and any straight or smart quotes
        (" ' and the curly versions pasted from Word/Teams/Outlook).

    .PARAMETER InputString
        The raw text to clean.

    .EXAMPLE
        ConvertTo-CleanInput '"DC01" '
        Returns DC01
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$InputString
    )

    Process {
        if ([string]::IsNullOrWhiteSpace($InputString)) {
            return ''
        }
        $QuoteChars = [char[]]@([char]0x22, [char]0x27, [char]0x201C, [char]0x201D, [char]0x2018, [char]0x2019)
        return $InputString.Trim().Trim($QuoteChars).Trim()
    }
}

#Function to normalize a path typed by the user
function Resolve-UserPath {
    <#
    .SYNOPSIS
        Normalizes a user-supplied file or folder path.

    .DESCRIPTION
        Accepts paths with or without wrapping quotes, and with or without a trailing
        backslash, so "C:\FT\", C:\FT\, "C:\FT" and C:\FT all resolve to C:\FT.
        Drive roots keep their backslash (C:\). Environment variables such as
        %USERPROFILE% are expanded. Blank input returns an empty string.

    .PARAMETER Path
        The raw path text.

    .EXAMPLE
        Resolve-UserPath '"C:\FT\Users.csv"'
        Returns C:\FT\Users.csv

    .EXAMPLE
        Resolve-UserPath 'C:\FT\'
        Returns C:\FT
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Path
    )

    Process {
        $Clean = ConvertTo-CleanInput -InputString $Path
        if ([string]::IsNullOrEmpty($Clean)) {
            return ''
        }

        $Clean = [System.Environment]::ExpandEnvironmentVariables($Clean)
        $Clean = $Clean.TrimEnd([char[]]@('\', '/'))

        # Keep the backslash on a drive root, otherwise "C:" means "current folder on C:"
        if ($Clean -match '^[A-Za-z]:$') {
            $Clean = "$Clean\"
        }

        Write-Verbose "[$($MyInvocation.InvocationName)] '$Path' -> '$Clean'"
        return $Clean
    }
}

#Function to prompt for a path and validate it
function Read-UserPath {
    <#
    .SYNOPSIS
        Prompts for a path and normalizes it.

    .DESCRIPTION
        Reads a path from the console, normalizes it with Resolve-UserPath, and
        optionally re-prompts until the file exists. Blank input returns an empty
        string so the caller can apply a default or cancel.

    .PARAMETER Prompt
        The prompt text to display.

    .PARAMETER RequireFile
        Re-prompt until the path points to an existing file. Blank input cancels.

    .EXAMPLE
        $Csv = Read-UserPath -Prompt "Enter the path to the CSV" -RequireFile
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory, Position = 0)]
        [string]$Prompt,

        [switch]$RequireFile
    )

    while ($true) {
        $UserPath = Resolve-UserPath -Path (Read-Host -Prompt $Prompt)

        if ([string]::IsNullOrEmpty($UserPath)) {
            return ''
        }
        if (-not $RequireFile -or (Test-Path -LiteralPath $UserPath -PathType Leaf)) {
            return $UserPath
        }
        Write-Warning "File not found: $UserPath. Try again, or leave blank to cancel."
    }
}

#Function to find a CSV column by name, tolerating case and stray spaces
function Resolve-CsvColumn {
    <#
    .SYNOPSIS
        Returns the actual CSV header that matches a column name.

    .DESCRIPTION
        Import-Csv keeps stray spaces in headers ("SamAccountName "), which makes
        $Row.SamAccountName silently return nothing. This finds the header whose trimmed
        name matches (not case-sensitive) and returns it exactly as it appears in the file.
        Throws a clear error listing the available columns when there is no match.

    .PARAMETER Rows
        The rows returned by Import-Csv.

    .PARAMETER ColumnName
        The column to find.

    .PARAMETER CsvPath
        The CSV path, used in the error message.

    .EXAMPLE
        $UserColumn = Resolve-CsvColumn -Rows $Rows -ColumnName 'SamAccountName' -CsvPath $CsvName
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Rows,

        [Parameter(Mandatory)]
        [string]$ColumnName,

        [string]$CsvPath
    )

    if ($Rows.Count -eq 0) {
        return $ColumnName
    }

    $Headers = @($Rows[0].PSObject.Properties.Name)
    $Match = $Headers | Where-Object { $_.Trim() -eq $ColumnName.Trim() } | Select-Object -First 1
    if (-not $Match) {
        throw "Column '$ColumnName' not found in '$CsvPath'. Columns in the file: $($Headers -join ', ')"
    }
    return $Match
}

#Function to preview a CSV-driven change and get a Y/N before anything is modified
function Show-CsvChangePreview {
    <#
    .SYNOPSIS
        Shows what a CSV-driven change will do and asks for confirmation.

    .DESCRIPTION
        Imports the CSV, finds the account column (case and stray spaces in the header
        are tolerated), and displays the file, the account count, how many blank rows
        will be skipped, the first few account names, and the action about to run.
        Returns $true only when the user answers Y. Nothing is modified.

    .PARAMETER CsvPath
        Path to the CSV file.

    .PARAMETER ColumnTitle
        The expected name of the account column. Default SamAccountName.

    .PARAMETER ExtraColumnTitle
        Optional: a second column that must exist (for example Password).

    .PARAMETER Action
        One-line description of the change about to be made.

    .EXAMPLE
        Show-CsvChangePreview -CsvPath $Csv -Action "Reset password (random, 14 characters)"
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory, Position = 0)]
        [string]$CsvPath,

        [Parameter(Position = 1)]
        [string]$ColumnTitle = 'SamAccountName',

        [Parameter(Position = 2)]
        [string]$ExtraColumnTitle,

        [Parameter(Mandatory, Position = 3)]
        [string]$Action
    )

    try {
        $Rows = @(Import-Csv -LiteralPath $CsvPath -ErrorAction Stop)
    }
    catch {
        Write-Warning "Could not read '$CsvPath': $($_.Exception.Message)"
        return $false
    }
    if ($Rows.Count -eq 0) {
        Write-Warning "The CSV '$CsvPath' contains no rows."
        return $false
    }

    try {
        $Column = Resolve-CsvColumn -Rows $Rows -ColumnName $ColumnTitle -CsvPath $CsvPath
        $ExtraColumn = $null
        if (-not [string]::IsNullOrEmpty($ExtraColumnTitle)) {
            $ExtraColumn = Resolve-CsvColumn -Rows $Rows -ColumnName $ExtraColumnTitle -CsvPath $CsvPath
        }
    }
    catch {
        Write-Warning $_.Exception.Message
        return $false
    }

    $Names = @($Rows | ForEach-Object { ([string]$_.$Column).Trim() } | Where-Object { $_ })
    $BlankRows = $Rows.Count - $Names.Count

    Write-Information "`nFile:     $CsvPath" -InformationAction Continue
    $AccountLine = "Accounts: $($Names.Count)"
    if ($BlankRows -gt 0) { $AccountLine += " ($BlankRows blank row(s) will be skipped)" }
    Write-Information $AccountLine -InformationAction Continue
    $FirstFew = ($Names | Select-Object -First 5) -join ', '
    if ($Names.Count -gt 5) { $FirstFew += ', ...' }
    Write-Information "First 5:  $FirstFew" -InformationAction Continue
    if ($ExtraColumn) { Write-Information "Columns:  accounts from '$($Column.Trim())', passwords from '$($ExtraColumn.Trim())'" -InformationAction Continue }
    Write-Information "Action:   $Action" -InformationAction Continue

    return ((ConvertTo-CleanInput -InputString (Read-Host "Proceed? (Y/N)")) -eq 'Y')
}

#Function to select the accounts an "all users" bulk change may touch
function Get-AdUserForBulkChange {
    <#
    .SYNOPSIS
        Returns the user accounts that an "all users" bulk change should touch.

    .DESCRIPTION
        Returns ENABLED accounts only, and always excludes krbtgt and the per-RODC
        krbtgt_<number> accounts. Their passwords are managed by option 13 (and by
        the RODC), so a bulk flag change must never touch them.

    .EXAMPLE
        Get-AdUserForBulkChange
    #>
    [CmdletBinding()]
    [OutputType('Microsoft.ActiveDirectory.Management.ADUser')]
    param ()

    # krbtgt accounts are disabled by default, so Enabled alone normally excludes them.
    # The name checks keep them out even if one has been enabled.
    Get-ADUser -Filter 'Enabled -eq $true -and SamAccountName -ne "krbtgt" -and SamAccountName -notlike "krbtgt_*"' -Properties SamAccountName -ErrorAction Stop
}

#Function to require typed confirmation before a destructive action
function Confirm-Action {
    <#
    .SYNOPSIS
        Requires the operator to type a phrase before a destructive action.

    .DESCRIPTION
        Shows a warning and returns $true only if the operator types ConfirmText
        exactly (not case-sensitive). Anything else cancels.

    .PARAMETER Message
        What is about to happen.

    .PARAMETER ConfirmText
        The text required to proceed. Default is YES.

    .EXAMPLE
        if (Confirm-Action -Message "Move all FSMO roles to DC02" -ConfirmText DC02) { Move-FSMO -DestServer DC02 }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory, Position = 0)]
        [string]$Message,

        [Parameter(Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfirmText = 'YES'
    )

    Write-Warning $Message
    $Response = ConvertTo-CleanInput -InputString (Read-Host "Type '$ConfirmText' to continue, or anything else to cancel")

    if ($Response -eq $ConfirmText) {
        return $true
    }

    Write-Information "Action cancelled." -InformationAction Continue
    return $false
}
#Function to create the working directory
function Set-ProjectFolder {
    <#
    .SYNOPSIS
    Create a project folder

    .DESCRIPTION
    The default (with no parameters) is to create C:\FT

    .PARAMETER BaseDir
    Base folder. Default is FT on the system drive (C:\FT).

    .PARAMETER TaskDir
    Optional subfolder to create under BaseDir.

    .PARAMETER ChangeDir
    Change the current location to the folder after creating it.

    .EXAMPLE
    Set-ProjectFolder
    Creates C:\FT

    .EXAMPLE
    Set-ProjectFolder -TaskDir "WorkWork" -ChangeDir
    Creates C:\FT\WorkWork and changes to that directory

    .EXAMPLE
    $ProjectFolder = Set-ProjectFolder -TaskDir "Work\Work"
    Creates C:\FT\Work\Work and assigns the path to the variable $ProjectFolder

    .EXAMPLE
    Set-ProjectFolder -BaseDir "D:\WorkDir" -ChangeDir
    Overrides the default base directory, creates D:\WorkDir, and changes to that directory

    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [string]$BaseDir = "$env:SystemDrive\FT",
        [string]$TaskDir,
        [switch]$ChangeDir
    )
    process {
        # Normalize input (quotes / trailing backslash). Blank falls back to the default.
        $BaseDir = Resolve-UserPath -Path $BaseDir
        if ([string]::IsNullOrEmpty($BaseDir)) {
            $BaseDir = "$env:SystemDrive\FT"
        }
        $TaskDir = (Resolve-UserPath -Path $TaskDir).TrimStart([char[]]@('\', '/'))

        if ([string]::IsNullOrEmpty($TaskDir)) {
            $TargetDir = $BaseDir
        }
        else {
            $TargetDir = Join-Path -Path $BaseDir -ChildPath $TaskDir
        }

        #If the path doesn't exist - Make it. Output is discarded so only the path string is returned.
        #-WhatIf:$false so a -WhatIf run in a calling function still has a folder for its log.
        if (-not (Test-Path -LiteralPath $TargetDir -PathType Container)) {
            $null = New-Item -Path $TargetDir -ItemType Directory -Force -WhatIf:$false -Confirm:$false -ErrorAction Stop
        }
    }
    end {
        #Set working dir
        if ($ChangeDir) {
            Set-Location -LiteralPath $TargetDir
        }
        #Return path for working dir
        return $TargetDir
    }
}

#Function to validate an IPv4 address string (single source for the old copied regexes)
function Test-IPv4Address {
    <#
    .SYNOPSIS
        Returns $true when the input is a valid IPv4 address.

    .DESCRIPTION
        Validates four dot-separated octets, each 0-255. Use anywhere an IP is
        accepted, including inside [ValidateScript(...)] attribute blocks.

    .PARAMETER Address
        The string to test. Empty/null returns $false.

    .EXAMPLE
        Test-IPv4Address -Address '192.168.1.10'
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Position = 0)]
        [AllowEmptyString()]
        [string]$Address
    )
    [bool]($Address -match '^((25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(25[0-5]|2[0-4]\d|1?\d?\d)$')
}

#Function to build a timestamped report path (single source for the old copied blocks)
function New-ReportPath {
    <#
    .SYNOPSIS
        Builds a timestamped report file path.

    .DESCRIPTION
        Combines the output folder, an optional prefix, a base name, a timestamp,
        and an extension into one path: <Prefix>_<BaseName>_MMddyy_HHmm.<Extension>

    .PARAMETER OutputDir
        Folder the report goes into.

    .PARAMETER BaseName
        Report type, such as 'Users' or 'HealthChecks'.

    .PARAMETER Extension
        File extension without the dot. Default csv.

    .PARAMETER Prefix
        Optional file-name prefix (usually the domain name).

    .EXAMPLE
        New-ReportPath -OutputDir C:\FT -BaseName Users -Prefix contoso
        Returns C:\FT\contoso_Users_103026_1455.csv
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory, Position = 0)]
        [string]$OutputDir,

        [Parameter(Mandatory, Position = 1)]
        [string]$BaseName,

        [Parameter(Position = 2)]
        [ValidateSet('csv', 'txt', 'log', 'json')]
        [string]$Extension = 'csv',

        [Parameter(Position = 3)]
        [string]$Prefix
    )
    $DateTime = (Get-Date).ToString('MMddyy_HHmm')
    $Name = if ([string]::IsNullOrEmpty($Prefix)) { "$($BaseName)_$DateTime.$Extension" }
            else { "$($Prefix)_$($BaseName)_$DateTime.$Extension" }
    Join-Path -Path $OutputDir -ChildPath $Name
}

#Function to prompt for a save path and export results to CSV (options 10 and 14)
function Save-ReportCsv {
    <#
    .SYNOPSIS
        Asks where to save results and writes them to a CSV file.

    .DESCRIPTION
        Prompts for a folder or .csv path. A folder (or any path without a file
        extension) gets a timestamped <BaseName>_MMddyy_HHmm.csv file. Creates
        missing folders. Writes UTF-8. Returns the saved path, or $null when the user
        skips or the save fails.

    .PARAMETER InputObject
        The results to save.

    .PARAMETER BaseName
        Default file name used when a folder is given, such as 'NetworkScan'.

    .PARAMETER Prompt
        The prompt text shown to the user.

    .EXAMPLE
        Save-ReportCsv -InputObject $ScanResults -BaseName NetworkScan
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyCollection()]
        [object[]]$InputObject,

        [Parameter(Mandatory, Position = 1)]
        [string]$BaseName,

        [Parameter(Position = 2)]
        [string]$Prompt = 'Enter a folder or .csv path to save these results, or leave blank to skip'
    )
    $SaveCsv = Read-UserPath -Prompt $Prompt
    if ([string]::IsNullOrEmpty($SaveCsv)) {
        return $null
    }
    if ((Test-Path -LiteralPath $SaveCsv -PathType Container) -or [string]::IsNullOrEmpty([System.IO.Path]::GetExtension($SaveCsv))) {
        $SaveCsv = Join-Path -Path $SaveCsv -ChildPath "$($BaseName)_$((Get-Date).ToString('MMddyy_HHmm')).csv"
    }
    try {
        $SaveDir = Split-Path -Path $SaveCsv -Parent
        if ($SaveDir -and -not (Test-Path -LiteralPath $SaveDir -PathType Container)) {
            $null = New-Item -Path $SaveDir -ItemType Directory -Force -ErrorAction Stop
        }
        $InputObject | Export-Csv -LiteralPath $SaveCsv -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        Write-Warning "Could not save to $SaveCsv : $($_.Exception.Message)"
        return $null
    }
    Write-Information "Saved to $SaveCsv" -InformationAction Continue
    return $SaveCsv
}

#Function to get the domain name
function Get-DomainName {
    <#
    .SYNOPSIS
        Gets the domain name of the current computer.

    .DESCRIPTION
        Reads the Domain property of Win32_ComputerSystem. Writes an error and
        returns "UnknownDomain" if it cannot be read.

    .EXAMPLE
        $DomainName = Get-DomainName
    #>
    Process {
        try {
            $domainName = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).Domain
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
        Searches the DHCP server audit logs for an exact IPv4 address.

    .DESCRIPTION
        Searches every DhcpSrvLog-*.log audit log for lines containing the IPv4 address as a
        whole address: 10.1.1.1 does not match 10.1.1.10, 10.1.1.123 or 110.1.1.1.

        Uses the audit log path configured on the DHCP server when the DhcpServer module is
        available, otherwise %SystemRoot%\System32\dhcp.

        Windows keeps one audit log per weekday and overwrites it the following week, so
        results cover roughly the last 7 days.

    .PARAMETER IPAddress
        The IPv4 address to search for.

    .PARAMETER LogPath
        Folder containing the DHCP audit logs. Defaults to the server's configured audit log path.

    .EXAMPLE
        Get-DHCPLogInfo -IPAddress 10.10.32.64
        Returns every audit log entry for exactly 10.10.32.64

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory, Position = 0)]
        [ValidateScript({
            if (Test-IPv4Address -Address $_) { $true }
            else { throw "'$_' is not a valid IPv4 address (four octets, each 0-255)." }
        })]
        [string]$IPAddress,

        [Parameter(Position = 1)]
        [string]$LogPath
    )

    if ([string]::IsNullOrEmpty($LogPath)) {
        $LogPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\dhcp'
        if (Get-Command -Name Get-DhcpServerAuditLog -ErrorAction SilentlyContinue) {
            try {
                $ConfiguredPath = (Get-DhcpServerAuditLog -ErrorAction Stop).Path
                if (-not [string]::IsNullOrEmpty($ConfiguredPath)) {
                    $LogPath = $ConfiguredPath
                }
            }
            catch {
                Write-Verbose "[$($MyInvocation.InvocationName)] Could not read the configured audit log path; using $LogPath. $($_.Exception.Message)"
            }
        }
    }

    $LogFiles = @(Get-ChildItem -LiteralPath $LogPath -Filter 'DhcpSrvLog-*.log' -File -ErrorAction SilentlyContinue)
    if ($LogFiles.Count -eq 0) {
        Write-Warning "No DHCP audit logs (DhcpSrvLog-*.log) found in $LogPath. Run this on the DHCP server and confirm audit logging is enabled."
        return
    }

    # Whole-address match: not preceded or followed by a digit or a dot
    $Pattern = '(?<![\d.])' + [regex]::Escape($IPAddress) + '(?![\d.])'

    foreach ($LogFile in $LogFiles) {
        Write-Verbose "[$($MyInvocation.InvocationName)] Searching $($LogFile.Name)"
        try {
            $LineNumber = 0
            # Get-Content can read the current day's log while the DHCP service has it open
            foreach ($Line in (Get-Content -LiteralPath $LogFile.FullName -ErrorAction Stop)) {
                $LineNumber++
                if ($Line -match $Pattern) {
                    [pscustomobject]@{
                        LogFile    = $LogFile.Name
                        LineNumber = $LineNumber
                        Entry      = $Line
                    }
                }
            }
        }
        catch {
            Write-Warning "Could not read $($LogFile.FullName): $($_.Exception.Message)"
        }
    }
}

#Function to purge entries from DNS
function Remove-DnsEntry {
    <#
    .SYNOPSIS
        Removes DNS records that refer to a specific host name or IPv4 address.

    .DESCRIPTION
        Searches every primary, non-auto-created zone on the DNS server, collects the records
        that refer to the value provided, shows them, and removes them after confirmation.

        Matching is exact, never partial:
        - Short name (DC01): records whose owner name or target has DC01 as its first label,
          such as dc01.contoso.com and dc01.child.contoso.com. DC010, OLDDC01 and DC01-BACKUP do not match.
        - FQDN (DC01.contoso.com): only that exact FQDN.
        - IPv4 address: A records with that address, and the PTR record for that address.

        Owner names are never matched on zone-apex (@) records, so a name can never remove a
        zone's own NS/SOA/A records by owner. Apex records are still matched by their target or address.

        Record types: A, AAAA, CNAME, NS, MX, SRV, PTR. SOA records that name the host as
        primary server are reported, not edited.

        To fully clean up a removed DC, run this for both its name AND its IP address
        (same-as-parent, DomainDnsZones and ForestDnsZones A records only match by IP).

    .PARAMETER PurgeThis
        Host name, FQDN, or IPv4 address. Accepts multiple values and pipeline input.

    .PARAMETER ComputerName
        DNS server to operate on. Defaults to this computer.

    .PARAMETER Force
        Skip the typed confirmation. -WhatIf is still honored.

    .EXAMPLE
        Remove-DnsEntry -PurgeThis DC01 -WhatIf
        Shows every record that would be removed for DC01

    .EXAMPLE
        Remove-DnsEntry -PurgeThis DC01.contoso.com, 192.168.42.42
        Removes records for that FQDN and that IP after confirmation

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$PurgeThis,

        [Parameter()]
        [string]$ComputerName = $env:COMPUTERNAME,

        [switch]$Force
    )

    Begin {
        try {
            $Zones = @(Get-DnsServerZone -ComputerName $ComputerName -ErrorAction Stop |
                Where-Object { -not $_.IsAutoCreated -and $_.ZoneType -eq 'Primary' -and $_.ZoneName -ne 'TrustAnchors' })
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    $_.Exception,
                    'DnsZoneQueryFailed',
                    [System.Management.Automation.ErrorCategory]::ConnectionError,
                    $ComputerName
                )
            )
        }
        Write-Verbose "[$($MyInvocation.InvocationName)] Searching $($Zones.Count) zone(s) on $ComputerName"
    }

    Process {
        foreach ($RawValue in $PurgeThis) {
            $Value = (ConvertTo-CleanInput -InputString $RawValue).TrimEnd('.')
            if ([string]::IsNullOrEmpty($Value)) {
                continue
            }

            $IsIP   = Test-IPv4Address -Address $Value
            $IsFqdn = (-not $IsIP) -and $Value.Contains('.')
            $PtrOwner = $null
            if ($IsIP) {
                $Octets = $Value.Split('.')
                [Array]::Reverse($Octets)
                $PtrOwner = ($Octets -join '.') + '.in-addr.arpa'
            }

            # Exact name test: full FQDN for FQDN input, first label for short-name input
            $TestName = {
                param ([string]$Name)
                if ([string]::IsNullOrEmpty($Name)) { return $false }
                $Name = $Name.TrimEnd('.')
                if ($IsFqdn) { return ($Name -eq $Value) }
                return ($Name.Split('.')[0] -eq $Value)
            }

            $Found   = [System.Collections.Generic.List[object]]::new()
            $SoaHits = [System.Collections.Generic.List[string]]::new()

            foreach ($Zone in $Zones) {
                try {
                    $Records = @(Get-DnsServerResourceRecord -ZoneName $Zone.ZoneName -ComputerName $ComputerName -ErrorAction Stop)
                }
                catch {
                    Write-Warning "Failed to read zone $($Zone.ZoneName): $($_.Exception.Message)"
                    continue
                }

                foreach ($Record in $Records) {
                    $Owner = if ($Record.HostName -eq '@') { $Zone.ZoneName } else { "$($Record.HostName).$($Zone.ZoneName)" }
                    $Target = switch ($Record.RecordType) {
                        'CNAME' { $Record.RecordData.HostNameAlias }
                        'NS'    { $Record.RecordData.NameServer }
                        'MX'    { $Record.RecordData.MailExchange }
                        'SRV'   { $Record.RecordData.DomainName }
                        'PTR'   { $Record.RecordData.PtrDomainName }
                        'SOA'   { $Record.RecordData.PrimaryServer }
                        'A'     { $Record.RecordData.IPv4Address.IPAddressToString }
                        'AAAA'  { $Record.RecordData.IPv6Address.IPAddressToString }
                        default { $null }
                    }

                    $Reason = $null
                    if ($IsIP) {
                        if ($Record.RecordType -eq 'A' -and $Target -eq $Value) {
                            $Reason = 'A record has this address'
                        }
                        elseif ($Record.RecordType -eq 'PTR' -and $Owner -eq $PtrOwner) {
                            $Reason = 'PTR record for this address'
                        }
                    }
                    elseif ($Record.RecordType -eq 'SOA') {
                        if (& $TestName $Target) {
                            $SoaHits.Add($Zone.ZoneName)
                        }
                        continue
                    }
                    elseif ($Record.HostName -ne '@' -and (& $TestName $Owner)) {
                        $Reason = 'Owner name'
                    }
                    elseif ($Record.RecordType -in 'CNAME', 'NS', 'MX', 'SRV', 'PTR' -and (& $TestName $Target)) {
                        $Reason = "Points to this host ($($Record.RecordType))"
                    }

                    if ($Reason) {
                        $Found.Add([pscustomobject]@{
                            Zone   = $Zone.ZoneName
                            Owner  = $Owner
                            Type   = $Record.RecordType
                            Data   = $Target
                            Reason = $Reason
                            Record = $Record
                        })
                    }
                }
            }

            if ($SoaHits.Count -gt 0) {
                Write-Warning "$Value is the SOA primary server of: $($SoaHits -join ', '). SOA records are not edited; change the primary server in DNS Manager (zone Properties > Start of Authority)."
            }

            if ($Found.Count -eq 0) {
                Write-Information "No DNS records found for $Value." -InformationAction Continue
                continue
            }

            $Preview = $Found | Select-Object Zone, Owner, Type, Data, Reason | Format-Table -AutoSize | Out-String
            Write-Information "DNS records matching '$Value':$Preview" -InformationAction Continue

            if (-not $Force -and -not $WhatIfPreference) {
                if (-not (Confirm-Action -Message "Delete the $($Found.Count) DNS record(s) above for $Value?" -ConfirmText 'DELETE')) {
                    continue
                }
            }

            foreach ($Item in $Found) {
                if ($PSCmdlet.ShouldProcess("$($Item.Type) $($Item.Owner) -> $($Item.Data) [zone $($Item.Zone)]", 'Remove DNS record')) {
                    $Result = 'Removed'
                    try {
                        Remove-DnsServerResourceRecord -ZoneName $Item.Zone -InputObject $Item.Record -ComputerName $ComputerName -Force -ErrorAction Stop
                    }
                    catch {
                        $Result = "Failed: $($_.Exception.Message)"
                    }
                    [pscustomobject]@{
                        Zone   = $Item.Zone
                        Owner  = $Item.Owner
                        Type   = $Item.Type
                        Data   = $Item.Data
                        Result = $Result
                    }
                }
            }
        }
    }
}

#Function to find active hosts in a network range
function Find-NetworkHost {
    <#
    .SYNOPSIS
        Scans a range of IPv4 addresses for hosts that reply to ping.

    .DESCRIPTION
        Treats the range as 32-bit integers so any start/end pair works across octet
        boundaries. Pings are sent in parallel batches with a timeout. Responding hosts
        get a reverse DNS lookup. Returns one object per address.

        A host that does not reply may still be online - Windows Firewall blocks ICMP
        echo by default on many systems.

    .PARAMETER StartRange
        First IPv4 address in the range.

    .PARAMETER EndRange
        Last IPv4 address in the range.

    .PARAMETER OnlyActive
        Only return hosts that replied.

    .PARAMETER TimeoutMs
        Ping timeout in milliseconds. Default 1000.

    .PARAMETER BatchSize
        Number of simultaneous pings. Default 256.

    .PARAMETER NoHostname
        Skip reverse DNS lookups (faster).

    .PARAMETER Force
        Skip the confirmation prompt for ranges larger than 1,024 addresses.

    .EXAMPLE
        Find-NetworkHost -StartRange 192.168.1.1 -EndRange 192.168.1.254 -OnlyActive

    .EXAMPLE
        Find-NetworkHost 10.1.1.200 10.1.2.10 | Export-Csv C:\FT\Scan.csv -NoTypeInformation -Encoding UTF8

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory, Position = 0)]
        [ValidateScript({
            if (Test-IPv4Address -Address $_) { $true }
            else { throw "'$_' is not a valid IPv4 address (four octets, each 0-255)." }
        })]
        [string]$StartRange,

        [Parameter(Mandatory, Position = 1)]
        [ValidateScript({
            if (Test-IPv4Address -Address $_) { $true }
            else { throw "'$_' is not a valid IPv4 address (four octets, each 0-255)." }
        })]
        [string]$EndRange,

        [switch]$OnlyActive,

        [ValidateRange(100, 10000)]
        [int]$TimeoutMs = 1000,

        [ValidateRange(1, 1024)]
        [int]$BatchSize = 256,

        [switch]$NoHostname,

        [switch]$Force
    )

    #region Helpers
    $ToNumber = {
        param ([string]$Address)
        $Bytes = [System.Net.IPAddress]::Parse($Address).GetAddressBytes()
        [Array]::Reverse($Bytes)
        [long][BitConverter]::ToUInt32($Bytes, 0)
    }
    $ToAddress = {
        param ([long]$Number)
        $Bytes = [BitConverter]::GetBytes([uint32]$Number)
        [Array]::Reverse($Bytes)
        [System.Net.IPAddress]::new($Bytes).ToString()
    }
    #endregion Helpers

    #region Validation
    $Start = & $ToNumber $StartRange
    $End   = & $ToNumber $EndRange

    if ($Start -gt $End) {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.ArgumentException]::new("StartRange ($StartRange) is after EndRange ($EndRange)."),
                'InvalidRange',
                [System.Management.Automation.ErrorCategory]::InvalidArgument,
                "$StartRange-$EndRange"
            )
        )
    }

    $Count = $End - $Start + 1
    if ($Count -gt 1024 -and -not $Force) {
        $Minutes = [math]::Ceiling(([math]::Ceiling($Count / $BatchSize) * ($TimeoutMs / 1000)) / 60)
        if (-not $PSCmdlet.ShouldContinue("Scan $Count addresses? Worst case is about $Minutes minute(s).", 'Large network scan')) {
            return
        }
    }
    #endregion Validation

    #region Scan
    $Scanned = 0
    for ($BatchStart = $Start; $BatchStart -le $End; $BatchStart += $BatchSize) {
        $BatchEnd = [math]::Min($BatchStart + $BatchSize - 1, $End)
        $Pending  = [System.Collections.Generic.List[object]]::new()

        try {
            for ($n = $BatchStart; $n -le $BatchEnd; $n++) {
                $Address = & $ToAddress $n
                $Pinger  = [System.Net.NetworkInformation.Ping]::new()
                $Task    = $null
                try {
                    $Task = $Pinger.SendPingAsync($Address, $TimeoutMs)
                }
                catch {
                    Write-Verbose "[$($MyInvocation.InvocationName)] Could not ping $Address : $($_.Exception.Message)"
                }
                $Pending.Add([pscustomobject]@{ IPAddress = $Address; Pinger = $Pinger; Task = $Task })
            }

            $Tasks = @($Pending | Where-Object { $null -ne $_.Task } | ForEach-Object { $_.Task })
            if ($Tasks.Count -gt 0) {
                try {
                    [System.Threading.Tasks.Task]::WaitAll([System.Threading.Tasks.Task[]]$Tasks)
                }
                catch {
                    # Individual faulted pings are handled per item below
                    Write-Verbose "[$($MyInvocation.InvocationName)] One or more pings faulted in this batch."
                }
            }

            # Collect the ping replies first
            $BatchResults = [System.Collections.Generic.List[object]]::new()
            foreach ($Item in $Pending) {
                $Reply = $null
                if ($null -ne $Item.Task -and $Item.Task.Status -eq [System.Threading.Tasks.TaskStatus]::RanToCompletion) {
                    $Reply = $Item.Task.Result
                }
                $IsActive = ($null -ne $Reply) -and ($Reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success)
                if (-not $IsActive -and $OnlyActive) {
                    continue
                }
                $BatchResults.Add([pscustomobject]@{ IPAddress = $Item.IPAddress; IsActive = $IsActive; Reply = $Reply; DnsTask = $null })
            }

            # Reverse DNS for the whole batch in parallel. A failed lookup can take several seconds
            # (DNS retry timeouts), and doing them one at a time is what made large scans slow.
            if (-not $NoHostname) {
                foreach ($Entry in $BatchResults) {
                    if ($Entry.IsActive) {
                        try {
                            $Entry.DnsTask = [System.Net.Dns]::GetHostEntryAsync($Entry.IPAddress)
                        }
                        catch {
                            Write-Verbose "[$($MyInvocation.InvocationName)] Could not start a name lookup for $($Entry.IPAddress) : $($_.Exception.Message)"
                        }
                    }
                }
                $LookupTasks = @($BatchResults | Where-Object { $null -ne $_.DnsTask } | ForEach-Object { $_.DnsTask })
                if ($LookupTasks.Count -gt 0) {
                    try {
                        # Cap the wait so a slow DNS server cannot stall the whole scan
                        [void][System.Threading.Tasks.Task]::WaitAll([System.Threading.Tasks.Task[]]$LookupTasks, 5000)
                    }
                    catch {
                        Write-Verbose "[$($MyInvocation.InvocationName)] One or more name lookups failed in this batch."
                    }
                }
            }

            foreach ($Entry in $BatchResults) {
                $HostName = $null
                if ($Entry.IsActive -and -not $NoHostname) {
                    if ($null -ne $Entry.DnsTask -and $Entry.DnsTask.Status -eq [System.Threading.Tasks.TaskStatus]::RanToCompletion) {
                        $HostName = $Entry.DnsTask.Result.HostName
                    }
                    else {
                        $HostName = 'Hostname not found'
                    }
                }
                [pscustomobject]@{
                    IPAddress      = $Entry.IPAddress
                    Status         = if ($Entry.IsActive) { 'Active' } else { 'Inactive' }
                    HostName       = $HostName
                    ResponseTimeMs = if ($Entry.IsActive) { $Entry.Reply.RoundtripTime } else { $null }
                }
            }
        }
        finally {
            foreach ($Item in $Pending) {
                $Item.Pinger.Dispose()
            }
        }

        $Scanned += ($BatchEnd - $BatchStart + 1)
        Write-Progress -Activity "Scanning $StartRange - $EndRange" -Status "$Scanned of $Count" -PercentComplete (($Scanned / $Count) * 100)
    }

    Write-Progress -Activity "Scanning $StartRange - $EndRange" -Completed
    #endregion Scan
}

#Function to suggest DNS servers for this device
function Get-SuggestedDnsServer {
    <#
    .SYNOPSIS
        Suggests the primary and secondary DNS servers for this device.

    .DESCRIPTION
        On a server that runs DNS (normally a DC): another DC first, this server
        (127.0.0.1) second. Microsoft's Best Practices Analyzer flags loopback as the
        first DNS server when other DCs exist. If no other DNS server answers,
        127.0.0.1 alone.

        On any other device: two other DCs. 127.0.0.1 is never suggested, because
        nothing on this device would answer.

        Other DCs in this device's AD site are preferred. A DC is only suggested if it
        answers a DNS query.

    .PARAMETER MaxCandidates
        How many DCs to test before giving up. Default 6.

    .EXAMPLE
        Get-SuggestedDnsServer
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [ValidateRange(1, 50)]
        [int]$MaxCandidates = 6
    )

    $LocalRunsDns = [bool](Get-Service -Name DNS -ErrorAction SilentlyContinue)

    $LocalSite = $null
    try {
        $LocalSite = [System.DirectoryServices.ActiveDirectory.ActiveDirectorySite]::GetComputerSite().Name
    }
    catch {
        Write-Verbose "[$($MyInvocation.InvocationName)] Could not determine this device's AD site: $($_.Exception.Message)"
    }

    $Candidates = @()
    try {
        # Same-site DCs first ($false sorts before $true), then by name
        $Candidates = @(Get-ADDomainController -Filter * -ErrorAction Stop |
            Where-Object { $_.Name -ne $env:COMPUTERNAME -and $_.IPv4Address } |
            Sort-Object -Property @{ Expression = { $_.Site -ne $LocalSite } }, Name |
            Select-Object -First $MaxCandidates)
    }
    catch {
        Write-Verbose "[$($MyInvocation.InvocationName)] AD unavailable; no DC suggestions: $($_.Exception.Message)"
    }

    # Keep only DCs that actually answer DNS queries (a DC does not always run DNS)
    $DnsDcs = [System.Collections.Generic.List[string]]::new()
    foreach ($Dc in $Candidates) {
        if ($DnsDcs.Count -ge 2) { break }
        try {
            $null = Resolve-DnsName -Name $Dc.HostName -Server $Dc.IPv4Address -DnsOnly -QuickTimeout -ErrorAction Stop
            $DnsDcs.Add($Dc.IPv4Address)
        }
        catch {
            Write-Verbose "[$($MyInvocation.InvocationName)] $($Dc.HostName) ($($Dc.IPv4Address)) did not answer DNS; skipped."
        }
    }

    $Suggestion = [pscustomobject]@{
        Primary      = $null
        Secondary    = $null
        LocalRunsDns = $LocalRunsDns
        Note         = ''
    }

    if ($LocalRunsDns) {
        if ($DnsDcs.Count -ge 1) {
            $Suggestion.Primary   = $DnsDcs[0]
            $Suggestion.Secondary = '127.0.0.1'
            $Suggestion.Note      = 'another DC first, this server second (best practice)'
        }
        else {
            $Suggestion.Primary = '127.0.0.1'
            $Suggestion.Note    = 'no other DNS server answered; this server only'
        }
    }
    elseif ($DnsDcs.Count -ge 1) {
        $Suggestion.Primary = $DnsDcs[0]
        if ($DnsDcs.Count -ge 2) {
            $Suggestion.Secondary = $DnsDcs[1]
        }
        $Suggestion.Note = 'domain controllers that answered DNS'
    }
    else {
        $Suggestion.Note = 'no DNS server could be suggested'
    }

    return $Suggestion
}

#Function to list adapters eligible for DNS changes
function Get-DnsTargetAdapter {
    <#
    .SYNOPSIS
        Lists connected network adapters that have an IPv4 address.

    .DESCRIPTION
        Returns adapters with Status Up and at least one non-APIPA IPv4 address, with their
        current DNS servers. Disconnected adapters and adapters with no IPv4 address are
        excluded. Hyper-V vEthernet adapters that carry the host's IP are included.

    .EXAMPLE
        Get-DnsTargetAdapter | Format-Table
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param ()

    foreach ($Adapter in @(Get-NetAdapter -ErrorAction Stop | Where-Object { $_.Status -eq 'Up' })) {
        $IPv4 = @(Get-NetIPAddress -InterfaceIndex $Adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -notlike '169.254.*' } |
            Select-Object -ExpandProperty IPAddress)
        if ($IPv4.Count -eq 0) {
            continue
        }
        $CurrentDns = @((Get-DnsClientServerAddress -InterfaceIndex $Adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses)

        [pscustomobject]@{
            InterfaceIndex = $Adapter.InterfaceIndex
            Name           = $Adapter.Name
            Description    = $Adapter.InterfaceDescription
            IPv4Address    = $IPv4 -join ', '
            CurrentDns     = $CurrentDns -join ', '
        }
    }
}

#Function to Set DNS
function Set-DNS {
    <#
    .SYNOPSIS
        Set the DNS servers on this computer's connected adapters.

    .DESCRIPTION
        Sets the IPv4 DNS server list on connected adapters that have an IPv4 address
        (see Get-DnsTargetAdapter), or only on the adapters given in -InterfaceIndex.
        The secondary server is optional; duplicates are removed.

        The default primary is 127.0.0.1 (this server). That is only valid when this computer
        runs the DNS Server service, so it is refused on other computers unless -Force is used.

        Returns the DNS settings of each changed adapter after the change.

    .PARAMETER Primary
        Primary DNS server IPv4 address. Default 127.0.0.1.

    .PARAMETER Secondary
        Optional secondary DNS server IPv4 address.

    .PARAMETER InterfaceIndex
        Only change these adapters. Default is every adapter returned by Get-DnsTargetAdapter.

    .PARAMETER Force
        Allow 127.0.0.1 on a computer that is not running the DNS Server service.

    .EXAMPLE
        Set-DNS
        Sets DNS on all connected adapters to the loopback (DNS servers / DCs only)

    .EXAMPLE
        Set-DNS -Primary 10.0.0.10 -Secondary 10.0.0.11 -InterfaceIndex 12
        Sets DNS on adapter 12 only
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Position = 0)]
        [ValidateScript({
            if (Test-IPv4Address -Address $_) { $true }
            else { throw "'$_' is not a valid IPv4 address (four octets, each 0-255)." }
        })]
        [string]$Primary = '127.0.0.1',

        [Parameter(Position = 1)]
        [AllowEmptyString()]
        [ValidateScript({
            if ([string]::IsNullOrEmpty($_) -or (Test-IPv4Address -Address $_)) { $true }
            else { throw "'$_' is not a valid IPv4 address (four octets, each 0-255)." }
        })]
        [string]$Secondary,

        [Parameter()]
        [int[]]$InterfaceIndex,

        [switch]$Force
    )

    $ServerAddresses = @(@($Primary, $Secondary) | Where-Object { -not [string]::IsNullOrEmpty($_) } | Select-Object -Unique)

    $UsesLoopback = $ServerAddresses -contains '127.0.0.1'
    if ($UsesLoopback -and -not $Force -and -not (Get-Service -Name DNS -ErrorAction SilentlyContinue)) {
        Write-Warning "127.0.0.1 only works on a computer running the DNS Server service, and this computer is not. Enter real DNS server addresses, or use -Force."
        return
    }

    $Targets = @(Get-DnsTargetAdapter)
    if ($InterfaceIndex) {
        $Missing = @($InterfaceIndex | Where-Object { $Targets.InterfaceIndex -notcontains $_ })
        foreach ($Index in $Missing) {
            Write-Warning "InterfaceIndex $Index is not a connected adapter with an IPv4 address; skipped."
        }
        $Targets = @($Targets | Where-Object { $InterfaceIndex -contains $_.InterfaceIndex })
    }
    if ($Targets.Count -eq 0) {
        Write-Warning "No adapters to change."
        return
    }

    foreach ($Target in $Targets) {
        if ($PSCmdlet.ShouldProcess("$($Target.Name) (index $($Target.InterfaceIndex))", "Set DNS servers to $($ServerAddresses -join ', ')")) {
            try {
                Set-DnsClientServerAddress -InterfaceIndex $Target.InterfaceIndex -ServerAddresses $ServerAddresses -ErrorAction Stop
            }
            catch {
                Write-Warning "Failed to set DNS on $($Target.Name): $($_.Exception.Message)"
            }
        }
    }

    # Report the settings after the change
    foreach ($Target in $Targets) {
        [pscustomobject]@{
            InterfaceIndex = $Target.InterfaceIndex
            Name           = $Target.Name
            IPv4Address    = $Target.IPv4Address
            DnsBefore      = $Target.CurrentDns
            DnsAfter       = @((Get-DnsClientServerAddress -InterfaceIndex $Target.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses) -join ', '
        }
    }
}

#Function to prompt the user
function Read-MenuChoice {
    <#
    .SYNOPSIS
        Displays the grouped menu and returns the user's choice.

    .DESCRIPTION
        Shows the domain and working folder at the top, groups the options by task,
        and accepts Q as well as 99 to exit.

    .EXAMPLE
        $Choice = Read-MenuChoice
    #>
    $DomainShown  = if ($script:ToolkitEnv.AdAvailable) { $script:ToolkitEnv.Domain.DNSRoot } else { 'not available' }
    $WorkDirShown = if ($script:WorkDir) { $script:WorkDir } else { "$env:SystemDrive\FT" }
    # Prompt the user to choose an option
    $choice = Read-Host "Domain: $DomainShown   Working folder: $WorkDirShown
Choose an option
--- Reports ---
0 - Run some general health checks
1 - Pull a list of all active users in AD or users with admin privileges
2 - Pull a list of all computers or all domain controllers
--- Accounts ---
3 - Set the password on accounts
4 - Set or Remove the password never expires flag on accounts
5 - Set the password expires at next logon flag on accounts
6 - Disable accounts in AD
--- Network / DNS ---
7 - Set DNS on this device
8 - Purge DNS of a specified entry
9 - Search DHCP for activity related to an IP
10 - Scan a network range for active IPs
--- DC maintenance ---
11 - Move or seize FSMO roles to a different server
12 - Perform a metadata cleanup (Remove a demoted or tombstoned DC from AD)
13 - Reset the krbtgt (Kerberos) password
14 - Check for orphaned domain controllers
15 - Replicate AD Schema between all DCs
--- Other ---
98 - Change the working folder
99 or Q - Exit
"
    return $choice
}

#Function to get the current FSMO role holders
function Get-FsmoRoleHolder {
    <#
    .SYNOPSIS
        Returns the current FSMO role holders.

    .DESCRIPTION
        Reads the five FSMO role holders. Use -Server to read them from a specific DC.
        Right after a role move, read from the destination DC: other DCs show the old
        holder until replication catches up.

    .PARAMETER Server
        Optional DC to query.

    .EXAMPLE
        Get-FsmoRoleHolder -Server DC02
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [string]$Server
    )

    $Params = @{ ErrorAction = 'Stop' }
    if (-not [string]::IsNullOrEmpty($Server)) {
        $Params.Server = $Server
    }

    $Forest = Get-ADForest @Params
    $Domain = Get-ADDomain @Params
    [PSCustomObject]@{
        SchemaMaster         = $Forest.SchemaMaster
        DomainNamingMaster   = $Forest.DomainNamingMaster
        PDCEmulator          = $Domain.PDCEmulator
        RIDMaster            = $Domain.RIDMaster
        InfrastructureMaster = $Domain.InfrastructureMaster
    }
}

#Function to move FSMO roles
function Move-FSMO {
    <#
    .SYNOPSIS
        Transfers or seizes FSMO roles to another server.

    .DESCRIPTION
        Moves all five FSMO roles by default, or only the roles given in -Roles.
        Always returns the role holders afterwards, read from the destination DC, even if
        the move failed, so a partial move is visible.

    .PARAMETER DestServer
        The server to move the roles to. Defaults to this computer.

    .PARAMETER Roles
        Any of: SchemaMaster, DomainNamingMaster, PDCEmulator, RIDMaster, InfrastructureMaster.
        Leave out to move all five.

    .PARAMETER Force
        Seize the roles instead of transferring them. Only for a role holder that is
        permanently offline.

    .EXAMPLE
        Move-FSMO -DestServer DC02 -Roles PDCEmulator, RIDMaster

    .EXAMPLE
        Move-FSMO -DestServer DC02 -Force
        Seizes all five roles to DC02.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [string]$DestServer,

        [ValidateSet('SchemaMaster', 'DomainNamingMaster', 'PDCEmulator', 'RIDMaster', 'InfrastructureMaster')]
        [string[]]$Roles = @('SchemaMaster', 'DomainNamingMaster', 'PDCEmulator', 'RIDMaster', 'InfrastructureMaster'),

        [switch]$Force
    )

    Begin {
        $DestServer = ConvertTo-CleanInput -InputString $DestServer
        if ([string]::IsNullOrEmpty($DestServer)) {
            $DestServer = $env:COMPUTERNAME
        }
    }

    Process {
        $Verb = if ($Force) { 'SEIZE' } else { 'Transfer' }
        if ($PSCmdlet.ShouldProcess($DestServer, "$Verb FSMO role(s): $($Roles -join ', ')")) {
            try {
                Move-ADDirectoryServerOperationMasterRole -Identity $DestServer -OperationMasterRole $Roles -Force:$Force -Confirm:$false -ErrorAction Stop
            }
            catch {
                Write-Warning "FSMO move failed: $($_.Exception.Message)"
                Write-Warning "Some roles may have moved and others not. Check the role holders below."
            }
        }
    }

    End {
        # Read from the destination: other DCs show the old holders until replication catches up
        try {
            return (Get-FsmoRoleHolder -Server $DestServer)
        }
        catch {
            Write-Warning "Could not read the role holders from $DestServer ($($_.Exception.Message)). Showing the default DC's view, which may lag behind."
            return (Get-FsmoRoleHolder)
        }
    }
}

#Function to generate passwords
function Get-RandomString {
    <#
    .SYNOPSIS
        Generate a random password string that meets Windows complexity rules.

    .DESCRIPTION
        Generates a random string that always contains at least one uppercase letter, one
        lowercase letter, one digit and one symbol, then shuffles the characters so the
        guaranteed ones are not in fixed positions. The default length is 14 characters.

        Characters are chosen with System.Security.Cryptography.RandomNumberGenerator.
        (Get-Random does not guarantee cryptographically secure randomness.) Values from
        the uneven tail of the random range are redrawn so every character is equally
        likely, and the shuffle (Fisher-Yates) uses the same secure source.

        The symbols " ' and , are excluded because they are hard to read out, paste, or
        keep intact in CSV files. Symbols used: ! # $ % & ( ) * + - . /

    .PARAMETER length
        Length of the string, 4-256. Default 14.

    .EXAMPLE
        Get-RandomString
        Generate a 14 character string

    .EXAMPLE
        Get-RandomString -length 20
        Generate a 20 character string
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [ValidateRange(4, 256)]
        [int]$length = 14
    )

    $Upper  = [char[]](65..90)          # A-Z
    $Lower  = [char[]](97..122)         # a-z
    $Digit  = [char[]](48..57)          # 0-9
    $Symbol = [char[]]'!#$%&()*+-./'    # excludes " ' ,
    $All    = $Upper + $Lower + $Digit + $Symbol

    $Rng    = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $Buffer = [byte[]]::new(4)

    # Uniform random index from 0 to (Count - 1)
    $GetIndex = {
        param ([int]$Count)
        $Limit = [uint32]([math]::Floor([uint32]::MaxValue / $Count) * $Count)
        do {
            $Rng.GetBytes($Buffer)
            $Value = [BitConverter]::ToUInt32($Buffer, 0)
        } while ($Value -ge $Limit)
        [int]($Value % $Count)
    }

    try {
        $Picked = [System.Collections.Generic.List[char]]::new()
        # One from each category guarantees 4 of 4 complexity categories
        $Picked.Add($Upper[(& $GetIndex $Upper.Count)])
        $Picked.Add($Lower[(& $GetIndex $Lower.Count)])
        $Picked.Add($Digit[(& $GetIndex $Digit.Count)])
        $Picked.Add($Symbol[(& $GetIndex $Symbol.Count)])
        for ($Index = $Picked.Count; $Index -lt $length; $Index++) {
            $Picked.Add($All[(& $GetIndex $All.Count)])
        }

        # Fisher-Yates shuffle so the guaranteed characters are not always the first four
        for ($Index = $Picked.Count - 1; $Index -gt 0; $Index--) {
            $Swap = & $GetIndex ($Index + 1)
            $Temp = $Picked[$Index]
            $Picked[$Index] = $Picked[$Swap]
            $Picked[$Swap]  = $Temp
        }

        return -join $Picked
    }
    finally {
        $Rng.Dispose()
    }
}

#Function to run the shared start-up of the CSV account functions
function Import-AccountCsv {
    <#
    .SYNOPSIS
        Imports the account CSV and starts the log transcript.

    .DESCRIPTION
        Does the start-up every CSV account function repeats: normalizes the CSV
        path, sets up the working folder and log path, imports the CSV, warns on
        an empty file, resolves the account column (case/space tolerant), imports
        the ActiveDirectory module, shows the log notice, and starts the
        transcript. With an empty CsvName the import and column steps are skipped
        (all-users mode) unless -RequireCsv is set, which stops with an error.
        Returns the normalized CSV path, the rows, and the resolved column names.
        The caller must stop the transcript in its End block.

    .PARAMETER CsvName
        Path to the CSV file. Empty for all-users mode.

    .PARAMETER ProjectFolder
        Working folder for the log file.

    .PARAMETER UserNameColumnTitle
        Expected name of the account column.

    .PARAMETER LogFileName
        Log/transcript file name.

    .PARAMETER ExtraColumnTitle
        Optional second column that must exist (for example Password).

    .PARAMETER RequireCsv
        Stop with an error when no CSV path is given (for functions that only work from a CSV).

    .EXAMPLE
        $Import = Import-AccountCsv -CsvName $CsvName -ProjectFolder C:\FT -LogFileName ResetUserPasswords.log -RequireCsv
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [AllowEmptyString()]
        [string]$CsvName,

        [Parameter(Position = 1)]
        [string]$ProjectFolder = "$env:SystemDrive\FT",

        [Parameter(Position = 2)]
        [string]$UserNameColumnTitle = 'SamAccountName',

        [Parameter(Mandatory, Position = 3)]
        [string]$LogFileName,

        [Parameter(Position = 4)]
        [string]$ExtraColumnTitle,

        [switch]$RequireCsv
    )
    # Normalize paths: accepts input with or without quotes and with or without a trailing backslash
    $CsvName = Resolve-UserPath -Path $CsvName
    $WorkingDir = Set-ProjectFolder -BaseDir $ProjectFolder
    $LogPath = Join-Path -Path $WorkingDir -ChildPath $LogFileName

    $Rows = $null
    $UserColumn = $null
    $ExtraColumn = $null
    if ([string]::IsNullOrEmpty($CsvName)) {
        if ($RequireCsv) {
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.ArgumentException]::new('A CSV path is required.'),
                    'CsvPathMissing',
                    [System.Management.Automation.ErrorCategory]::InvalidArgument,
                    $CsvName
                )
            )
        }
    }
    else {
        try {
            $Rows = @(Import-Csv -LiteralPath $CsvName -ErrorAction Stop)
        }
        catch {
            Add-Content -LiteralPath $LogPath -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Error importing CSV '$CsvName': $($_.Exception.Message)" -WhatIf:$false -Confirm:$false
            $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new($_.Exception, 'CsvImportFailed', [System.Management.Automation.ErrorCategory]::ReadError, $CsvName))
        }
        if ($Rows.Count -eq 0) {
            Write-Warning "The CSV '$CsvName' contains no rows."
        }
        # Find the columns (tolerates case and stray spaces in headers); stop with a clear error if missing
        try {
            $UserColumn = Resolve-CsvColumn -Rows $Rows -ColumnName $UserNameColumnTitle -CsvPath $CsvName
            if (-not [string]::IsNullOrEmpty($ExtraColumnTitle)) {
                $ExtraColumn = Resolve-CsvColumn -Rows $Rows -ColumnName $ExtraColumnTitle -CsvPath $CsvName
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.IO.InvalidDataException]::new($_.Exception.Message),
                    'CsvColumnMissing',
                    [System.Management.Automation.ErrorCategory]::InvalidData,
                    $CsvName
                )
            )
        }
    }

    Import-Module ActiveDirectory -ErrorAction SilentlyContinue
    # Write-Host kept on purpose: the yellow log notice is easy to spot
    Write-Host -ForegroundColor Yellow "`nFor errors check log file at $LogPath, or run with -Verbose for more details.`n"
    # $null = : Start-Transcript writes a status line to the output stream, which would otherwise
    # become part of this function's return value. -Confirm:$false: a -Confirm run of the caller
    # should prompt for the account changes only, not for the log.
    $null = Start-Transcript -Path $LogPath -Append -WhatIf:$false -Confirm:$false

    [pscustomobject]@{
        CsvName     = $CsvName
        Rows        = $Rows
        UserColumn  = $UserColumn
        ExtraColumn = $ExtraColumn
        WorkingDir  = $WorkingDir
        LogPath     = $LogPath
    }
}

#Function to stop the log transcript on any PowerShell version
function Stop-ToolkitTranscript {
    <#
    .SYNOPSIS
        Stops the running transcript, on Windows PowerShell 5.1 and PowerShell 7.

    .DESCRIPTION
        PowerShell 7's Stop-Transcript honors -WhatIf, so a -WhatIf run must pass
        -WhatIf:$false or the log is left open. Windows PowerShell 5.1's Stop-Transcript
        has no -WhatIf/-Confirm parameters at all, and passing them is a parameter error
        that would also leave the log open. This passes them only when they exist.

    .EXAMPLE
        Stop-ToolkitTranscript
    #>
    [CmdletBinding()]
    param ()

    $StopParams = @{ ErrorAction = 'Stop' }
    if ((Get-Command -Name Stop-Transcript).Parameters.ContainsKey('WhatIf')) {
        $StopParams.WhatIf  = $false
        $StopParams.Confirm = $false
    }
    try {
        $null = Stop-Transcript @StopParams
    }
    catch {
        Write-Verbose "No active transcript to stop."
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
    The default is to title the username column SamAccountName and the passwords column Password. This can be overridden with the UserNameColumnTitle, and PwColumnTitle parameters.

    .PARAMETER ProjectFolder
    The default is $env:SystemDrive\FT

    .PARAMETER PwFromCSV
    A switch to determine if the passwords should be generated or provided in the CSV.
    If the switch is enabled a Password column must be included in the CSV.

    .PARAMETER UserNameColumnTitle
    Name of the account column. The default is SamAccountName (case and stray spaces are tolerated).

    .PARAMETER PwColumnTitle
    Name of the password column used with -PwFromCSV. The default is Password.

    .PARAMETER LogFileName
    The name of the log (transcript) file. The default is ResetUserPasswords.log.

    .PARAMETER PwLength
    Sets the length of the randomly generated password, 4-256. The default is 14.

    .PARAMETER OutputCsv
    Where to save the generated passwords: a .csv file or a folder. The default is
    UpdatedPasswords_<date>_<time>.csv in ProjectFolder. Not used with -PwFromCSV.

    .PARAMETER ChangePwAtNextLogon
    Also require each account to change its password at next sign-in.

    .EXAMPLE
    Set-ADPasswordFromCSV -CsvName "C:\MyFolder\Users.csv"
    Sets random 14 character passwords for all users listed in Users.csv

    .EXAMPLE
    Set-ADPasswordFromCSV -CsvName "C:\FT\pwresets\test.csv" -PwLength 22
    Sets a 22 character password

    .EXAMPLE
    Set-ADPasswordFromCSV -CsvName "C:\MyFolder\Users.csv" -PwFromCSV
    Sets the passwords provided in the CSV
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory=$true,
        HelpMessage='Enter the path to the CSV with the list of users. Such as "C:\FT\Users.csv"')]
        [String]$CsvName,
        [String]$ProjectFolder = "$env:SystemDrive\FT",
        [Switch]$PwFromCSV,
        [String]$UserNameColumnTitle = "SamAccountName",
        [String]$PwColumnTitle = "Password",
        [String]$LogFileName = "ResetUserPasswords.log",
        [ValidateRange(4, 256)]
        [Int]$PwLength = 14,
        [String]$OutputCsv,
        [Switch]$ChangePwAtNextLogon
    )
    Begin {
        $Import = Import-AccountCsv -CsvName $CsvName -ProjectFolder $ProjectFolder -UserNameColumnTitle $UserNameColumnTitle -LogFileName $LogFileName -ExtraColumnTitle $(if ($PwFromCSV) { $PwColumnTitle }) -RequireCsv
        $CsvName       = $Import.CsvName
        $UserNamesList = $Import.Rows
        $UserColumn    = $Import.UserColumn
        $WorkingDir    = $Import.WorkingDir
        $LogPath       = $Import.LogPath
        $PwColumn      = $Import.ExtraColumn

        # Default is a timestamped file so every run's passwords are kept, never overwritten
        $DefaultCsvName = "UpdatedPasswords_$((Get-Date).ToString('MMddyy_HHmmss')).csv"
        $OutputCsv = Resolve-UserPath -Path $OutputCsv
        if ([string]::IsNullOrWhiteSpace($OutputCsv)) {
            $OutputCsv = Join-Path -Path $WorkingDir -ChildPath $DefaultCsvName
        }
        elseif ((Test-Path -LiteralPath $OutputCsv -PathType Container) -or [string]::IsNullOrEmpty([System.IO.Path]::GetExtension($OutputCsv))) {
            # A folder (existing, or anything without a file extension) gets the default file name
            $OutputCsv = Join-Path -Path $OutputCsv -ChildPath $DefaultCsvName
        }
        $OutputDir = Split-Path -Path $OutputCsv -Parent
        if ($OutputDir -and -not (Test-Path -LiteralPath $OutputDir -PathType Container)) {
            # -Confirm:$false: the password is already changed, so creating the output folder must never prompt
            $null = New-Item -Path $OutputDir -ItemType Directory -Force -WhatIf:$false -Confirm:$false -ErrorAction Stop
        }
    }

    Process {
        $total = $UserNamesList.Count
        $i = 0

        if (-not $PwFromCSV) {
            $SavedCount = 0
            $RecoveryCsv = [System.IO.Path]::ChangeExtension($OutputCsv, $null).TrimEnd('.') + '_recovery.csv'
            $NotRecorded = [System.Collections.Generic.List[string]]::new()

            foreach ($User in $UserNamesList) {
                $i++
                $ADUser = ([string]$User.$UserColumn).Trim()
                if ([string]::IsNullOrEmpty($ADUser)) {
                    Write-Warning "Row $i has no value in column '$UserNameColumnTitle'; skipped."
                    continue
                }
                $ADPW = Get-RandomString -length $PwLength
                $password = ConvertTo-SecureString -AsPlainText $ADPW -Force
                Write-Verbose "Setting password for $ADUser"
                Write-Progress -Activity "Setting random passwords from CSV" -Status "$i of $total" -PercentComplete (($i / $total) * 100)

                if (-not $PSCmdlet.ShouldProcess($ADUser, 'Reset password (random)')) {
                    continue
                }

                try {
                    Set-ADAccountPassword $ADUser -NewPassword $password -Reset -ErrorAction Stop
                }
                catch {
                    Write-Warning "Error setting password for $ADUser $($_.Exception.Message)"
                    continue
                }

                # From here on the password HAS been changed - nothing below may lose it
                if ($ChangePwAtNextLogon) {
                    try {
                        Set-ADUser -Identity $ADUser -ChangePasswordAtLogon:$true -ErrorAction Stop
                    }
                    catch {
                        Write-Warning "Password set, but 'change at next logon' could not be set for $ADUser : $($_.Exception.Message)"
                    }
                }

                $PulledUser = $null
                try {
                    $PulledUser = Get-ADUser -Identity $ADUser -Properties EmailAddress -ErrorAction Stop
                }
                catch {
                    Write-Verbose "Could not read name/email for $ADUser : $($_.Exception.Message)"
                }

                $Row = [PSCustomObject]@{
                    Name                 = if ($PulledUser) { $PulledUser.Name } else { "Not Found" }
                    $UserNameColumnTitle = $ADUser
                    $PwColumnTitle       = $ADPW
                    EmailAddress         = if ($PulledUser) { $PulledUser.EmailAddress } else { "Not Found" }
                }

                # Save this row now, so an interrupted run loses nothing already done.
                # If the file is locked (for example open in Excel), use a recovery file instead.
                $SavedTo = $null
                foreach ($Target in @($OutputCsv, $RecoveryCsv)) {
                    try {
                        # -Confirm:$false / -WhatIf:$false: the password is already changed, so saving it must never be skipped
                        $Row | Export-Csv -LiteralPath $Target -Append -NoTypeInformation -Encoding UTF8 -Confirm:$false -WhatIf:$false -ErrorAction Stop
                        $SavedTo = $Target
                        break
                    }
                    catch {
                        Write-Warning "Could not write to $Target : $($_.Exception.Message)"
                    }
                }

                if ($SavedTo) {
                    $SavedCount++
                }
                else {
                    $NotRecorded.Add($ADUser)
                }
            }

            if ($SavedCount -gt 0) {
                Write-Host -ForegroundColor Green "Passwords for $SavedCount account(s) saved to $OutputCsv"
                if (Test-Path -LiteralPath $RecoveryCsv) {
                    Write-Warning "Some rows could not be written to $OutputCsv and were saved to $RecoveryCsv instead."
                }
                Write-Warning "These files contain the passwords in PLAIN TEXT. Store them securely and delete them once the passwords have been handed out."
            }
            else {
                Write-Warning "No passwords were recorded, so $OutputCsv was not written."
            }

            if ($NotRecorded.Count -gt 0) {
                Write-Warning "Passwords were CHANGED but could NOT be recorded for: $($NotRecorded -join ', '). Reset these accounts again."
            }
        }
        else {
            foreach ($User in $UserNamesList) {
                $i++
                $ADUser = ([string]$User.$UserColumn).Trim()
                if ([string]::IsNullOrEmpty($ADUser)) {
                    Write-Warning "Row $i has no value in column '$UserNameColumnTitle'; skipped."
                    continue
                }
                $ADPW = [string]$User.$PwColumn
                if ([string]::IsNullOrEmpty($ADPW)) {
                    Write-Warning "Row $i ($ADUser) has no password; skipped."
                    continue
                }
                $password = ConvertTo-SecureString -AsPlainText $ADPW -Force
                Write-Verbose "Setting password for $ADUser (from CSV)"
                Write-Progress -Activity "Setting provided passwords from CSV" -Status "$i of $total" -PercentComplete (($i / $total) * 100)

                if ($PSCmdlet.ShouldProcess($ADUser, 'Reset password (from CSV)')) {
                    try {
                        Set-ADAccountPassword $ADUser -NewPassword $password -Reset -ErrorAction Stop
                    }
                    catch {
                        Write-Warning "Error setting password for $ADUser $($_.Exception.Message)"
                        continue
                    }
                    if ($ChangePwAtNextLogon) {
                        try {
                            Set-ADUser -Identity $ADUser -ChangePasswordAtLogon:$true -ErrorAction Stop
                        }
                        catch {
                            Write-Warning "Password set, but 'change at next logon' could not be set for $ADUser : $($_.Exception.Message)"
                        }
                    }
                }
            }
        }

        Write-Progress -Activity "Processing Complete" -Completed
    }
    End {
        Stop-ToolkitTranscript
        # Write-Host kept on purpose: the yellow log notice is easy to spot
        Write-Host -ForegroundColor Yellow "`nThe log file can be found at $LogPath"
    }
}

#Function to set pw expires at next logon flag
function Set-PwExpiresNextLogon {
    <#
    .SYNOPSIS
    Set AD Password Expires at Next Logon flag

    .DESCRIPTION
    Set AD Password Expires at Next Logon flag. Either set the flag for accounts (default), or remove the flag for accounts. If no CSV path is provided to -CsvName this will run on all accounts.

    .PARAMETER CsvName
    Enter the path to a csv with the list of Sam Account Names.
    The default is to title the username column SamAccountName. This can be overridden with the UserNameColumnTitle parameter.
    .PARAMETER ProjectFolder
    The default is $env:SystemDrive\FT
    .PARAMETER UserNameColumnTitle
    Name of the account column. The default is SamAccountName (case and stray spaces are tolerated).
    .PARAMETER LogFileName
    The name of the log (transcript) file. The default is PWExpiresNextLogon.log.
    .PARAMETER SetDisable
    Default is to enable (set the flag). Include this switch to disable instead.

    .EXAMPLE
    Set-PwExpiresNextLogon
    Sets the password to expire at next logon for all AD accounts.

    .EXAMPLE
    Set-PwExpiresNextLogon -CsvName "C:\MyFolder\Users.csv"
    Sets the password to expire at next logon for all accounts listed in a CSV.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(HelpMessage='Enter the path to the CSV with the list of users. Such as "C:\FT\Users.csv"')]
        [String]$CsvName,
        [String]$ProjectFolder = "$env:SystemDrive\FT",
        [String]$UserNameColumnTitle = "SamAccountName",
        [String]$LogFileName = "PWExpiresNextLogon.log",
        [Switch]$SetDisable
    )
    Begin {
        $Import = Import-AccountCsv -CsvName $CsvName -ProjectFolder $ProjectFolder -UserNameColumnTitle $UserNameColumnTitle -LogFileName $LogFileName
        $CsvName       = $Import.CsvName
        $UserNamesList = $Import.Rows
        $UserColumn    = $Import.UserColumn
        $LogPath       = $Import.LogPath
    }

    Process {
        # Build the account list once: all enabled users, or the CSV column
        if ([string]::IsNullOrEmpty($CsvName)) {
            try {
                $users = @(Get-AdUserForBulkChange)
            }
            catch {
                # return (not throw) so the End block still runs and stops the transcript
                Write-Warning "Could not list user accounts: $($_.Exception.Message)"
                return
            }
            $SamList = @($users | ForEach-Object { $_.SamAccountName })
            $FromCsv = $false
        }
        else {
            $SamList = @($UserNamesList | ForEach-Object { ([string]$_.$UserColumn).Trim() })
            $FromCsv = $true
        }

        # One loop instead of four: the switch parameter sets the flag value and the wording
        $NewValue = -not $SetDisable
        $Verb = if ($NewValue) { 'Setting' } else { 'Removing' }
        $total = $SamList.Count
        $i = 0
        foreach ($Sam in $SamList) {
            $i++
            if ([string]::IsNullOrEmpty($Sam)) {
                if ($FromCsv) { Write-Warning "Row $i has no value in column '$UserNameColumnTitle'; skipped." }
                continue
            }
            Write-Verbose "$Verb Password Expires at Next Logon for $Sam"
            Write-Progress -Activity "$Verb Password Expires at Next Logon" -Status "$i of $total" -PercentComplete (($i / $total) * 100)
            if ($PSCmdlet.ShouldProcess($Sam, "Set ChangePasswordAtLogon to $NewValue")) {
                try { Set-ADUser $Sam -ChangePasswordAtLogon:$NewValue -ErrorAction Stop }
                catch {
                    Write-Warning "Error setting ChangePasswordAtLogon for $Sam : $($_.Exception.Message)"
                }
            }
        }
        Write-Progress -Activity "Processing Complete" -Completed
    }

    End {
        Stop-ToolkitTranscript
        # Write-Host kept on purpose: the yellow log notice is easy to spot
        Write-Host -ForegroundColor Yellow "`nThe log file can be found at $LogPath"
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
    The default is to title the username column SamAccountName. This can be overridden with the UserNameColumnTitle parameter.
    .PARAMETER ProjectFolder
    The default is $env:SystemDrive\FT
    .PARAMETER UserNameColumnTitle
    Name of the account column. The default is SamAccountName (case and stray spaces are tolerated).
    .PARAMETER LogFileName
    The name of the log (transcript) file. The default is DisabledUsers.log.

    .EXAMPLE
    Disable-AdAccountFromCSV -CsvName "C:\MyFolder\Users.csv"
    Disables all accounts listed in Users.csv under the column titled SamAccountName
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory=$true,
        HelpMessage='Enter the path to the CSV with the list of users. Such as "C:\FT\Users.csv"')]
        [String]$CsvName,
        [String]$ProjectFolder = "$env:SystemDrive\FT",
        [String]$UserNameColumnTitle = "SamAccountName",
        [String]$LogFileName = "DisabledUsers.log"
    )
    Begin {
        $Import = Import-AccountCsv -CsvName $CsvName -ProjectFolder $ProjectFolder -UserNameColumnTitle $UserNameColumnTitle -LogFileName $LogFileName -RequireCsv
        $CsvName       = $Import.CsvName
        $UserNamesList = $Import.Rows
        $UserColumn    = $Import.UserColumn
        $LogPath       = $Import.LogPath
        # Used to stop the script from disabling the account running it
        $CurrentUserSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    }

    Process {
        $total = $UserNamesList.Count
        $i = 0
        foreach ($User in $UserNamesList) {
            $i++
            $ADUser = ([string]$User.$UserColumn).Trim()
            if ([string]::IsNullOrEmpty($ADUser)) {
                Write-Warning "Row $i has no value in column '$UserNameColumnTitle'; skipped."
                continue
            }
            Write-Verbose "Disabling account $ADUser"
            Write-Progress -Activity "Disabling AD accounts from CSV" -Status "$i of $total" -PercentComplete (($i / $total) * 100)
            if ($PSCmdlet.ShouldProcess($ADUser, 'Disable account')) {
                try {
                    $SafeSam = $ADUser -replace '\\', '\5c' -replace '\*', '\2a' -replace '\(', '\28' -replace '\)', '\29'
                    $Account = @(Get-ADObject -LDAPFilter "(sAMAccountName=$SafeSam)" -Properties objectSid -ErrorAction Stop)
                    if ($Account.Count -eq 0) {
                        Write-Warning "No account with sAMAccountName '$ADUser' was found; skipped."
                        continue
                    }
                    $AccountSid = $Account[0].objectSid.Value

                    # Never disable the account running this script
                    if ($AccountSid -eq $CurrentUserSid) {
                        Write-Warning "Skipped $ADUser - it is the account running this script."
                        continue
                    }

                    # The built-in Administrator is often the break-glass account; disabling it is sometimes
                    # intended (hardening), so require a typed confirmation instead of blocking it
                    if ($AccountSid -like '*-500') {
                        if (-not (Confirm-Action -Message "$ADUser is the built-in Administrator account (often the emergency break-glass account). Disable it?" -ConfirmText $ADUser)) {
                            continue
                        }
                    }

                    Disable-ADAccount -Identity $Account[0].DistinguishedName -ErrorAction Stop
                    Write-Information "Disabled $ADUser" -InformationAction Continue
                }
                catch {
                    Write-Warning "Error disabling $ADUser $($_.Exception.Message)"
                }
            }
        }
        Write-Progress -Activity "Processing Complete" -Completed
    }
    End {
        Stop-ToolkitTranscript
        # Write-Host kept on purpose: the yellow log notice is easy to spot
        Write-Host -ForegroundColor Yellow "`nThe log file can be found at $LogPath"
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
    The default is to title the username column SamAccountName. This can be overridden with the UserNameColumnTitle parameter.
    .PARAMETER ProjectFolder
    The default is $env:SystemDrive\FT
    .PARAMETER UserNameColumnTitle
    Name of the account column. The default is SamAccountName (case and stray spaces are tolerated).
    .PARAMETER LogFileName
    The name of the log (transcript) file. The default is PwNeverExpires.log.
    .PARAMETER SetEnable
    Default is to disable (remove the flag). Include this switch to enable password never expires instead.

    .EXAMPLE
    Set-PasswordNeverExpires
    Removes the password never expires flag from all AD accounts.

    .EXAMPLE
    Set-PasswordNeverExpires -CsvName "C:\MyFolder\Users.csv"
    Removes the password never expires flag from all accounts listed in a CSV.

    .EXAMPLE
    Set-PasswordNeverExpires -CsvName "C:\MyFolder\Users.csv" -SetEnable
    Sets the Password Never Expires flag for all accounts listed in a CSV. Useful for service accounts.

    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(HelpMessage='Enter the path to the CSV with the list of users. Such as "C:\FT\Users.csv"')]
        [String]$CsvName,
        [String]$ProjectFolder = "$env:SystemDrive\FT",
        [String]$UserNameColumnTitle = "SamAccountName",
        [String]$LogFileName = "PwNeverExpires.log",
        [Switch]$SetEnable
    )
    Begin {
        $Import = Import-AccountCsv -CsvName $CsvName -ProjectFolder $ProjectFolder -UserNameColumnTitle $UserNameColumnTitle -LogFileName $LogFileName
        $CsvName       = $Import.CsvName
        $UserNamesList = $Import.Rows
        $UserColumn    = $Import.UserColumn
        $LogPath       = $Import.LogPath
    }

    Process {
        # Build the account list once: all enabled users, or the CSV column
        if ([string]::IsNullOrEmpty($CsvName)) {
            try {
                $users = @(Get-AdUserForBulkChange)
            }
            catch {
                # return (not throw) so the End block still runs and stops the transcript
                Write-Warning "Could not list user accounts: $($_.Exception.Message)"
                return
            }
            $SamList = @($users | ForEach-Object { $_.SamAccountName })
            $FromCsv = $false
        }
        else {
            $SamList = @($UserNamesList | ForEach-Object { ([string]$_.$UserColumn).Trim() })
            $FromCsv = $true
        }

        # One loop instead of four: the switch parameter sets the flag value and the wording
        $NewValue = [bool]$SetEnable
        $Verb = if ($NewValue) { 'Setting' } else { 'Removing' }
        $total = $SamList.Count
        $i = 0
        foreach ($Sam in $SamList) {
            $i++
            if ([string]::IsNullOrEmpty($Sam)) {
                if ($FromCsv) { Write-Warning "Row $i has no value in column '$UserNameColumnTitle'; skipped." }
                continue
            }
            Write-Verbose "$Verb Password Never Expires for $Sam"
            Write-Progress -Activity "$Verb Password Never Expires" -Status "$i of $total" -PercentComplete (($i / $total) * 100)
            if ($PSCmdlet.ShouldProcess($Sam, "Set PasswordNeverExpires to $NewValue")) {
                try { Set-ADUser $Sam -PasswordNeverExpires:$NewValue -ErrorAction Stop }
                catch {
                    Write-Warning "Error setting PasswordNeverExpires for $Sam : $($_.Exception.Message)"
                }
            }
        }
        Write-Progress -Activity "Processing Complete" -Completed
    }

    End {
        Stop-ToolkitTranscript
        # Write-Host kept on purpose: the yellow log notice is easy to spot
        Write-Host -ForegroundColor Yellow "`nThe log file can be found at $LogPath"
    }
}

#Function to do Metadata cleanup
function Invoke-MetaDataCleanup {
    <#
    .SYNOPSIS
        Removes a demoted or tombstoned Domain Controller from Active Directory.

    .DESCRIPTION
        Runs ntdsutil metadata cleanup for a DC that is permanently offline, removes its
        site server object, then removes leftover objects whose CN EXACTLY matches the DC
        name (computer, msDFSR-Member, nTFRSMember, server). Every deletion is listed and
        requires the operator to type the DC name.

        Safety checks: refuses the local computer, refuses if the DC still holds an FSMO
        role, and warns (with an extra confirmation) if the DC still answers ping.

    .PARAMETER DcToRemove
        The name of the Domain Controller to remove: the short name (DC01) or the
        FQDN (DC01.contoso.com). An FQDN is reduced to its short name. IP addresses
        are rejected.

    .EXAMPLE
        Invoke-MetaDataCleanup -DcToRemove DC01

    .EXAMPLE
        Invoke-MetaDataCleanup -DcToRemove DC01 -WhatIf
        Shows what would be removed without deleting anything.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DcToRemove
    )

    #region Guardrails
    $DcInput = ConvertTo-CleanInput -InputString $DcToRemove
    if ($DcInput -match '^\d{1,3}(\.\d{1,3}){3}$') {
        Write-Warning "Enter the DC's name (such as DC01 or DC01.contoso.com), not its IP address."
        return
    }

    # Accept "DC01" or "DC01.contoso.com": AD stores the site server object under the short name
    $ShortName = ($DcInput -split '\.')[0]
    if ([string]::IsNullOrEmpty($ShortName)) {
        Write-Warning "'$DcInput' is not a valid DC name."
        return
    }
    if ($ShortName -ne $DcInput) {
        Write-Information "Using the short name '$ShortName' (from '$DcInput')." -InformationAction Continue
    }
    $DcToRemove = $ShortName

    try {
        $RootDse = Get-ADRootDSE -ErrorAction Stop
        $Forest  = Get-ADForest -ErrorAction Stop
        $Domain  = Get-ADDomain -ErrorAction Stop
    }
    catch {
        Write-Warning "Unable to query Active Directory: $($_.Exception.Message)"
        return
    }
    $DomainDN = $RootDse.defaultNamingContext
    $ConfigDN = $RootDse.configurationNamingContext

    if ($DcToRemove -eq $env:COMPUTERNAME) {
        Write-Warning "Refusing to run metadata cleanup against the local computer ($env:COMPUTERNAME)."
        return
    }

    $Roles = [ordered]@{
        SchemaMaster         = $Forest.SchemaMaster
        DomainNamingMaster   = $Forest.DomainNamingMaster
        PDCEmulator          = $Domain.PDCEmulator
        RIDMaster            = $Domain.RIDMaster
        InfrastructureMaster = $Domain.InfrastructureMaster
    }
    $HeldRoles = @($Roles.GetEnumerator() |
        Where-Object { ($_.Value -split '\.')[0] -eq $DcToRemove } |
        ForEach-Object -MemberName Key)
    if ($HeldRoles.Count -gt 0) {
        Write-Warning "$DcToRemove still holds: $($HeldRoles -join ', '). Seize these roles to a healthy DC first (menu option 11)."
        return
    }

    if (-not $WhatIfPreference) {
        if (Test-Connection -ComputerName $DcToRemove -Count 2 -Quiet) {
            Write-Warning "$DcToRemove responds to ping. Metadata cleanup is only for DCs that are permanently offline. If it is still running, demote it properly instead."
            if (-not (Confirm-Action -Message "Continue cleanup of a REACHABLE DC?" -ConfirmText $DcToRemove)) { return }
        }
        if (-not (Confirm-Action -Message "Metadata cleanup of $DcToRemove is PERMANENT and cannot be undone." -ConfirmText $DcToRemove)) { return }
    }
    #endregion Guardrails

    #region Cleanup DC
    # ntdsutil and every follow-up check must use the SAME DC; querying a different DC
    # right after the cleanup gives false results until replication catches up.
    try {
        $CleanupDC = (Get-ADDomainController -Identity $env:COMPUTERNAME -ErrorAction Stop).HostName
    }
    catch {
        # Not running on a DC - use the PDC Emulator
        $CleanupDC = $Domain.PDCEmulator
    }
    Write-Information "Metadata cleanup will run against $CleanupDC." -InformationAction Continue

    # Filled in when the DC is found in a site; used by the DNS step at the end
    $DcDnsName   = $null
    $DcAddresses = @()
    #endregion Cleanup DC

    #region NTDS and Site Cleanup
    $AllADSites = Get-ADReplicationSite -Filter *

    $FoundInSite = $false
    :AllADSites foreach ($AdSite in $AllADSites) {
        $ServerDN = "CN=$DcToRemove,CN=Servers,$($AdSite.DistinguishedName)"

        $DC_In_Site = try { Get-ADObject -Identity $ServerDN -Partition $ConfigDN -ErrorAction Stop } catch { $null }
        if ($null -eq $DC_In_Site) { continue }
        $FoundInSite = $true

        # Capture the DC's DNS name and addresses BEFORE anything is deleted (used by the DNS step)
        $DcDnsName = (Get-ADObject -Identity $ServerDN -Partition $ConfigDN -Properties dNSHostName -ErrorAction SilentlyContinue).dNSHostName
        $DcAddresses = @()
        if ($DcDnsName) {
            try {
                $DcAddresses = @([System.Net.Dns]::GetHostAddresses($DcDnsName) |
                    Where-Object { $_.AddressFamily -eq 'InterNetwork' } |
                    ForEach-Object { $_.IPAddressToString })
            }
            catch {
                Write-Verbose "[$($MyInvocation.InvocationName)] $DcDnsName does not resolve; DNS cleanup will use the name only."
            }
        }

        Write-Information "Site $($AdSite.Name) contains $DcToRemove." -InformationAction Continue

        if ($PSCmdlet.ShouldProcess($ServerDN, 'ntdsutil metadata cleanup')) {
            $StandardOut = New-TemporaryFile
            $ErrorOut    = New-TemporaryFile
            try {
                # "popups off": without it, "remove selected server" opens a Yes/No dialog box that
                # blocks this script (and hangs with no visible prompt in a remote session).
                # The operator has already confirmed by typing the DC name.
                $NtdsArgs = """popups off"" ""metadata cleanup"" ""connections"" ""connect to server $CleanupDC"" q ""remove selected server $ServerDN"" q q"
                $NTDS = Start-Process -FilePath ntdsutil -ArgumentList $NtdsArgs -Wait -NoNewWindow -PassThru -RedirectStandardOutput $StandardOut.FullName -RedirectStandardError $ErrorOut.FullName
                Get-Content -Path $StandardOut.FullName -Raw

                # ntdsutil's exit code is unreliable - verify the NTDS Settings object is actually gone
                $NtdsSettingsDN = "CN=NTDS Settings,$ServerDN"
                $CleanupState = 'Unknown'
                try {
                    $null = Get-ADObject -Identity $NtdsSettingsDN -Partition $ConfigDN -Server $CleanupDC -ErrorAction Stop
                    $CleanupState = 'StillPresent'
                }
                catch {
                    if ($_.Exception.GetType().Name -eq 'ADIdentityNotFoundException') {
                        $CleanupState = 'Removed'
                    }
                    else {
                        Write-Warning "Could not verify the cleanup on ${CleanupDC}: $($_.Exception.Message)"
                    }
                }

                switch ($CleanupState) {
                    'Removed' {
                        if ($NTDS.ExitCode -ne 0) {
                            Write-Warning "ntdsutil returned exit code $($NTDS.ExitCode), but the NTDS Settings object is gone - continuing."
                        }
                        Write-Information "Verified: NTDS Settings for $DcToRemove removed on $CleanupDC." -InformationAction Continue
                    }
                    default {
                        Get-Content -Path $ErrorOut.FullName -Raw
                        Write-Warning "Metadata cleanup NOT confirmed (state: $CleanupState, ntdsutil exit code $($NTDS.ExitCode)). Stopping before any further deletions."
                        return
                    }
                }
            }
            finally {
                Remove-Item -Path $StandardOut.FullName, $ErrorOut.FullName -Force -ErrorAction SilentlyContinue -WhatIf:$false
            }
        }

        # ntdsutil may already have removed it - re-query before deleting
        $DC_In_Site = try { Get-ADObject -Identity $ServerDN -Partition $ConfigDN -Server $CleanupDC -ErrorAction Stop } catch { $null }
        if ($DC_In_Site -and $PSCmdlet.ShouldProcess($ServerDN, 'Remove site server object (recursive)')) {
            try {
                $DC_In_Site | Remove-ADObject -Recursive -Confirm:$false -ErrorAction Stop
                Write-Information "Removed site server object $ServerDN" -InformationAction Continue
            }
            catch {
                Write-Warning "Failed to remove $ServerDN : $($_.Exception.Message)"
            }
        }
        break AllADSites
    }

    if (-not $FoundInSite) {
        Write-Warning "$DcToRemove was not found in any AD site. Check the spelling (option 14 lists every DC)."
        Write-Warning "If it belongs to another domain, run this cleanup from that domain: leftover-object cleanup only searches the current domain."
        if (-not $WhatIfPreference) {
            if (-not (Confirm-Action -Message "Continue with leftover-object and DNS cleanup for $DcToRemove anyway?" -ConfirmText $DcToRemove)) { return }
        }
    }
    #endregion NTDS and Site Cleanup

    #region Residual Object Cleanup (exact match only)
    # Escape LDAP filter special characters (RFC 4515)
    $SafeName = $DcToRemove -replace '\\', '\5c' -replace '\*', '\2a' -replace '\(', '\28' -replace '\)', '\29'
    $ResidualFilter = "(&(cn=$SafeName)(|(objectClass=computer)(objectClass=msDFSR-Member)(objectClass=nTFRSMember)(objectClass=server)))"

    $Residuals = @(
        Get-ADObject -LDAPFilter $ResidualFilter -SearchBase $DomainDN -SearchScope Subtree -Properties ObjectClass
        Get-ADObject -LDAPFilter $ResidualFilter -SearchBase $ConfigDN -SearchScope Subtree -Properties ObjectClass
    ) | Where-Object { $_ }
    $Residuals = @($Residuals)

    if ($Residuals.Count -eq 0) {
        Write-Information "No residual objects found for $DcToRemove." -InformationAction Continue
    }
    else {
        $ResidualTable = $Residuals | Select-Object ObjectClass, DistinguishedName | Format-Table -AutoSize | Out-String
        Write-Information "Residual objects matching '$DcToRemove' exactly:$ResidualTable" -InformationAction Continue

        $DeleteResiduals = $true
        if (-not $WhatIfPreference) {
            $DeleteResiduals = Confirm-Action -Message "Delete the $($Residuals.Count) object(s) above (recursively)?" -ConfirmText $DcToRemove
        }

        if ($DeleteResiduals) {
            foreach ($Object in $Residuals) {
                if ($PSCmdlet.ShouldProcess($Object.DistinguishedName, 'Remove-ADObject -Recursive')) {
                    try {
                        Remove-ADObject -Identity $Object.DistinguishedName -Recursive -Confirm:$false -ErrorAction Stop
                        Write-Information "Removed $($Object.DistinguishedName)" -InformationAction Continue
                    }
                    catch {
                        Write-Warning "Failed to remove $($Object.DistinguishedName): $($_.Exception.Message)"
                    }
                }
            }
        }
    }
    #endregion Residual Object Cleanup

    #region DNS Cleanup
    # Offer to purge DNS records for the removed DC (name, FQDN and the IPs captured before cleanup)
    $PurgeTargets = @(@($DcToRemove, $DcDnsName) + $DcAddresses | Where-Object { $_ } | Select-Object -Unique)
    if ($PurgeTargets.Count -gt 0) {
        if (-not (Get-Command -Name Get-DnsServerZone -ErrorAction SilentlyContinue)) {
            Write-Warning "DnsServer module not installed. Run menu option 8 on a DNS server for: $($PurgeTargets -join ', ')"
        }
        elseif ($WhatIfPreference) {
            Remove-DnsEntry -PurgeThis $PurgeTargets -ComputerName $CleanupDC
        }
        else {
            $DnsAnswer = ConvertTo-CleanInput -InputString (Read-Host "Also remove DNS records for $($PurgeTargets -join ', ')? You will see the list before anything is deleted. (Y/N)")
            if ($DnsAnswer -eq 'Y') {
                Remove-DnsEntry -PurgeThis $PurgeTargets -ComputerName $CleanupDC | Format-Table -AutoSize | Out-Host
            }
        }
    }
    #endregion DNS Cleanup
}

#Function to find orphaned domain controllers
function Get-OrphanedDomainControllers {
    <#
    .SYNOPSIS
        Lists every DC in the forest's AD metadata and flags suspected orphans.

    .DESCRIPTION
        Reads every NTDS Settings (nTDSDSA) object from the forest's configuration partition,
        which works from any domain in the forest. For each DC it reports:
          - Domain and site
          - Whether its computer account still exists (checked against a global catalog)
          - Whether it answers on LDAP (TCP 389)
          - The most recent successful replication FROM it, as recorded by its replication
            partners (the configuration partition replicates between every DC in the forest)

        A DC is flagged SuspectedOrphan when its computer account is missing, or when it does
        not answer on LDAP AND no partner has replicated from it within StaleDays.
        Verify every suspected orphan before running metadata cleanup (menu option 12).

    .PARAMETER StaleDays
        Days without successful replication before an unreachable DC is flagged. Default 14.

    .PARAMETER TimeoutMs
        LDAP connection timeout per DC in milliseconds. Default 2000.

    .EXAMPLE
        Get-OrphanedDomainControllers | Format-Table

    .EXAMPLE
        Get-OrphanedDomainControllers -StaleDays 7 | Where-Object SuspectedOrphan

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [ValidateRange(1, 365)]
        [int]$StaleDays = 14,

        [ValidateRange(200, 10000)]
        [int]$TimeoutMs = 2000
    )

    #region Collect metadata
    try {
        $ConfigDN    = (Get-ADRootDSE -ErrorAction Stop).configurationNamingContext
        $GlobalCat   = @((Get-ADDomainController -Discover -Service GlobalCatalog -ErrorAction Stop).HostName)[0]
        $NtdsObjects = @(Get-ADObject -SearchBase "CN=Sites,$ConfigDN" -LDAPFilter '(objectClass=nTDSDSA)' -Properties 'msDS-HasDomainNCs' -ErrorAction Stop)
        $ServerObjs  = @(Get-ADObject -SearchBase "CN=Sites,$ConfigDN" -LDAPFilter '(objectClass=server)' -Properties dNSHostName, serverReference -ErrorAction Stop)
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                $_.Exception,
                'MetadataQueryFailed',
                [System.Management.Automation.ErrorCategory]::ConnectionError,
                $ConfigDN
            )
        )
    }

    $ServerByDN = @{}
    foreach ($ServerObj in $ServerObjs) {
        $ServerByDN[$ServerObj.DistinguishedName.ToLower()] = $ServerObj
    }
    #endregion Collect metadata

    #region Per-DC checks
    $Entries = foreach ($Ntds in $NtdsObjects) {
        $ServerDN = $Ntds.DistinguishedName -replace '^CN=NTDS Settings,', ''
        $ServerObj = $ServerByDN[$ServerDN.ToLower()]
        $HostName = if ($ServerObj) { $ServerObj.dNSHostName } else { $null }
        $DomainNC = @($Ntds.'msDS-HasDomainNCs')[0]
        $Domain = if ($DomainNC) { (($DomainNC -split ',') | ForEach-Object { $_ -replace '^DC=', '' }) -join '.' } else { 'Unknown' }

        # Computer account (global catalog covers every domain in the forest)
        $ComputerAccount = 'Missing'
        $ComputerRef = if ($ServerObj) { $ServerObj.serverReference } else { $null }
        if ($ComputerRef) {
            try {
                $null = Get-ADObject -Identity $ComputerRef -Server "$($GlobalCat):3268" -ErrorAction Stop
                $ComputerAccount = 'Present'
            }
            catch {
                if ($_.Exception.GetType().Name -ne 'ADIdentityNotFoundException') {
                    $ComputerAccount = 'Unknown'
                    Write-Verbose "[$($MyInvocation.InvocationName)] Computer lookup for $ComputerRef failed: $($_.Exception.Message)"
                }
            }
        }

        # LDAP reachability with a short timeout
        $LdapReachable = $false
        if ($HostName) {
            $Tcp = [System.Net.Sockets.TcpClient]::new()
            try {
                $LdapReachable = $Tcp.ConnectAsync($HostName, 389).Wait($TimeoutMs) -and $Tcp.Connected
            }
            catch {
                $LdapReachable = $false
            }
            finally {
                $Tcp.Dispose()
            }
        }

        [pscustomobject]@{
            Name            = ($ServerDN -split ',')[0] -replace '^CN=', ''
            HostName        = $HostName
            Domain          = $Domain
            Site            = ($ServerDN -split ',')[2] -replace '^CN=', ''
            NtdsDN          = $Ntds.DistinguishedName
            ComputerAccount = $ComputerAccount
            LdapReachable   = $LdapReachable
        }
    }
    $Entries = @($Entries)
    #endregion Per-DC checks

    #region Partner view of replication
    # On each reachable DC, inbound partner metadata for the configuration partition records
    # when that DC last replicated successfully FROM each partner.
    $LastSuccess = @{}
    foreach ($Entry in ($Entries | Where-Object { $_.LdapReachable })) {
        try {
            $Partners = @(Get-ADReplicationPartnerMetadata -Target $Entry.HostName -Partition $ConfigDN -ErrorAction Stop)
        }
        catch {
            Write-Verbose "[$($MyInvocation.InvocationName)] Could not read partner metadata from $($Entry.HostName): $($_.Exception.Message)"
            continue
        }
        foreach ($Partner in $Partners) {
            if (-not $Partner.Partner -or -not $Partner.LastReplicationSuccess) { continue }
            $Key = $Partner.Partner.ToLower()
            if (-not $LastSuccess.ContainsKey($Key) -or $Partner.LastReplicationSuccess -gt $LastSuccess[$Key]) {
                $LastSuccess[$Key] = $Partner.LastReplicationSuccess
            }
        }
    }
    #endregion Partner view of replication

    #region Report
    $Cutoff = (Get-Date).AddDays(-$StaleDays)
    foreach ($Entry in $Entries) {
        $LastFrom = $LastSuccess[$Entry.NtdsDN.ToLower()]
        $Reasons = [System.Collections.Generic.List[string]]::new()
        if ($Entry.ComputerAccount -eq 'Missing') {
            $Reasons.Add('Computer account missing')
        }
        if (-not $Entry.LdapReachable -and (-not $LastFrom -or $LastFrom -lt $Cutoff)) {
            $Reasons.Add("Unreachable and no successful replication from it in $StaleDays days")
        }

        [pscustomobject]@{
            Name               = $Entry.Name
            HostName           = $Entry.HostName
            Domain             = $Entry.Domain
            Site               = $Entry.Site
            ComputerAccount    = $Entry.ComputerAccount
            LdapReachable      = $Entry.LdapReachable
            LastReplicatedFrom = $LastFrom
            SuspectedOrphan    = ($Reasons.Count -gt 0)
            Reason             = $Reasons -join '; '
        }
    }
    #endregion Report
}

# Function to push the schema partition to every domain controller in the forest
function Invoke-ADSchemaReplicationAllDCs {
    <#
    .SYNOPSIS
        Pushes the AD schema partition from the Schema Master to every DC in the forest.

    .DESCRIPTION
        Runs "repadmin /syncall <SchemaMaster> <schema partition> /d /e /P", which pushes
        the whole schema partition outward from the Schema Master to every DC in every
        site. The previous version used Sync-ADObject, which replicates a single object
        only, so it never copied the schema contents.

    .EXAMPLE
        Invoke-ADSchemaReplicationAllDCs

    .EXAMPLE
        Invoke-ADSchemaReplicationAllDCs -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param ()

    try {
        $SchemaMaster = (Get-ADForest -ErrorAction Stop).SchemaMaster
        $SchemaDN     = (Get-ADRootDSE -Server $SchemaMaster -ErrorAction Stop).schemaNamingContext
    }
    catch {
        Write-Warning "Unable to determine the schema partition or Schema Master: $($_.Exception.Message)"
        return
    }

    if (-not $PSCmdlet.ShouldProcess($SchemaDN, "repadmin /syncall (push from $SchemaMaster)")) {
        return
    }

    Write-Information "Pushing the schema partition from $SchemaMaster to all DCs. This can take a few minutes." -InformationAction Continue
    # /d = full names in output, /e = every site and domain, /P = push outward from the Schema Master
    $Output = repadmin /syncall $SchemaMaster $SchemaDN /d /e /P 2>&1
    $Output | Out-Host

    if (($Output | Out-String) -notmatch 'terminated with no errors') {
        Write-Warning "Schema sync reported errors. Review the repadmin output above."
    }
    else {
        Write-Information "Schema replication pushed to all DCs." -InformationAction Continue
    }
}

#Function to safely reset the krbtgt password
function Reset-KrbtgtPassword {
    <#
    .SYNOPSIS
        Safely performs ONE krbtgt password reset and replicates it to all writable DCs.

    .DESCRIPTION
        Verifies that the last krbtgt reset is older than MinHoursSinceLastReset and that
        domain replication is healthy, resets krbtgt on the PDC Emulator, pushes the object
        to every writable DC with Sync-ADObject, and reports PasswordLastSet per DC.
        A full key rotation requires running this TWICE, at least MinHoursSinceLastReset apart.
        RODC krbtgt_##### accounts are not touched.

    .PARAMETER MinHoursSinceLastReset
        Minimum hours since the previous krbtgt reset. Default 10 (default maximum
        Kerberos user ticket lifetime). Increase if your Kerberos policy is longer.

    .EXAMPLE
        Reset-KrbtgtPassword

    .EXAMPLE
        Reset-KrbtgtPassword -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [Parameter(Position = 0)]
        [ValidateRange(1, 720)]
        [int]$MinHoursSinceLastReset = 10
    )

    #region Pre-checks
    try {
        $Domain = Get-ADDomain -ErrorAction Stop
        $Pdc    = $Domain.PDCEmulator
        $Krbtgt = Get-ADUser -Identity krbtgt -Server $Pdc -Properties PasswordLastSet -ErrorAction Stop
    }
    catch {
        Write-Warning "Unable to query krbtgt on the PDC Emulator: $($_.Exception.Message)"
        return
    }

    $HoursSince = ((Get-Date) - $Krbtgt.PasswordLastSet).TotalHours
    if ($HoursSince -lt $MinHoursSinceLastReset) {
        Write-Warning ("krbtgt was last reset {0:N1} hours ago ({1}). Wait until {2} before resetting again, or Kerberos authentication can break." -f $HoursSince, $Krbtgt.PasswordLastSet, $Krbtgt.PasswordLastSet.AddHours($MinHoursSinceLastReset))
        return
    }

    try {
        $Failures = @(Get-ADReplicationFailure -Target $Domain.DNSRoot -Scope Domain -ErrorAction Stop | Where-Object { $_.FailureCount -gt 0 })
    }
    catch {
        Write-Warning "Could not verify replication health: $($_.Exception.Message). Aborting."
        return
    }
    if ($Failures.Count -gt 0) {
        $FailureTable = $Failures | Select-Object Server, Partner, FailureCount, LastError | Format-Table -AutoSize | Out-String
        Write-Warning "Replication failures detected. Fix replication before resetting krbtgt:$FailureTable"
        return
    }
    #endregion Pre-checks

    #region Reset
    if (-not $PSCmdlet.ShouldProcess("krbtgt in $($Domain.DNSRoot) via $Pdc", "Reset password (one of two resets in a full rotation)")) {
        return
    }

    try {
        # The value is irrelevant - the DC generates its own strong krbtgt password
        $NewPassword = ConvertTo-SecureString -String (Get-RandomString -length 32) -AsPlainText -Force
        Set-ADAccountPassword -Identity krbtgt -Reset -NewPassword $NewPassword -Server $Pdc -ErrorAction Stop
        Write-Information "krbtgt password reset on $Pdc." -InformationAction Continue
    }
    catch {
        Write-Warning "krbtgt reset failed: $($_.Exception.Message)"
        return
    }
    #endregion Reset

    #region Replicate
    $KrbtgtObject = Get-ADUser -Identity krbtgt -Server $Pdc
    $WritableDcs  = @(Get-ADDomainController -Filter * | Where-Object { -not $_.IsReadOnly })

    foreach ($Dc in ($WritableDcs | Where-Object { $_.HostName -ne $Pdc })) {
        try {
            Sync-ADObject -Object $KrbtgtObject -Source $Pdc -Destination $Dc.HostName -ErrorAction Stop
            Write-Verbose "Replicated krbtgt to $($Dc.HostName)"
        }
        catch {
            Write-Warning "Failed to replicate krbtgt to $($Dc.HostName): $($_.Exception.Message)"
        }
    }
    #endregion Replicate

    #region Verify
    $Expected = (Get-ADUser -Identity krbtgt -Server $Pdc -Properties PasswordLastSet).PasswordLastSet

    $Report = foreach ($Dc in $WritableDcs) {
        try {
            $Seen = (Get-ADUser -Identity krbtgt -Server $Dc.HostName -Properties PasswordLastSet -ErrorAction Stop).PasswordLastSet
            [pscustomobject]@{ DomainController = $Dc.HostName; PasswordLastSet = $Seen; InSync = ($Seen -eq $Expected) }
        }
        catch {
            [pscustomobject]@{ DomainController = $Dc.HostName; PasswordLastSet = $null; InSync = $false }
        }
    }

    Write-Output $Report

    if ($Report.InSync -contains $false) {
        Write-Warning "Not all writable DCs show the new password yet. Re-check before the second reset."
    }
    Write-Information "Do NOT perform the second reset before $($Expected.AddHours($MinHoursSinceLastReset))." -InformationAction Continue
    #endregion Verify
}
#Function to check what this session can do
function Initialize-ToolkitEnvironment {
    <#
    .SYNOPSIS
        Loads required modules and reports which toolkit features are available.

    .DESCRIPTION
        Checks for elevation, attempts to import ActiveDirectory and query the forest/domain,
        and checks whether the DnsServer module exists. Never throws - returns a status
        object so the banner and menu can adapt instead of crashing at launch.

    .EXAMPLE
        $script:ToolkitEnv = Initialize-ToolkitEnvironment
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param ()

    $Status = [pscustomobject]@{
        IsAdmin      = $false
        AdAvailable  = $false
        DnsAvailable = $false
        Forest       = $null
        Domain       = $null
        AdError      = $null
    }

    $Identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = [System.Security.Principal.WindowsPrincipal]::new($Identity)
    $Status.IsAdmin = $Principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        $Status.Forest = Get-ADForest -ErrorAction Stop
        $Status.Domain = Get-ADDomain -ErrorAction Stop
        $Status.AdAvailable = $true
    }
    catch {
        $Status.AdError = $_.Exception.Message
        Write-Verbose "[$($MyInvocation.InvocationName)] AD unavailable: $($Status.AdError)"
    }

    $Status.DnsAvailable = [bool](Get-Module -ListAvailable -Name DnsServer)
    return $Status
}

#Function to display the startup banner
function Show-ToolkitBanner {
    <#
    .SYNOPSIS
        Displays the toolkit banner and environment summary.

    .DESCRIPTION
        Uses cached forest/domain data from Initialize-ToolkitEnvironment. AD details are
        only shown when AD is available; otherwise a warning explains which options are
        disabled. Write-Host is used intentionally here for colored console output.

    .PARAMETER Environment
        The status object returned by Initialize-ToolkitEnvironment.

    .EXAMPLE
        Show-ToolkitBanner -Environment $script:ToolkitEnv
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [pscustomobject]$Environment
    )

    $Green = @{ ForegroundColor = 'Green' }

    Write-Host ""
    Write-Host "===========================================================" @Green
    Write-Host "|                                                         |" @Green
    Write-Host "|              Active Directory Toolkit                   |" @Green
    Write-Host "|                                                         |" @Green
    Write-Host "|                Written By: Colby C                      |" @Green
    Write-Host "|                                                         |" @Green
    Write-Host "===========================================================" @Green
    Write-Host ""
    Write-Host "You are working on $env:COMPUTERNAME" @Green

    $IPs = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
        Select-Object -ExpandProperty IPAddress)
    Write-Host "The IP is $($IPs -join ', ')" @Green
    Write-Host ""

    if (-not $Environment.IsAdmin) {
        Write-Warning "This session is not elevated. Run as Administrator for options that change this machine or run ntdsutil (for example 7 and 12)."
    }

    if (-not $Environment.AdAvailable) {
        Write-Warning "Active Directory is unavailable: $($Environment.AdError)"
        if ($Environment.DnsAvailable) {
            Write-Warning "AD options (0-6, 11-15) are disabled this session. Options 7, 8, 9 and 10 still work."
        }
        else {
            Write-Warning "AD options (0-6, 11-15) are disabled this session. Options 7, 9 and 10 still work (8 also works once the DnsServer module is installed)."
        }
        return
    }

    if (-not $Environment.DnsAvailable) {
        Write-Warning "The DnsServer module is not installed. Option 8 (Purge DNS) is disabled this session."
    }

    Write-Host "The domain is $($Environment.Domain.DNSRoot)" @Green
    Write-Host ""
    Write-Host "The domain controllers are:" @Green
    try {
        Get-ADDomainController -Filter * -ErrorAction Stop |
            Select-Object Name, IPv4Address, Site, OperatingSystem |
            Format-Table -AutoSize | Out-String | Write-Host @Green
    }
    catch {
        Write-Warning "Unable to list domain controllers: $($_.Exception.Message)"
    }

    Write-Host "The FSMO roles holders are:" @Green
    Write-Host "Schema Master : $($Environment.Forest.SchemaMaster)" @Green
    Write-Host "Domain Naming Master : $($Environment.Forest.DomainNamingMaster)" @Green
    Write-Host "PDC Emulator : $($Environment.Domain.PDCEmulator)" @Green
    Write-Host "RID Master : $($Environment.Domain.RIDMaster)" @Green
    Write-Host "Infrastructure Master : $($Environment.Domain.InfrastructureMaster)" @Green
    Write-Host ""
}

#Function to list users with administrative privileges
function Get-PrivilegedADUser {
    <#
    .SYNOPSIS
        Lists users with administrative privileges through membership in protected groups.

    .DESCRIPTION
        Resolves the built-in privileged groups by well-known SID (works if they are renamed
        or localized), then finds every direct or nested user member with one
        LDAP_MATCHING_RULE_IN_CHAIN query per group. Users whose primary group is a privileged
        domain group are also included. Returns one row per user with the group(s) that
        grant the privilege.

        Groups checked: Administrators, Domain Admins, Enterprise Admins, Schema Admins,
        Account Operators, Server Operators, Print Operators, Backup Operators.

        With -IncludeAdminCount, accounts with adminCount=1 that were not found through the
        groups above are also returned. adminCount is set by SDProp (AdminSDHolder) and is NOT
        cleared when an account leaves a protected group, so these rows are review candidates:
        former admins, or members of other protected groups not listed above.

    .PARAMETER IncludeAdminCount
        Also return accounts flagged adminCount=1 that are not current members of the groups above.

    .EXAMPLE
        Get-PrivilegedADUser -IncludeAdminCount | Sort-Object Name | Export-Csv C:\FT\Admins.csv -NoTypeInformation -Encoding UTF8

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [switch]$IncludeAdminCount
    )

    $Domain    = Get-ADDomain -ErrorAction Stop
    $Forest    = Get-ADForest -ErrorAction Stop
    $DomainSid = $Domain.DomainSID.Value

    # Enterprise Admins and Schema Admins live in the forest root domain
    $RootSid = $null
    try {
        $RootSid = (Get-ADDomain -Identity $Forest.RootDomain -Server $Forest.RootDomain -ErrorAction Stop).DomainSID.Value
    }
    catch {
        Write-Warning "Unable to query the forest root domain ($($Forest.RootDomain)). Enterprise Admins and Schema Admins will be skipped."
    }

    $GroupMap = [ordered]@{
        'S-1-5-32-544'   = $Domain.DNSRoot    # Administrators (builtin)
        "$DomainSid-512" = $Domain.DNSRoot    # Domain Admins
        'S-1-5-32-548'   = $Domain.DNSRoot    # Account Operators
        'S-1-5-32-549'   = $Domain.DNSRoot    # Server Operators
        'S-1-5-32-550'   = $Domain.DNSRoot    # Print Operators
        'S-1-5-32-551'   = $Domain.DNSRoot    # Backup Operators
    }
    if ($RootSid) {
        $GroupMap["$RootSid-519"] = $Forest.RootDomain   # Enterprise Admins
        $GroupMap["$RootSid-518"] = $Forest.RootDomain   # Schema Admins
    }

    $Properties = 'CanonicalName', 'Created', 'LastLogonDate', 'mail', 'PasswordLastSet', 'PasswordNeverExpires', 'Enabled', 'adminCount'
    $Results = @{}

    foreach ($Sid in $GroupMap.Keys) {
        try {
            $Group = Get-ADGroup -Identity $Sid -Server $GroupMap[$Sid] -ErrorAction Stop
        }
        catch {
            Write-Verbose "[$($MyInvocation.InvocationName)] Group $Sid not found in $($GroupMap[$Sid]); skipping."
            continue
        }

        # Escape LDAP filter special characters in the DN (RFC 4515)
        $SafeDN = $Group.DistinguishedName -replace '\\', '\5c' -replace '\*', '\2a' -replace '\(', '\28' -replace '\)', '\29'
        $Filter = "(memberOf:1.2.840.113556.1.4.1941:=$SafeDN)"

        # Primary group membership is not reflected in memberOf - check it for same-domain groups
        if ($Sid -like "$DomainSid-*") {
            $Rid = $Sid.Split('-')[-1]
            $Filter = "(|$Filter(primaryGroupID=$Rid))"
        }

        try {
            $Users = @(Get-ADUser -LDAPFilter $Filter -Properties $Properties -ErrorAction Stop)
        }
        catch {
            Write-Warning "Failed to query members of $($Group.Name): $($_.Exception.Message)"
            continue
        }

        Write-Verbose "[$($MyInvocation.InvocationName)] $($Group.Name): $($Users.Count) user(s)"

        foreach ($User in $Users) {
            $Key = $User.SID.Value
            if (-not $Results.ContainsKey($Key)) {
                $Results[$Key] = [pscustomobject]@{
                    User = $User
                    Via  = [System.Collections.Generic.List[string]]::new()
                }
            }
            $Results[$Key].Via.Add($Group.Name)
        }
    }

    if ($IncludeAdminCount) {
        try {
            $Flagged = @(Get-ADUser -LDAPFilter '(adminCount=1)' -Properties $Properties -ErrorAction Stop)
        }
        catch {
            Write-Warning "Failed to query adminCount=1 accounts: $($_.Exception.Message)"
            $Flagged = @()
        }

        foreach ($User in $Flagged) {
            $Key = $User.SID.Value
            if (-not $Results.ContainsKey($Key)) {
                $Results[$Key] = [pscustomobject]@{
                    User = $User
                    Via  = [System.Collections.Generic.List[string]]::new()
                }
                $Results[$Key].Via.Add('adminCount=1 only (protected now or previously - review)')
            }
        }
    }

    foreach ($Entry in $Results.Values) {
        $U = $Entry.User
        [pscustomobject]@{
            Name                 = $U.Name
            SamAccountName       = $U.SamAccountName
            CanonicalName        = $U.CanonicalName
            Created              = $U.Created
            LastLogonDate        = $U.LastLogonDate
            Mail                 = $U.mail
            PasswordLastSet      = $U.PasswordLastSet
            PasswordNeverExpires = $U.PasswordNeverExpires
            Enabled              = $U.Enabled
            AdminCount           = $U.adminCount
            PrivilegedVia        = $Entry.Via -join '; '
        }
    }
}

#endregion Functions #####

#######################
#region Formatting #####
#####################

####Set a window title and foreground color (console host only; original color restored on exit)
$script:OriginalForeground = $null
if ($Host.Name -eq 'ConsoleHost') {
    try {
        $Host.UI.RawUI.WindowTitle = "Active Directory Toolkit"
        $script:OriginalForeground = $Host.UI.RawUI.ForegroundColor
        $Host.UI.RawUI.ForegroundColor = 'Cyan'
    }
    catch {
        Write-Verbose "Unable to set console title/color: $($_.Exception.Message)"
    }
}

$script:ToolkitEnv = Initialize-ToolkitEnvironment
Show-ToolkitBanner -Environment $script:ToolkitEnv

# Ask for the working folder once; every option reuses it (menu option 98 changes it)
$WorkDirAnswer = Read-UserPath -Prompt "Enter the path you want to use for the working directory. Leave blank to use the default $env:SystemDrive\FT"
$script:WorkDir = Set-ProjectFolder -BaseDir $WorkDirAnswer
Write-Information "The working folder is $script:WorkDir" -InformationAction Continue

#endregion Formatting #####

#########################
#region Do The Thing #####
#######################
# Options that need the ActiveDirectory module and a reachable domain
$AdOptions = '0','1','2','3','4','5','6','11','12','13','14','15'

try {
    do {
        # Prompt the user to choose an option
        $userChoice = (ConvertTo-CleanInput -InputString (Read-MenuChoice)).ToUpper()
        # Q is accepted as an alias for 99
        if ($userChoice -eq 'Q') { $userChoice = '99' }

        # Block options this session cannot run, instead of letting them crash
        if ($userChoice -in $AdOptions -and -not $script:ToolkitEnv.AdAvailable) {
            Write-Warning "Option $userChoice requires the ActiveDirectory module and a reachable domain. ($($script:ToolkitEnv.AdError))"
            continue
        }
        if ($userChoice -eq '8' -and -not $script:ToolkitEnv.DnsAvailable) {
            Write-Warning "Option 8 requires the DnsServer module (run it on a DNS server, or install RSAT DNS tools)."
            continue
        }

        # Any terminating error in an option is reported here and the menu continues
        try {
            # Call the corresponding function based on the user's choice
            switch ($userChoice) {
                #Health checks
                0 {
                    # repadmin and dcdiag ship with the AD DS role, or with RSAT on other machines
                    if (-not (Get-Command -Name repadmin.exe -ErrorAction SilentlyContinue) -or
                        -not (Get-Command -Name dcdiag.exe -ErrorAction SilentlyContinue)) {
                        Write-Warning "repadmin and dcdiag were not found. Install the AD DS tools first:"
                        Write-Warning "  Windows Server:  Install-WindowsFeature RSAT-ADDS-Tools"
                        Write-Warning "  Windows 10/11:   Add-WindowsCapability -Online -Name 'Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0'"
                        break
                    }

                    #Ask the user to use default workdir or not
                    $outputDir = $script:WorkDir

                    #Ask for the scope
                    $HealthScope = ConvertTo-CleanInput -InputString (Read-Host "Run the health checks on:
1 - One DC
2 - All DCs in the forest (slower)
")
                    if ($HealthScope -notin '1', '2') {
                        Write-Information "Invalid entry. Please enter 1 or 2." -InformationAction Continue
                        break
                    }

                    # Home DC for repadmin/dcdiag: this machine if it is a DC (DomainRole 4 or 5),
                    # otherwise the PDC Emulator. dcdiag without /s: uses the local computer,
                    # which fails on a workstation or member server.
                    $LocalIsDc = $false
                    try {
                        $LocalIsDc = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).DomainRole -ge 4
                    }
                    catch {
                        Write-Verbose "Could not read this machine's domain role: $($_.Exception.Message)"
                    }
                    $HomeDC = $env:COMPUTERNAME
                    if (-not $LocalIsDc) {
                        try {
                            $HomeDC = (Get-ADDomain -ErrorAction Stop).PDCEmulator
                        }
                        catch {
                            Write-Warning "This computer is not a DC and the PDC Emulator could not be found: $($_.Exception.Message)"
                            break
                        }
                    }

                    $TargetDC = $null
                    if ($HealthScope -eq '1') {
                        $TargetDC = ConvertTo-CleanInput -InputString (Read-Host "Which DC? Leave blank for $HomeDC")
                        if ([string]::IsNullOrEmpty($TargetDC)) {
                            $TargetDC = $HomeDC
                        }

                        # Catch typos before writing a report full of connection errors
                        try {
                            $null = Get-ADDomainController -Identity $TargetDC -ErrorAction Stop
                        }
                        catch {
                            Write-Warning "'$TargetDC' was not found as a domain controller in this domain."
                            if ((ConvertTo-CleanInput -InputString (Read-Host "Run the checks against it anyway? (Y/N)")) -ne 'Y') {
                                Write-Information "Cancelled." -InformationAction Continue
                                break
                            }
                        }
                    }

                    # Report path: <DC or AllDCs>_HealthChecks_MMddyy_HHmm.txt
                    $HName = if ($TargetDC) { ($TargetDC -split '\.')[0] } else { 'AllDCs' }
                    $outputFile = New-ReportPath -OutputDir $outputDir -BaseName HealthChecks -Extension txt -Prefix $HName

                    #Generate the file
                    $null = New-Item -Path $outputFile -ItemType File -Force

                    # Run the commands and write the output to the file
                    $Forest = Get-ADForest
                    $Domain = Get-ADDomain
                    Write-Information "Getting FSMO roles" -InformationAction Continue
                    Add-Content -LiteralPath $outputFile -Value "-----FSMO START-----"
                    Add-Content -LiteralPath $outputFile -Value "Schema Master : $($Forest.SchemaMaster)"
                    Add-Content -LiteralPath $outputFile -Value "Domain Naming Master : $($Forest.DomainNamingMaster)"
                    Add-Content -LiteralPath $outputFile -Value "PDC Emulator : $($Domain.PDCEmulator)"
                    Add-Content -LiteralPath $outputFile -Value "RID Master : $($Domain.RIDMaster)"
                    Add-Content -LiteralPath $outputFile -Value "Infrastructure Master : $($Domain.InfrastructureMaster)"
                    Add-Content -LiteralPath $outputFile -Value "-----FSMO END-----"

                    if ($HealthScope -eq '2') {
                        # Forest-wide. 2>&1 captures tool errors in the report too.
                        Write-Information "Running repadmin /replsummary" -InformationAction Continue
                        Add-Content -LiteralPath $outputFile -Value "-----REPLSUMMARY START-----"
                        repadmin /replsummary 2>&1 | Add-Content -LiteralPath $outputFile
                        Add-Content -LiteralPath $outputFile -Value "-----REPLSUMMARY END-----"

                        Write-Information "Running repadmin /showrepl * (all DCs)" -InformationAction Continue
                        Add-Content -LiteralPath $outputFile -Value "-----REPADMIN START-----"
                        repadmin /showrepl * 2>&1 | Add-Content -LiteralPath $outputFile
                        Add-Content -LiteralPath $outputFile -Value "-----REPADMIN END-----"

                        # /e = every DC in the forest, /c = comprehensive tests, /q = errors only (keeps a forest-wide report readable)
                        Write-Information "Running dcdiag /e /c /q from $HomeDC (all DCs - this can take a long time)" -InformationAction Continue
                        Add-Content -LiteralPath $outputFile -Value "-----DCDIAG START-----"
                        dcdiag "/s:$HomeDC" /e /c /q 2>&1 | Add-Content -LiteralPath $outputFile
                        Add-Content -LiteralPath $outputFile -Value "-----DCDIAG END-----"
                    }
                    else {
                        Write-Information "Running repadmin /showrepl against $TargetDC" -InformationAction Continue
                        Add-Content -LiteralPath $outputFile -Value "-----REPADMIN START-----"
                        repadmin /showrepl $TargetDC 2>&1 | Add-Content -LiteralPath $outputFile
                        Add-Content -LiteralPath $outputFile -Value "-----REPADMIN END-----"

                        Write-Information "Running dcdiag /v against $TargetDC" -InformationAction Continue
                        Add-Content -LiteralPath $outputFile -Value "-----DCDIAG START-----"
                        dcdiag "/s:$TargetDC" /v 2>&1 | Add-Content -LiteralPath $outputFile
                        Add-Content -LiteralPath $outputFile -Value "-----DCDIAG END-----"

                        Write-Information "Running dcdiag /test:netlogons against $TargetDC" -InformationAction Continue
                        Add-Content -LiteralPath $outputFile -Value "-----NETLOGON START-----"
                        dcdiag "/s:$TargetDC" /test:netlogons 2>&1 | Add-Content -LiteralPath $outputFile
                        Add-Content -LiteralPath $outputFile -Value "-----NETLOGON END-----"
                    }

                    # Notify the user
                    Write-Information "Health check report saved to $outputFile" -InformationAction Continue
                    # Short on-screen summary so the file does not have to be opened to check for failures
                    $FailedTests = @(Select-String -LiteralPath $outputFile -Pattern 'failed test')
                    $ReplErrors  = @(Select-String -LiteralPath $outputFile -Pattern 'failed,|error 0x|RPC server is unavailable')
                    if ($FailedTests.Count -eq 0 -and $ReplErrors.Count -eq 0) {
                        Write-Host "Summary: all dcdiag tests passed and no replication errors detected." -ForegroundColor Green
                    }
                    else {
                        if ($FailedTests.Count -gt 0) {
                            Write-Warning "$($FailedTests.Count) dcdiag test failure(s):"
                            $FailedTests | Select-Object -ExpandProperty Line -Unique | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
                        }
                        if ($ReplErrors.Count -gt 0) {
                            Write-Warning "$($ReplErrors.Count) replication error line(s) found - see the report for details."
                        }
                    }
                    if ((ConvertTo-CleanInput -InputString (Read-Host "Open the report now? (Y/N)")) -eq 'Y') {
                        Invoke-Item -LiteralPath $outputFile
                    }
                }
                #Pull users
                1 {
                    #Ask the user to use default workdir or not
                    $outputDir = $script:WorkDir
                    $userType = ConvertTo-CleanInput -InputString (Read-Host "Would you like to:
1 - Pull all active users
2 - Pull all users with administrative privileges
")
                    switch ($userType) {
                        1 {
                            # Report path: <domain>_Users_MMddyy_HHmm.csv
                            $outputFile = New-ReportPath -OutputDir $outputDir -BaseName Users -Prefix (Get-DomainName)

                            #Do the thing
                            Get-ADUser -Filter 'enabled -eq $true' -properties name,SamAccountName,CanonicalName,created,lastlogondate,mail,passwordlastset,passwordneverexpires,enabled | Select-Object name,SamAccountName,CanonicalName,created,lastlogondate,mail,passwordlastset,passwordneverexpires,enabled | Export-Csv -LiteralPath $outputFile -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
                            Write-Information "Saved to $outputFile" -InformationAction Continue
                        }
                        2 {
                            # Report path: <domain>_AdminUsers_MMddyy_HHmm.csv
                            $outputFile = New-ReportPath -OutputDir $outputDir -BaseName AdminUsers -Prefix (Get-DomainName)

                            #Do the thing
                            Get-PrivilegedADUser -IncludeAdminCount | Sort-Object Name | Export-Csv -LiteralPath $outputFile -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
                            Write-Information "Saved to $outputFile" -InformationAction Continue
                        }
                        default { Write-Information "Invalid entry. Please enter 1 or 2." -InformationAction Continue }
                    }
                }
                #Pull computers
                2 {
                    #Ask the user to use default workdir or not
                    $outputDir = $script:WorkDir
                    $pcType = ConvertTo-CleanInput -InputString (Read-Host "Would you like to:
1 - Pull all computers
2 - Pull domain controllers
")
                    switch ($pcType) {
                        1 {
                            # Report path: <domain>_Computers_MMddyy_HHmm.csv
                            $outputFile = New-ReportPath -OutputDir $outputDir -BaseName Computers -Prefix (Get-DomainName)

                            #Do the thing
                            Get-ADComputer -Filter * -Properties name,LastLogonDate,OperatingSystem,description | Select-Object name,LastLogonDate,OperatingSystem,description | Export-Csv -LiteralPath $outputFile -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
                            Write-Information "Saved to $outputFile" -InformationAction Continue
                        }
                        2 {
                            # Report path: <domain>_DCs_MMddyy_HHmm.csv
                            $outputFile = New-ReportPath -OutputDir $outputDir -BaseName DCs -Prefix (Get-DomainName)

                            # Find DCs by role, not by OU: primary group 516 = writable DCs, 521 = read-only DCs,
                            # plus the SERVER_TRUST_ACCOUNT flag (8192). Works even if a DC was moved out of the Domain Controllers OU.
                            Get-ADComputer -LDAPFilter '(|(primaryGroupID=516)(primaryGroupID=521)(userAccountControl:1.2.840.113556.1.4.803:=8192))' -Properties Name,LastLogonDate,OperatingSystem,Description,DistinguishedName |
                                Select-Object Name,LastLogonDate,OperatingSystem,Description,DistinguishedName |
                                Export-Csv -LiteralPath $outputFile -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
                            Write-Information "Saved to $outputFile" -InformationAction Continue
                        }
                        default { Write-Information "Invalid entry. Please enter 1 or 2." -InformationAction Continue }
                    }
                }
                #Set pw
                3 {
                    Write-Host -ForegroundColor Yellow "The account column is found regardless of case or stray spaces (any variation of 'SamAccountName' works). Choosing 'passwords from the CSV' also requires a 'Password' column."
                    $PwCsvPath = Read-UserPath -Prompt "Enter the path to the CSV with the list of SAM Account Names. Leave blank to cancel" -RequireFile
                    if ([string]::IsNullOrEmpty($PwCsvPath)) {
                        Write-Information "Cancelled." -InformationAction Continue
                        break
                    }
                    $CsvOrRand = ConvertTo-CleanInput -InputString (Read-Host "Would you like to
1 - Generate random passwords
2 - Use passwords listed in the CSV
")
                    switch ($CsvOrRand) {
                        1 {
                            $CSVOut = Read-UserPath -Prompt "Enter the path for the output CSV with passwords (a file or a folder). Leave blank to save UpdatedPasswords_<date>_<time>.csv in $script:WorkDir"

                            # Re-prompt until a valid whole number is entered (no more [int] cast crash)
                            $PwCharCnt = $null
                            while ($null -eq $PwCharCnt) {
                                $PwInput = ConvertTo-CleanInput -InputString (Read-Host "How many characters should the password be (8-128)? Leave blank for 14")
                                $Parsed = 0
                                if ([string]::IsNullOrEmpty($PwInput)) {
                                    $PwCharCnt = 14
                                }
                                elseif ([int]::TryParse($PwInput, [ref]$Parsed) -and $Parsed -ge 8 -and $Parsed -le 128) {
                                    $PwCharCnt = $Parsed
                                }
                                else {
                                    Write-Warning "Please enter a whole number between 8 and 128."
                                }
                            }

                            $ChangeAtLogon = (ConvertTo-CleanInput -InputString (Read-Host "Require these users to change the password at next sign-in? (Y/N)")) -eq 'Y'
                            $PwParams = @{
                                CsvName             = $PwCsvPath
                                ProjectFolder       = $script:WorkDir
                                PwLength            = $PwCharCnt
                                ChangePwAtNextLogon = $ChangeAtLogon
                            }
                            if (-not [string]::IsNullOrEmpty($CSVOut)) {
                                $PwParams.OutputCsv = $CSVOut
                            }
                            $PreviewAction = "Reset password (random, $PwCharCnt characters)"
                            if ($ChangeAtLogon) { $PreviewAction += ' + must change at next sign-in' }
                            if (-not (Show-CsvChangePreview -CsvPath $PwCsvPath -Action $PreviewAction)) {
                                Write-Information "Cancelled." -InformationAction Continue
                                break
                            }
                            Set-ADPasswordFromCSV @PwParams
                        }
                        2 {
                            $ChangeAtLogon = (ConvertTo-CleanInput -InputString (Read-Host "Require these users to change the password at next sign-in? (Y/N)")) -eq 'Y'
                            $PreviewAction = "Reset password (from the CSV's Password column)"
                            if ($ChangeAtLogon) { $PreviewAction += ' + must change at next sign-in' }
                            if (Show-CsvChangePreview -CsvPath $PwCsvPath -ExtraColumnTitle 'Password' -Action $PreviewAction) {
                                Set-ADPasswordFromCSV -CsvName $PwCsvPath -PwFromCSV -ProjectFolder $script:WorkDir -ChangePwAtNextLogon:$ChangeAtLogon
                            }
                            else {
                                Write-Information "Cancelled." -InformationAction Continue
                            }
                        }
                        default {
                            Write-Information "Please enter 1 for random passwords, or 2 for passwords from CSV." -InformationAction Continue
                        }
                    }
                }
                #Remove pw no expire
                4 {
                    $AllOrCsv = ConvertTo-CleanInput -InputString (Read-Host "Would you like to:
1 - Remove the password never expires flag from all users
2 - Remove the password never expires flag from users in a csv
3 - Set the password never expires flag for users in a csv
")
                    $CsvPrompt = "Enter the path to the CSV with the list of SAM Account Names. Leave blank to cancel"
                    switch ($AllOrCsv) {
                        1 {
                            $UserCount = @(Get-AdUserForBulkChange).Count
                            if (Confirm-Action -Message "This REMOVES 'Password Never Expires' from ALL $UserCount enabled accounts (krbtgt excluded), including service accounts.") {
                                $UserSetDir = $script:WorkDir
                                Set-PasswordNeverExpires -ProjectFolder $UserSetDir
                            }
                        }
                        2 {
                            $UserSetCSV = Read-UserPath -Prompt $CsvPrompt -RequireFile
                            if ([string]::IsNullOrEmpty($UserSetCSV)) { Write-Information "Cancelled." -InformationAction Continue; break }
                            if (-not (Show-CsvChangePreview -CsvPath $UserSetCSV -Action "Remove 'Password Never Expires'")) {
                                Write-Information "Cancelled." -InformationAction Continue
                                break
                            }
                            $UserSetDir = $script:WorkDir
                            Set-PasswordNeverExpires -CsvName $UserSetCSV -ProjectFolder $UserSetDir
                        }
                        3 {
                            $UserSetCSV = Read-UserPath -Prompt $CsvPrompt -RequireFile
                            if ([string]::IsNullOrEmpty($UserSetCSV)) { Write-Information "Cancelled." -InformationAction Continue; break }
                            if (-not (Show-CsvChangePreview -CsvPath $UserSetCSV -Action "Set 'Password Never Expires'")) {
                                Write-Information "Cancelled." -InformationAction Continue
                                break
                            }
                            $UserSetDir = $script:WorkDir
                            Set-PasswordNeverExpires -CsvName $UserSetCSV -ProjectFolder $UserSetDir -SetEnable
                        }
                        default {
                            Write-Information "Please enter 1, 2, or 3." -InformationAction Continue
                        }
                    }
                }
                #Set pw expire
                5 {
                    $AllOrCsv = ConvertTo-CleanInput -InputString (Read-Host "Would you like to:
1 - Set the password to expire at next logon for all users
2 - Set the password to expire at next logon for users from a csv
")
                    switch ($AllOrCsv) {
                        1 {
                            $UserCount = @(Get-AdUserForBulkChange).Count
                            if (Confirm-Action -Message "This forces a password change at next logon for ALL $UserCount enabled accounts (krbtgt excluded).") {
                                $UserSetDir = $script:WorkDir
                                Set-PwExpiresNextLogon -ProjectFolder $UserSetDir
                            }
                        }
                        2 {
                            $UserSetCSV = Read-UserPath -Prompt "Enter the path to the CSV with the list of SAM Account Names. Leave blank to cancel" -RequireFile
                            if ([string]::IsNullOrEmpty($UserSetCSV)) { Write-Information "Cancelled." -InformationAction Continue; break }
                            if (-not (Show-CsvChangePreview -CsvPath $UserSetCSV -Action "Force a password change at next logon")) {
                                Write-Information "Cancelled." -InformationAction Continue
                                break
                            }
                            $UserSetDir = $script:WorkDir
                            Set-PwExpiresNextLogon -CsvName $UserSetCSV -ProjectFolder $UserSetDir
                        }
                        default {
                            Write-Information "Please enter 1 or 2" -InformationAction Continue
                        }
                    }
                }
                #Disable accounts
                6 {
                    $UserSetCSV = Read-UserPath -Prompt "Enter the path to the CSV with the list of SAM Account Names. Leave blank to cancel" -RequireFile
                    if ([string]::IsNullOrEmpty($UserSetCSV)) { Write-Information "Cancelled." -InformationAction Continue; break }
                    if (-not (Show-CsvChangePreview -CsvPath $UserSetCSV -Action "Disable the accounts")) {
                        Write-Information "Cancelled." -InformationAction Continue
                        break
                    }
                    $UserSetDir = $script:WorkDir
                    Disable-AdAccountFromCSV -CsvName $UserSetCSV -ProjectFolder $UserSetDir
                }
                #Set DNS
                7 {
                    #Show the adapters that can be changed
                    $DnsAdapters = @(Get-DnsTargetAdapter)
                    if ($DnsAdapters.Count -eq 0) {
                        Write-Warning "No connected adapters with an IPv4 address were found."
                        break
                    }
                    $DnsAdapters | Format-Table -AutoSize | Out-Host

                    #Ask the user which adapters and which IPs
                    $UserIndexes = ConvertTo-CleanInput -InputString (Read-Host "Enter the InterfaceIndex value(s) to change, separated by commas. Leave blank for all adapters listed")

                    Write-Information "Finding suggested DNS servers..." -InformationAction Continue
                    $Suggested = Get-SuggestedDnsServer

                    $PrimaryPrompt = if ($Suggested.Primary) { "Enter the Primary DNS IP. Leave blank for $($Suggested.Primary) ($($Suggested.Note))" }
                                     else { "Enter the Primary DNS IP (no suggestion available: $($Suggested.Note))" }
                    $UserPrimaryIP = ConvertTo-CleanInput -InputString (Read-Host $PrimaryPrompt)
                    if ([string]::IsNullOrEmpty($UserPrimaryIP)) {
                        $UserPrimaryIP = $Suggested.Primary
                    }
                    if ([string]::IsNullOrEmpty($UserPrimaryIP)) {
                        Write-Warning "No primary DNS server entered. Cancelled."
                        break
                    }

                    $SecondaryPrompt = if ($Suggested.Secondary) { "Enter the Secondary DNS IP. Leave blank for $($Suggested.Secondary), or type NONE for no secondary" }
                                       else { "Enter the Secondary DNS IP. Leave blank for none" }
                    $UserSecondaryIP = ConvertTo-CleanInput -InputString (Read-Host $SecondaryPrompt)
                    if ($UserSecondaryIP -eq 'NONE') {
                        $UserSecondaryIP = ''
                    }
                    elseif ([string]::IsNullOrEmpty($UserSecondaryIP)) {
                        $UserSecondaryIP = $Suggested.Secondary
                    }

                    if ($UserPrimaryIP -eq '127.0.0.1' -and $Suggested.LocalRunsDns -and $Suggested.Primary -and $Suggested.Primary -ne '127.0.0.1') {
                        Write-Warning "Loopback as the primary DNS server is flagged by Microsoft's Best Practices Analyzer when other DCs exist. Suggested order: $($Suggested.Primary), then 127.0.0.1."
                    }

                    $DnsParams = @{
                        Primary = $UserPrimaryIP
                    }
                    if (-not [string]::IsNullOrEmpty($UserSecondaryIP)) {
                        $DnsParams.Secondary = $UserSecondaryIP
                    }
                    if (-not [string]::IsNullOrEmpty($UserIndexes)) {
                        $IndexList = @($UserIndexes -split '[,\s]+' | Where-Object { $_ })
                        if (@($IndexList | Where-Object { $_ -notmatch '^\d+$' }).Count -gt 0) {
                            Write-Warning "InterfaceIndex values must be numbers, such as 12 or 12,14."
                            break
                        }
                        $DnsParams.InterfaceIndex = [int[]]$IndexList
                    }

                    #Do the thing
                    Set-DNS @DnsParams | Format-Table -AutoSize | Out-Host
                }
                #Purge DNS
                8 {
                    #Ask the user for the item to purge
                    $UserItemToPurge = ConvertTo-CleanInput -InputString (Read-Host "Enter the host name, FQDN, or IPv4 address to remove. Such as DC01, DC01.Contoso.com, or 192.168.42.42")

                    # Blank input cancels
                    if ([string]::IsNullOrEmpty($UserItemToPurge)) {
                        Write-Information "Nothing entered. Cancelled." -InformationAction Continue
                        break
                    }

                    #Do the thing
                    Remove-DnsEntry -PurgeThis $UserItemToPurge | Format-Table -AutoSize | Out-Host

                    #Inform user
                    Write-Information "To fully clean up a removed server, run this for both its name and its IP address." -InformationAction Continue
                }
                #Search DHCP
                9 {
                    #Ask the user for the IP to find
                    $UserIpToFind = ConvertTo-CleanInput -InputString (Read-Host "Enter IP address that you want to search for")

                    #Do the thing
                    $DhcpResults = @(Get-DHCPLogInfo -IPAddress $UserIpToFind)
                    if ($DhcpResults.Count -eq 0) {
                        Write-Information "No DHCP log entries found for $UserIpToFind (logs cover about the last 7 days)." -InformationAction Continue
                    }
                    else {
                        $DhcpResults | Format-Table -AutoSize -Wrap | Out-Host
                    }

                }
                #Scan a network range
                10 {
                    #Ask the user for IPs
                    $UserStartIP = ConvertTo-CleanInput -InputString (Read-Host "Enter the start IP")
                    $UserEndIP = ConvertTo-CleanInput -InputString (Read-Host "Enter the end IP")

                    #Do the thing
                    $ScanResults = @(Find-NetworkHost -StartRange $UserStartIP -EndRange $UserEndIP -OnlyActive)

                    if ($ScanResults.Count -eq 0) {
                        Write-Information "No hosts responded. Note: hosts with ICMP blocked by firewall will not appear." -InformationAction Continue
                    }
                    else {
                        $ScanResults | Format-Table -AutoSize | Out-Host

                        $null = Save-ReportCsv -InputObject $ScanResults -BaseName NetworkScan
                    }

                }
                #Move or seize FSMO roles
                11 {
                    Write-Information "Current FSMO role holders:" -InformationAction Continue
                    Get-FsmoRoleHolder | Format-List | Out-Host

                    #Ask the user to use this computer or not
                    $UserSetPC = ConvertTo-CleanInput -InputString (Read-Host "Enter the name of the computer to move roles to. Leave blank for this computer ($env:COMPUTERNAME)")
                    if ([string]::IsNullOrEmpty($UserSetPC)) {
                        $UserSetPC = $env:COMPUTERNAME
                    }

                    $MoveOrSeize = ConvertTo-CleanInput -InputString (Read-Host "Would you like to:
1 - Transfer the FSMO roles (normal - the current role holders are online)
2 - Seize the FSMO roles (only if the current role holder is permanently offline)
")
                    if ($MoveOrSeize -notin '1', '2') {
                        Write-Information "Please enter 1 or 2." -InformationAction Continue
                        break
                    }

                    # Validate the role list BEFORE the confirmation prompt
                    $RoleMap = [ordered]@{
                        '1' = 'SchemaMaster'
                        '2' = 'DomainNamingMaster'
                        '3' = 'PDCEmulator'
                        '4' = 'RIDMaster'
                        '5' = 'InfrastructureMaster'
                    }
                    $RoleInput = ConvertTo-CleanInput -InputString (Read-Host "Which roles? Leave blank for all five, or enter numbers or names separated by commas:
1 - SchemaMaster
2 - DomainNamingMaster
3 - PDCEmulator
4 - RIDMaster
5 - InfrastructureMaster
")
                    $RoleList = [System.Collections.Generic.List[string]]::new()
                    $BadRoles = [System.Collections.Generic.List[string]]::new()
                    foreach ($Token in @($RoleInput -split '[,\s]+' | Where-Object { $_ })) {
                        $RoleName = if ($RoleMap.Contains($Token)) { $RoleMap[$Token] }
                                    else { @($RoleMap.Values) | Where-Object { $_ -eq $Token } | Select-Object -First 1 }
                        if ($RoleName) {
                            if (-not $RoleList.Contains($RoleName)) { $RoleList.Add($RoleName) }
                        }
                        else {
                            $BadRoles.Add($Token)
                        }
                    }
                    if ($BadRoles.Count -gt 0) {
                        Write-Warning "Unknown role(s): $($BadRoles -join ', '). Use 1-5 or the role names listed."
                        break
                    }
                    if ($RoleList.Count -eq 0) {
                        $RoleList.AddRange([string[]]@($RoleMap.Values))
                    }

                    $FsmoParams = @{
                        DestServer = $UserSetPC
                        Roles      = $RoleList.ToArray()
                        Confirm    = $false
                    }
                    if ($MoveOrSeize -eq '1') {
                        $Prompt = "Transfer $($RoleList -join ', ') to $UserSetPC."
                    }
                    else {
                        $Prompt = "SEIZE $($RoleList -join ', ') to $UserSetPC. The old role holder must never be brought back online after a seize."
                        $FsmoParams.Force = $true
                    }

                    if (Confirm-Action -Message $Prompt -ConfirmText $UserSetPC) {
                        Write-Information "FSMO role holders after the move (read from $UserSetPC):" -InformationAction Continue
                        Move-FSMO @FsmoParams | Format-List | Out-Host
                    }
                }
                #Metadata cleanup (confirmation prompts are inside the function)
                12 {
                    $DcToRmv = ConvertTo-CleanInput -InputString (Read-Host "Enter the name of the Domain Controller you would like to perform a metadata cleanup for. Leave blank to cancel")
                    if ([string]::IsNullOrEmpty($DcToRmv)) {
                        Write-Information "Cancelled." -InformationAction Continue
                        break
                    }
                    Invoke-MetaDataCleanup -DcToRemove $DcToRmv
                }
                #Reset krbtgt
                13 {
                    if (Confirm-Action -Message "Reset the krbtgt password. This is ONE of the two resets in a full rotation; the second must wait for the ticket-lifetime window (default 10 hours)." -ConfirmText 'krbtgt') {
                        Reset-KrbtgtPassword -Confirm:$false | Format-Table -AutoSize | Out-Host
                    }
                }
                14 {
                    $DcReport = @(Get-OrphanedDomainControllers)
                    $DcReport | Format-Table Name, Domain, Site, ComputerAccount, LdapReachable, LastReplicatedFrom, SuspectedOrphan -AutoSize | Out-Host

                    $Suspects = @($DcReport | Where-Object { $_.SuspectedOrphan })
                    if ($Suspects.Count -gt 0) {
                        foreach ($Suspect in $Suspects) {
                            Write-Warning "Suspected orphan: $($Suspect.Name) ($($Suspect.Domain)) - $($Suspect.Reason)"
                        }
                        Write-Warning "Confirm each DC is permanently offline before running metadata cleanup (option 12)."
                    }
                    else {
                        Write-Information "No suspected orphaned domain controllers found." -InformationAction Continue
                    }

                    $null = Save-ReportCsv -InputObject $DcReport -BaseName DcMetadataReport -Prompt 'Enter a folder or .csv path to save this report, or leave blank to skip'
                }
                15 {
                    Invoke-ADSchemaReplicationAllDCs
                }
                98 {
                    $WorkDirAnswer = Read-UserPath -Prompt "Enter the path you want to use for the working directory. Leave blank to keep $script:WorkDir"
                    if (-not [string]::IsNullOrEmpty($WorkDirAnswer)) {
                        $script:WorkDir = Set-ProjectFolder -BaseDir $WorkDirAnswer
                    }
                    Write-Information "The working folder is $script:WorkDir" -InformationAction Continue
                }
                99 {
                    # The loop condition ends the script; Exit was removed because it closed the whole PowerShell window
                    Write-Information "Thank you for using the AD Toolkit." -InformationAction Continue
                }

                default { Write-Warning "Invalid choice. Please choose an option from 0 to 15, 98, or 99/Q." }
            }
        }
        catch {
            Write-Warning "Option '$userChoice' failed: $($_.Exception.Message)"
            Write-Verbose ($_ | Out-String)
        }
        # One pause for every option so results stay on screen before the menu redraws
        if ($userChoice -ne '99') {
            $null = Read-Host -Prompt 'Press Enter to return to the menu'
        }
    } while ($userChoice -ne '99')
}
finally {
    # Runs on normal exit and on Ctrl+C
    if ($null -ne $script:OriginalForeground) {
        $Host.UI.RawUI.ForegroundColor = $script:OriginalForeground
    }
}

#endregion Do The Thing